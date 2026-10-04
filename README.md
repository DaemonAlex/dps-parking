# dps-parking

Parking system for Qbox servers: parked cars, meters, tickets, impound, valet, delivery and reserved spots.

## Features

- Park a vehicle where you leave it. It stays in the world, frozen, with optional floating text (owner, plate, brand).
- Parking limit per player (default 5 slots). VIP players get more slots.
- Auto-park: with the engine off, press `E` in the driver seat to park.
- Timed parking: a car parked longer than the maximum time is charged and impounded.
- Parking lots (8 defaults) and no-parking zones, with optional job exceptions.
- Lot business: players buy a lot, earn a share of the fees, and pay city tax.
- Parking meters: pay by the minute, premium price zones, free hours, grace time, automatic ticket and tow on expiry.
- Violations: seven ticket types, late fees, pay and contest tickets, police issue tickets.
- Impound: fee by reason, daily fee growth, insurance discount, police impound, admin release.
- Insurance check on impound fees.
- Valet: NPC valet that parks and retrieves cars, with tips for faster service.
- Delivery: have your parked car delivered to you. Rush option, VIP tiers, NPC driver for higher tiers, job discounts.
- Reserved spots: VIP, job, business and rental spots.
- Dispatch alerts to police for expired meters and zone violations.
- Phone app for your parked cars (lb-phone).
- Discord audit log (optional).
- Pre-hooks and post-hooks plus exports for other resources.

### Commands

Player:

| Command | What it does |
|---|---|
| `/park` | Park the vehicle you are driving. Also bound to the key in `Config.Keybinds.parkKey` (default F5). |
| `/tickets` | Open your parking tickets. |
| `/rentspot` | Open the rental spot menu. |
| `/myrentals` | Show your rented spots. |
| `/issueticket` | Open the ticket menu. Only for jobs in the ticket job list (see Job permissions). |

Admin (ACE `group.admin`, `admin` or `command`; the server console always works):

| Command | What it does |
|---|---|
| `/addparkvip [id] [slots]` | Make a player VIP. Saved in the database. |
| `/removeparkvip [id]` | Remove VIP. |
| `/parkresetplayer [id]` | Reset one player's parking. |
| `/parkresetall` | Reset all parking. |
| `/parkdebug` | Toggle zone debug polygons (the same name is registered on the client). |
| `/deletepark [plate]` | Delete a parked vehicle. |
| `/dpsparking` | Show the admin command list (console) or a notice (in game). |

The admin command names come from `Config.Commands`. Player commands `/park`, `/tickets`, `/issueticket`, `/rentspot` and `/myrentals` have fixed names.

Keys:

- `F5` (`Config.Keybinds.parkKey`): park. Players can rebind it in the game key settings.
- `E`: auto-park prompt when the engine is off and `useAutoPark` and `onlyAutoParkWhenEngineOff` are on.
- Impound keybind for police: only registered when `Config.Impound.policeKeybind` is set (see Configuration).

Meters, delivery and the valet have no chat command. Meters and delivery are opened through the exports `OpenMeterPayment` and `RequestDelivery`, or through the phone app. The valet is used through its NPC with ox_target or qb-target.

### Exports

Server:

```lua
-- Parking
exports['dps-parking']:ParkVehicle(source, data)
exports['dps-parking']:UnparkVehicle(source, plate)
exports['dps-parking']:GetParkedVehicle(plate)
exports['dps-parking']:IsVehicleParked(plate)
exports['dps-parking']:GetAllParkedVehicles()
exports['dps-parking']:GetPlayerParkedVehicles(citizenid)
exports['dps-parking']:GetPlayerMaxSlots(citizenid)
exports['dps-parking']:SetPlayerMaxSlots(citizenid, slots)
exports['dps-parking']:CanPlayerPark(citizenid)

-- VIP
exports['dps-parking']:SetVipPlayer(citizenid, slots, perks)
exports['dps-parking']:RemoveVipPlayer(citizenid)
exports['dps-parking']:IsVipPlayer(citizenid)

-- Hooks and events
exports['dps-parking']:RegisterPreHook(action, callback, priority)
exports['dps-parking']:RegisterPostHook(action, callback, priority)
exports['dps-parking']:OnParkingEvent(event, callback)

-- Meters
exports['dps-parking']:PayMeter(source, plate, minutes)
exports['dps-parking']:GetMeterStatus(plate)
exports['dps-parking']:GetExpiredMeters()

-- Business
exports['dps-parking']:GetLotOwner(lotId)
exports['dps-parking']:IsLotOwned(lotId)
exports['dps-parking']:PurchaseLot(source, lotId)

-- Delivery
exports['dps-parking']:RequestDelivery(source, plate, coords, rush)
exports['dps-parking']:GetPlayerDeliveries(citizenid)

-- Zones
exports['dps-parking']:IsInNoParkingZone(...)
exports['dps-parking']:IsInParkingLot(...)
exports['dps-parking']:CanParkAt(...)
exports['dps-parking']:GetParkingLot(...)
exports['dps-parking']:GetVehiclesInLot(...)
```

