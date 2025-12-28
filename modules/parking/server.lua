--[[
    DPS-Parking - Parking Module (Server)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Core parking functionality.
]]

Parking = {}

local hasSpawned = false

-- ============================================
-- INITIALIZATION
-- ============================================

---Load all parked vehicles from database and spawn them
function Parking.Initialize()
    if hasSpawned then return end
    hasSpawned = true

    Utils.Debug('Initializing parking system...')

    -- Get all parked vehicles from database
    local vehicles = Bridge.DB.GetAllParkedVehicles()

    if not vehicles or #vehicles == 0 then
        Utils.Debug('No parked vehicles found in database')
        return
    end

    Utils.Debug(('Found %d parked vehicles to spawn'):format(#vehicles))

    for _, vehicle in ipairs(vehicles) do
        Parking.SpawnParkedVehicle(vehicle)
    end

    Utils.Debug(('Spawned %d parked vehicles'):format(State.CountAll('parkedVehicles')))
end

---Spawn a single parked vehicle
---@param vehicleData table Database vehicle record
---@return boolean success
function Parking.SpawnParkedVehicle(vehicleData)
    if not vehicleData or not vehicleData.plate then
        return false
    end

    -- Check if already spawned
    if State.IsVehicleParked(vehicleData.plate) then
        return false
    end

    -- Parse location
    local location = vehicleData.location
    if type(location) == 'string' then
        location = json.decode(location)
    end

    if not location then
        Utils.Debug(('Invalid location for plate %s'):format(vehicleData.plate))
        return false
    end

    -- Delete any existing vehicle at location
    Parking.DeleteVehicleAtCoords(vector3(location.x, location.y, location.z))
    Wait(100)

    -- Get vehicle hash
    local modelHash = GetHashKey(vehicleData.vehicle)
    local vehType = 'automobile'

    -- Check vehicle types from config
    if Config.Vehicles and Config.Vehicles[vehicleData.vehicle] then
        vehType = Config.Vehicles[vehicleData.vehicle].type or 'automobile'
    end

    -- Spawn vehicle
    local entity = CreateVehicleServerSetter(modelHash, vehType, location.x, location.y, location.z, location.h or location.w or 0.0)

    local attempts = 0
    while not DoesEntityExist(entity) and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end

    if not DoesEntityExist(entity) then
        Utils.Debug(('Failed to spawn vehicle %s'):format(vehicleData.plate))
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)

    -- Set plate
    SetVehicleNumberPlateText(entity, vehicleData.plate)

    -- Get owner name
    local ownerName = 'Unknown'
    local citizenid = vehicleData.citizenid or vehicleData.owner
    if citizenid then
        local playerData = Bridge.GetPlayerByCitizenId(citizenid)
        if playerData then
            if Bridge.IsESX() then
                ownerName = playerData.getName and playerData.getName() or 'Unknown'
            else
                local charinfo = playerData.PlayerData and playerData.PlayerData.charinfo
                if charinfo then
                    ownerName = charinfo.firstname .. ' ' .. charinfo.lastname
                end
            end
        end
    end

    -- Parse mods
    local mods = vehicleData.mods
    if type(mods) == 'string' then
        mods = json.decode(mods)
    end

    -- Store in state
    State.SetParkedVehicle(vehicleData.plate, {
        citizenid = citizenid,
        fullname = ownerName,
        netid = netId,
        entity = entity,
        plate = vehicleData.plate,
        model = vehicleData.vehicle,
        hash = modelHash,
        mods = mods,
        fuel = vehicleData.fuel or 100,
        body = vehicleData.body or 1000,
        engine = vehicleData.engine or 1000,
        street = vehicleData.street or '',
        steerangle = vehicleData.steerangle or 0,
        location = location,
        trailerdata = vehicleData.trailerdata,
        parkedAt = os.time(),
    })

    -- Notify clients
    TriggerClientEvent('dps-parking:client:vehicleSpawned', -1, {
        plate = vehicleData.plate,
        netId = netId,
        data = State.GetParkedVehicle(vehicleData.plate)
    })

    return true
end

-- ============================================
-- PARKING ACTIONS
-- ============================================

---Park a vehicle
---@param source number Player source
---@param data table { netId, plate, location, steerangle, street, fuel, trailerdata }
---@return boolean success
---@return string message
function Parking.Park(source, data)
    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then
        return false, L('error')
    end

    -- Execute with hooks
    local shouldContinue, modifiedData = EventBus.ExecutePreHooks('parking:park', {
        source = source,
        citizenid = citizenid,
        data = data
    })

    if not shouldContinue then
        return false, L('parking_failed')
    end

    data = modifiedData and modifiedData.data or data

    -- Check slot limit
    if not State.CanPlayerPark(citizenid) then
        local used = State.CountPlayerParkedVehicles(citizenid)
        local max = State.GetMaxSlots(citizenid)
        return false, L('max_slots_reached', used, max)
    end

    -- Verify ownership
    if not Bridge.DB.PlayerOwnsVehicle(citizenid, data.plate) then
        return false, L('vehicle_not_owned')
    end

    -- Check if already parked
    if State.IsVehicleParked(data.plate) then
        return false, L('already_parked')
    end

    -- Get vehicle entity
    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if not DoesEntityExist(vehicle) then
        return false, L('no_vehicle')
    end

    -- Get owner name
    local ownerName = Bridge.GetPlayerName(source)

    -- Get vehicle data from database
    local tbl = Bridge.DB.GetVehicleTable()
    local owner = Bridge.DB.GetOwnerColumn()
    local vehicleRecord = MySQL.query.await(
        ('SELECT * FROM %s WHERE %s = ? AND plate = ?'):format(tbl, owner),
        {citizenid, data.plate}
    )[1]

    if not vehicleRecord then
        return false, L('vehicle_not_owned')
    end

    -- Update database
    Bridge.DB.SetVehicleParked(
        data.plate,
        data.location,
        data.street,
        data.steerangle,
        data.fuel,
        data.trailerdata
    )

    -- Parse mods
    local mods = vehicleRecord.mods
    if type(mods) == 'string' then
        mods = json.decode(mods)
    end

    -- Store in state
    State.SetParkedVehicle(data.plate, {
        citizenid = citizenid,
        fullname = ownerName,
        netid = data.netId,
        entity = vehicle,
        plate = data.plate,
        model = vehicleRecord.vehicle,
        hash = vehicleRecord.hash,
        mods = mods,
        fuel = data.fuel,
        body = vehicleRecord.body or 1000,
        engine = vehicleRecord.engine or 1000,
        street = data.street,
        steerangle = data.steerangle,
        location = data.location,
        trailerdata = data.trailerdata,
        parkedAt = os.time(),
    })

    -- Notify all clients
    TriggerClientEvent('dps-parking:client:vehicleParked', -1, {
        plate = data.plate,
        netId = data.netId,
        data = State.GetParkedVehicle(data.plate)
    })

    -- Sync state to owner
    Bridge.SyncStateToClient(source)

    -- Execute post hooks
    EventBus.ExecutePostHooks('parking:park', {
        source = source,
        citizenid = citizenid,
        plate = data.plate,
        data = State.GetParkedVehicle(data.plate)
    })

    return true, L('vehicle_parked')
end

---Unpark a vehicle
---@param source number Player source
---@param plate string Vehicle plate
---@return boolean success
---@return string message
function Parking.Unpark(source, plate)
    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then
        return false, L('error')
    end

    -- Get parked vehicle
    local parkedVehicle = State.GetParkedVehicle(plate)
    if not parkedVehicle then
        return false, L('vehicle_not_parked')
    end

    -- Check ownership
    if parkedVehicle.citizenid ~= citizenid and not Bridge.IsAdmin(source) then
        return false, L('not_owner')
    end

    -- Execute pre-hooks
    local shouldContinue = EventBus.ExecutePreHooks('parking:unpark', {
        source = source,
        citizenid = citizenid,
        plate = plate,
        data = parkedVehicle
    })

    if not shouldContinue then
        return false, L('unparking_failed')
    end

    -- Update database
    Bridge.DB.SetVehicleOut(plate)

    -- Remove from state
    local removedData = State.RemoveParkedVehicle(plate)

    -- Notify all clients
    TriggerClientEvent('dps-parking:client:vehicleUnparked', -1, {
        plate = plate,
        netId = parkedVehicle.netid
    })

    -- Sync state to owner
    Bridge.SyncStateToClient(source)

    -- Execute post hooks
    EventBus.ExecutePostHooks('parking:unpark', {
        source = source,
        citizenid = citizenid,
        plate = plate,
        data = removedData
    })

    return true, L('vehicle_unparked')
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

---Delete vehicle at coordinates
---@param coords vector3
function Parking.DeleteVehicleAtCoords(coords)
    local vehicles = GetAllVehicles()

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(vehCoords - coords)

            if distance <= 2.0 then
                DeleteEntity(vehicle)
                local attempts = 0
                while DoesEntityExist(vehicle) and attempts < 10 do
                    DeleteEntity(vehicle)
                    Wait(100)
                    attempts = attempts + 1
                end
            end
        end
    end
end

---Get all parked vehicles (for sync)
---@return table
function Parking.GetAllParked()
    return State.GetAllParkedVehicles()
end

---Get player's parked vehicles
---@param citizenid string
---@return table
function Parking.GetPlayerParked(citizenid)
    return State.GetPlayerParkedVehicles(citizenid)
end

-- ============================================
-- TIME-BASED IMPOUND CHECK
-- ============================================

local function CheckParkingTimeouts()
    if not Config.Parking.useTimerPark then return end

    local allParked = State.GetAllParkedVehicles()
    local now = os.time()

    for plate, data in pairs(allParked) do
        if data.parkedAt then
            local elapsed = now - data.parkedAt

            if elapsed >= Config.Parking.maxParkTime then
                Utils.Debug(('Vehicle %s exceeded max park time, impounding...'):format(plate))

                -- Calculate impound cost
                local cost = math.floor((elapsed / Config.Parking.payTimeRate) * Config.Parking.parkingFee)

                -- Impound vehicle
                Bridge.PoliceImpound(plate, true, cost, data.body, data.engine, data.fuel)

                -- Remove from parked state
                if data.entity and DoesEntityExist(data.entity) then
                    DeleteEntity(data.entity)
                end

                State.RemoveParkedVehicle(plate)

                -- Notify clients
                TriggerClientEvent('dps-parking:client:vehicleImpounded', -1, {
                    plate = plate,
                    netId = data.netid
                })

                -- Publish event for hooks
                EventBus.Publish('parking:impounded', {
                    plate = plate,
                    citizenid = data.citizenid,
                    reason = 'timeout',
                    cost = cost
                })
            end
        end
    end
end

-- Start timeout loop
CreateThread(function()
    Bridge.WaitReady()
    Wait(5000) -- Wait for initial spawn

    while true do
        CheckParkingTimeouts()
        Wait(Config.Parking.impoundCheckInterval or 10000)
    end
end)

-- ============================================
-- EVENTS
-- ============================================

-- Player joined - sync parked vehicles
RegisterNetEvent('dps-parking:server:playerJoined', function()
    local source = source
    local citizenid = Bridge.GetCitizenId(source)

    -- Initialize on first player
    local players = Bridge.GetOnlinePlayers()
    if #players <= 1 then
        Parking.Initialize()
    end

    -- Sync state to player
    TriggerClientEvent('dps-parking:client:syncParkedVehicles', source, {
        vehicles = Parking.GetAllParked()
    })

    Bridge.SyncStateToClient(source)
end)

-- Park vehicle request
RegisterNetEvent('dps-parking:server:parkVehicle', function(data)
    local source = source
    local success, message = Parking.Park(source, data)

    Bridge.Notify(source, message, success and 'success' or 'error')
end)

-- Unpark vehicle request
RegisterNetEvent('dps-parking:server:unparkVehicle', function(plate)
    local source = source
    local success, message = Parking.Unpark(source, plate)

    Bridge.Notify(source, message, success and 'success' or 'error')
end)

-- Set vehicle lock state
RegisterNetEvent('dps-parking:server:setVehicleLock', function(netId, state)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, state)
    end
end)

