--[[
    DPS-Parking - Unified Configuration
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development
    Version: 1.0.0

    Single configuration file for all parking system settings.
]]

Config = {}

-- ============================================
-- DEBUG & DEVELOPMENT
-- ============================================

Config.Debug = false                          -- Enable debug mode
Config.DevMode = false                        -- Enable developer mode (extra logging)
Config.Locale = 'en'                          -- Language (en, nl, etc.)

-- ============================================
-- CORE PARKING SETTINGS
-- ============================================

Config.Parking = {
    -- Slot limits
    defaultMaxSlots = 5,                      -- Default parking slots per player
    maxVipSlots = 20,                         -- Maximum VIP slots

    -- Fees
    parkingFee = 100,                         -- Base fee to park
    payTimeRate = 10,                         -- $ per X seconds of parking

    -- Behavior
    requireEngineOff = true,                  -- Must turn off engine to park
    saveSteeringAngle = true,                 -- Remember wheel position
    disableCollision = true,                  -- Disable collision on parked cars
    parkWithTrailers = false,                 -- Allow parking with trailers attached
    parkTrailersWithLoad = false,             -- Allow trailers with cargo

    -- Timer/Auto-impound
    useTimerPark = true,                      -- Enable parking time limits
    maxParkTime = 259200,                     -- Max park time in seconds (3 days)
    impoundCheckInterval = 10000,             -- Check interval in ms

    -- Display
    display3DText = true,                     -- Show floating text on parked cars
    displayOwner = true,                      -- Show vehicle owner name
    displayBrand = true,                      -- Show vehicle brand
    displayModel = true,                      -- Show vehicle model
    displayPlate = true,                      -- Show license plate
    displayDistance = 15,                     -- Max distance to show text (meters)
    displayToAllPlayers = true,               -- Show to everyone (false = owner only)
    displayToPolice = true,                   -- Always show to police
    streamerMode = false,                     -- Hide all parking UI

    -- Auto-park
    useAutoPark = true,                       -- Auto-park when engine off + press F
    onlyAutoParkWhenEngineOff = true,         -- Require engine off for auto-park
}

-- ============================================
-- PARKING ZONES
-- ============================================

Config.Zones = {
    -- Zone restrictions
    useParkingLotsOnly = false,               -- Restrict parking to designated lots only
    usePrivateParking = true,                 -- Enable private/reserved parking areas

    -- Blips
    showParkingLotBlips = true,               -- Show blips for parking lots
    showNoParkingBlips = false,               -- Show blips for no-parking zones
    debugBlipForRadius = false,               -- Show debug radius on map
}

-- ============================================
-- PARKING METERS
-- ============================================

Config.Meters = {
    enabled = true,                           -- Enable parking meter system
    ratePerHour = 50,                         -- $ per hour
    minimumMinutes = 15,                      -- Minimum time to purchase
    maximumMinutes = 480,                     -- Maximum time (8 hours)
    graceMinutes = 5,                         -- Grace period after expiry
    ticketAmount = 150,                       -- Fine for expired meter
    towAfterMinutes = 30,                     -- Tow X minutes after expiry

    -- Premium zones (higher rates)
    premiumZones = {
        -- { coords = vector3(-250.0, -900.0, 31.0), radius = 100.0, multiplier = 2.0, name = 'Downtown' },
    },

    -- Free parking hours
    freeParking = {
        enabled = false,
        startHour = 20,                       -- 8 PM
        endHour = 8,                          -- 8 AM
    }
}

-- ============================================
-- VEHICLE DELIVERY
-- ============================================