Client:

```lua
exports['dps-parking']:ParkCurrentVehicle()
exports['dps-parking']:UnparkVehicle(plate)
exports['dps-parking']:GetLocalParkedVehicles()
exports['dps-parking']:OpenMeterPayment(plate)
exports['dps-parking']:GetActiveMeters()
exports['dps-parking']:RequestDelivery(plate)
exports['dps-parking']:ShowActiveDeliveries()
exports['dps-parking']:OpenTicketsMenu()
exports['dps-parking']:OpenRentalMenu()
exports['dps-parking']:ShowMyRentals()
exports['dps-parking']:IsInNoParkingZone()
exports['dps-parking']:IsInParkingLot()
exports['dps-parking']:ToggleZoneDebug()
```

### Hooks

```lua
-- Pre-hook: return false to cancel
exports['dps-parking']:RegisterPreHook('parking:park', function(data)
    if someCondition then return false end
    return true, data
end)

-- Post-hook: runs after the action
exports['dps-parking']:RegisterPostHook('parking:park', function(data) end)
```

The parking module runs the hooks `parking:park` and `parking:unpark`. The events `parking:impounded` and `meters:expired` are published on the EventBus.

## Prerequisites

Required:

- `oxmysql`
- `ox_lib`
- `qbx_core` (the code also detects `qb-core` and `es_extended`, but this guide covers Qbox)
- A vehicle table with columns for parking data. On Qbox this is `player_vehicles`.

Optional, detected automatically. Each one is used only if it is started:

- Target: `ox_target` or `qb-target`. Needed for the valet and impound NPCs. You can force one with `Config.Integration.target`.
- Insurance (first found wins): `dps-insurance`, `qs-insurance`, `qb-vehicleinsurance`, `wasabi_insurance`, `esx_insurance`, `renewed-insurance`, `jg-insurance`. Without one, no insurance discount is applied. Only `dps-insurance`, `qs-insurance`, `qb-vehicleinsurance`, `wasabi_insurance`, `renewed-insurance` and `jg-insurance` have an insured check in the code.
- Garages (first found wins): `jg-advancedgarages`, `qs-advancedgarages`, `qb-garages`, `cd_garage`, `esx_garages`, `okokGarage`, `renewed-vehiclekeys`. Used to set the stored, out and impound state.
- Dispatch (first found wins): `wasabi_mdt`, `qs-dispatch`, `ps-dispatch`, `cd_dispatch`, `origen_dispatch`, `rcore_dispatch`.
- Billing: `qs-billing`, `qb-billing`, `esx_billing`, `okokBilling`. Without one, ticket fees are charged directly.
- Society money: `qs-banking`, `Renewed-Banking`, `qbx_management`, `qb-banking`, `qb-management`. Fines are paid into the `government` account.
- Phone: `lb-phone` (the app is registered automatically).
- Fuel: `LegacyFuel`, `cdn-fuel`, `ps-fuel`, `qs-fuelstations`.
- Vehicle keys: `qs-vehiclekeys`, `qb-vehiclekeys`, `qbx_vehiclekeys`. You can force one with `Config.Integration.vehicleKeys`.
- `dps-vehiclepersistence`: if started, parked cars are checked against it.

## Installation

