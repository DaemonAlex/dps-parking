--[[
    DPS-Parking - English Locale
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development
]]

Locale = Locale or {}

Locale.en = {
    -- General
    ['parking'] = 'Parking',
    ['success'] = 'Success',
    ['error'] = 'Error',
    ['confirm'] = 'Confirm',
    ['cancel'] = 'Cancel',
    ['close'] = 'Close',

    -- Parking actions
    ['vehicle_parked'] = 'Vehicle parked successfully',
    ['vehicle_unparked'] = 'Vehicle unparked',
    ['parking_failed'] = 'Failed to park vehicle',
    ['unparking_failed'] = 'Failed to unpark vehicle',
    ['not_owner'] = 'You do not own this vehicle',
    ['max_slots_reached'] = 'You have reached your maximum parking slots (%s/%s)',
    ['no_vehicle'] = 'You are not in a vehicle',
    ['engine_must_be_off'] = 'Turn off the engine first',
    ['vehicle_not_owned'] = 'You can only park owned vehicles',
    ['already_parked'] = 'This vehicle is already parked',
    ['vehicle_not_parked'] = 'This vehicle is not parked',

    -- Zones
    ['no_parking_zone'] = 'You cannot park here',
    ['restricted_area'] = 'This area is restricted to %s',
    ['parking_lot_only'] = 'You can only park in designated parking lots',
    ['in_parking_lot'] = 'Parking Lot: %s',

    -- Meters
    ['meter_paid'] = 'Parking meter paid for %s',
    ['meter_expired'] = 'Your parking meter has expired!',
    ['meter_expiring'] = 'Your parking meter expires in %s',
    ['meter_ticket'] = 'You received a parking ticket: %s',
    ['no_active_meter'] = 'No active parking meter',
    ['meter_already_paid'] = 'Meter already paid',
    ['free_parking_hours'] = 'Free parking is active',

    -- Delivery
    ['delivery_ordered'] = 'Delivery ordered. Your vehicle will arrive in %s',
    ['delivery_arrived'] = 'Your vehicle has arrived!',
    ['delivery_failed'] = 'Delivery failed',
    ['delivery_cooldown'] = 'Please wait %s before ordering another delivery',
    ['delivery_max_reached'] = 'Maximum deliveries reached for this hour',
    ['delivery_cost'] = 'Delivery cost: %s',
    ['rush_delivery'] = 'Rush delivery: %s',

    -- Business
    ['lot_purchased'] = 'You purchased %s for %s',
    ['lot_sold'] = 'You sold %s for %s',
    ['not_lot_owner'] = 'You do not own this parking lot',
    ['employee_added'] = 'Employee added',
    ['employee_removed'] = 'Employee removed',
    ['revenue_collected'] = 'You collected %s in revenue',

    -- VIP
    ['vip_status'] = 'VIP Status: %s',
    ['vip_slots'] = 'VIP Parking Slots: %s',
    ['vip_discount'] = 'VIP Discount Applied: %s%%',
    ['not_vip'] = 'You are not a VIP member',
    ['vip_added'] = 'VIP status granted',
    ['vip_removed'] = 'VIP status removed',

    -- Admin
    ['admin_only'] = 'This command is for administrators only',
    ['player_not_found'] = 'Player not found',
    ['parking_reset'] = 'Parking reset for %s',
    ['all_parking_reset'] = 'All parking data has been reset',
    ['debug_enabled'] = 'Debug mode enabled',
    ['debug_disabled'] = 'Debug mode disabled',

    -- Money
    ['insufficient_funds'] = 'Insufficient funds. Need: %s',
    ['payment_success'] = 'Paid: %s',
    ['refund_received'] = 'Refund received: %s',

    -- UI
    ['press_to_park'] = 'Press [%s] to park',
    ['press_to_unpark'] = 'Press [%s] to unpark',
    ['press_to_interact'] = 'Press [%s] to interact',
    ['parking_menu'] = 'Parking Menu',
    ['my_vehicles'] = 'My Parked Vehicles',
    ['park_vehicle'] = 'Park Vehicle',
    ['unpark_vehicle'] = 'Unpark Vehicle',
    ['request_delivery'] = 'Request Delivery',
    ['pay_meter'] = 'Pay Meter',
    ['view_tickets'] = 'View Tickets',

    -- 3D Text
    ['parked_vehicle'] = 'Parked Vehicle',
    ['owner'] = 'Owner: %s',
    ['plate'] = 'Plate: %s',
    ['time_remaining'] = 'Time: %s',

    -- Impound
    ['vehicle_impounded'] = 'Vehicle impounded due to expired parking',
    ['impound_warning'] = 'Warning: Vehicle will be impounded in %s',
}

-- Set default locale
Locale.Current = Locale.en

---Get localized string
---@param key string
---@param ... any Format arguments
---@return string
function L(key, ...)
    local text = Locale.Current[key] or Locale.en[key] or key
    if select('#', ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

return Locale
