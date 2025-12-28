--[[
    DPS-Parking - Client StateManager
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side state synchronized from server.
    Tracks local state and synced data.
]]

ClientState = {}

-- Synced from server
ClientState._synced = {
    myVehicles = {},          -- My parked vehicles
    myDeliveries = {},        -- My active deliveries
    isVip = false,            -- VIP status
    maxSlots = 5,             -- Max parking slots
    usedSlots = 0,            -- Current used slots
}

-- Local client state
ClientState._local = {
    isInVehicle = false,
    currentVehicle = nil,
    currentPlate = nil,
    currentZone = nil,
    isNearParked = false,
    nearbyParkedVehicle = nil,
    uiOpen = false,
    lastSync = 0,
}

-- Subscribers
ClientState._subscribers = {}

-- ============================================
-- SUBSCRIPTION SYSTEM
-- ============================================

function ClientState.Subscribe(key, callback)
    if not ClientState._subscribers[key] then
        ClientState._subscribers[key] = {}
    end

    local id = key .. '_sub_' .. GetGameTimer()
    table.insert(ClientState._subscribers[key], {
        id = id,
        callback = callback
    })

    return id
end

function ClientState.Unsubscribe(key, id)
    if not ClientState._subscribers[key] then return false end

    for i, sub in ipairs(ClientState._subscribers[key]) do
        if sub.id == id then
            table.remove(ClientState._subscribers[key], i)
            return true
        end
    end
    return false
end

local function NotifySubscribers(key, oldValue, newValue)
    if not ClientState._subscribers[key] then return end

    for _, sub in ipairs(ClientState._subscribers[key]) do
        local success, err = pcall(sub.callback, key, oldValue, newValue)
        if not success and Config and Config.Debug then
            print(('[DPS-Parking] ClientState: Subscriber error for "%s": %s'):format(key, err))
        end
    end

    if EventBus then
        EventBus.Publish('clientstate:changed:' .. key, {
            key = key,
            old = oldValue,
            new = newValue
        })
    end
end

-- ============================================
-- SYNCED STATE (from server)
-- ============================================

---Update synced state from server
---@param data table
function ClientState.UpdateFromServer(data)
    if data.myVehicles then
        local old = ClientState._synced.myVehicles
        ClientState._synced.myVehicles = data.myVehicles
        NotifySubscribers('myVehicles', old, data.myVehicles)
    end

    if data.myDeliveries then
        local old = ClientState._synced.myDeliveries
        ClientState._synced.myDeliveries = data.myDeliveries
        NotifySubscribers('myDeliveries', old, data.myDeliveries)
    end

    if data.isVip ~= nil then
        local old = ClientState._synced.isVip
        ClientState._synced.isVip = data.isVip
        if old ~= data.isVip then
            NotifySubscribers('isVip', old, data.isVip)
        end
    end

    if data.maxSlots then
        local old = ClientState._synced.maxSlots
        ClientState._synced.maxSlots = data.maxSlots
        if old ~= data.maxSlots then
            NotifySubscribers('maxSlots', old, data.maxSlots)
        end
    end

    if data.usedSlots then
        local old = ClientState._synced.usedSlots
        ClientState._synced.usedSlots = data.usedSlots
        if old ~= data.usedSlots then
            NotifySubscribers('usedSlots', old, data.usedSlots)
        end
    end

    ClientState._local.lastSync = GetGameTimer()
end

---Get my parked vehicles
---@return table
function ClientState.GetMyVehicles()
    return ClientState._synced.myVehicles
end

---Get my vehicle by plate
---@param plate string
---@return table|nil
function ClientState.GetMyVehicle(plate)
    return ClientState._synced.myVehicles[plate]
end

---Check if I own a parked vehicle
---@param plate string
---@return boolean
function ClientState.IsMyVehicle(plate)
    return ClientState._synced.myVehicles[plate] ~= nil
end

---Get my deliveries
---@return table
function ClientState.GetMyDeliveries()
    return ClientState._synced.myDeliveries
end

---Check if VIP
---@return boolean
function ClientState.IsVip()
    return ClientState._synced.isVip
end

