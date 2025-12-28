--[[
    DPS-Parking - Parking API (Server Exports)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Public exports for other resources to interact with parking.
]]

-- ============================================
-- EXPORTS
-- ============================================

---Park a vehicle programmatically
---@param source number Player source
---@param data table { netId, plate, location, ... }
---@return boolean success
---@return string message
exports('ParkVehicle', function(source, data)
    return Parking.Park(source, data)
end)

---Unpark a vehicle programmatically
---@param source number Player source
---@param plate string Vehicle plate
---@return boolean success
---@return string message
exports('UnparkVehicle', function(source, plate)
    return Parking.Unpark(source, plate)
end)

---Get a parked vehicle's data
---@param plate string
---@return table|nil
exports('GetParkedVehicle', function(plate)
    return State.GetParkedVehicle(plate)
end)

---Check if a vehicle is parked
---@param plate string
---@return boolean
exports('IsVehicleParked', function(plate)
    return State.IsVehicleParked(plate)
end)

---Get all parked vehicles
---@return table
exports('GetAllParkedVehicles', function()
    return State.GetAllParkedVehicles()
end)

---Get player's parked vehicles
---@param citizenid string
---@return table
exports('GetPlayerParkedVehicles', function(citizenid)
    return State.GetPlayerParkedVehicles(citizenid)
end)

---Get player's max slots
---@param citizenid string
---@return number
exports('GetPlayerMaxSlots', function(citizenid)
    return State.GetMaxSlots(citizenid)
end)

---Check if player can park
---@param citizenid string
---@return boolean
exports('CanPlayerPark', function(citizenid)
    return State.CanPlayerPark(citizenid)
end)

---Set custom max slots for a player
---@param citizenid string
---@param slots number
exports('SetPlayerMaxSlots', function(citizenid, slots)
    State.SetPlayerSlots(citizenid, slots)
end)

-- ============================================
-- HOOK REGISTRATION EXPORTS
-- ============================================

---Register a pre-hook for parking actions
---@param action string Action name (e.g., "parking:park")
---@param callback function
---@param priority? number
---@return string hookId
exports('RegisterPreHook', function(action, callback, priority)
    return EventBus.RegisterPreHook(action, callback, priority)
end)

---Register a post-hook for parking actions
---@param action string Action name
---@param callback function
---@param priority? number
---@return string hookId
exports('RegisterPostHook', function(action, callback, priority)
    return EventBus.RegisterPostHook(action, callback, priority)
end)

---Subscribe to parking events
---@param event string Event name
---@param callback function
---@return string subscriptionId
exports('OnParkingEvent', function(event, callback)
    return EventBus.Subscribe(event, callback)
end)

-- ============================================
-- VIP EXPORTS
-- ============================================

---Set player as VIP
---@param citizenid string
---@param slots number
---@param perks? table
exports('SetVipPlayer', function(citizenid, slots, perks)
    State.SetVipPlayer(citizenid, {
        slots = slots,
        perks = perks or Config.VIP.perks
    })
end)

---Remove VIP status
---@param citizenid string
exports('RemoveVipPlayer', function(citizenid)
    State.RemoveVipPlayer(citizenid)
end)

---Check if player is VIP
---@param citizenid string
---@return boolean
exports('IsVipPlayer', function(citizenid)
    return State.IsVip(citizenid)
end)

print('^2[DPS-Parking] Parking API exports registered^0')