-- ============================================
-- CALLBACKS
-- ============================================

Bridge.CreateCallback('dps-parking:getMyVehicles', function(source, cb)
    local citizenid = Bridge.GetCitizenId(source)
    local vehicles = Parking.GetPlayerParked(citizenid)
    cb({ vehicles = vehicles })
end)

Bridge.CreateCallback('dps-parking:canPark', function(source, cb)
    local citizenid = Bridge.GetCitizenId(source)
    local canPark = State.CanPlayerPark(citizenid)
    local used = State.CountPlayerParkedVehicles(citizenid)
    local max = State.GetMaxSlots(citizenid)
    cb({ canPark = canPark, used = used, max = max })
end)

-- ============================================
-- CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    hasSpawned = false

    -- Delete all spawned parked vehicles
    local allParked = State.GetAllParkedVehicles()
    for plate, data in pairs(allParked) do
        if data.entity and DoesEntityExist(data.entity) then
            DeleteEntity(data.entity)
        end
    end
end)

-- ============================================
-- LEGACY EVENT HANDLERS (Backwards Compatibility)
-- ============================================

RegisterNetEvent('mh-parking:server:OnJoin', function()
    TriggerEvent('dps-parking:server:playerJoined')
end)

RegisterNetEvent('mh-parking:server:LeftVehicle', function(netid, seat, plate, location, steerangle, street, fuel, trailerdata)
    if seat == -1 then
        TriggerEvent('dps-parking:server:parkVehicle', {
            netId = netid,
            plate = plate,
            location = location,
            steerangle = steerangle,
            street = street,
            fuel = fuel,
            trailerdata = trailerdata
        })
    end
end)

RegisterNetEvent('mh-parking:server:EnteringVehicle', function(netid, seat)
    if seat == -1 then
        local vehicle = NetworkGetEntityFromNetworkId(netid)
        if DoesEntityExist(vehicle) then
            local plate = Utils.FormatPlate(GetVehicleNumberPlateText(vehicle))
            TriggerEvent('dps-parking:server:unparkVehicle', plate)
        end
    end
end)

print('^2[DPS-Parking] Parking module (server) loaded^0')

return Parking
