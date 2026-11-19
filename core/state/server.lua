--[[
    DPS-Parking - Server StateManager
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Centralized state management for server-side data.
    Single source of truth - replaces scattered global tables.
]]

State = {}

-- Internal state storage
State._data = {
    parkedVehicles = {},      -- plate -> vehicle data
    activeMeters = {},        -- plate -> meter data
    activeDeliveries = {},    -- deliveryId -> delivery data
    businessOwners = {},      -- lotId -> owner data
    vipPlayers = {},          -- citizenid -> vip data
    playerSlots = {},         -- citizenid -> slot count
}

-- Subscribers for reactive updates
State._subscribers = {}

-- ============================================
-- SUBSCRIPTION SYSTEM
-- ============================================

---Subscribe to state changes
---@param key string State key to watch (e.g., "parkedVehicles")
---@param callback function Called with (key, oldValue, newValue)
---@return string id Subscription ID
function State.Subscribe(key, callback)
    if not State._subscribers[key] then
        State._subscribers[key] = {}
    end

    local id = key .. '_sub_' .. GetGameTimer()
    table.insert(State._subscribers[key], {
        id = id,
        callback = callback
    })

    return id
end

---Unsubscribe from state changes
function State.Unsubscribe(key, id)
    if not State._subscribers[key] then return false end

    for i, sub in ipairs(State._subscribers[key]) do
        if sub.id == id then
            table.remove(State._subscribers[key], i)
            return true
        end
    end
    return false
end

---Notify subscribers of state change
local function NotifySubscribers(key, oldValue, newValue)
    if not State._subscribers[key] then return end

    for _, sub in ipairs(State._subscribers[key]) do
        local success, err = pcall(sub.callback, key, oldValue, newValue)
        if not success then
            print(('[DPS-Parking] State: Subscriber error for "%s": %s'):format(key, err))
        end
    end

    -- Also publish to EventBus
    if EventBus then
        EventBus.Publish('state:changed:' .. key, {
            key = key,
            old = oldValue,
            new = newValue
        })
    end
end

-- ============================================
-- PARKED VEHICLES
-- ============================================

---Get all parked vehicles
---@return table<string, table>
function State.GetAllParkedVehicles()
    return State._data.parkedVehicles
end

---Get parked vehicle by plate
---@param plate string
---@return table|nil
function State.GetParkedVehicle(plate)
    return State._data.parkedVehicles[plate]
end

---Get parked vehicles for a player
---@param citizenid string
---@return table<string, table>
function State.GetPlayerParkedVehicles(citizenid)
    local vehicles = {}
    for plate, data in pairs(State._data.parkedVehicles) do
        if data.citizenid == citizenid then
            vehicles[plate] = data
        end
    end
    return vehicles
end

---Count parked vehicles for a player
---@param citizenid string
---@return number
function State.CountPlayerParkedVehicles(citizenid)
    local count = 0
    for _, data in pairs(State._data.parkedVehicles) do
        if data.citizenid == citizenid then
            count = count + 1
        end
    end
    return count
end

---Add or update parked vehicle
---@param plate string
---@param data table
function State.SetParkedVehicle(plate, data)
    local old = State._data.parkedVehicles[plate]
    State._data.parkedVehicles[plate] = data

    NotifySubscribers('parkedVehicles', old, data)

    if Config and Config.Debug then
        print(('[DPS-Parking] State: Vehicle "%s" parked'):format(plate))
    end
end

---Remove parked vehicle
---@param plate string
---@return table|nil removed The removed vehicle data
function State.RemoveParkedVehicle(plate)
    local old = State._data.parkedVehicles[plate]
    State._data.parkedVehicles[plate] = nil

    if old then
        NotifySubscribers('parkedVehicles', old, nil)
        if Config and Config.Debug then
            print(('[DPS-Parking] State: Vehicle "%s" unparked'):format(plate))
        end
    end

    return old
end

---Check if vehicle is parked
---@param plate string
---@return boolean
function State.IsVehicleParked(plate)
    return State._data.parkedVehicles[plate] ~= nil
end

-- ============================================
-- PARKING METERS
-- ============================================

---Get active meter for plate
---@param plate string
---@return table|nil
function State.GetActiveMeter(plate)
    return State._data.activeMeters[plate]
end

---Set active meter
---@param plate string
---@param data table { expiresAt, paidAmount, zone, ... }
function State.SetActiveMeter(plate, data)
    local old = State._data.activeMeters[plate]
    State._data.activeMeters[plate] = data
    NotifySubscribers('activeMeters', old, data)
end

---Remove active meter
---@param plate string
function State.RemoveActiveMeter(plate)
    local old = State._data.activeMeters[plate]
    State._data.activeMeters[plate] = nil
    if old then
        NotifySubscribers('activeMeters', old, nil)
    end
end

---Get all expired meters
---@return table<string, table>
function State.GetExpiredMeters()
    local expired = {}
    local now = os.time()

    for plate, data in pairs(State._data.activeMeters) do
        if data.expiresAt and data.expiresAt < now then
            expired[plate] = data
        end
    end

    return expired
end

-- ============================================
-- DELIVERIES
-- ============================================

---Get delivery by ID
---@param deliveryId string
---@return table|nil
function State.GetDelivery(deliveryId)
    return State._data.activeDeliveries[deliveryId]
end

