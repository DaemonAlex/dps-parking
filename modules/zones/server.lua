--[[
    DPS-Parking - Zones Module (Server)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Server-side zone management.
]]

Zones = {}

-- ============================================
-- ZONE VALIDATION
-- ============================================

---Check if coordinates are in a no-parking zone
---@param coords vector3
---@param playerJob string|nil
---@return boolean inZone
---@return table|nil zone
function Zones.IsInNoParkingZone(coords, playerJob)
    return Utils.IsInNoParkingZone(coords, playerJob)
end

---Check if coordinates are in a parking lot
---@param coords vector3
---@return boolean inLot
---@return table|nil lot
function Zones.IsInParkingLot(coords)
    return Utils.IsInParkingLot(coords)
end

---Check if parking is allowed at coordinates
---@param coords vector3
---@param playerJob string|nil
---@return boolean allowed
---@return string|nil reason
function Zones.CanParkAt(coords, playerJob)
    -- Check no-parking zones first
    local inNoParking, zone = Zones.IsInNoParkingZone(coords, playerJob)
    if inNoParking then
        if zone.jobs and #zone.jobs > 0 then
            return false, L('restricted_area', table.concat(zone.jobs, ', '))
        else
            return false, L('no_parking_zone')
        end
    end

    -- Check if parking lots only mode
    if Config.Zones.useParkingLotsOnly then
        local inLot = Zones.IsInParkingLot(coords)
        if not inLot then
            return false, L('parking_lot_only')
        end
    end

    return true, nil
end

-- ============================================
-- PARKING LOT MANAGEMENT
-- ============================================

---Get parking lot by ID
---@param lotId number
---@return table|nil
function Zones.GetParkingLot(lotId)
    for _, lot in ipairs(Config.ParkingLots) do
        if lot.id == lotId then
            return lot
        end
    end
    return nil
end

---Get all parking lots
---@return table
function Zones.GetAllParkingLots()
    return Config.ParkingLots
end

---Get vehicles parked in a lot
---@param lotId number
---@return table
function Zones.GetVehiclesInLot(lotId)
    local lot = Zones.GetParkingLot(lotId)
    if not lot then return {} end

    local vehicles = {}
    local allParked = State.GetAllParkedVehicles()

    for plate, data in pairs(allParked) do
        if data.location then
            local coords = vector3(data.location.x, data.location.y, data.location.z)
            if Utils.IsInRadius(coords, lot.coords, lot.radius) then
                vehicles[plate] = data
            end
        end
    end

    return vehicles
end

---Count vehicles in a lot
---@param lotId number
---@return number
function Zones.CountVehiclesInLot(lotId)
    return Utils.Count(Zones.GetVehiclesInLot(lotId))
end

-- ============================================
-- PRIVATE PARKING ZONES
-- ============================================

---Add private parking zone
---@param data table
---@return boolean success
function Zones.AddPrivateZone(data)
    if not data.coords or not data.citizenid then
        return false
    end

    local id = #Config.PrivateParking + 1
    data.id = id

    Config.PrivateParking[id] = data

    -- Notify clients
    TriggerClientEvent('dps-parking:client:zoneAdded', -1, data)

    return true
end

---Remove private parking zone
---@param zoneId number
---@return boolean success
function Zones.RemovePrivateZone(zoneId)
    if not Config.PrivateParking[zoneId] then
        return false
    end

    table.remove(Config.PrivateParking, zoneId)

    -- Notify clients
    TriggerClientEvent('dps-parking:client:zoneRemoved', -1, { zoneId = zoneId })

    return true
end

-- ============================================
-- HOOKS FOR PARKING
-- ============================================

-- Register pre-hook for zone validation
EventBus.RegisterPreHook('parking:park', function(data)
    local source = data.source
    local coords = data.data and data.data.location

    if not coords then
        return true, data -- No location data, skip check
    end

    local coordsVec = vector3(coords.x, coords.y, coords.z)
    local playerJob = Bridge.GetPlayerJob(source)

    local canPark, reason = Zones.CanParkAt(coordsVec, playerJob)

    if not canPark then
        Bridge.Notify(source, reason, 'error')
        return false, data
    end

    -- Attach lot info if in a lot
    local inLot, lot = Zones.IsInParkingLot(coordsVec)
    if inLot then
        data.lot = lot
    end

    return true, data
end, EventBus.Priority.HIGH)

-- ============================================
-- EXPORTS
-- ============================================

exports('IsInNoParkingZone', Zones.IsInNoParkingZone)
exports('IsInParkingLot', Zones.IsInParkingLot)
exports('CanParkAt', Zones.CanParkAt)
exports('GetParkingLot', Zones.GetParkingLot)
exports('GetVehiclesInLot', Zones.GetVehiclesInLot)

print('^2[DPS-Parking] Zones module (server) loaded^0')

return Zones
