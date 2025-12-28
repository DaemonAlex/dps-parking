--[[
    DPS-Parking - Parking Module (Client)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side parking functionality.
]]

local isInitialized = false
local parkedVehicleBlips = {}
local localParkedVehicles = {}

-- ============================================
-- INITIALIZATION
-- ============================================

local function Initialize()
    if isInitialized then return end
    isInitialized = true

    -- Request initial sync
    TriggerServerEvent('dps-parking:server:playerJoined')
end

-- ============================================
-- VEHICLE DETECTION
-- ============================================

---Get current vehicle plate
---@return string|nil
local function GetCurrentVehiclePlate()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then return nil end

    return Utils.FormatPlate(GetVehicleNumberPlateText(vehicle))
end

---Check if we're in the driver seat
---@return boolean
local function IsDriver()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then return false end

    return GetPedInVehicleSeat(vehicle, -1) == ped
end

-- ============================================
-- PARKING ACTIONS
-- ============================================

---Attempt to park current vehicle
function ParkCurrentVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    -- Validation
    if vehicle == 0 then
        Bridge.Notify(L('no_vehicle'), 'error')
        return
    end

    if not IsDriver() then
        Bridge.Notify(L('not_owner'), 'error')
        return
    end

    -- Check engine state if required
    if Config.Parking.requireEngineOff and GetIsVehicleEngineRunning(vehicle) then
        Bridge.Notify(L('engine_must_be_off'), 'error')
        return
    end

    -- Check if in no-parking zone
    local coords = GetEntityCoords(vehicle)
    local playerJob = Bridge.GetJobName()

    local inNoParking, zone = Utils.IsInNoParkingZone(coords, playerJob)
    if inNoParking then
        if zone.jobs and #zone.jobs > 0 then
            Bridge.Notify(L('restricted_area', table.concat(zone.jobs, ', ')), 'error')
        else
            Bridge.Notify(L('no_parking_zone'), 'error')
        end
        return
    end

    -- Check if parking lots only mode
    if Config.Zones.useParkingLotsOnly then
        local inLot = Utils.IsInParkingLot(coords)
        if not inLot then
            Bridge.Notify(L('parking_lot_only'), 'error')
            return
        end
    end

    -- Get vehicle data
    local plate = Utils.FormatPlate(GetVehicleNumberPlateText(vehicle))
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local heading = GetEntityHeading(vehicle)

    -- Get street name
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)

    -- Get steering angle
    local steerAngle = 0
    if Config.Parking.saveSteeringAngle then
        steerAngle = GetVehicleSteeringAngle(vehicle)
    end

    -- Get fuel
    local fuel = Bridge.GetFuel(vehicle)

    -- Get trailer data if attached
    local trailerData = nil
    if Config.Parking.parkWithTrailers then
        local hasTrailer, trailer = GetVehicleTrailerVehicle(vehicle)
        if hasTrailer and DoesEntityExist(trailer) then
            local trailerCoords = GetEntityCoords(trailer)
            local trailerHeading = GetEntityHeading(trailer)
            local trailerModel = GetEntityModel(trailer)

            trailerData = {
                coords = { x = trailerCoords.x, y = trailerCoords.y, z = trailerCoords.z, h = trailerHeading },
                model = trailerModel,
                hash = trailerModel,
                mods = Bridge.GetVehicleProperties(trailer)
            }
        end
    end

    -- Send park request
    TriggerServerEvent('dps-parking:server:parkVehicle', {
        netId = netId,
        plate = plate,
        location = { x = coords.x, y = coords.y, z = coords.z, h = heading },
        steerangle = steerAngle,
        street = street,
        fuel = fuel,
        trailerdata = trailerData
    })
end

---Attempt to unpark a vehicle
---@param plate string
function UnparkVehicle(plate)
    TriggerServerEvent('dps-parking:server:unparkVehicle', plate)
end

-- ============================================
-- 3D TEXT DISPLAY
-- ============================================

