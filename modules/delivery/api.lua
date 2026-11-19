--[[
    DPS-Parking - Delivery API
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development
]]

-- DPS 2026-11-19: switched off in the config until it is rebuilt.
if not (Config.Delivery and Config.Delivery.enabled) then return end

exports('RequestDelivery', function(source, plate, coords, rush)
    return Delivery.Request(source, plate, coords, rush)
end)

exports('GetPlayerDeliveries', function(citizenid)
    return State.GetPlayerDeliveries(citizenid)
end)

print('^2[DPS-Parking] Delivery API loaded^0')
