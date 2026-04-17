# NPC Mechanic

`NPC Mechanic` is a mobile NPC roadside assistance script for FiveM/QBCore.

Players can call an NPC mechanic who drives to their location and can:

- tow damaged vehicles to configured depot locations
- repair vehicles on site
- refuel stranded vehicles with a fuel can

The script is built to feel natural in-game, with configurable spawn points, structured service flows, unsafe route protection, localized UI/messages, and many behavior settings for tuning.

## Overview

This resource is meant for servers that want a believable AI mechanic instead of instant menu-based recovery.

The mechanic arrives in a tow truck, interacts with the player's vehicle, and offers different services depending on the vehicle's condition:

- heavily damaged vehicles can be towed
- repairable vehicles can be fixed on site
- low-fuel vehicles can be refueled on site

Everything is configurable through separate config files for main settings, fixed spawn points, unsafe zones, and localization.

## Features

- NPC mechanic drives to the player in a tow truck
- Vehicle towing to configurable depot/workshop locations
- Roadside repair service with damage checks
- Roadside refuel service with petrol/diesel selection
- Cash or bank payment flow
- Fixed mechanic spawn points
- Optional spawn point debug display
- Unsafe zone system to block dangerous NPC routes
- Localized language system with German, English, and Russian
- Configurable prices, timers, props, sounds, route handling, and service behavior

## Service Flow

### Towing

1. Player calls the mechanic.
2. Mechanic drives to the player.
3. Player chooses towing and payment method.
4. Mechanic attaches the vehicle.
5. Vehicle is delivered to the configured depot.

### Repair

1. Player calls the mechanic.
2. Mechanic drives to the player.
3. Player chooses repair and payment method.
4. Vehicle damage is checked.
5. If repairable, the mechanic repairs it on site.
6. If too damaged, the mechanic tells the player that towing is required.

### Refuel

1. Player calls the mechanic.
2. Mechanic drives to the player.
3. Player chooses fuel service, fuel type, and payment method.
4. Mechanic refuels the vehicle with the configured can amount.
5. Mechanic leaves after the service is finished.

## Dependencies

- `qb-core`
- `qb-target`
- `qb-menu`

Depending on your setup, roadside refueling may also require your fuel resource integration to be active.

## Installation

1. Place the resource in your server's resources folder.
2. Make sure the folder name is `npc-mechanic`.
3. Add the resource to your server config:

```cfg
ensure npc-mechanic
```

4. Make sure the required dependencies are started before this resource.

Example order:

```cfg
ensure qb-core
ensure qb-target
ensure qb-menu
ensure npc-mechanic
```

## Configuration

Main settings are located in:

- [`config.lua`](./config.lua)
- [`spawnpoints.lua`](./spawnpoints.lua)
- [`unsafezones.lua`](./unsafezones.lua)
- [`locales.lua`](./locales.lua)

Important examples:

- set the language with `Config.Locale = 'de'`, `'en'`, or `'ru'`
- configure fixed mechanic spawn points in `spawnpoints.lua`
- configure dangerous route areas in `unsafezones.lua`
- adjust towing, repair, and refuel prices in `config.lua`

## File Structure

```text
npc-mechanic/
|-- client.lua
|-- server.lua
|-- config.lua
|-- locales.lua
|-- spawnpoints.lua
|-- unsafezones.lua
|-- fxmanifest.lua
`-- html/
```

## Services

### Towing

If the vehicle is too heavily damaged, the mechanic can tow it to the nearest configured depot.

### Repair

If the vehicle is still repairable, the mechanic performs an on-site repair with animation and service timing based on the damage level.

### Refuel

If the vehicle is low on fuel, the mechanic can refuel it using a configured fuel-can amount.

## Localization

The script supports:

- German
- English
- Russian

All language strings are stored in `locales.lua`.

## Debug Options

Optional map debug tools are available for:

- fixed mechanic spawn points
- unsafe route zones

These are controlled in:

- `spawnpoints.lua`
- `unsafezones.lua`

For public/community use, these debug options are best kept disabled by default.

## Compatibility

- Framework: QBCore
- UI/Interaction: `qb-target`, `qb-menu`
- Game: FiveM / GTA V

Fuel handling may need small adjustments depending on your server's fuel resource.

## Notes

- Fixed spawn points are recommended for stable mechanic arrivals.
- Unsafe zones can be used to prevent NPCs from entering dangerous roads, cliffs, or water routes.
- The script is built for QBCore-based servers and may require small adjustments for custom frameworks or fuel systems.

## Support

If you find bugs or want to suggest improvements, open an issue in this repository.
