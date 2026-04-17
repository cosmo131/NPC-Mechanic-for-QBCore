# NPC Mechanic

`NPC Mechanic` is an immersive mobile mechanic script for FiveM/QBCore.

Players can call an NPC mechanic who drives to their location and offers multiple roadside services:

- towing damaged vehicles to configured depot locations
- repairing vehicles on site
- refueling stranded vehicles with a fuel can

The script is designed to feel natural in-game, with configurable spawn points, service flows, unsafe route zones, localized UI/messages, and detailed behavior settings.

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

## Notes

- Fixed spawn points are recommended for stable mechanic arrivals.
- Unsafe zones can be used to prevent NPCs from entering dangerous roads, cliffs, or water routes.
- The script is built for QBCore-based servers and may require small adjustments for custom frameworks or fuel systems.
