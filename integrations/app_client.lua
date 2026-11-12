--[[
    DPS-Parking - Parking app (phone + tablet), CLIENT
    DelPerroSands 2026-10-26

    The app page (ui/phone/index.html) runs inside the phone or tablet frame and calls
    these NUI callbacks. The game-only parts live here: vehicle labels, distances, the
    waypoint, and where the player stands for a delivery. Everything else is forwarded
    to the server callbacks in integrations/app_server.lua.
]]

local APP = 'dps-parking'

local function ask(name, ...)
    local ok, r = pcall(lib.callback.await, name, false, ...)
    if ok and type(r) == 'table' then return r end
    return { ok = false, message = 'No answer from the city. Try again in a moment.' }
end

local labelCache = {}
local function label(model)
    if not model then return 'Vehicle' end
    if labelCache[model] then return labelCache[model] end
    local hash = type(model) == 'string' and joaat(model) or model
    local name = GetDisplayNameFromVehicleModel(hash)
    local text = name and name ~= 'NULL' and name ~= 'CARNOTFOUND' and GetLabelText(name) or nil
    if not text or text == 'NULL' then text = type(model) == 'string' and model:upper() or 'Vehicle' end
    labelCache[model] = text
    return text
end

local function here()
    local ped = cache.ped or PlayerPedId()
    return GetEntityCoords(ped), GetEntityHeading(ped)
end

RegisterNUICallback('appSummary', function(_, cb)
    local data = ask('dps-parking:app:summary')
    if data.ok then
        local pc = here()
        for _, car in ipairs(data.cars or {}) do
            car.label = label(car.model)
            if car.location then
                car.distance = #(pc - vector3(car.location.x, car.location.y, car.location.z))
            end
        end
        for _, v in ipairs(data.impounded or {}) do v.label = label(v.model) end
        for _, lot in ipairs(data.lots or {}) do
            if lot.coords then lot.distance = #(pc - vector3(lot.coords.x, lot.coords.y, lot.coords.z)) end
        end
    end
    cb(data)
end)

RegisterNUICallback('appFind', function(d, cb)
    local x, y = tonumber(d and d.x), tonumber(d and d.y)
    if not x or not y then cb({ ok = false, message = 'No position for that car' }) return end
    SetNewWaypoint(x + 0.0, y + 0.0)
    cb({ ok = true, message = 'Waypoint set' })
end)

RegisterNUICallback('appQuoteMeter', function(d, cb)
    cb(ask('dps-parking:app:quoteMeter', d and d.plate, d and d.minutes))
end)

RegisterNUICallback('appPayMeter', function(d, cb)
    cb(ask('dps-parking:app:payMeter', d and d.plate, d and d.minutes))
end)

RegisterNUICallback('appBring', function(d, cb)
    local c, h = here()
    cb(ask('dps-parking:app:requestDelivery', d and d.plate, { x = c.x, y = c.y, z = c.z, h = h }, d and d.rush == true))
end)

RegisterNUICallback('appCancelDelivery', function(d, cb)
    cb(ask('dps-parking:app:cancelDelivery', d and d.id))
end)

RegisterNUICallback('appPayTicket', function(d, cb)
    cb(ask('dps-parking:app:payTicket', d and d.id))
end)

RegisterNUICallback('appContestTicket', function(d, cb)
    cb(ask('dps-parking:app:contestTicket', d and d.id, d and d.reason))
end)

RegisterNUICallback('appRelease', function(d, cb)
    cb(ask('dps-parking:app:releaseImpound', d and d.plate))
end)

RegisterNUICallback('appBuyLot', function(d, cb)
    cb(ask('dps-parking:app:buyLot', d and d.lotId))
end)

RegisterNUICallback('appCollect', function(d, cb)
    cb(ask('dps-parking:app:collect', d and d.lotId))
end)

RegisterNUICallback('appSetPrice', function(d, cb)
    cb(ask('dps-parking:app:setPrice', d and d.lotId, d and d.price))
end)

RegisterNUICallback('appUpgrade', function(d, cb)
    cb(ask('dps-parking:app:buyUpgrade', d and d.lotId, d and d.key))
end)

-- Tell an open app page to reload when something it shows has changed.
local function pokeApp(action)
    pcall(function() exports['lb-phone']:SendCustomAppMessage(APP, { action = action }) end)
    pcall(function() exports['lb-tablet']:SendCustomAppMessage(APP, action, false) end)
end

for _, ev in ipairs({
    'dps-parking:client:meterPaid', 'dps-parking:client:meterExpired', 'dps-parking:client:deliveryArrived',
    'dps-parking:client:receivedTicket', 'dps-parking:client:vehicleImpounded', 'dps-parking:client:stateSync',
}) do
    RegisterNetEvent(ev, function() pokeApp('refresh') end)
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() pokeApp('reset') end)

print('^2[DPS-Parking] Parking app (client) loaded^0')
