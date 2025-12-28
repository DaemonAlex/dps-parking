--[[
    DPS-Parking - Phone Integration
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Integration with phone resources (lb-phone, qs-smartphone, etc.)
]]

if not Config.Integration.phoneEnabled then
    print('^3[DPS-Parking] Phone integration disabled^0')
    return
end

-- ============================================
-- PHONE APP REGISTRATION
-- ============================================

local function RegisterPhoneApp()
    -- Try lb-phone
    if GetResourceState('lb-phone') == 'started' then
        exports['lb-phone']:AddCustomApp({
            identifier = 'dps-parking',
            name = 'Parking',
            description = 'Manage your parked vehicles',
            developer = 'DPS Development',
            defaultApp = false,
            ui = GetCurrentResourceName() .. '/ui/phone/index.html'
        })
        print('^2[DPS-Parking] Registered with lb-phone^0')
        return true
    end

    -- Try qs-smartphone-pro
    if GetResourceState('qs-smartphone-pro') == 'started' then
        -- QS smartphone uses different registration
        print('^2[DPS-Parking] QS Smartphone detected - use built-in integration^0')
        return true
    end

    return false
end

-- ============================================
-- PHONE CALLBACKS
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
    local success, message = Delivery.Request(source, plate, coords, rush)
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

-- ============================================
-- INITIALIZE
-- ============================================

CreateThread(function()
    Wait(5000) -- Wait for phone resources to load
    RegisterPhoneApp()
end)

print('^2[DPS-Parking] Phone integration loaded^0')
