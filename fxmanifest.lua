--[[
    DPS-Parking - Advanced Parking System
    Original Script: mh-parking by MaDHouSe79
    Enhanced Version: DPS Development
    License: GPL-3.0

    Features:
    - Modular architecture with EventBus and StateManager
    - Parking meters with premium zones
    - Business ownership system
    - Vehicle delivery service
    - VIP parking perks
    - Phone integration
    - Framework-agnostic (QB/QBX/ESX)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dps-parking'
author 'DPS Development (Original: MaDHouSe79)'
description 'Advanced Parking System with Meters, Business Ownership, Delivery & Phone Integration'
version '1.0.0'

-- Dependencies
dependencies {
    'oxmysql',
    'ox_lib',
}

-- Shared files (load first)
shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'core/utils/shared.lua',
    'core/events/eventbus.lua',
    'locales/en.lua',
}

-- Client scripts
client_scripts {
    -- Optional PolyZone support
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',

    -- Core
    'core/bridge/init.lua',
    'core/utils/vehicle.lua',
    'core/bridge/client.lua',
    'core/state/client.lua',

    -- Modules
    'modules/zones/client.lua',
    'modules/parking/client.lua',
    'modules/meters/client.lua',
    'modules/delivery/client.lua',

    -- Integrations
    'integrations/phone.lua',
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- Core
    'core/bridge/init.lua',
    'core/bridge/server.lua',
    'core/database/queries.lua',
    'core/state/server.lua',

    -- Modules
    'modules/zones/server.lua',
    'modules/parking/server.lua',
    'modules/parking/api.lua',
    'modules/meters/server.lua',
    'modules/meters/api.lua',
    'modules/business/server.lua',
    'modules/business/api.lua',
    'modules/delivery/server.lua',
    'modules/delivery/api.lua',

    -- Admin
    'admin/commands.lua',
    'admin/audit.lua',
}

-- UI files
ui_page 'ui/garage/index.html'

files {
    'ui/garage/index.html',
    'ui/garage/style.css',
    'ui/garage/app.js',
    'ui/meters/index.html',
    'ui/phone/index.html',
}

-- Exports (for other resources)
provides {
    'dps-parking',
}
