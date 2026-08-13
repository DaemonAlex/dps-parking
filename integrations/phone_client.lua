--[[
    DPS-Parking - Phone Integration (CLIENT)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side phone app registration (lb-phone / qs-smartphone).
    H3: split out of integrations/phone.lua, which was wrongly loaded as a
    client_script even though it only contained server code.
]]

if not Config.Integration.phoneEnabled then
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
-- INITIALIZE
-- ============================================

CreateThread(function()
    Wait(5000) -- Wait for phone resources to load
    RegisterPhoneApp()
end)

print('^2[DPS-Parking] Phone integration (client) loaded^0')