Config.Delivery = {
    enabled = true,                           -- Enable delivery service
    baseCost = 500,                           -- Base delivery fee
    perMileCost = 50,                         -- Additional per mile
    rushMultiplier = 2.0,                     -- Rush delivery cost multiplier

    standardTime = 5,                         -- Standard delivery time (minutes)
    rushTime = 2,                             -- Rush delivery time (minutes)

    maxPerHour = 3,                           -- Max deliveries per hour per player
    cooldownMinutes = 10,                     -- Cooldown between deliveries

    -- Job discounts
    discounts = {
        ['mechanic'] = 0.50,                  -- 50% off
        ['police'] = 0.25,                    -- 25% off
    }
}

-- ============================================
-- PARKING LOT BUSINESS
-- ============================================

Config.Business = {
    enabled = true,                           -- Enable business ownership
    maxLotsPerPlayer = 3,                     -- Max lots one player can own
    ownerRevenuePercent = 70,                 -- Owner gets 70% of fees
    taxPercent = 10,                          -- City tax

    -- Employee system
    maxEmployeesPerLot = 5,
    employeePayPercent = 10,                  -- Employee cut per transaction

    -- Price limits (multiplier of base price)
    minPriceMultiplier = 0.5,                 -- 50% of base
    maxPriceMultiplier = 3.0,                 -- 300% of base

    -- Upgrades
    upgrades = {
        security = { cost = 50000, description = 'Security cameras and guards' },
        lighting = { cost = 25000, description = 'Better lighting' },
        capacity = { cost = 75000, description = '+10 parking spots' },
        evCharging = { cost = 100000, description = 'EV charging stations' },
        carwash = { cost = 150000, description = 'Automatic car wash' },
        valet = { cost = 200000, description = 'Valet service' },
    }
}

-- ============================================
-- VIP SYSTEM
-- ============================================

Config.VIP = {
    enabled = true,                           -- Enable VIP system
    useAsVip = false,                         -- Require VIP for any parking

    -- VIP perks
    perks = {
        freeMeters = false,                   -- Free parking meters
        discountPercent = 25,                 -- Discount on all parking
        priorityDelivery = true,              -- Faster delivery times
        reservedSpots = true,                 -- Access to reserved spots
    }
}

-- ============================================
-- INTEGRATION
-- ============================================

Config.Integration = {
    -- Phone integration
    phoneEnabled = true,                      -- Enable phone app integration

    -- Target script (auto-detected if nil)
    target = nil,                             -- ox_target, qb-target, or nil for auto

    -- Vehicle keys (auto-detected if nil)
    vehicleKeys = nil,                        -- qs-vehiclekeys, qb-vehiclekeys, qbx_vehiclekeys, or nil

    -- Vehicle persistence
    usePersistence = true,                    -- Integrate with dps-vehiclepersistence

    -- Discord webhook for audit logs
    discordWebhook = '',                      -- Your Discord webhook URL
}

-- ============================================
-- KEYBINDS & CONTROLS
-- ============================================

Config.Keybinds = {
    parkButton = 155,                         -- Control ID (155 = F5)
    parkKey = 'F5',                           -- Key name
    menuKey = 'F6',                           -- Open menu key
}

-- ============================================
-- COMMANDS
-- ============================================

Config.Commands = {
    -- Player commands
    park = 'park',                            -- Park vehicle
    parkmenu = 'parkmenu',                    -- Open parking menu
    delivery = 'delivery',                    -- Request delivery
    meter = 'meter',                          -- Pay parking meter
    tickets = 'tickets',                      -- View parking tickets
    toggleSteerAngle = 'togglesteerangle',    -- Toggle steer angle saving
    toggleParkText = 'toggleparktext',        -- Toggle 3D text display

    -- Admin commands
    addVip = 'addparkvip',                    -- Add VIP player
    removeVip = 'removeparkvip',              -- Remove VIP
    resetPlayer = 'parkresetplayer',          -- Reset player's parking
    resetAll = 'parkresetall',                -- Reset all parking
    debugPoly = 'parkdebug',                  -- Toggle debug polygons
    createLot = 'createlot',                  -- Create parking lot
    deleteLot = 'deletelot',                  -- Delete parking lot
    deleteParked = 'deletepark',              -- Delete parked vehicle
}

