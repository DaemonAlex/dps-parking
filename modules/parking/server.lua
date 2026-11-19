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

    -- One pass over the world: a car that is already out there with a parked plate (another script's copy, or a
    -- leftover) is removed, so each parked car exists once. Nothing is deleted just for standing near a spot.
    local wanted = {}
    for _, vehicle in ipairs(vehicles) do wanted[Utils.FormatPlate(vehicle.plate)] = true end
    for _, entity in ipairs(GetAllVehicles()) do
        if DoesEntityExist(entity) and wanted[Utils.FormatPlate(GetVehicleNumberPlateText(entity))] then
            DeleteEntity(entity)
        end
    end

    for _, vehicle in ipairs(vehicles) do
        Parking.Forget(vehicle.plate)
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
        parkedAt = tonumber(vehicleData.parkedAt) or os.time(),   -- the real time it was parked, across restarts
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

    -- DPS 2026-11-19: the client only says "park this car". The server finds the car, reads its plate and
    -- position itself, and checks the player is at it. Nothing about where or which car is taken on trust.
    if type(data) ~= 'table' then return false, L('parking_failed') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return false, L('no_vehicle')
    end
    local ped = GetPlayerPed(source)
    local at = GetEntityCoords(vehicle)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - at) > (Config.Parking.parkReach or 8.0) then
        return false, L('no_vehicle')
    end
    data = {
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        plate = Utils.FormatPlate(GetVehicleNumberPlateText(vehicle)),
        location = { x = at.x, y = at.y, z = at.z, h = GetEntityHeading(vehicle) },
        steerangle = math.max(-90.0, math.min(90.0, tonumber(data.steerangle) or 0.0)),
        street = type(data.street) == 'string' and data.street:sub(1, 60) or '',
        fuel = math.max(0.0, math.min(100.0, tonumber(data.fuel) or 100.0)),
        trailerdata = Config.Parking.parkWithTrailers and type(data.trailerdata) == 'table' and data.trailerdata or nil,
    }

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
    if type(data) ~= 'table' then return false, L('parking_failed') end
    -- The zones pre-hook attaches the parking lot (if any) to the hook payload.
    -- Capture it here so it can be forwarded to the post-hooks (business revenue).
    local lot = modifiedData and modifiedData.lot

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

    -- Get owner name
    local ownerName = Bridge.GetPlayerName(source)

    -- The vehicle row, only if the garage script says this car is out. A car that is stored or impounded
    -- cannot be given a street spot.
    local vehicleRecord = Bridge.DB.GetOutVehicle(citizenid, data.plate)
    if not vehicleRecord then
        return false, 'The garage has this car listed as stored or impounded. Take it out at a garage first.'
    end

    -- Parse mods (so appearance persists across restart via vehicle_state JSON)
    local mods = vehicleRecord.mods
    if type(mods) == 'string' then
        mods = json.decode(mods)
    end

    -- Update database (JSON schema columns via DB layer)
    Bridge.DB.SetVehicleParked(
        data.plate,
        data.location,
        data.street,
        data.steerangle,
        data.fuel,
        data.trailerdata,
        {
            citizenid = citizenid,
            mods = mods,
            lotId = lot and lot.id or nil,
        }
    )

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

    -- This resource keeps the car now: the world-persistence script drops its own record of it.
    Parking.HandOver(data.plate)

    -- Notify all clients
    TriggerClientEvent('dps-parking:client:vehicleParked', -1, {
        plate = data.plate,
        netId = data.netId,
        data = State.GetParkedVehicle(data.plate)
    })

    -- Sync state to owner
    Bridge.SyncStateToClient(source)

    -- Execute post hooks (forward the lot so the business revenue hook can accrue)
    EventBus.ExecutePostHooks('parking:park', {
        source = source,
        citizenid = citizenid,
        plate = data.plate,
        lot = lot,
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

---Tell dps-vehiclepersistence this car is kept here, so it is not saved and spawned twice
---@param plate string
function Parking.HandOver(plate)
    if GetResourceState('dps-vehiclepersistence') ~= 'started' then return end
    pcall(function() exports['dps-vehiclepersistence']:NotifyVehicleHandled(plate, 'stored', 'dps-parking') end)
end

---Same, before this resource spawns its own copy at start
function Parking.Forget(plate) Parking.HandOver(plate) end

---Give up a street spot: the entity, the record and the database columns. The garage columns are not touched.
---@param plate string
---@param reason string
function Parking.GiveUpSpot(plate, reason)
    local data = State.GetParkedVehicle(plate)
    if data and data.entity and DoesEntityExist(data.entity) then DeleteEntity(data.entity) end
    State.RemoveParkedVehicle(plate)
    if State.RemoveActiveMeter then State.RemoveActiveMeter(plate) end
    TriggerClientEvent('dps-parking:client:vehicleImpounded', -1, { plate = plate, netId = data and data.netid })
    EventBus.Publish('parking:impounded', { plate = plate, citizenid = data and data.citizenid, reason = reason, cost = 0 })
end

---The garage script is the owner of where a car is. Any car it has stored or impounded loses its street spot.
function Parking.Reconcile()
    for _, plate in ipairs(Bridge.DB.ParkedButInGarage()) do
        Utils.Debug(('Vehicle %s is in a garage or impound: street spot removed'):format(plate))
        Bridge.DB.ClearParkingSpot(plate)
        local key = State.GetParkedVehicle(plate) and plate or Utils.FormatPlate(plate)
        Parking.GiveUpSpot(key, 'garage')
    end
end

CreateThread(function()
    Bridge.WaitReady()
    Wait(15000)
    while true do
        local ok, err = pcall(Parking.Reconcile)
        if not ok then print(('^1[DPS-Parking] reconcile failed: %s^0'):format(err)) end
        Wait((Config.Parking.reconcileSeconds or 30) * 1000)
    end
end)

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

                -- Left too long: towed back to its garage. No bill is made up here.
                Bridge.DB.TowToGarage(plate, data.body, data.engine, data.fuel)
                Parking.GiveUpSpot(plate, 'timeout')
            end
        end
    end
end

-- Start timeout loop
CreateThread(function()
    Bridge.WaitReady()
    Wait(5000)
    Parking.Initialize()

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

    -- Normally done at start (below); this covers a start that could not finish.
    Parking.Initialize()

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

print('^2[DPS-Parking] Parking module (server) loaded^0')

return Parking
