--[[
    DPS-Parking - Audit Logging
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Discord webhook and logging for audit trail.
]]

Audit = {}

-- ============================================
-- DISCORD WEBHOOK
-- ============================================

---Send audit log to Discord
---@param title string
---@param description string
---@param color? number
---@param fields? table
function Audit.LogToDiscord(title, description, color, fields)
    local webhook = Config.Integration.discordWebhook
    if not webhook or webhook == '' then return end

    color = color or 3447003 -- Blue

    local embed = {
        {
            title = title,
            description = description,
            color = color,
            fields = fields or {},
            footer = {
                text = 'DPS-Parking Audit Log'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers)
        if err ~= 200 and err ~= 204 then
            Utils.Debug(('Discord webhook error: %s'):format(err))
        end
    end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
end

-- ============================================
-- EVENT SUBSCRIPTIONS
-- ============================================

-- Log vehicle parked
EventBus.Subscribe('parking:park', function(data)
    if not Config.Integration.discordWebhook or Config.Integration.discordWebhook == '' then return end

    Audit.LogToDiscord(
        'Vehicle Parked',
        ('**%s** parked vehicle **%s**'):format(data.citizenid, data.plate),
        3066993, -- Green
        {
            { name = 'Plate', value = data.plate, inline = true },
            { name = 'Location', value = data.data and data.data.street or 'Unknown', inline = true }
        }
    )
end)

-- Log vehicle unparked
EventBus.Subscribe('parking:unpark', function(data)
    if not Config.Integration.discordWebhook or Config.Integration.discordWebhook == '' then return end

    Audit.LogToDiscord(
        'Vehicle Unparked',
        ('**%s** retrieved vehicle **%s**'):format(data.citizenid, data.plate),
        15105570, -- Orange
        {
            { name = 'Plate', value = data.plate, inline = true }
        }
    )
end)

-- Log impounds
EventBus.Subscribe('parking:impounded', function(data)
    Audit.LogToDiscord(
        'Vehicle Impounded',
        ('Vehicle **%s** was impounded'):format(data.plate),
        15158332, -- Red
        {
            { name = 'Plate', value = data.plate, inline = true },
            { name = 'Reason', value = data.reason or 'Unknown', inline = true },
            { name = 'Cost', value = Utils.FormatMoney(data.cost or 0), inline = true }
        }
    )
end)

-- Log tickets
EventBus.Subscribe('meters:ticketIssued', function(data)
    Audit.LogToDiscord(
        'Parking Ticket Issued',
        ('Ticket issued for vehicle **%s**'):format(data.plate),
        16776960, -- Yellow
        {
            { name = 'Plate', value = data.plate, inline = true },
            { name = 'Amount', value = Utils.FormatMoney(data.amount), inline = true }
        }
    )
end)

print('^2[DPS-Parking] Audit logging loaded^0')

return Audit
