--[[
    DPS-Parking - Zones Module (Client)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side zone visualization and detection.
]]

local parkingLotBlips = {}
local noParkingBlips = {}
local debugEnabled = false

-- ============================================
-- BLIP MANAGEMENT
-- ============================================

local function CreateParkingLotBlips()
    -- Remove existing blips
    for _, blip in ipairs(parkingLotBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    parkingLotBlips = {}

    if not Config.Zones.showParkingLotBlips then return end

    for _, lot in ipairs(Config.ParkingLots) do
        local blip = AddBlipForCoord(lot.coords.x, lot.coords.y, lot.coords.z)
        SetBlipSprite(blip, Config.Blips.parkingLot.sprite)
        SetBlipColour(blip, Config.Blips.parkingLot.color)
        SetBlipScale(blip, Config.Blips.parkingLot.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(lot.name or 'Parking Lot')
        EndTextCommandSetBlipName(blip)

        table.insert(parkingLotBlips, blip)

        -- Debug radius
        if debugEnabled then
            local radiusBlip = AddBlipForRadius(lot.coords.x, lot.coords.y, lot.coords.z, lot.radius)
            SetBlipColour(radiusBlip, Config.Blips.parkingLot.color)
            SetBlipAlpha(radiusBlip, 50)
            table.insert(parkingLotBlips, radiusBlip)
        end
    end
end

local function CreateNoParkingBlips()
    -- Remove existing blips
    for _, blip in ipairs(noParkingBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    noParkingBlips = {}

    if not Config.Zones.showNoParkingBlips then return end

    for _, zone in ipairs(Config.NoParkingZones) do
        local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(blip, Config.Blips.noParking.sprite)
        SetBlipColour(blip, Config.Blips.noParking.color)
        SetBlipScale(blip, Config.Blips.noParking.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(zone.name or 'No Parking')
        EndTextCommandSetBlipName(blip)

        table.insert(noParkingBlips, blip)

        -- Debug radius
        if debugEnabled then
            local radiusBlip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipColour(radiusBlip, Config.Blips.noParking.color)
            SetBlipAlpha(radiusBlip, 50)
            table.insert(noParkingBlips, radiusBlip)
        end
    end
end

-- ============================================
-- ZONE DETECTION
-- ============================================

---Check if player is in a no-parking zone
---@return boolean
---@return table|nil zone
local function IsInNoParkingZone()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local playerJob = Bridge.GetJobName()

    return Utils.IsInNoParkingZone(coords, playerJob)
end

---Check if player is in a parking lot
---@return boolean
---@return table|nil lot
local function IsInParkingLot()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    return Utils.IsInParkingLot(coords)
end

-- ============================================
-- ZONE TRACKING THREAD
-- ============================================

CreateThread(function()
    Bridge.WaitReady()
    Wait(2000)

    local lastZone = nil
    local lastLot = nil

    while true do
        local inNoParking, zone = IsInNoParkingZone()
        local inLot, lot = IsInParkingLot()

        -- Track zone changes
        if inLot and lot ~= lastLot then
            lastLot = lot
            ClientState.SetCurrentZone(lot)

            if EventBus then
                EventBus.Publish('zones:enteredLot', lot)
            end
        elseif not inLot and lastLot then
            lastLot = nil
            ClientState.SetCurrentZone(nil)

            if EventBus then
                EventBus.Publish('zones:exitedLot', nil)
            end
        end

        -- Track no-parking zone entry
        if inNoParking and zone ~= lastZone then
            lastZone = zone
            if EventBus then
                EventBus.Publish('zones:enteredNoParking', zone)
            end
        elseif not inNoParking and lastZone then
            lastZone = nil
            if EventBus then
                EventBus.Publish('zones:exitedNoParking', nil)
            end
        end

        Wait(500)
    end
end)

-- ============================================
-- DEBUG TOGGLE
-- ============================================

local function ToggleDebug()
    debugEnabled = not debugEnabled

    -- Recreate blips with/without debug radius
    CreateParkingLotBlips()
    CreateNoParkingBlips()

    if debugEnabled then
        Bridge.Notify('Zone debug enabled', 'info')
    else
        Bridge.Notify('Zone debug disabled', 'info')
    end
end

-- ============================================
-- COMMANDS
-- ============================================

RegisterCommand(Config.Commands.debugPoly, function()
    ToggleDebug()
end, false)

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:client:zoneAdded', function(data)
    -- Handle dynamically added zones
    Utils.Debug(('Zone added: %s'):format(data.label or data.id))
end)

RegisterNetEvent('dps-parking:client:zoneRemoved', function(data)
    -- Handle dynamically removed zones
    Utils.Debug(('Zone removed: %s'):format(data.zoneId))
end)

RegisterNetEvent('dps-parking:client:toggleDebug', function()
    ToggleDebug()
end)

-- Legacy event
RegisterNetEvent('mh-parking:client:TogglDebugPoly', function()
    ToggleDebug()
end)

RegisterNetEvent('mh-parking:client:reloadZones', function(data)
    if data.list then
        Config.PrivateParking = data.list
    end
    CreateParkingLotBlips()
    CreateNoParkingBlips()
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('IsInNoParkingZone', IsInNoParkingZone)
exports('IsInParkingLot', IsInParkingLot)
exports('ToggleZoneDebug', ToggleDebug)

-- ============================================
-- INITIALIZATION
-- ============================================

CreateThread(function()
    Bridge.WaitReady()
    Wait(1000)

    CreateParkingLotBlips()
    CreateNoParkingBlips()
end)

print('^2[DPS-Parking] Zones module (client) loaded^0')
