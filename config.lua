Config = {}

-- Active language: de / en / ru
Config.Locale = 'en'

-- Command used to request the NPC mechanic
Config.Command = 'mechanic'

-- Debug blip settings used when spawn point debug is enabled in spawnpoints.lua
Config.SpawnPointDebugBlip = {
    sprite = 1,
    color = 5,
    scale = 0.7,
    label = 'spawnpoint_label'
}

-- Dynamic spawn search distance range.
-- These values are only relevant when fixed spawn points are disabled or unavailable.
Config.MinSpawnDistance = 500.0
Config.MaxSpawnDistance = 700.0
Config.SpawnDistanceStep = 5.0
Config.SpawnSearchPasses = 4
Config.SpawnSearchPassDelay = 250
Config.SpawnRetryAttempts = 2

-- Use fixed map spawn points for the mechanic instead of dynamic road search
Config.UseFixedSpawnPoints = true

-- Extra fallback distances if no valid main spawn point is found
Config.AdditionalSpawnDistances = { 800.0, 950.0, 1100.0 }

-- Last resort spawn search distances
Config.LastResortSpawnDistances = { 1200.0, 1400.0, 1600.0 }

-- Last resort spawn search directions around the player
Config.LastResortSpawnOffsets = {
    vector3(0.0, -1.0, 0.0),
    vector3(0.7, -0.7, 0.0),
    vector3(-0.7, -0.7, 0.0),
    vector3(1.0, 0.0, 0.0),
    vector3(-1.0, 0.0, 0.0),
    vector3(0.0, 1.0, 0.0)
}

-- Spawn validation settings for dynamic road searches
Config.SpawnClearRadius = 4.0
Config.RelaxedSpawnClearance = 2.2
Config.LastResortSpawnClearRadius = 6.0
Config.SpawnLaneOffset = 4.0
Config.MaxSpawnHeightDifference = 7.5
Config.LastResortHeightBonus = 8.0

-- Loose ground fallback settings used only by dynamic spawn search
Config.LooseGroundSpawnDistances = { 400.0, 520.0, 620.0 }
Config.LooseGroundSpawnClearRadius = 5.0
Config.LooseGroundHeightBonus = 12.0

-- Random road/path fallback used when normal road search fails
Config.RandomRoadSpawnAttempts = 40
Config.RandomRoadSpawnMinDistance = 500
Config.RandomRoadSpawnMaxDistance = 1400

-- NPC ped and tow truck models
Config.MechanicPed = 's_m_m_autoshop_01'
Config.MechanicVehicle = 'towtruck4'

-- Pricing settings
-- Tow price = BaseCalloutPrice + (distance in km * PricePerKM)
Config.BaseCalloutPrice = 150
Config.PricePerKM = 50

-- Repair price scales with engine/body/tank damage
Config.RepairBasePrice = 75
Config.RepairPricePerEngineDamage = 0.35
Config.RepairPricePerBodyDamage = 0.20
Config.RepairPricePerTankDamage = 0.10

-- Driving speeds
Config.DriveSpeed = 12.0
Config.TowSpeed = 13.0
Config.DepartSpeed = 14.0
Config.PlayerApproachSpeed = 18.0
Config.PlayerSlowdownDistance = 90.0

-- Short forward drive used to leave the spawn point cleanly before navigating to the player
Config.SpawnDepartureSpeed = 10.0
Config.SpawnDepartureDistance = 18.0
Config.SpawnDepartureStopRadius = 6.0
Config.SpawnDepartureMinTravel = 8.0
Config.SpawnDepartureTimeout = 10000

-- Detect if the tow truck is stuck right after spawning
Config.SpawnStuckTimeout = 10000
Config.SpawnStuckCheckInterval = 500
Config.SpawnStuckSpeedThreshold = 1.5
Config.SpawnStuckMinTravel = 3.0
Config.SpawnRetryMinDistanceToPlayer = 140.0

-- General NPC driving behaviour
Config.VehicleDrivingStyle = 786603
Config.DriverAbility = 1.0
Config.DriverAggressiveness = 0.15
Config.PlayerApproachAggressiveness = 0.5