1. Copy the folder `dps-parking` into your `resources` folder.
2. Import the SQL file `database/schema.sql` into your database, for example:
   ```
   mysql <database> < database/schema.sql
   ```
   It adds the columns `parking_data`, `vehicle_state`, `parking_lot` and `parked_at` to `player_vehicles`, two indexes, and creates these tables: `dps_parking_vip`, `dps_parking_business`, `dps_parking_meters`, `dps_parking_deliveries`, `dps_parking_audit`. The ESX block in the file is commented out. The script does not create tables by itself.
3. Add to `server.cfg`, after your framework, database, ox_lib and any optional scripts above:
   ```
   ensure oxmysql
   ensure ox_lib
   ensure qbx_core
   ensure dps-parking
   ```
   Start `dps-parking` after your insurance, garage, dispatch, billing, target and phone scripts so they are detected.
4. Give your admins an ACE so they can use the admin commands. The code accepts `group.admin`, `admin` or `command`, for example:
   ```
   add_ace group.admin command allow
   ```
   Qbox admins normally already have `group.admin`.
5. Edit `config/config.lua`, and the job tables in `integrations/permissions.lua` (see Job permissions).
6. Restart the server.

## Configuration

All options are in `config/config.lua`. Values below are the defaults.

### Debug

| Option | Default | Meaning |
|---|---|---|
| `Config.Debug` | `false` | Print debug messages. |
| `Config.DevMode` | `false` | Developer mode flag. Not read by the code. |
| `Config.Locale` | `'en'` | Language label. The only locale file is `locales/en.lua`. |

### Config.Parking

| Option | Default | Meaning |
|---|---|---|
| `defaultMaxSlots` | `5` | Parking slots per player. |
| `maxVipSlots` | `20` | Not read by the code. Set VIP slots with `/addparkvip`. |
| `parkingFee` | `100` | Base fee, used for timed charges and as the default lot fee. |
| `payTimeRate` | `10` | Seconds per fee unit in the timed charge: cost = seconds parked / `payTimeRate` x `parkingFee`. |
| `requireEngineOff` | `true` | The engine must be off to park. |
| `saveSteeringAngle` | `true` | Remember the wheel position. |
| `disableCollision` | `true` | Turn off collision on parked cars. |
| `parkWithTrailers` | `false` | Allow parking with a trailer attached. |
| `parkTrailersWithLoad` | `false` | Not read by the code. |
| `useTimerPark` | `true` | Turn on the parking time limit. |
| `maxParkTime` | `259200` | Maximum park time in seconds (3 days). |
| `impoundCheckInterval` | `10000` | How often the time limit is checked, in ms. |
| `display3DText` | `true` | Show floating text on parked cars. |
| `displayOwner` | `true` | Show the owner name. |
| `displayBrand` | `true` | Show the vehicle name. |
| `displayModel` | `true` | Not read by the code. |
| `displayPlate` | `true` | Show the plate. |
| `displayDistance` | `15` | Distance in meters to show the text. |
| `displayToAllPlayers` | `true` | Show the text to everyone. If false, only police see it (when `displayToPolice` is on). |
| `displayToPolice` | `true` | Show the text to police jobs when it is hidden for others. |
| `streamerMode` | `false` | Hide the floating text. |
| `useAutoPark` | `true` | Turn on auto-park. |
| `onlyAutoParkWhenEngineOff` | `true` | Auto-park uses `E` with the engine off. If false, it uses `Config.Keybinds.parkButton` with the engine on. |

### Config.Zones

| Option | Default | Meaning |
|---|---|---|
| `useParkingLotsOnly` | `false` | Allow parking only inside lots from `Config.ParkingLots`. |
| `usePrivateParking` | `true` | Not read by the code. |
| `showParkingLotBlips` | `true` | Show lot blips. |
| `showNoParkingBlips` | `false` | Show no-parking zone blips. |
| `debugBlipForRadius` | `false` | Not read by the code. |

### Config.Meters

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Turn meters on. |
| `ratePerHour` | `50` | Price per hour. |
| `minimumMinutes` | `15` | Smallest purchase. |
| `maximumMinutes` | `480` | Largest purchase (8 hours). |
| `graceMinutes` | `5` | Time after expiry before a ticket. |
| `ticketAmount` | `150` | Fine for an expired meter. |
| `towAfterMinutes` | `30` | Minutes after expiry before the car is impounded. |
| `premiumZones` | `{}` | List of `{ coords = vector3, radius = number, multiplier = number, name = string }`. A car inside a zone pays the multiplier. |
| `freeParking.enabled` | `false` | Free parking in a time window. |
| `freeParking.startHour` | `20` | Window start (server hour, 24h). |
| `freeParking.endHour` | `8` | Window end. |

