# DPS-Parking

Advanced Parking System with Modular Architecture for FiveM.

## Credits

- **Original Script**: [mh-parking](https://github.com/MaDHouSe79/mh-parking) by MaDHouSe79
- **Enhanced Version**: DPS Development
- **License**: GPL-3.0

## Features

- **Modular Architecture**: EventBus, StateManager, and module-based design
- **Framework Agnostic**: Supports QB-Core, QBX, and ESX
- **Parking Meters**: Time-based parking with premium zones
- **Business Ownership**: Buy and manage parking lots
- **Vehicle Delivery**: Request parked vehicles delivered to you
- **VIP System**: Special perks and extra parking slots
- **Phone Integration**: Works with lb-phone and qs-smartphone
- **Extension Hooks**: Pre/post hooks for custom integrations

## Dependencies

- oxmysql
- ox_lib
- PolyZone (optional)

## Installation

1. Add `dps-parking` to your resources folder
2. Add to your `server.cfg`:
   ```
   ensure oxmysql
   ensure ox_lib
   ensure dps-parking
   ```
3. Configure `config/config.lua` for your server

## Architecture

```
dps-parking/
├── config/           # Configuration
├── core/
│   ├── bridge/       # Framework abstraction
│   ├── events/       # EventBus system
│   ├── state/        # StateManager
│   └── utils/        # Utilities
├── modules/
│   ├── parking/      # Core parking
│   ├── meters/       # Parking meters
│   ├── business/     # Lot ownership
│   ├── delivery/     # Vehicle delivery
│   └── zones/        # Zone management
├── integrations/     # Phone, etc.
├── admin/            # Admin commands
├── locales/          # Translations
└── ui/               # NUI files
```

## Exports

### Server

```lua
-- Parking
exports['dps-parking']:ParkVehicle(source, data)
exports['dps-parking']:UnparkVehicle(source, plate)
exports['dps-parking']:GetParkedVehicle(plate)
exports['dps-parking']:IsVehicleParked(plate)
exports['dps-parking']:GetPlayerParkedVehicles(citizenid)

-- Hooks
exports['dps-parking']:RegisterPreHook(action, callback, priority)
exports['dps-parking']:RegisterPostHook(action, callback, priority)

-- VIP
exports['dps-parking']:SetVipPlayer(citizenid, slots, perks)
exports['dps-parking']:RemoveVipPlayer(citizenid)
exports['dps-parking']:IsVipPlayer(citizenid)
```

### Client

```lua
exports['dps-parking']:ParkCurrentVehicle()
exports['dps-parking']:UnparkVehicle(plate)
exports['dps-parking']:GetLocalParkedVehicles()
```

## Hooks

Register hooks to extend functionality:

```lua
-- Pre-hook: Return false to cancel action
exports['dps-parking']:RegisterPreHook('parking:park', function(data)
    -- data.source, data.citizenid, data.data
    if someCondition then
        return false -- Cancel parking
    end
    return true, data -- Continue with optionally modified data
end)

-- Post-hook: React to completed actions
exports['dps-parking']:RegisterPostHook('parking:park', function(data)
    -- Vehicle was parked, do something
end)
```

## Events

Subscribe to events:

```lua
EventBus.Subscribe('parking:park', function(data) end)
EventBus.Subscribe('parking:unpark', function(data) end)
EventBus.Subscribe('parking:impounded', function(data) end)
EventBus.Subscribe('meters:ticketIssued', function(data) end)
```

## Commands

### Player
- `/park` - Park current vehicle
- `/parkmenu` - Open parking menu
- `/delivery` - Request delivery

### Admin
- `/addparkvip [id] [slots]` - Add VIP
- `/removeparkvip [id]` - Remove VIP
- `/parkresetplayer [id]` - Reset player's parking
- `/parkresetall` - Reset all parking
- `/parkdebug` - Toggle zone debug

## UI Customization

The UI files in `/ui/` are placeholders. Replace them with your server's UI framework for visual consistency.

## License

GPL-3.0 - See LICENSE file