---Get player's active deliveries
---@param citizenid string
---@return table<string, table>
function State.GetPlayerDeliveries(citizenid)
    local deliveries = {}
    for id, data in pairs(State._data.activeDeliveries) do
        if data.citizenid == citizenid then
            deliveries[id] = data
        end
    end
    return deliveries
end

---Set delivery
---@param deliveryId string
---@param data table
function State.SetDelivery(deliveryId, data)
    local old = State._data.activeDeliveries[deliveryId]
    State._data.activeDeliveries[deliveryId] = data
    NotifySubscribers('activeDeliveries', old, data)
end

---Remove delivery
---@param deliveryId string
function State.RemoveDelivery(deliveryId)
    local old = State._data.activeDeliveries[deliveryId]
    State._data.activeDeliveries[deliveryId] = nil
    if old then
        NotifySubscribers('activeDeliveries', old, nil)
    end
end

-- ============================================
-- VIP PLAYERS
-- ============================================

---Get VIP data for player
---@param citizenid string
---@return table|nil
function State.GetVipPlayer(citizenid)
    return State._data.vipPlayers[citizenid]
end

---Check if player is VIP
---@param citizenid string
---@return boolean
function State.IsVip(citizenid)
    return State._data.vipPlayers[citizenid] ~= nil
end

---Set VIP player
---@param citizenid string
---@param data table { slots, perks, ... }
function State.SetVipPlayer(citizenid, data)
    local old = State._data.vipPlayers[citizenid]
    State._data.vipPlayers[citizenid] = data
    NotifySubscribers('vipPlayers', old, data)
end

---Remove VIP player
---@param citizenid string
function State.RemoveVipPlayer(citizenid)
    local old = State._data.vipPlayers[citizenid]
    State._data.vipPlayers[citizenid] = nil
    if old then
        NotifySubscribers('vipPlayers', old, nil)
    end
end

-- ============================================
-- PARKING SLOTS
-- ============================================

---Get max parking slots for player
---@param citizenid string
---@return number
function State.GetMaxSlots(citizenid)
    -- Check VIP first
    local vipData = State.GetVipPlayer(citizenid)
    if vipData and vipData.slots then
        return vipData.slots
    end

    -- Check custom slots
    if State._data.playerSlots[citizenid] then
        return State._data.playerSlots[citizenid]
    end

    -- Return default
    return Config and Config.Parking and Config.Parking.defaultMaxSlots or 5
end

---Set custom slots for player
---@param citizenid string
---@param slots number
function State.SetPlayerSlots(citizenid, slots)
    local old = State._data.playerSlots[citizenid]
    State._data.playerSlots[citizenid] = slots
    NotifySubscribers('playerSlots', old, slots)
end

---Check if player can park more vehicles
---@param citizenid string
---@return boolean
function State.CanPlayerPark(citizenid)
    local current = State.CountPlayerParkedVehicles(citizenid)
    local max = State.GetMaxSlots(citizenid)
    return current < max
end

-- ============================================
-- BUSINESS OWNERSHIP
-- ============================================

---Get business owner for lot
---@param lotId number
---@return table|nil
function State.GetBusinessOwner(lotId)
    return State._data.businessOwners[lotId]
end

---Set business owner
---@param lotId number
---@param data table
function State.SetBusinessOwner(lotId, data)
    local old = State._data.businessOwners[lotId]
    State._data.businessOwners[lotId] = data
    NotifySubscribers('businessOwners', old, data)
end

-- ============================================
-- BULK OPERATIONS
-- ============================================

---Load initial state from database
---@param parkedVehicles table
---@param vipPlayers table
---@param businessOwners table
function State.LoadFromDatabase(parkedVehicles, vipPlayers, businessOwners)
    if parkedVehicles then
        for _, v in ipairs(parkedVehicles) do
            if v.plate then
                State._data.parkedVehicles[v.plate] = v
            end
        end
    end

    if vipPlayers then
        for _, v in ipairs(vipPlayers) do
            if v.citizenid then
                State._data.vipPlayers[v.citizenid] = v
            end
        end
    end

    if businessOwners then
        for _, v in ipairs(businessOwners) do
            if v.lotId then
                State._data.businessOwners[v.lotId] = v
            end
        end
    end

    print(('[DPS-Parking] State: Loaded %d parked vehicles, %d VIPs, %d businesses'):format(
        State.CountAll('parkedVehicles'),
        State.CountAll('vipPlayers'),
        State.CountAll('businessOwners')
    ))
end

---Count items in a state category
---@param key string
---@return number
function State.CountAll(key)
    local count = 0
    if State._data[key] then
        for _ in pairs(State._data[key]) do
            count = count + 1
        end
    end
    return count
end

---Get full state snapshot (for debugging)
---@return table
function State.GetSnapshot()
    return {
        parkedVehicles = State.CountAll('parkedVehicles'),
        activeMeters = State.CountAll('activeMeters'),
        activeDeliveries = State.CountAll('activeDeliveries'),
        vipPlayers = State.CountAll('vipPlayers'),
        businessOwners = State.CountAll('businessOwners'),
    }
end

-- ============================================
-- CLIENT SYNC
-- ============================================

---Get state data to sync to client
---@param citizenid string
---@return table
function State.GetClientSyncData(citizenid)
    return {
        myVehicles = State.GetPlayerParkedVehicles(citizenid),
        myDeliveries = State.GetPlayerDeliveries(citizenid),
        isVip = State.IsVip(citizenid),
        maxSlots = State.GetMaxSlots(citizenid),
        usedSlots = State.CountPlayerParkedVehicles(citizenid),
    }
end

return State
