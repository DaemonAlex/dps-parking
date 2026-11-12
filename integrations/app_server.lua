--[[
    DPS-Parking - Parking app (phone + tablet), SERVER
    DelPerroSands 2026-10-26

    Every callback here is ox_lib style: it RETURNS its answer. Bridge.CreateCallback
    hands ox_lib the old cb-style handlers, which never answer, so the app does not use it.
    All money and ownership rules stay in the modules (Meters.Pay, Delivery.Request,
    Violations.*, Impound.RetrieveVehicle, Business.*); this file only reads state and
    forwards actions.
]]

local function result(ok, message)
    return { ok = ok and true or false, message = message }
end

local function ownerOf(lotId)
    return State.GetBusinessOwner(lotId) or State.GetBusinessOwner(tostring(lotId))
end

local function lotFor(rec)
    if not rec or not rec.location then return nil end
    local inLot, lot = Zones.IsInParkingLot(vector3(rec.location.x, rec.location.y, rec.location.z))
    if inLot and lot then return lot end
    return nil
end

local function lotCapacity(lot, owner)
    local cap = lot.capacity or 0
    if owner and owner.upgrades and owner.upgrades.capacity then cap = cap + 10 end
    return cap
end

local function lotPrice(lot, owner)
    local set = owner and owner.settings and tonumber(owner.settings.price)
    if set and set > 0 then return math.floor(set) end
    return lot.basePrice or Config.Parking.parkingFee
end

local function modelsByPlate(plates)
    local out = {}
    if #plates == 0 then return out end
    local marks = {}
    for i = 1, #plates do marks[i] = '?' end
    local rows = MySQL.query.await(('SELECT plate, vehicle FROM player_vehicles WHERE plate IN (%s)'):format(table.concat(marks, ',')), plates) or {}
    for _, row in ipairs(rows) do out[Utils.FormatPlate(row.plate)] = row.vehicle end
    return out
end

local function myCars(citizenid)
    local cars = {}
    for plate, rec in pairs(State.GetPlayerParkedVehicles(citizenid) or {}) do
        local lot = lotFor(rec)
        local meter = State.GetActiveMeter(plate)
        cars[#cars + 1] = {
            plate = plate,
            model = rec.model,
            street = rec.street,
            location = rec.location and { x = rec.location.x, y = rec.location.y, z = rec.location.z } or nil,
            parkedAt = rec.parkedAt,
            lot = lot and { id = lot.id, name = lot.name } or nil,
            meter = meter and { expiresAt = meter.expiresAt, paidAmount = meter.paidAmount, minutes = meter.minutes } or nil,
        }
    end
    table.sort(cars, function(a, b) return (a.parkedAt or 0) > (b.parkedAt or 0) end)
    return cars
end