local function Draw3DText(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(screenX, screenY)
    end
end

-- ============================================
-- DISPLAY THREAD
-- ============================================

CreateThread(function()
    while true do
        local sleep = 1000

        if Config.Parking.display3DText and not Config.Parking.streamerMode then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local playerJob = Bridge.GetJobName()

            for plate, data in pairs(localParkedVehicles) do
                if data.location then
                    local vehCoords = vector3(data.location.x, data.location.y, data.location.z)
                    local distance = #(playerCoords - vehCoords)

                    if distance <= Config.Parking.displayDistance then
                        sleep = 0

                        -- Check if should display
                        local shouldDisplay = Config.Parking.displayToAllPlayers
                        if not shouldDisplay and data.citizenid == Bridge.GetCitizenId() then
                            shouldDisplay = true
                        end
                        if not shouldDisplay and Config.Parking.displayToPolice and (playerJob == 'police' or playerJob == 'sheriff') then
                            shouldDisplay = true
                        end

                        if shouldDisplay then
                            local lines = {}

                            if Config.Parking.displayOwner and data.fullname then
                                table.insert(lines, L('owner', data.fullname))
                            end

                            if Config.Parking.displayPlate then
                                table.insert(lines, L('plate', plate))
                            end

                            if Config.Parking.displayBrand and data.model then
                                local label = Utils.GetVehicleLabel(data.model)
                                table.insert(lines, label)
                            end

                            if #lines > 0 then
                                Draw3DText(vehCoords, table.concat(lines, '\n'))
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ============================================
-- VEHICLE STATE TRACKING
-- ============================================

local lastVehicle = nil
local wasDriver = false

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        -- Entered vehicle
        if vehicle ~= 0 and lastVehicle ~= vehicle then
            local plate = Utils.FormatPlate(GetVehicleNumberPlateText(vehicle))
            local netId = NetworkGetNetworkIdFromEntity(vehicle)

            ClientState.SetVehicleState(true, vehicle, plate)

            -- Check if this is a parked vehicle we're entering
            if isDriver and localParkedVehicles[plate] then
                TriggerServerEvent('dps-parking:server:unparkVehicle', plate)
            end
        end

        -- Exited vehicle
        if vehicle == 0 and lastVehicle ~= 0 then
            ClientState.SetVehicleState(false, nil, nil)
        end

        lastVehicle = vehicle
        wasDriver = isDriver

        Wait(500)
    end
end)

-- ============================================
-- AUTO-PARK THREAD
-- ============================================

if Config.Parking.useAutoPark then
    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 and IsDriver() then
                local engineRunning = GetIsVehicleEngineRunning(vehicle)

                -- Check for auto-park conditions
                if Config.Parking.onlyAutoParkWhenEngineOff then
                    if not engineRunning then
                        sleep = 0
                        -- Show prompt
                        if IsControlJustPressed(0, 38) then -- E key
                            ParkCurrentVehicle()
                        end
                    end
                else
                    sleep = 0
                    if IsControlJustPressed(0, Config.Keybinds.parkButton) then
                        ParkCurrentVehicle()
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- ============================================
-- KEYBIND REGISTRATION
-- ============================================

RegisterCommand('park', function()
    ParkCurrentVehicle()
end, false)

RegisterKeyMapping('park', 'Park Vehicle', 'keyboard', Config.Keybinds.parkKey)

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:client:syncParkedVehicles', function(data)
    localParkedVehicles = data.vehicles or {}
    Utils.Debug(('Synced %d parked vehicles'):format(Utils.Count(localParkedVehicles)))
end)

RegisterNetEvent('dps-parking:client:vehicleParked', function(data)
    localParkedVehicles[data.plate] = data.data

    -- Freeze vehicle
    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, true)
        if Config.Parking.disableCollision then
            SetEntityCollision(vehicle, false, true)
        end
        SetVehicleDoorsLocked(vehicle, 2)
    end

    Utils.Debug(('Vehicle parked: %s'):format(data.plate))
end)

RegisterNetEvent('dps-parking:client:vehicleUnparked', function(data)
    localParkedVehicles[data.plate] = nil

    -- Unfreeze vehicle
    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, false)
        SetEntityCollision(vehicle, true, true)
        SetVehicleDoorsLocked(vehicle, 1)

        -- Give keys
        Bridge.GiveKeys(data.plate, vehicle)
    end

    Utils.Debug(('Vehicle unparked: %s'):format(data.plate))
end)

RegisterNetEvent('dps-parking:client:vehicleSpawned', function(data)
    localParkedVehicles[data.plate] = data.data

    -- Apply parked state
    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, true)
        if Config.Parking.disableCollision then
            SetEntityCollision(vehicle, false, true)
        end
        SetVehicleDoorsLocked(vehicle, 2)

        -- Apply mods if available
        if data.data and data.data.mods then
            Bridge.SetVehicleProperties(vehicle, data.data.mods)
        end

        -- Apply steering angle
        if data.data and data.data.steerangle and Config.Parking.saveSteeringAngle then
            SetVehicleSteeringAngle(vehicle, data.data.steerangle)
        end

        -- Set fuel
        if data.data and data.data.fuel then
            Bridge.SetFuel(vehicle, data.data.fuel)
        end
    end
end)

RegisterNetEvent('dps-parking:client:vehicleImpounded', function(data)
    localParkedVehicles[data.plate] = nil
    Utils.Debug(('Vehicle impounded: %s'):format(data.plate))
end)

-- ============================================
-- LEGACY EVENT HANDLERS
-- ============================================

RegisterNetEvent('mh-parking:client:Onjoin', function(data)
    if data.status and data.vehicles then
        localParkedVehicles = data.vehicles
    end
end)

RegisterNetEvent('mh-parking:client:AddVehicle', function(data)
    if data.data then
        localParkedVehicles[data.data.plate] = data.data
    end
end)

RegisterNetEvent('mh-parking:client:RemoveVehicle', function(data)
    if data.plate then
        localParkedVehicles[data.plate] = nil
    elseif data.netid then
        for plate, veh in pairs(localParkedVehicles) do
            if veh.netid == data.netid then
                localParkedVehicles[plate] = nil
                break
            end
        end
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('ParkCurrentVehicle', ParkCurrentVehicle)
exports('UnparkVehicle', UnparkVehicle)
exports('GetLocalParkedVehicles', function() return localParkedVehicles end)

-- ============================================
-- INITIALIZATION
-- ============================================

CreateThread(function()
    Bridge.WaitReady()
    Wait(1000)
    Initialize()
end)

print('^2[DPS-Parking] Parking module (client) loaded^0')