---Get max slots
---@return number
function ClientState.GetMaxSlots()
    return ClientState._synced.maxSlots
end

---Get used slots
---@return number
function ClientState.GetUsedSlots()
    return ClientState._synced.usedSlots
end

---Can park more vehicles
---@return boolean
function ClientState.CanPark()
    return ClientState._synced.usedSlots < ClientState._synced.maxSlots
end

-- ============================================
-- LOCAL STATE
-- ============================================

---Set vehicle state
---@param inVehicle boolean
---@param vehicle number|nil
---@param plate string|nil
function ClientState.SetVehicleState(inVehicle, vehicle, plate)
    local oldInVehicle = ClientState._local.isInVehicle

    ClientState._local.isInVehicle = inVehicle
    ClientState._local.currentVehicle = vehicle
    ClientState._local.currentPlate = plate

    if oldInVehicle ~= inVehicle then
        NotifySubscribers('isInVehicle', oldInVehicle, inVehicle)

        if EventBus then
            if inVehicle then
                EventBus.Publish('player:enteredVehicle', { vehicle = vehicle, plate = plate })
            else
                EventBus.Publish('player:exitedVehicle', { vehicle = vehicle, plate = plate })
            end
        end
    end
end

---Get current vehicle
---@return number|nil
function ClientState.GetCurrentVehicle()
    return ClientState._local.currentVehicle
end

---Get current plate
---@return string|nil
function ClientState.GetCurrentPlate()
    return ClientState._local.currentPlate
end

---Is in vehicle
---@return boolean
function ClientState.IsInVehicle()
    return ClientState._local.isInVehicle
end

---Set current zone
---@param zone table|nil
function ClientState.SetCurrentZone(zone)
    local old = ClientState._local.currentZone
    ClientState._local.currentZone = zone

    if old ~= zone then
        NotifySubscribers('currentZone', old, zone)
    end
end

---Get current zone
---@return table|nil
function ClientState.GetCurrentZone()
    return ClientState._local.currentZone
end

---Set nearby parked vehicle
---@param isNear boolean
---@param vehicle number|nil
---@param plate string|nil
function ClientState.SetNearbyParkedVehicle(isNear, vehicle, plate)
    local oldNear = ClientState._local.isNearParked

    ClientState._local.isNearParked = isNear
    ClientState._local.nearbyParkedVehicle = isNear and { entity = vehicle, plate = plate } or nil

    if oldNear ~= isNear then
        NotifySubscribers('isNearParked', oldNear, isNear)
    end
end

---Is near parked vehicle
---@return boolean
function ClientState.IsNearParkedVehicle()
    return ClientState._local.isNearParked
end

---Get nearby parked vehicle
---@return table|nil
function ClientState.GetNearbyParkedVehicle()
    return ClientState._local.nearbyParkedVehicle
end

---Set UI open state
---@param isOpen boolean
function ClientState.SetUIOpen(isOpen)
    local old = ClientState._local.uiOpen
    ClientState._local.uiOpen = isOpen

    if old ~= isOpen then
        NotifySubscribers('uiOpen', old, isOpen)
    end
end

---Is UI open
---@return boolean
function ClientState.IsUIOpen()
    return ClientState._local.uiOpen
end

-- ============================================
-- REQUEST SYNC
-- ============================================

---Request state sync from server
function ClientState.RequestSync()
    TriggerServerEvent('dps-parking:server:requestStateSync')
end

-- Register event to receive sync data
RegisterNetEvent('dps-parking:client:stateSync', function(data)
    ClientState.UpdateFromServer(data)
end)

-- ============================================
-- DEBUG
-- ============================================

function ClientState.GetSnapshot()
    return {
        synced = ClientState._synced,
        localState = {
            isInVehicle = ClientState._local.isInVehicle,
            currentPlate = ClientState._local.currentPlate,
            currentZone = ClientState._local.currentZone and ClientState._local.currentZone.name or nil,
            isNearParked = ClientState._local.isNearParked,
            uiOpen = ClientState._local.uiOpen,
            lastSync = ClientState._local.lastSync,
        }
    }
end

return ClientState