local function myImpounded(citizenid)
    local list = Impound.GetPlayerVehicles(citizenid) or {}
    local seen, plates = {}, {}
    for _, v in ipairs(list) do
        v.plate = Utils.FormatPlate(v.plate)
        seen[v.plate] = true
        plates[#plates + 1] = v.plate
    end
    -- Cars towed by the meter timer or the 3-day timer only exist as state 2 in the DB.
    local rows = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ? AND state = 2', { citizenid }) or {}
    for _, row in ipairs(rows) do
        local plate = Utils.FormatPlate(row.plate)
        if not seen[plate] then
            local fee, discount, reason = Impound.CalculateFee(plate)
            list[#list + 1] = { plate = plate, model = row.vehicle, reason = reason or 'Impounded', fee = fee or 0, discount = discount or 0 }
            seen[plate] = true
            plates[#plates + 1] = plate
        end
    end
    local models = modelsByPlate(plates)
    for _, v in ipairs(list) do v.model = v.model or models[v.plate] end
    return list
end

local function myTickets(citizenid)
    local out = {}
    for _, t in ipairs(Violations.GetPlayerTickets(citizenid) or {}) do
        if t.status == 'unpaid' or t.status == 'contested' then out[#out + 1] = t end
    end
    table.sort(out, function(a, b) return (a.issuedAt or 0) > (b.issuedAt or 0) end)
    return out
end

local function upgradeList()
    local out = {}
    for key, u in pairs(Config.Business.upgrades or {}) do
        out[#out + 1] = { key = key, cost = u.cost, description = u.description }
    end
    table.sort(out, function(a, b) return a.cost < b.cost end)
    return out
end

local function lots(citizenid)
    local out = {}
    for _, lot in ipairs(Config.ParkingLots or {}) do
        local owner = ownerOf(lot.id)
        local mine = owner ~= nil and owner.citizenid == citizenid
        local used = Zones.CountVehiclesInLot(lot.id) or 0
        local cap = lotCapacity(lot, owner)
        local base = lot.basePrice or Config.Parking.parkingFee
        local entry = {
            id = lot.id, name = lot.name,
            capacity = cap, used = used, free = math.max(0, cap - used),
            price = lotPrice(lot, owner), basePrice = base,
            purchasePrice = lot.purchasePrice, forSale = owner == nil, mine = mine,
            coords = { x = lot.coords.x, y = lot.coords.y, z = lot.coords.z },
        }
        if mine then
            entry.revenue = owner.revenue or 0
            entry.upgrades = owner.upgrades or {}
            entry.minPrice = math.floor(base * (Config.Business.minPriceMultiplier or 0.5))
            entry.maxPrice = math.floor(base * (Config.Business.maxPriceMultiplier or 3.0))
        end
        out[#out + 1] = entry
    end
    return out
end

-- ============================================
-- READ
-- ============================================

lib.callback.register('dps-parking:app:summary', function(source)
    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then return result(false, 'Not logged in') end

    local tier, tierData = Delivery.GetPlayerTier(citizenid)
    local job = Bridge.GetPlayerJob(source)
    local jobDiscount = (job and Config.Delivery.discounts and Config.Delivery.discounts[job]) or 0

    return {
        ok = true,
        now = os.time(),
        cars = myCars(citizenid),
        deliveries = Delivery.GetActive(source) or {},
        tickets = myTickets(citizenid),
        impounded = myImpounded(citizenid),
        lots = lots(citizenid),
        money = { cash = Bridge.GetMoney(source, 'cash') or 0, bank = Bridge.GetMoney(source, 'bank') or 0 },
        slots = { used = State.CountPlayerParkedVehicles(citizenid), max = State.GetMaxSlots(citizenid) },
        isVip = State.IsVip(citizenid),
        tier = tier,
        rules = {
            ratePerHour = Config.Meters.ratePerHour,
            minMinutes = Config.Meters.minimumMinutes,
            maxMinutes = Config.Meters.maximumMinutes,
            graceMinutes = Config.Meters.graceMinutes,
            towAfterMinutes = Config.Meters.towAfterMinutes,
            freeParking = Config.Meters.freeParking,
            delivery = {
                baseCost = Config.Delivery.baseCost or 500,
                rushMultiplier = Config.Delivery.rushMultiplier or 2.0,
                standardTime = Config.Delivery.standardTime or 5,
                rushTime = Config.Delivery.rushTime or 2,
                maxPerHour = tierData.maxPerHour,
                discount = tierData.discount or 0,
                jobDiscount = jobDiscount,
                rushAvailable = tierData.rushAvailable and true or false,
                priorityMinutes = tierData.priorityMinutes or 0,
            },
            upgrades = upgradeList(),
            ownerCut = Config.Business.ownerRevenuePercent,
            tax = Config.Business.taxPercent,
            maxLots = Config.Business.maxLotsPerPlayer,
        },
    }
end)

lib.callback.register('dps-parking:app:quoteMeter', function(source, plate, minutes)
    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then return result(false, 'Not logged in') end
    local cost, mins = Meters.Quote(citizenid, Utils.FormatPlate(tostring(plate or '')), tonumber(minutes) or 0)
    return { ok = true, cost = cost, minutes = mins }
end)

-- ============================================
-- ACTIONS
-- ============================================

lib.callback.register('dps-parking:app:payMeter', function(source, plate, minutes)
    plate = Utils.FormatPlate(tostring(plate or ''))
    local ok, msg = Meters.Pay(source, plate, tonumber(minutes) or 0)
    local r = result(ok, msg)
    if ok then
        local m = State.GetActiveMeter(plate)
        r.expiresAt = m and m.expiresAt or nil
    end
    return r
end)

lib.callback.register('dps-parking:app:requestDelivery', function(source, plate, coords, rush)
    if type(coords) ~= 'table' or not tonumber(coords.x) then return result(false, 'No position') end
    plate = Utils.FormatPlate(tostring(plate or ''))
    local ok, msg = Delivery.Request(source, plate, coords, { rush = rush == true, withDriver = false })
    return result(ok, msg)
end)

lib.callback.register('dps-parking:app:cancelDelivery', function(source, deliveryId)
    local ok, msg = Delivery.Cancel(source, tostring(deliveryId or ''))
    return result(ok, msg)
end)

lib.callback.register('dps-parking:app:payTicket', function(source, ticketId)
    local ok, msg = Violations.PayTicket(source, tostring(ticketId or ''))
    return result(ok, msg)
end)

lib.callback.register('dps-parking:app:contestTicket', function(source, ticketId, reason)
    reason = tostring(reason or ''):sub(1, 300)
    if reason == '' then return result(false, 'Say why you dispute it') end
    local ok, msg = Violations.ContestTicket(source, tostring(ticketId or ''), reason)
    return result(ok, msg)
end)

-- Release from impound: the fee is paid through Impound.RetrieveVehicle, then the car is
-- put back in the owner's last garage (the in-world flow spawns it at the lot instead).
lib.callback.register('dps-parking:app:releaseImpound', function(source, plate)
    plate = Utils.FormatPlate(tostring(plate or ''))
    local ok, msg = Impound.RetrieveVehicle(source, plate)
    local r = result(ok, msg)
    if not ok then return r end

    local row = MySQL.single.await('SELECT garage, garage_id FROM player_vehicles WHERE plate = ?', { plate })
    local garage = row and (row.garage_id or row.garage) or nil
    if GetResourceState('jg-advancedgarages') == 'started' then
        pcall(function() exports['jg-advancedgarages']:setVehicleState(plate, 1, garage) end)
    else
        MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE plate = ?', { plate })
    end
    r.garage = garage
    r.message = (msg or 'Released') .. '. The car is back in your garage.'
    return r
end)

lib.callback.register('dps-parking:app:buyLot', function(source, lotId)
    local ok, msg = Business.PurchaseLot(source, tonumber(lotId))
    return result(ok, msg)
end)

lib.callback.register('dps-parking:app:collect', function(source, lotId)
    local ok, msg = Business.CollectRevenue(source, tonumber(lotId))
    return result(ok, msg)
end)

local function myLot(source, lotId)
    local citizenid = Bridge.GetCitizenId(source)
    lotId = tonumber(lotId)
    local lot = lotId and Zones.GetParkingLot(lotId)
    if not citizenid or not lot then return nil, nil, nil, 'Lot not found' end
    local owner = ownerOf(lotId)
    if not owner or owner.citizenid ~= citizenid then return nil, nil, nil, L('not_lot_owner') end
    return citizenid, lot, owner
end

lib.callback.register('dps-parking:app:setPrice', function(source, lotId, price)
    local citizenid, lot, owner, err = myLot(source, lotId)
    if not owner then return result(false, err) end
    price = math.floor(tonumber(price) or 0)
    local base = lot.basePrice or Config.Parking.parkingFee
    local minP = math.floor(base * (Config.Business.minPriceMultiplier or 0.5))
    local maxP = math.floor(base * (Config.Business.maxPriceMultiplier or 3.0))
    if price < minP or price > maxP then
        return result(false, ('Price must be between %s and %s'):format(Utils.FormatMoney(minP), Utils.FormatMoney(maxP)))
    end
    owner.settings = owner.settings or {}
    owner.settings.price = price
    State.SetBusinessOwner(lot.id, owner)
    DB.SetBusinessOwner(lot.id, owner)
    if DB.AuditLog then DB.AuditLog('lot_price', citizenid, nil, { lotId = lot.id, price = price }) end
    return { ok = true, message = ('%s now charges %s an hour'):format(lot.name, Utils.FormatMoney(price)), price = price }
end)

lib.callback.register('dps-parking:app:buyUpgrade', function(source, lotId, key)
    local citizenid, lot, owner, err = myLot(source, lotId)
    if not owner then return result(false, err) end
    key = tostring(key or '')
    local up = Config.Business.upgrades and Config.Business.upgrades[key]
    if not up then return result(false, 'No such upgrade') end
    owner.upgrades = owner.upgrades or {}
    if owner.upgrades[key] then return result(false, 'Already installed') end
    if (Bridge.GetMoney(source, 'bank') or 0) < up.cost then
        return result(false, L('insufficient_funds', Utils.FormatMoney(up.cost)))
    end
    if not Bridge.RemoveMoney(source, 'bank', up.cost, 'Parking lot upgrade: ' .. key) then
        return result(false, L('error'))
    end
    owner.upgrades[key] = true
    State.SetBusinessOwner(lot.id, owner)
    DB.SetBusinessOwner(lot.id, owner)
    if DB.AuditLog then DB.AuditLog('lot_upgrade', citizenid, nil, { lotId = lot.id, upgrade = key, cost = up.cost }) end
    return { ok = true, message = ('%s installed at %s'):format(up.description or key, lot.name) }
end)

print('^2[DPS-Parking] Parking app (server) loaded^0')
