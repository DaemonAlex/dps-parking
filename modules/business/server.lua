--[[
    DPS-Parking - Business Module (Server)
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Parking lot ownership and business management.
]]

Business = {}

-- ============================================
-- OWNERSHIP
-- ============================================

---Purchase a parking lot
---@param source number
---@param lotId number
---@return boolean success
---@return string message
function Business.PurchaseLot(source, lotId)
    if not Config.Business.enabled then
        return false, 'Business system disabled'
    end

    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then
        return false, L('error')
    end

    local lot = Zones.GetParkingLot(lotId)
    if not lot then
        return false, 'Lot not found'
    end

    -- Check if already owned
    local owner = State.GetBusinessOwner(lotId)
    if owner then
        return false, 'This lot is already owned'
    end

    -- Check max lots
    local ownedCount = 0
    for _, ownerData in pairs(State._data.businessOwners) do
        if ownerData.citizenid == citizenid then
            ownedCount = ownedCount + 1
        end
    end

    if ownedCount >= Config.Business.maxLotsPerPlayer then
        return false, 'You already own the maximum number of lots'
    end

    -- Check funds
    local price = lot.purchasePrice or 500000
    if Bridge.GetMoney(source, 'bank') < price then
        return false, L('insufficient_funds', Utils.FormatMoney(price))
    end

    -- Process purchase
    Bridge.RemoveMoney(source, 'bank', price, 'Parking lot purchase')

    State.SetBusinessOwner(lotId, {
        citizenid = citizenid,
        lotId = lotId,
        purchasedAt = os.time(),
        revenue = 0,
        employees = {},
        upgrades = {}
    })

    return true, L('lot_purchased', lot.name, Utils.FormatMoney(price))
end

---Collect revenue from owned lot
---@param source number
---@param lotId number
---@return boolean success
---@return string message
function Business.CollectRevenue(source, lotId)
    local citizenid = Bridge.GetCitizenId(source)
    local owner = State.GetBusinessOwner(lotId)

    if not owner or owner.citizenid ~= citizenid then
        return false, L('not_lot_owner')
    end

    local revenue = owner.revenue or 0
    if revenue <= 0 then
        return false, 'No revenue to collect'
    end

    -- Apply tax
    local tax = math.floor(revenue * (Config.Business.taxPercent / 100))
    local payout = revenue - tax

    Bridge.AddMoney(source, 'bank', payout, 'Parking lot revenue')

    -- Reset revenue
    owner.revenue = 0
    State.SetBusinessOwner(lotId, owner)

    return true, L('revenue_collected', Utils.FormatMoney(payout))
end

-- ============================================
-- REVENUE HOOK
-- ============================================

-- Add revenue when vehicles park in owned lots
EventBus.RegisterPostHook('parking:park', function(data)
    if not Config.Business.enabled then return end
    if not data.lot then return end

    local owner = State.GetBusinessOwner(data.lot.id)
    if not owner then return end

    local fee = data.lot.basePrice or Config.Parking.parkingFee
    local ownerCut = math.floor(fee * (Config.Business.ownerRevenuePercent / 100))

    owner.revenue = (owner.revenue or 0) + ownerCut
    State.SetBusinessOwner(data.lot.id, owner)
end, EventBus.Priority.LOW)

-- ============================================
-- EVENTS
-- ============================================

RegisterNetEvent('dps-parking:server:purchaseLot', function(lotId)
    local source = source
    local success, message = Business.PurchaseLot(source, lotId)
    Bridge.Notify(source, message, success and 'success' or 'error')
end)

RegisterNetEvent('dps-parking:server:collectRevenue', function(lotId)
    local source = source
    local success, message = Business.CollectRevenue(source, lotId)
    Bridge.Notify(source, message, success and 'success' or 'error')
end)

print('^2[DPS-Parking] Business module (server) loaded^0')

return Business
