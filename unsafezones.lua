-- Enable this to automatically show all unsafe zones with colored blips and radius circles.
Config.EnableUnsafeZoneDebug = true
Config.UnsafeZoneDebugBlipSprite = 161
Config.UnsafeZoneDebugBlipScale = 0.8
Config.UnsafeZoneDebugRadiusAlpha = 90

-- Debug colors by unsafe zone reason.
Config.UnsafeZoneDebugColors = {
    default = 1,
    water = 3,
    cliff = 1,
    narrow = 5,
    bridge = 47,
    offroad = 17
}

-- Unsafe driving zones. Add known water / cliff / narrow-road danger spots here.
-- reason = water / cliff / narrow / bridge / offroad
Config.UnsafeZones = {
    -- Cliff
    { coords = vector3(1318.12, -178.62, 108.24), radius = 35.0, reason = 'cliff' },
    { coords = vector3(1475.82, -108.88, 142.96), radius = 35.0, reason = 'cliff' },
    { coords = vector3(1862.0, -82.89, 189.13), radius = 35.0, reason = 'cliff' },
    { coords = vector3(2097.79, 9.48, 215.62), radius = 35.0, reason = 'cliff' },
    { coords = vector3(2382.62, 374.59, 175.72), radius = 35.0, reason = 'cliff' },
    { coords = vector3(2388.82, 850.07, 116.88), radius = 35.0, reason = 'cliff' },
    { coords = vector3(1916.1, 777.3, 194.09), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-17.15, 2258.92, 117.65), radius = 35.0, reason = 'cliff' },
    { coords = vector3(112.33, 1972.64, 162.38), radius = 35.0, reason = 'cliff' },
    { coords = vector3(239.49, 1841.93, 193.73), radius = 35.0, reason = 'cliff' },
    { coords = vector3(666.44, 1744.2, 189.51), radius = 35.0, reason = 'cliff' },
    { coords = vector3(882.73, 1852.93, 141.29), radius = 35.0, reason = 'cliff' },
    { coords = vector3(814.73, 1987.45, 102.02), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1714.53, 4319.29, 66.37), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1448.84, 4222.6, 50.52), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1210.08, 4296.91, 76.7), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1035.17, 4232.64, 116.34), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-520.95, 4361.68, 67.46), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-748.25, 4414.97, 20.07), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1488.55, 4789.59, 74.57), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1369.17, 4797.2, 129.2), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1224.43, 5017.81, 156.55), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-1079.58, 5074.85, 162.85), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-737.68, 5245.58, 95.92), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-592.91, 5000.72, 143.6), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-232.42, 6510.61, 11.08), radius = 35.0, reason = 'cliff' },
    { coords = vector3(852.88, 973.51, 241.06), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-958.7, 1168.31, 218.63), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-2612.69, 1654.74, 137.6), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-2524.87, 1851.89, 165.86), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-2305.66, 1865.75, 182.42), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-2096.48, 2000.32, 190.19), radius = 35.0, reason = 'cliff' },
    { coords = vector3(-2043.49, 1922.77, 187.16), radius = 35.0, reason = 'cliff' },
    -- Bridge
    { coords = vector3(1475.82, -108.88, 142.96), radius = 25.0, reason = 'bridge' },
    { coords = vector3(-406.67, 2962.93, 25.05), radius = 25.0, reason = 'bridge' },
    { coords = vector3(-222.81, 3856.22, 39.22), radius = 15.0, reason = 'bridge' },
    { coords = vector3(-150.36, 3649.53, 46.15), radius = 15.0, reason = 'bridge' },
    { coords = vector3(139.48, 3415.35, 40.6), radius = 15.0, reason = 'bridge' },
    { coords = vector3(-160.52, 4252.48, 44.93), radius = 35.0, reason = 'bridge' },
    { coords = vector3(-852.95, 5135.72, 150.13), radius = 15.0, reason = 'bridge' },
    { coords = vector3(3493.16, 4618.59, 55.94), radius = 15.0, reason = 'bridge' },
    { coords = vector3(13.92, 629.55, 207.38), radius = 15.0, reason = 'bridge' },
    { coords = vector3(-1812.52, 1910.61, 147.01), radius = 15.0, reason = 'bridge' },
    -- Water
    { coords = vector3(1814.41, 127.53, 171.62), radius = 35.0, reason = 'water' },
    { coords = vector3(1811.2, 359.98, 171.68), radius = 35.0, reason = 'water' },
    { coords = vector3(1899.26, 360.41, 162.45), radius = 35.0, reason = 'water' },
    { coords = vector3(-1015.65, 4356.98, 11.87), radius = 35.0, reason = 'water' },
    { coords = vector3(-1175.58, 4364.09, 7.41), radius = 35.0, reason = 'water' },
    { coords = vector3(-1330.27, 4327.89, 7.32), radius = 35.0, reason = 'water' },
    { coords = vector3(-1614.58, 4383.11, 2.43), radius = 35.0, reason = 'water' },
    { coords = vector3(3264.31, 5138.63, 19.64), radius = 35.0, reason = 'water' },
    { coords = vector3(3808.12, 4460.0, 4.33), radius = 35.0, reason = 'water' },
    -- Narrow
    { coords = vector3(-573.31, 5341.52, 70.21), radius = 35.0, reason = 'narrow' },
    { coords = vector3(-454.5, 6361.32, 12.49), radius = 35.0, reason = 'narrow' },
    { coords = vector3(3141.9, 5339.96, 29.01), radius = 35.0, reason = 'narrow' },
}
