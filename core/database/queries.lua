--[[
    DPS-Parking - Database Queries
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Optimized queries using JSON columns for single-fetch operations.
    All vehicle metadata (damage, fuel, mods) in one query.
]]

DB = {}

-- ============================================
-- VEHICLE QUERIES (Single-fetch with JSON)
-- ============================================

---Get all parked vehicles with full state in ONE query
---@return table
function DB.GetAllParkedVehicles()
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    local result = MySQL.query.await(([[
        SELECT
            plate,
            %s as owner,
            vehicle,
            parking_data,
            vehicle_state,
            parking_lot,
            parked_at
        FROM %s
        WHERE %s = ?
    ]]):format(
        Bridge.DB.GetOwnerColumn(),
        tbl,
        state
    ), {Bridge.DB.States.PARKED})

    if not result then return {} end

    -- Parse JSON columns
    local vehicles = {}
    for _, row in ipairs(result) do
        local parkingData = row.parking_data and json.decode(row.parking_data) or {}
        local vehicleState = row.vehicle_state and json.decode(row.vehicle_state) or {}

        vehicles[row.plate] = {
            plate = row.plate,
            citizenid = row.owner,
            vehicle = row.vehicle,
            -- Parking location data
            location = parkingData.location,
            street = parkingData.street,
            steerangle = parkingData.steerangle,
            heading = parkingData.heading,
            -- Vehicle state data
            mods = vehicleState.mods,
            damage = vehicleState.damage,
            fuel = vehicleState.fuel,
            extras = vehicleState.extras,
            neon = vehicleState.neon,
            -- Metadata
            lotId = row.parking_lot,
            parkedAt = row.parked_at,
        }
    end

    return vehicles
end

---Get player's parked vehicles with full state
---@param citizenid string
---@return table
function DB.GetPlayerParkedVehicles(citizenid)
    local tbl = Bridge.DB.GetVehicleTable()
    local owner = Bridge.DB.GetOwnerColumn()
    local state = Bridge.DB.GetStateColumn()

    local result = MySQL.query.await(([[
        SELECT
            plate,
            vehicle,
            parking_data,
            vehicle_state,
            parking_lot,
            parked_at
        FROM %s
        WHERE %s = ? AND %s = ?
    ]]):format(tbl, owner, state), {citizenid, Bridge.DB.States.PARKED})

    if not result then return {} end

    local vehicles = {}
    for _, row in ipairs(result) do
        local parkingData = row.parking_data and json.decode(row.parking_data) or {}
        local vehicleState = row.vehicle_state and json.decode(row.vehicle_state) or {}

        vehicles[row.plate] = {
            plate = row.plate,
            citizenid = citizenid,
            vehicle = row.vehicle,
            location = parkingData.location,
            street = parkingData.street,
            steerangle = parkingData.steerangle,
            mods = vehicleState.mods,
            damage = vehicleState.damage,
            fuel = vehicleState.fuel,
            extras = vehicleState.extras,
            lotId = row.parking_lot,
            parkedAt = row.parked_at,
        }
    end

    return vehicles
end

---Park vehicle with full state (single INSERT/UPDATE)
---@param plate string
---@param citizenid string
---@param data table Full vehicle data
function DB.ParkVehicle(plate, citizenid, data)
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    -- Build JSON objects
    local parkingData = json.encode({
        location = data.location,
        street = data.street,
        steerangle = data.steerangle,
        heading = data.heading,
    })

    local vehicleState = json.encode({
        mods = data.mods,
        damage = data.damage,
        fuel = data.fuel,
        extras = data.extras,
        neon = data.neon,
    })

    MySQL.update.await(([[
        UPDATE %s SET
            %s = ?,
            parking_data = ?,
            vehicle_state = ?,
            parking_lot = ?,
            parked_at = NOW()
        WHERE plate = ?
    ]]):format(tbl, state), {
        Bridge.DB.States.PARKED,
        parkingData,
        vehicleState,
        data.lotId,
        plate
    })

    Utils.Debug(('DB: Parked vehicle %s with full state'):format(plate))
end

---Unpark vehicle (clear parking data)
---@param plate string
function DB.UnparkVehicle(plate)
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    MySQL.update.await(([[
        UPDATE %s SET
            %s = ?,
            parking_data = NULL,
            vehicle_state = NULL,
            parking_lot = NULL,
            parked_at = NULL
        WHERE plate = ?
    ]]):format(tbl, state), {
        Bridge.DB.States.OUT,
        plate
    })
end

---Update only vehicle state (damage, fuel) without changing location
---@param plate string
---@param vehicleState table
function DB.UpdateVehicleState(plate, vehicleState)
    local tbl = Bridge.DB.GetVehicleTable()

    MySQL.update.await(([[
        UPDATE %s SET
            vehicle_state = ?
        WHERE plate = ?
    ]]):format(tbl), {
        json.encode(vehicleState),
        plate
    })
end

-- ============================================
-- VIP QUERIES
-- ============================================