-- ============================================
-- BLIPS
-- ============================================

Config.Blips = {
    parkingLot = {
        sprite = 357,
        color = 2,                            -- Green
        scale = 0.7,
    },
    ownedLot = {
        sprite = 357,
        color = 5,                            -- Yellow
        scale = 0.8,
    },
    noParking = {
        sprite = 163,
        color = 1,                            -- Red
        scale = 0.5,
    }
}

-- ============================================
-- NO PARKING ZONES
-- ============================================

Config.NoParkingZones = {
    -- Job-restricted areas
    { coords = vector3(477.65, -1021.89, 27.39), radius = 20.0, jobs = {'police'}, name = 'MRPD Back Gate' },
    { coords = vector3(291.27, -587.29, 42.55), radius = 15.0, jobs = {'ambulance'}, name = 'Pillbox Hospital' },
    { coords = vector3(-333.02, -135.53, 38.37), radius = 15.0, jobs = {'mechanic'}, name = 'LS Customs 1' },
    { coords = vector3(731.73, -1088.91, 21.30), radius = 10.0, jobs = {'mechanic'}, name = 'LS Customs 2' },
    { coords = vector3(-212.25, -1325.47, 30.25), radius = 18.0, jobs = {'mechanic'}, name = 'Bennys' },
    { coords = vector3(539.61, -181.28, 53.85), radius = 30.0, jobs = {'mechanic'}, name = 'Mechanic Shop' },

    -- Public no-parking
    { coords = vector3(408.91, -1639.31, 28.66), radius = 25.0, jobs = nil, name = 'Impound' },
    { coords = vector3(-644.06, -232.35, 37.14), radius = 30.0, jobs = nil, name = 'Jewelry Store' },
    { coords = vector3(137.23, -3029.21, 20.42), radius = 50.0, jobs = nil, name = 'Airport Runway' },
}

-- ============================================
-- PARKING LOTS
-- ============================================

Config.ParkingLots = {
    -- Public parking lots
    { id = 1, coords = vector3(228.76, -786.55, 30.01), radius = 40.0, name = 'Legion Square Parking', capacity = 30, basePrice = 100, purchasePrice = 750000 },
    { id = 2, coords = vector3(40.60, -869.44, 29.83), radius = 30.0, name = 'Alta Street Parking', capacity = 25, basePrice = 75, purchasePrice = 500000 },
    { id = 3, coords = vector3(-318.91, -763.36, 33.33), radius = 50.0, name = 'Pillbox Hill Garage', capacity = 40, basePrice = 100, purchasePrice = 800000 },
    { id = 4, coords = vector3(65.46, 24.48, 68.98), radius = 15.0, name = 'Vinewood Parking', capacity = 15, basePrice = 150, purchasePrice = 1000000 },
    { id = 5, coords = vector3(-1136.97, -753.52, 18.76), radius = 17.0, name = 'Del Perro Lot', capacity = 20, basePrice = 50, purchasePrice = 400000 },
    { id = 6, coords = vector3(1702.28, 3769.26, 33.84), radius = 10.0, name = 'Sandy Shores Parking', capacity = 10, basePrice = 25, purchasePrice = 150000 },
    { id = 7, coords = vector3(45.98, 6376.60, 30.60), radius = 20.0, name = 'Paleto Bay Parking', capacity = 15, basePrice = 25, purchasePrice = 200000 },
    { id = 8, coords = vector3(-759.90, 5537.73, 32.85), radius = 20.0, name = 'Grapeseed Lot', capacity = 12, basePrice = 20, purchasePrice = 100000 },
}

-- ============================================
-- PRIVATE PARKING POLYZONES
-- ============================================

Config.PrivateParking = {
    -- Reserved spots that require ownership/permission
    -- Can be added dynamically through admin commands
}

return Config