### Config.Delivery

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Turn delivery on. |
| `baseCost` | `500` | Base fee. |
| `perMileCost` | `50` | Not read by the code. |
| `rushMultiplier` | `2.0` | Rush price multiplier. |
| `standardTime` | `5` | Minutes for a standard delivery. |
| `rushTime` | `2` | Minutes for a rush delivery. |
| `maxPerHour` | `3` | Not read by the code. Hourly limits come from the VIP tiers (none 2, bronze 3, silver 5, gold 10, platinum unlimited) in `modules/delivery/server.lua`. |
| `cooldownMinutes` | `10` | Not read by the code. |
| `discounts` | see below | Discount by job name. |

Default discounts: `mechanic` 0.50, `police` 0.25, `bcso` 0.25, `sasp` 0.25, `rpd` 0.25, `rcso` 0.25.

### Config.Business

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Turn lot ownership on. |
| `maxLotsPerPlayer` | `3` | Lots one player can own. |
| `ownerRevenuePercent` | `70` | Owner share of each parking fee. |
| `taxPercent` | `10` | City tax taken when the owner collects revenue. |
| `maxEmployeesPerLot` | `5` | Not read by the code. |
| `employeePayPercent` | `10` | Not read by the code. |
| `minPriceMultiplier` | `0.5` | Not read by the code. |
| `maxPriceMultiplier` | `3.0` | Not read by the code. |
| `upgrades` | six entries | `security` 50000, `lighting` 25000, `capacity` 75000, `evCharging` 100000, `carwash` 150000, `valet` 200000. Each has `cost` and `description`. Not read by the code. |

### Config.VIP

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Not read by the code. |
| `useAsVip` | `false` | Not read by the code. |
| `perks.freeMeters` | `false` | VIP players pay nothing at meters. |
| `perks.discountPercent` | `25` | VIP discount on meters. Also stored as the perks of a new VIP. |
| `perks.priorityDelivery` | `true` | Stored with new VIPs. Not read elsewhere. |
| `perks.reservedSpots` | `true` | Stored with new VIPs. Not read elsewhere. |

### Config.Integration

| Option | Default | Meaning |
|---|---|---|
| `phoneEnabled` | `true` | Turn the phone app and phone callbacks on. |
| `target` | `nil` | Force `'ox_target'` or `'qb-target'`. `nil` detects it. |
| `vehicleKeys` | `nil` | Force a key script name. `nil` detects it. |
| `usePersistence` | `true` | Not read by the code. `dps-vehiclepersistence` is used whenever it is started. |
| `discordWebhook` | empty in a fresh setup | Leave empty or put your own Discord webhook URL. Used for the audit log (park, unpark and other entries). Keep this URL private. |

### Config.Keybinds

| Option | Default | Meaning |
|---|---|---|
| `parkButton` | `155` | Control ID (F5) used when `onlyAutoParkWhenEngineOff` is false. |
| `parkKey` | `'F5'` | Default key for `/park`. |
| `menuKey` | `'F6'` | Not read by the code. |

### Config.Commands

Admin names are used by the code: `addVip` = `addparkvip`, `removeVip` = `removeparkvip`, `resetPlayer` = `parkresetplayer`, `resetAll` = `parkresetall`, `debugPoly` = `parkdebug`, `deleteParked` = `deletepark`.

Not read by the code (the commands have fixed names or do not exist): `park`, `parkmenu`, `delivery`, `meter`, `tickets`, `toggleSteerAngle`, `toggleParkText`, `createLot`, `deleteLot`.

### Config.Blips

Each entry has `sprite`, `color` and `scale`.

| Entry | Default | Used for |
|---|---|---|
| `parkingLot` | sprite 357, color 2, scale 0.7 | Parking lots. |
| `ownedLot` | sprite 357, color 5, scale 0.8 | Not read by the code. |
| `noParking` | sprite 163, color 1, scale 0.5 | No-parking zones. |

### Config.NoParkingZones

A list of `{ coords, radius, jobs, name }`. `jobs` is a list of job names that may park there, or `nil` for a zone nobody may use. Defaults:

