--[[
    DPS-Parking - Phone Integration (CLIENT)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side phone app registration (lb-phone / qs-smartphone).
    H3: split out of integrations/phone.lua, which was wrongly loaded as a
    client_script even though it only contained server code.
    DPS 2026-10-26: real app page (ui/phone/index.html), icon, on the home screen,
    re-registered when the phone restarts. The page's callbacks live in app_client.lua.
]]

if not Config.Integration.phoneEnabled then
    return
end

-- Absolute address: the page and icon load inside the phone's frame, where
-- relative paths do not resolve.
local ICON = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/parking-icon.png'

-- ============================================
-- PHONE APP REGISTRATION
-- ============================================

local function RegisterPhoneApp()
    -- Try lb-phone
    if GetResourceState('lb-phone') == 'started' then
        local ok, err = pcall(function()
            exports['lb-phone']:AddCustomApp({
                identifier = 'dps-parking',
                name = 'Parking',
                description = 'Your parked cars, meters, deliveries, tickets and lots',
                developer = 'DelPerroSands',
                defaultApp = true,
                size = 110,
                ui = GetCurrentResourceName() .. '/ui/phone/index.html',
                icon = ICON,
            })
        end)
        if ok then
            print('^2[DPS-Parking] Registered with lb-phone^0')
        else
            print('^1[DPS-Parking] AddCustomApp failed: ' .. tostring(err) .. '^7')
        end
        return ok
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

-- Register on start, and again whenever the phone restarts after us, or the
-- icon disappears from the phone until this resource restarts too.
local function registerWhenReady(triesLeft)
    local state = GetResourceState('lb-phone')
    if state == 'started' then
        RegisterPhoneApp()
    elseif state == 'starting' and triesLeft > 0 then
        SetTimeout(3000, function() registerWhenReady(triesLeft - 1) end)
    else
        RegisterPhoneApp()
    end
end
SetTimeout(5000, function() registerWhenReady(5) end) -- Wait for phone resources to load

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'lb-phone' then return end
    SetTimeout(5000, RegisterPhoneApp)
end)

print('^2[DPS-Parking] Phone integration (client) loaded^0')