-- Driving behaviour while towing a vehicle
-- These values make the driver a bit more decisive once a vehicle is attached.
Config.TowDriverAbility = 1.0
Config.TowDriverAggressiveness = 0.55
Config.TowRecoverySpeed = 12.0
Config.TowRecoveryDuration = 30000
Config.TowRecoveryCheckInterval = 250
Config.TowRouteRealignAngle = 35.0
Config.TowFollowRoadMinTime = 4000
Config.TowFollowRoadMinDistance = 60.0

-- Nearby NPC traffic should hold position while the tow truck is stopped or slowly moving
Config.TrafficHoldEnabled = true
Config.TrafficHoldRadius = 18.0
Config.TrafficHoldAction = 27
Config.TrafficHoldDuration = 1800
Config.TrafficHoldInterval = 400
Config.TrafficHoldTowtruckSpeed = 5.0

-- Arrival and interaction distances
-- PlayerStopRadius controls when the mechanic is considered "close enough" to the player vehicle.
Config.PlayerStopRadius = 5.0
Config.DepotStopRadius = 6.0
Config.TargetRadius = 2.2

-- Tow truck parking position relative to the player's vehicle
-- Positive side offset means the truck prefers a parallel stop beside the vehicle.
Config.PlayerStopSideOffset = 1.0
Config.PlayerStopForwardOffset = 2.0

-- Position where the mechanic stands to talk to the player vehicle
Config.PlayerVehicleTalkOffset = 2.4

-- Mission and flow timers (all values in milliseconds)
Config.PlayerDriveTimeout = 420000
Config.DepotDriveTimeout = 1200000
Config.DepotProgressExtension = 45000
Config.DepotProgressThreshold = 0.75
Config.DepotRepathTicks = 15
Config.DepotRecoveryAttempts = 5
Config.DepotArrivalPause = 2000
Config.DepotStuckSpeedThreshold = 4.0
Config.PlayerWalkToMechanicTimeout = 45000
Config.PlayerEnterVehicleTimeout = 45000
Config.PlayerEngineStartTimeout = 45000
Config.PlayerReminderInterval = 5000
Config.PlayerExitVehicleTimeout = 30000

-- Attach / detach animation settings
Config.AttachAnimTime = 4000
Config.AttachAnimDict = 'mini@repair'
Config.AttachAnimName = 'fixing_a_ped'
Config.UnhookAnimTime = 5000

-- Repair service settings
-- Health thresholds decide whether the mechanic is allowed to repair the vehicle on site.
Config.RepairMinEngineHealth = 250.0
Config.RepairMinBodyHealth = 350.0
Config.RepairMinTankHealth = 250.0

-- Repair interaction positioning around the front/hood area
Config.RepairWalkOffset = vector3(0.0, 2.6, 0.0)
Config.RepairFrontExtraOffset = 0.0
Config.RepairReachRadius = 2.0
Config.RepairHoodDoorIndex = 4

-- Repair animation and duration calculation
Config.RepairAnimDict = 'mini@repair'
Config.RepairAnimName = 'fixing_a_ped'
Config.RepairDurationBase = 8000
Config.RepairDurationPerDamagePoint = 10
Config.RepairMaxDuration = 30000

-- Refuel service settings
-- RefuelCanAmount is the fixed amount added per mechanic refuel service.
Config.RefuelBasePrice = 40
Config.RefuelPricePerUnit = 2.5
Config.RefuelCanAmount = 20.0
Config.RefuelMaxStartingFuel = 90.0
Config.RefuelMinMissingFuel = 5.0

-- Refuel interaction positioning
Config.RefuelReachRadius = 2.0
Config.RefuelFallbackSideOffset = -0.9
Config.RefuelFallbackRearExtraOffset = 0.8
Config.RefuelFallbackHeightOffset = 0.2

-- Refuel animation and duration calculation
Config.RefuelAnimDict = 'timetable@gardener@filling_can'
Config.RefuelAnimName = 'gar_ig_5_filling_can'
Config.RefuelDurationBase = 7000
Config.RefuelDurationPerUnit = 150
Config.RefuelMaxDuration = 30000

