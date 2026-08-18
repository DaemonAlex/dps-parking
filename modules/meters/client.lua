--[[
    DPS-Parking - Meters Module (Client)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side meter UI and interactions.
]]

local activeMeters = {}

-- GetCloudTimeAsInt() returns 0 until cloud time syncs after join; fall back to
-- os.time() so early-session meter math doesn't produce absurd remaining times.
local function wallClock()
    local ct = GetCloudTimeAsInt()
    return (ct and ct > 0) and ct or os.time()
end

-- ============================================
-- METER PAYMENT
-- ============================================

---Open meter payment dialog
---@param plate string
function OpenMeterPayment(plate)
    if not Config.Meters.enabled then
        Bridge.Notify('Meters disabled', 'error')
        return
    end

    local input = Bridge.Input('Pay Parking Meter', {
        { type = 'number', label = 'Minutes', description = 'How many minutes?', default = 60, min = Config.Meters.minimumMinutes, max = Config.Meters.maximumMinutes }
    })

    if input and input[1] then
        local minutes = tonumber(input[1])
        TriggerServerEvent('dps-parking:server:payMeter', plate, minutes)
    end
end

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:client:meterPaid', function(data)
    activeMeters[data.plate] = data
    Bridge.Notify(L('meter_paid', Utils.FormatTime((data.expiresAt - wallClock()))), 'success')
end)

RegisterNetEvent('dps-parking:client:meterExpired', function(data)
    activeMeters[data.plate] = nil
    Bridge.Notify(L('meter_expired'), 'warning')
end)

-- ============================================
-- METER EXPIRY WARNING
-- ============================================

CreateThread(function()
    while true do
        local now = wallClock()

        for plate, data in pairs(activeMeters) do
            if data.expiresAt then
                local remaining = data.expiresAt - now

                -- Warn once at <= 5 minutes (a per-meter flag, not a 5s window
                -- the loop period could skip on a hitch)
                if remaining > 0 and remaining <= 300 and not data._warned then
                    data._warned = true
                    Bridge.Notify(L('meter_expiring', Utils.FormatTime(remaining)), 'warning')
                end

                -- Remove expired
                if remaining <= 0 then
                    activeMeters[plate] = nil
                end
            end
        end

        Wait(5000)
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('OpenMeterPayment', OpenMeterPayment)
exports('GetActiveMeters', function() return activeMeters end)

print('^2[DPS-Parking] Meters module (client) loaded^0')
