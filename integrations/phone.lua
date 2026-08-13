--[[
    DPS-Parking - Phone Integration (SERVER)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Server-side phone callbacks (State.*, Delivery.*, Bridge.CreateCallback are all
    server-only). H3: this file is loaded as a server_script. The client-side app
    registration (lb-phone AddCustomApp) lives in integrations/phone_client.lua.
]]

if not Config.Integration.phoneEnabled then
    print('^3[DPS-Parking] Phone integration (server) disabled^0')
    return
end

-- ============================================
-- PHONE CALLBACKS (server)
-- ============================================

Bridge.CreateCallback('dps-parking:phone:getVehicles', function(source, cb)
    local citizenid = Bridge.GetCitizenId(source)
    local vehicles = State.GetPlayerParkedVehicles(citizenid)

    local formatted = {}
    for plate, data in pairs(vehicles) do
        table.insert(formatted, {
            plate = plate,
            model = data.model,
            street = data.street,
            parkedAt = data.parkedAt,
            hasActiveMeter = State.GetActiveMeter(plate) ~= nil
        })
    end

    cb(formatted)
end)

Bridge.CreateCallback('dps-parking:phone:requestDelivery', function(source, cb, plate, coords, rush)
    -- M4: Delivery.Request expects an options table, not a bare boolean.
    local success, message = Delivery.Request(source, plate, coords, { rush = rush })
    cb({ success = success, message = message })
end)

Bridge.CreateCallback('dps-parking:phone:getMeterStatus', function(source, cb, plate)
    local meter = State.GetActiveMeter(plate)
    if meter then
        cb({
            active = true,
            expiresAt = meter.expiresAt,
            remaining = meter.expiresAt - os.time()
        })
    else
        cb({ active = false })
    end
end)

print('^2[DPS-Parking] Phone integration (server) loaded^0')
