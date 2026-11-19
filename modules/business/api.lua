--[[
    DPS-Parking - Business API
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development
]]

-- DPS 2026-11-19: switched off in the config until it is rebuilt.
if not (Config.Business and Config.Business.enabled) then return end

exports('GetLotOwner', function(lotId)
    return State.GetBusinessOwner(lotId)
end)

exports('IsLotOwned', function(lotId)
    return State.GetBusinessOwner(lotId) ~= nil
end)

exports('PurchaseLot', function(source, lotId)
    return Business.PurchaseLot(source, lotId)
end)

print('^2[DPS-Parking] Business API loaded^0')