- MRPD Back Gate (police), Pillbox Hospital (`sams`, `omc`), LS Customs 1, LS Customs 2, Bennys, Mechanic Shop (all `mechanic`).
- Impound, Jewelry Store, Airport Runway (`jobs = nil`).

### Config.ParkingLots

A list of `{ id, coords, radius, name, capacity, basePrice, purchasePrice }`. `basePrice` is the fee per park in that lot. `purchasePrice` is the price to buy it as a business. Defaults: eight lots, ids 1 to 8 (Legion Square, Alta Street, Pillbox Hill Garage, Vinewood, Del Perro, Sandy Shores, Paleto Bay, Grapeseed).

### Config.PrivateParking

Default `{}`. Reserved private areas. Empty by default.

### Config.Valet

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Turn the valet on. If this table is missing, the valet reports itself disabled. |
| `locations` | one entry | List of valet stands. |

A location has `id`, `name`, `coords` (stand), `retrievalPoint` (vector4 where cars appear), `npcModel`, `blip` (`sprite`, `color`, `scale`) and `parkingSpots` (list of `{ coords, occupied }`). The default is `legion` (Legion Square Valet) with four stalls.

### Config.Reserved

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Turn reserved spots on (client markers and checks). |
| `showMarkers` | `true` | Draw markers on the spots. |
| `spots` | three entries | List of reserved spots. |

A spot has `id`, `name`, `coords` and `type` (`vip`, `job`, `business` or `rental`). Job spots also take `requiredJob`, `requiredGrade` and `requireOnDuty`. Defaults: `vip_vinewood_1` (vip), `pd_reserved_1` (job `police`, grade 0, off duty allowed), `rental_legion_1` (rental).

### Config.Violations

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Not read by the code. |
| `autoTicket` | `true` | Issue tickets automatically on meter expiry and zone violations. |

### Config.Dispatch

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Not read by the code. |
| `alertOnMeterExpiry` | `true` | Alert police when a meter expires past the grace time. |
| `alertOnZoneViolation` | `true` | Alert police on a no-parking zone violation. |

### Config.Vehicles

Default `{}`. Optional per-model override used when respawning parked cars: `['sanchez'] = { type = 'bike' }`. Models not listed use `'automobile'`. Add entries for bikes, boats, helicopters and planes.

### Config.Impound (add it yourself)

`config.lua` does not define `Config.Impound`. Without it, no impound NPC, blip or police keybind is created, and cars retrieved from impound spawn at a fallback point. To use them, add this table:

```lua
Config.Impound = {
    enabled = true,
    policeKeybind = 'F7', -- optional key for the police impound menu
    lots = {
        {
            id = 1,
            name = 'Impound Lot',
            coords = vector4(0.0, 0.0, 0.0, 0.0), -- NPC position
            spawnPoint = vector4(0.0, 0.0, 0.0, 0.0), -- optional
            blip = { sprite = 524, color = 1, scale = 0.8 },
        },
    },
}
```

### Settings inside module files

These are not in `config.lua`. Edit the files directly.

- `modules/violations/server.lua`, `Violations.Config`: ticket types and fines (`expired_meter` 75, `no_parking` 150, `fire_lane` 250, `handicap` 500, `double_parked` 200, `blocking` 300, `hydrant` 350), `gracePeriodHours` 24, `lateFeeMultiplier` 1.5, `maxUnpaidTickets` 5, and `authorizedJobs` (`police`, `bcso`, `sasp`, `rpd`, `rcso`).
- `modules/impound/server.lua`, `Impound.Config`: `baseFee` 500, reason fees (`parking` 250, `abandoned` 500, `traffic` 750, `crime` 1500, `police` 2500), `dailyFeeIncrease` 100, `maxDailyFees` 10, `authorizedJobs`, `requireOnDuty`.
- `modules/valet/server.lua`, `Valet.Config`: `basePrice` 100, `retrievalPrice` 50, tip multipliers, `baseParkTime` 30 s, `baseRetrieveTime` 45 s, `vipPriorityBonus` 0.5, `maxQueuePerLocation` 10.
- `modules/reserved/server.lua`, `Reserved.Config`: `rentalPricePerHour` 50, `maxRentalHours` 24, VIP discounts.
- `modules/delivery/server.lua`, `Delivery.Tiers`: hourly limit, discount, rush and NPC driver by VIP tier.
- `integrations/billing.lua`, `Billing.Config`: `societyAccount` (`government`), `allowDirectPayment`, `invoiceLabel`, `invoiceDueDays`.
- `integrations/insurance.lua`: the impound discount by tier: basic 10%, standard 25%, premium 50%, platinum 75%, full 100%.

