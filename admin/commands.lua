--[[
    DPS-Parking - Admin Commands
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Administrative commands for parking management.
]]

-- ============================================
-- ADMIN COMMANDS
-- ============================================

-- Add VIP
RegisterCommand(Config.Commands.addVip, function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    local targetId = tonumber(args[1])
    local slots = tonumber(args[2]) or Config.VIP.defaultSlots or 10

    if not targetId then
        Bridge.Notify(source, 'Usage: /' .. Config.Commands.addVip .. ' [id] [slots]', 'error')
        return
    end

    local citizenid = Bridge.GetCitizenId(targetId)
    if not citizenid then
        Bridge.Notify(source, L('player_not_found'), 'error')
        return
    end

    State.SetVipPlayer(citizenid, {
        slots = slots,
        perks = Config.VIP.perks,
        addedAt = os.time(),
        addedBy = source == 0 and 'Console' or Bridge.GetPlayerName(source)
    })

    -- Update database
    local tbl = Bridge.IsESX() and 'users' or 'players'
    local col = Bridge.IsESX() and 'identifier' or 'citizenid'
    MySQL.update.await(('UPDATE %s SET parkvip = 1, parkmax = ? WHERE %s = ?'):format(tbl, col), {slots, citizenid})

    Bridge.Notify(targetId, L('vip_added'), 'success')
    if source ~= 0 then
        Bridge.Notify(source, 'VIP status granted to player', 'success')
    end
    print(('[DPS-Parking] VIP added: %s with %d slots'):format(citizenid, slots))
end, true)

-- Remove VIP
RegisterCommand(Config.Commands.removeVip, function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        Bridge.Notify(source, 'Usage: /' .. Config.Commands.removeVip .. ' [id]', 'error')
        return
    end

    local citizenid = Bridge.GetCitizenId(targetId)
    if not citizenid then
        Bridge.Notify(source, L('player_not_found'), 'error')
        return
    end

    State.RemoveVipPlayer(citizenid)

    -- Update database
    local tbl = Bridge.IsESX() and 'users' or 'players'
    local col = Bridge.IsESX() and 'identifier' or 'citizenid'
    MySQL.update.await(('UPDATE %s SET parkvip = 0, parkmax = 0 WHERE %s = ?'):format(tbl, col), {citizenid})

    Bridge.Notify(targetId, L('vip_removed'), 'info')
    if source ~= 0 then
        Bridge.Notify(source, 'VIP status removed from player', 'success')
    end
    print(('[DPS-Parking] VIP removed: %s'):format(citizenid))
end, true)

-- Reset player parking
RegisterCommand(Config.Commands.resetPlayer, function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        Bridge.Notify(source, 'Usage: /' .. Config.Commands.resetPlayer .. ' [id]', 'error')
        return
    end

    local citizenid = Bridge.GetCitizenId(targetId)
    if not citizenid then
        Bridge.Notify(source, L('player_not_found'), 'error')
        return
    end

    -- Get player's parked vehicles
    local vehicles = State.GetPlayerParkedVehicles(citizenid)

    -- Delete entities and remove from state
    for plate, data in pairs(vehicles) do
        if data.entity and DoesEntityExist(data.entity) then
            DeleteEntity(data.entity)
        end
        State.RemoveParkedVehicle(plate)
    end

    -- Reset in database
    local tbl = Bridge.DB.GetVehicleTable()
    local owner = Bridge.DB.GetOwnerColumn()
    local state = Bridge.DB.GetStateColumn()
    MySQL.update.await(
        ('UPDATE %s SET %s = 1, location = NULL, street = NULL WHERE %s = ? AND %s = 3'):format(tbl, state, owner, state),
        {citizenid}
    )

    TriggerClientEvent('dps-parking:client:syncParkedVehicles', -1, { vehicles = Parking.GetAllParked() })

    Bridge.Notify(targetId, L('parking_reset', 'your'), 'info')
    if source ~= 0 then
        Bridge.Notify(source, L('parking_reset', Bridge.GetPlayerName(targetId)), 'success')
    end
end, true)

-- Reset all parking
RegisterCommand(Config.Commands.resetAll, function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    -- Delete all parked vehicle entities
    local allParked = State.GetAllParkedVehicles()
    for plate, data in pairs(allParked) do
        if data.entity and DoesEntityExist(data.entity) then
            DeleteEntity(data.entity)
        end
        State.RemoveParkedVehicle(plate)
    end

    -- Reset database
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()
    MySQL.update.await(
        ('UPDATE %s SET %s = 1, location = NULL, street = NULL, parktime = 0 WHERE %s = 3'):format(tbl, state, state),
        {}
    )

    TriggerClientEvent('dps-parking:client:syncParkedVehicles', -1, { vehicles = {} })

    if source ~= 0 then
        Bridge.Notify(source, L('all_parking_reset'), 'success')
    end
    print('[DPS-Parking] All parking reset by admin')
end, true)

-- Toggle debug
RegisterCommand(Config.Commands.debugPoly, function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    TriggerClientEvent('dps-parking:client:toggleDebug', -1)

    if source ~= 0 then
        Bridge.Notify(source, 'Debug toggled', 'info')
    end
end, true)

-- Delete specific parked vehicle
RegisterCommand(Config.Commands.deleteParked, function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    local plate = args[1]
    if not plate then
        Bridge.Notify(source, 'Usage: /' .. Config.Commands.deleteParked .. ' [plate]', 'error')
        return
    end

    plate = Utils.FormatPlate(plate)
    local parkedVehicle = State.GetParkedVehicle(plate)

    if not parkedVehicle then
        Bridge.Notify(source, 'Vehicle not found', 'error')
        return
    end

    if parkedVehicle.entity and DoesEntityExist(parkedVehicle.entity) then
        DeleteEntity(parkedVehicle.entity)
    end

    State.RemoveParkedVehicle(plate)
    Bridge.DB.SetVehicleOut(plate)

    TriggerClientEvent('dps-parking:client:vehicleUnparked', -1, { plate = plate, netId = parkedVehicle.netid })

    if source ~= 0 then
        Bridge.Notify(source, 'Vehicle ' .. plate .. ' removed', 'success')
    end
end, true)

-- ============================================
-- ACE PERMISSIONS
-- ============================================

-- Register admin command permissions
RegisterCommand('dpsparking', function(source, args)
    if source == 0 then
        print('=== DPS-Parking Admin Commands ===')
        print('/' .. Config.Commands.addVip .. ' [id] [slots] - Add VIP')
        print('/' .. Config.Commands.removeVip .. ' [id] - Remove VIP')
        print('/' .. Config.Commands.resetPlayer .. ' [id] - Reset player parking')
        print('/' .. Config.Commands.resetAll .. ' - Reset all parking')
        print('/' .. Config.Commands.debugPoly .. ' - Toggle debug')
        print('/' .. Config.Commands.deleteParked .. ' [plate] - Delete parked vehicle')
        return
    end

    if not Bridge.IsAdmin(source) then
        Bridge.Notify(source, L('admin_only'), 'error')
        return
    end

    Bridge.Notify(source, 'DPS-Parking v1.0.0 - Check console for commands', 'info')
end, true)

print('^2[DPS-Parking] Admin commands loaded^0')