-- Service item pickup and carry settings
-- These values control where the mechanic "grabs" props from on the tow truck
-- and how those props are attached to the mechanic's hand.
Config.ServiceItemPickupOffset = vector3(-1.0, -3.8, 0.0)
Config.ServiceItemReachRadius = 2.0
Config.RepairToolPropModel = 'prop_tool_adjspanner'
Config.RepairToolCarryBone = 57005
Config.RepairToolCarryOffset = vector3(0.14, 0.02, -0.02)
Config.RepairToolCarryRotation = vector3(-95.0, 0.0, 0.0)
Config.FuelCanPropModel = 'prop_jerrycan_01a'
Config.FuelCanCarryBone = 57005
Config.FuelCanCarryOffset = vector3(0.18, 0.03, -0.06)
Config.FuelCanCarryRotation = vector3(-85.0, 5.0, 10.0)

-- Mechanic speech settings
-- Speech names depend on the ped voice set; some tokens may sound better than others.
Config.MechanicGreetingSpeech = 'GENERIC_HI'
Config.MechanicGoodbyeSpeech = 'GENERIC_BYE'
Config.MechanicSpeechParam = 'SPEECH_PARAMS_FORCE_NORMAL'

-- Delay before the tow truck is removed after the mission ends
Config.DespawnDelay = 20000

-- Legacy hook positioning values still used by some attach calculations
-- Keep these for towing fine-tuning even though towtruck4 is the only active truck.
Config.HookVehicleOffset = vector3(0.0, -6.0, 0.35)
Config.MinimumPreHookDistance = 5.8
Config.PreHookExtraDistance = 0.8
Config.AttachBaseOffset = vector3(-0.25, -0.6, 0.35)
Config.AttachLengthMultiplier = 0.46
Config.MinimumAttachHeight = 0.9
Config.AttachHeightMultiplier = 0.45

-- Tow attach profiles by tow truck model
Config.TowTruckProfiles = {
    towtruck4 = {
        attachVehicleBehindTowDistance = 4.4,
        attachTowXOffset = 0.0,
        attachTowYOffset = 1.4,
        attachTowZOffset = 1.25
    }
}

-- Winch / interaction reference positions used during hook-up
Config.WinchInteractionOffset = vector3(0.0, -4.9, 0.1)
Config.WinchReachRadius = 1.8
Config.PlayerHookInteractionOffset = vector3(0.0, -2.2, 0.1)
Config.PlayerHookReachRadius = 1.8

-- Important notification sound
Config.ImportantNotifySound = {
    name = 'Text_Arrive_Tone',
    set = 'Phone_SoundSet_Default'
}

-- Tow truck warning lights / siren behaviour
Config.WarningLightInterval = 250
Config.WarningLightExtras = { 1, 2, 3 }
Config.WarningLightsEnabled = true
Config.UseTowtruckSirenLights = true
Config.MuteTowtruckSirenSound = true

-- Tow truck blip settings
Config.MechanicBlip = {
    sprite = 635,
    color = 21,
    scale = 0.8,
    label = 'mechanic_blip_label'
}

-- Depot route blip settings
Config.DepotBlip = {
    sprite = 446,
    color = 3,
    scale = 0.85,
    routeColor = 3
}

-- Available depot / workshop drop-off locations
Config.Depots = {
    { label = 'depot_ls_airport', coords = vector3(-1132.75, -1991.08, 13.17), heading = 310.0 },
    { label = 'depot_ls_rockford', coords = vector3(-370.11, -109.92, 38.68), heading = 70.0 },
    { label = 'depot_bennys', coords = vector3(-205.26, -1302.36, 31.30), heading = 270.0 },
    { label = 'depot_sandy', coords = vector3(1173.22, 2662.28, 37.99), heading = 353.6 },
    { label = 'depot_paleto', coords = vector3(121.03, 6615.74, 31.85), heading = 225.0 }
}

-- Enable or disable debug prints
Config.Debug = true
