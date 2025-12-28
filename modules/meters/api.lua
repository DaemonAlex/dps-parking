--[[
    DPS-Parking - Meters API
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development
]]

exports('PayMeter', function(source, plate, minutes)
    return Meters.Pay(source, plate, minutes)
end)

exports('GetMeterStatus', function(plate)
    return State.GetActiveMeter(plate)
end)

exports('GetExpiredMeters', function()
    return State.GetExpiredMeters()
end)

print('^2[DPS-Parking] Meters API loaded^0')