The impound, ticket and valet keys that check a job also contain a hard-coded job list in the client files `modules/violations/client.lua` and `modules/impound/client.lua`. Change them together with the server lists.

## Job permissions

Enforcement powers are set in `integrations/permissions.lua`, in `Permissions.Config.enforcementJobs`. The format is:

```lua
enforcementJobs = {
    ['jobname'] = {
        actionName = minimumGrade,
        ...
    },
}
```

The key is the job name exactly as in your framework. Each action maps to the lowest job grade that may do it. If an action is missing for a job, that job cannot do it. A job that is not listed has no enforcement powers.

Actions: `issueTicket`, `checkMeters`, `bootVehicle`, `impoundVehicle`, `impoundCriminal`, `releaseImpound`, `viewTicketHistory`, `dismissTicket`.

Jobs in the file:

| Job | issueTicket | checkMeters | bootVehicle | impoundVehicle | impoundCriminal | releaseImpound | viewTicketHistory | dismissTicket |
|---|---|---|---|---|---|---|---|---|
| `police` | 1 | 1 | 2 | 3 | 2 | 4 | 1 | 5 |
| `rpd` | 1 | 1 | 2 | 3 | 2 | 4 | 1 | 5 |
| `rcso` | 1 | 1 | 2 | 3 | 2 | 4 | 1 | 5 |
| `bcso` | 1 | 1 | 2 | 3 | 2 | 4 | 1 | 5 |
| `sasp` | 1 | 1 | 2 | 2 | 1 | 3 | 1 | 4 |

Other settings in the same file:

- `requireOnDuty = true`: the officer must be on duty.
- `impoundReasons`: maps an impound reason to a permission. `parking`, `abandoned` and `traffic` use `impoundVehicle`. `crime` and `police` use `impoundCriminal`.
- `actionLabels`: display names for the actions.
- Admins (ACE `group.admin`, `admin` or `command`) pass the permission check when it is called through `Permissions.Check`.

To add a job, copy one block, rename the key to your job and set the grades. Then add the job name to the lists in `modules/violations/server.lua` and `modules/impound/server.lua`, and to the hard-coded lists in the two client files named above.

## Troubleshooting

- **"No supported framework detected" in the console.** `qbx_core`, `qb-core` or `es_extended` was not started before `dps-parking`. Move `ensure dps-parking` below it.
- **Database errors about missing columns or tables.** Import `database/schema.sql`. The script does not create tables itself.
- **The import stops with an error about `owned_vehicles`.** Keep the ESX block commented out on Qbox.
- **No impound NPC, blip or police key.** `Config.Impound` is not in the default config. Add it (see Configuration).
- **The valet is always disabled.** `Config.Valet` is missing or has no `locations`.
- **The valet NPC has no interaction.** Start `ox_target` or `qb-target` before `dps-parking`, or set `Config.Integration.target`.
- **An officer cannot ticket or impound.** Check that the job name is in `Permissions.Config.enforcementJobs`, the grade is high enough, the officer is on duty, and the job is in the `authorizedJobs` lists.
- **A job with a vendor name is locked out.** Job names in all lists must match your framework job names exactly.
- **No insurance discount at impound.** No supported insurance script is started, or it is started after `dps-parking`. The console prints which script was hooked.
- **Ticket fees are charged directly.** No billing script was detected. This is the fallback.
- **Admin commands say you are not allowed.** Give the player an ACE from the list in Installation.
- **No Discord log.** `Config.Integration.discordWebhook` is empty or the URL is wrong. With a wrong URL the error shows only when `Config.Debug` is on.
- **No phone app.** `Config.Integration.phoneEnabled` is false, or `lb-phone` was not started. The app registers about five seconds after start.
- **Floating text is not shown.** Check `display3DText`, `streamerMode` and `displayDistance`.
- **Setting a config option has no effect.** The option may be one marked "Not read by the code" in this guide.
