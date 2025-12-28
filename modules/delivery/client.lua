--[[
    DPS-Parking - Delivery Module (Client)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side delivery UI.
]]

---Request delivery for a vehicle
---@param plate string
function RequestDelivery(plate)
    if not Config.Delivery.enabled then
        Bridge.Notify('Delivery disabled', 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local input = Bridge.Input('Request Vehicle Delivery', {
        { type = 'checkbox', label = 'Rush Delivery', description = 'Faster but costs more' }
    })

    if input then
        local rush = input[1] == true
        TriggerServerEvent('dps-parking:server:requestDelivery', plate, {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            h = heading
        }, rush)
    end
end

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:client:deliveryArrived', function(data)
    -- Give keys
    Bridge.GiveKeys(data.plate)

    -- Create blip
    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if DoesEntityExist(vehicle) then
        local blip = AddBlipForEntity(vehicle)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Delivered Vehicle')
        EndTextCommandSetBlipName(blip)

        -- Remove blip after 60 seconds
        SetTimeout(60000, function()
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end)
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('RequestDelivery', RequestDelivery)

print('^2[DPS-Parking] Delivery module (client) loaded^0')
