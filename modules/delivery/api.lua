--[[
    DPS-Parking - Delivery API
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development
]]

exports('RequestDelivery', function(source, plate, coords, rush)
    return Delivery.Request(source, plate, coords, rush)
end)

exports('GetPlayerDeliveries', function(citizenid)
    return State.GetPlayerDeliveries(citizenid)
end)

print('^2[DPS-Parking] Delivery API loaded^0')
