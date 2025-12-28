--[[
    DPS-Parking - Delivery Module (Server)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Vehicle delivery service.
]]

Delivery = {}

local playerDeliveryCount = {}

-- ============================================
-- DELIVERY OPERATIONS
-- ============================================

---Request vehicle delivery
---@param source number
---@param plate string
---@param coords vector3
---@param rush boolean
---@return boolean success
---@return string message
function Delivery.Request(source, plate, coords, rush)
    if not Config.Delivery.enabled then
        return false, 'Delivery disabled'
    end

    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then
        return false, L('error')
    end

    -- Check if vehicle is parked
    local parkedVehicle = State.GetParkedVehicle(plate)
    if not parkedVehicle then
        return false, L('vehicle_not_parked')
    end

    -- Check ownership
    if parkedVehicle.citizenid ~= citizenid then
        return false, L('not_owner')
    end

    -- Check cooldown/limits
    local hourKey = citizenid .. '_' .. os.date('%Y%m%d%H')
    playerDeliveryCount[hourKey] = playerDeliveryCount[hourKey] or 0

    if playerDeliveryCount[hourKey] >= Config.Delivery.maxPerHour then
        return false, L('delivery_max_reached')
    end

    -- Calculate cost
    local cost = Config.Delivery.baseCost
    local deliveryTime = Config.Delivery.standardTime

    if rush then
        cost = math.ceil(cost * Config.Delivery.rushMultiplier)
        deliveryTime = Config.Delivery.rushTime
    end

    -- Apply job discounts
    local playerJob = Bridge.GetPlayerJob(source)
    if playerJob and Config.Delivery.discounts[playerJob] then
        local discount = cost * Config.Delivery.discounts[playerJob]
        cost = math.ceil(cost - discount)
    end

    -- VIP priority
    if State.IsVip(citizenid) and Config.VIP.perks.priorityDelivery then
        deliveryTime = math.max(1, deliveryTime - 1)
    end

    -- Charge player
    if not Bridge.RemoveMoney(source, 'bank', cost, 'Vehicle delivery') then
        if not Bridge.RemoveMoney(source, 'cash', cost, 'Vehicle delivery') then
            return false, L('insufficient_funds', Utils.FormatMoney(cost))
        end
    end

    -- Create delivery
    local deliveryId = citizenid .. '_' .. plate .. '_' .. os.time()
    local arrivalTime = os.time() + (deliveryTime * 60)

    State.SetDelivery(deliveryId, {
        id = deliveryId,
        citizenid = citizenid,
        plate = plate,
        destination = coords,
        requestedAt = os.time(),
        arrivalTime = arrivalTime,
        rush = rush,
        cost = cost
    })

    playerDeliveryCount[hourKey] = playerDeliveryCount[hourKey] + 1

    -- Schedule delivery
    SetTimeout(deliveryTime * 60 * 1000, function()
        Delivery.Complete(deliveryId)
    end)

    return true, L('delivery_ordered', Utils.FormatTime(deliveryTime * 60))
end

---Complete a delivery
---@param deliveryId string
function Delivery.Complete(deliveryId)
    local delivery = State.GetDelivery(deliveryId)
    if not delivery then return end

    -- Get parked vehicle
    local parkedVehicle = State.GetParkedVehicle(delivery.plate)
    if not parkedVehicle then
        State.RemoveDelivery(deliveryId)
        return
    end

    -- Delete parked vehicle entity
    if parkedVehicle.entity and DoesEntityExist(parkedVehicle.entity) then
        DeleteEntity(parkedVehicle.entity)
    end

    -- Spawn at delivery location
    local modelHash = GetHashKey(parkedVehicle.model)
    local coords = delivery.destination
    local entity = CreateVehicleServerSetter(modelHash, 'automobile', coords.x, coords.y, coords.z, coords.h or 0.0)

    Wait(500)

    if DoesEntityExist(entity) then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        SetVehicleNumberPlateText(entity, delivery.plate)

        -- Update database
        Bridge.DB.SetVehicleOut(delivery.plate)

        -- Remove from parked state
        State.RemoveParkedVehicle(delivery.plate)

        -- Notify player
        local player = Bridge.GetPlayerByCitizenId(delivery.citizenid)
        if player then
            local playerSource = Bridge.IsESX() and player.source or player.PlayerData.source
            if playerSource then
                Bridge.Notify(playerSource, L('delivery_arrived'), 'success')
                TriggerClientEvent('dps-parking:client:deliveryArrived', playerSource, {
                    plate = delivery.plate,
                    netId = netId
                })
            end
        end
    end

    State.RemoveDelivery(deliveryId)
end

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:server:requestDelivery', function(plate, coords, rush)
    local source = source
    local success, message = Delivery.Request(source, plate, coords, rush)
    Bridge.Notify(source, message, success and 'success' or 'error')
end)

print('^2[DPS-Parking] Delivery module (server) loaded^0')

return Delivery
