--[[
    DPS-Parking - Meters Module (Server)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Parking meter functionality.
]]

Meters = {}

-- ============================================
-- METER OPERATIONS
-- ============================================

---Pay for parking meter
---@param source number
---@param plate string
---@param minutes number
---@return boolean success
---@return string message
function Meters.Pay(source, plate, minutes)
    if not Config.Meters.enabled then
        return false, 'Meters disabled'
    end

    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then
        return false, L('error')
    end

    -- Validate time
    if minutes < Config.Meters.minimumMinutes then
        minutes = Config.Meters.minimumMinutes
    elseif minutes > Config.Meters.maximumMinutes then
        minutes = Config.Meters.maximumMinutes
    end

    -- Calculate cost
    local hours = minutes / 60
    local cost = math.ceil(hours * Config.Meters.ratePerHour)

    -- Check for premium zone multiplier
    local parkedVehicle = State.GetParkedVehicle(plate)
    if parkedVehicle and parkedVehicle.location then
        local coords = vector3(parkedVehicle.location.x, parkedVehicle.location.y, parkedVehicle.location.z)
        for _, zone in ipairs(Config.Meters.premiumZones) do
            if Utils.IsInRadius(coords, zone.coords, zone.radius) then
                cost = math.ceil(cost * zone.multiplier)
                break
            end
        end
    end

    -- VIP discount
    if State.IsVip(citizenid) and Config.VIP.perks.discountPercent > 0 then
        local discount = cost * (Config.VIP.perks.discountPercent / 100)
        cost = math.ceil(cost - discount)
    end

    -- Check free parking hours
    if Config.Meters.freeParking.enabled then
        local hour = tonumber(os.date('%H'))
        if hour >= Config.Meters.freeParking.startHour or hour < Config.Meters.freeParking.endHour then
            cost = 0
        end
    end

    -- Check if VIP has free meters
    if State.IsVip(citizenid) and Config.VIP.perks.freeMeters then
        cost = 0
    end

    -- Charge player
    if cost > 0 then
        local hasMoney = Bridge.GetMoney(source, 'cash') >= cost
        if not hasMoney then
            hasMoney = Bridge.GetMoney(source, 'bank') >= cost
            if hasMoney then
                Bridge.RemoveMoney(source, 'bank', cost, 'Parking meter')
            end
        else
            Bridge.RemoveMoney(source, 'cash', cost, 'Parking meter')
        end

        if not hasMoney then
            return false, L('insufficient_funds', Utils.FormatMoney(cost))
        end
    end

    -- Set meter
    local expiresAt = os.time() + (minutes * 60)
    State.SetActiveMeter(plate, {
        plate = plate,
        citizenid = citizenid,
        paidAt = os.time(),
        expiresAt = expiresAt,
        paidAmount = cost,
        minutes = minutes
    })

    -- Notify client
    TriggerClientEvent('dps-parking:client:meterPaid', source, {
        plate = plate,
        expiresAt = expiresAt,
        cost = cost
    })

    return true, L('meter_paid', Utils.FormatTime(minutes * 60))
end

---Check for expired meters
local function CheckExpiredMeters()
    if not Config.Meters.enabled then return end

    local expired = State.GetExpiredMeters()
    local now = os.time()

    for plate, meterData in pairs(expired) do
        local gracePeriod = Config.Meters.graceMinutes * 60
        local expiredTime = now - meterData.expiresAt

        -- Check if past grace period
        if expiredTime > gracePeriod then
            -- Issue ticket
            local ticketAmount = Config.Meters.ticketAmount

            Utils.Debug(('Meter expired for %s, issuing ticket of %s'):format(plate, ticketAmount))

            -- TODO: Issue ticket to owner
            EventBus.Publish('meters:ticketIssued', {
                plate = plate,
                citizenid = meterData.citizenid,
                amount = ticketAmount
            })

            -- Check if should tow
            local towTime = Config.Meters.towAfterMinutes * 60
            if expiredTime > towTime then
                Utils.Debug(('Towing vehicle %s for expired meter'):format(plate))

                local parkedVehicle = State.GetParkedVehicle(plate)
                if parkedVehicle then
                    Bridge.PoliceImpound(plate, true, ticketAmount,
                        parkedVehicle.body, parkedVehicle.engine, parkedVehicle.fuel)

                    if parkedVehicle.entity and DoesEntityExist(parkedVehicle.entity) then
                        DeleteEntity(parkedVehicle.entity)
                    end

                    State.RemoveParkedVehicle(plate)
                    State.RemoveActiveMeter(plate)

                    TriggerClientEvent('dps-parking:client:vehicleImpounded', -1, { plate = plate })
                end
            end
        end
    end
end

-- Meter check loop
CreateThread(function()
    Bridge.WaitReady()
    Wait(10000)

    while true do
        CheckExpiredMeters()
        Wait(60000) -- Check every minute
    end
end)

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:server:payMeter', function(plate, minutes)
    local source = source
    local success, message = Meters.Pay(source, plate, minutes)
    Bridge.Notify(source, message, success and 'success' or 'error')
end)

-- ============================================
-- CALLBACKS
-- ============================================

Bridge.CreateCallback('dps-parking:getMeterStatus', function(source, cb, plate)
    local meter = State.GetActiveMeter(plate)
    if meter then
        local remaining = meter.expiresAt - os.time()
        cb({ active = true, remaining = remaining, expiresAt = meter.expiresAt })
    else
        cb({ active = false })
    end
end)

print('^2[DPS-Parking] Meters module (server) loaded^0')

return Meters