---Get all VIP players
---@return table
function DB.GetAllVipPlayers()
    local result = MySQL.query.await([[
        SELECT citizenid, slots, perks, expires_at
        FROM dps_parking_vip
        WHERE expires_at IS NULL OR expires_at > NOW()
    ]])

    if not result then return {} end

    local vips = {}
    for _, row in ipairs(result) do
        vips[row.citizenid] = {
            citizenid = row.citizenid,
            slots = row.slots,
            perks = row.perks and json.decode(row.perks) or {},
            expiresAt = row.expires_at,
        }
    end

    return vips
end

---Set VIP player
---@param citizenid string
---@param slots number
---@param perks table|nil
---@param expiresAt string|nil
function DB.SetVipPlayer(citizenid, slots, perks, expiresAt)
    MySQL.insert.await([[
        INSERT INTO dps_parking_vip (citizenid, slots, perks, expires_at)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            slots = VALUES(slots),
            perks = VALUES(perks),
            expires_at = VALUES(expires_at)
    ]], {
        citizenid,
        slots,
        perks and json.encode(perks) or nil,
        expiresAt
    })
end

---Remove VIP player
---@param citizenid string
function DB.RemoveVipPlayer(citizenid)
    MySQL.query.await([[
        DELETE FROM dps_parking_vip WHERE citizenid = ?
    ]], {citizenid})
end

-- ============================================
-- BUSINESS QUERIES
-- ============================================

---Get all business owners
---@return table
function DB.GetAllBusinessOwners()
    local result = MySQL.query.await([[
        SELECT lot_id, citizenid, purchased_at, revenue, employees, upgrades, settings
        FROM dps_parking_business
    ]])

    if not result then return {} end

    local owners = {}
    for _, row in ipairs(result) do
        owners[row.lot_id] = {
            lotId = row.lot_id,
            citizenid = row.citizenid,
            purchasedAt = row.purchased_at,
            revenue = row.revenue,
            employees = row.employees and json.decode(row.employees) or {},
            upgrades = row.upgrades and json.decode(row.upgrades) or {},
            settings = row.settings and json.decode(row.settings) or {},
        }
    end

    return owners
end

---Set business owner
---@param lotId string
---@param data table
function DB.SetBusinessOwner(lotId, data)
    MySQL.insert.await([[
        INSERT INTO dps_parking_business (lot_id, citizenid, revenue, employees, upgrades, settings)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            citizenid = VALUES(citizenid),
            revenue = VALUES(revenue),
            employees = VALUES(employees),
            upgrades = VALUES(upgrades),
            settings = VALUES(settings)
    ]], {
        lotId,
        data.citizenid,
        data.revenue or 0,
        data.employees and json.encode(data.employees) or nil,
        data.upgrades and json.encode(data.upgrades) or nil,
        data.settings and json.encode(data.settings) or nil,
    })
end

---Update business revenue
---@param lotId string
---@param revenue number
function DB.UpdateBusinessRevenue(lotId, revenue)
    MySQL.update.await([[
        UPDATE dps_parking_business SET revenue = ? WHERE lot_id = ?
    ]], {revenue, lotId})
end

---Remove business owner
---@param lotId string
function DB.RemoveBusinessOwner(lotId)
    MySQL.query.await([[
        DELETE FROM dps_parking_business WHERE lot_id = ?
    ]], {lotId})
end

-- ============================================
-- METER QUERIES
-- ============================================

---Get active meter for plate
---@param plate string
---@return table|nil
function DB.GetActiveMeter(plate)
    local result = MySQL.query.await([[
        SELECT id, plate, citizenid, zone, paid_amount, started_at, expires_at
        FROM dps_parking_meters
        WHERE plate = ? AND status = 'active'
        LIMIT 1
    ]], {plate})

    if result and #result > 0 then
        return result[1]
    end
    return nil
end

---Create meter session
---@param plate string
---@param citizenid string
---@param zone string
---@param paidAmount number
---@param minutes number
function DB.CreateMeterSession(plate, citizenid, zone, paidAmount, minutes)
    MySQL.insert.await([[
        INSERT INTO dps_parking_meters (plate, citizenid, zone, paid_amount, expires_at)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {plate, citizenid, zone, paidAmount, minutes})
end

---Expire meter
---@param plate string
function DB.ExpireMeter(plate)
    MySQL.update.await([[
        UPDATE dps_parking_meters SET status = 'expired' WHERE plate = ? AND status = 'active'
    ]], {plate})
end

-- ============================================
-- AUDIT QUERIES
-- ============================================

---Log audit entry
---@param action string
---@param citizenid string|nil
---@param plate string|nil
---@param details table|nil
function DB.AuditLog(action, citizenid, plate, details)
    MySQL.insert.await([[
        INSERT INTO dps_parking_audit (action, citizenid, plate, details)
        VALUES (?, ?, ?, ?)
    ]], {
        action,
        citizenid,
        plate,
        details and json.encode(details) or nil
    })
end

print('^2[DPS-Parking] Database queries loaded^0')

return DB
