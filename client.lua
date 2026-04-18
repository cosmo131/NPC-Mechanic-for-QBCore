local QBCore = exports['qb-core']:GetCoreObject()

local mechanicPed = nil
local mechanicVeh = nil
local mechanicBlip = nil
local depotBlip = nil
local playerVeh = nil
local targetZone = nil
local targetAdded = false
local serviceActive = false
local serviceState = 'idle'
local selectedPaymentMethod = nil
local selectedServiceType = nil
local selectedFuelType = nil
local selectedDepot = nil
local selectedTowTruckModel = nil
local quotedPrice = 0
local quotedTowPrice = 0
local quotedRepairPrice = 0
local quotedFuelPrice = 0
local repairAssessment = nil
local fuelAssessment = nil
local carriedServiceProp = nil
local warningLightsActive = false
local warningLightsThreadRunning = false
local spawnRetryCount = 0
local trafficHoldThreadRunning = false
local spawnDebugBlips = {}
local unsafeZoneDebugBlips = {}
local unsafeZoneDebugRadiusBlips = {}
local SpawnMechanic
local CleanupSpawnedMechanic

local DRIVING_STYLE = Config.VehicleDrivingStyle or 786603

local function L(key, vars)
    return Lang(key, vars)
end

local function GetPaymentMethodLabel(method)
    return method == 'cash' and L('payment_method_cash') or L('payment_method_bank')
end

local function GetFuelTypeLabel(fuelType)
    return fuelType == 'diesel' and L('fuel_type_name_diesel') or L('fuel_type_name_petrol')
end

local function GetServiceLabel(serviceType)
    if serviceType == 'repair' then
        return L('service_repair')
    elseif serviceType == 'fuel' then
        return L('service_refuel', { fuelType = GetFuelTypeLabel(selectedFuelType) })
    end

    return L('service_tow')
end

local function GetDepotLabel(depot)
    if not depot then
        return ''
    end

    return L(depot.label)
end

local function GetUnsafeReasonLabel(reason)
    return L('unsafe_reason_' .. tostring(reason or 'unknown'))
end

function MechanicNotify(msg)
    SendNUIMessage({ type = 'show', text = msg })
end

local function MechanicAlert(msg, important)
    MechanicNotify(msg)

    if important then
        PlaySoundFrontend(-1, Config.ImportantNotifySound.name, Config.ImportantNotifySound.set, true)
    end
end

RegisterNetEvent('mechanic:notify', function(msg)
    MechanicNotify(msg)
end)

QBCore.Functions.Notify = function(msg, type, length)
    MechanicNotify(msg)
end

local function DebugPrint(message)
    if Config.Debug then
        print(('[Mechanic] %s'):format(message))
    end
end

local function StartTrafficHold()
    if trafficHoldThreadRunning or not Config.TrafficHoldEnabled then
        return
    end

    trafficHoldThreadRunning = true

    CreateThread(function()
        while serviceActive and mechanicVeh and DoesEntityExist(mechanicVeh) do
            local towSpeed = GetEntitySpeed(mechanicVeh) * 3.6

            local shouldHoldTraffic =
                serviceState == 'at_vehicle' or
                serviceState == 'awaiting_payment' or
                serviceState == 'hooking' or
                serviceState == 'rehooking' or
                serviceState == 'repairing' or
                serviceState == 'refueling'

            if shouldHoldTraffic and towSpeed <= Config.TrafficHoldTowtruckSpeed then
                local towCoords = GetEntityCoords(mechanicVeh)

                for _, nearbyVeh in ipairs(GetGamePool('CVehicle')) do
                    if nearbyVeh ~= mechanicVeh and DoesEntityExist(nearbyVeh) then
                        local distance = #(GetEntityCoords(nearbyVeh) - towCoords)

                        if distance <= Config.TrafficHoldRadius then
                            local driver = GetPedInVehicleSeat(nearbyVeh, -1)

                            if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
                                TaskVehicleTempAction(
                                    driver,
                                    nearbyVeh,
                                    Config.TrafficHoldAction,
                                    Config.TrafficHoldDuration
                                )
                            end
                        end
                    end
                end
            end

            Wait(Config.TrafficHoldInterval)
        end

        trafficHoldThreadRunning = false
    end)
end

local function GetSelectedTowTruckProfile()
    if Config.TowTruckProfiles and selectedTowTruckModel and Config.TowTruckProfiles[selectedTowTruckModel] then
        return Config.TowTruckProfiles[selectedTowTruckModel]
    end

    return {
        attachVehicleBehindTowDistance = Config.AttachVehicleBehindTowDistance or 3.5,
        attachTowXOffset = Config.AttachTowXOffset or 0.0,
        attachTowYOffset = Config.AttachTowYOffset or 1.0,
        attachTowZOffset = Config.AttachTowZOffset or 0.8
    }
end

local function IsPlayerVehicleAttachedToServiceTruck()
    if not mechanicVeh or not DoesEntityExist(mechanicVeh) or not playerVeh or not DoesEntityExist(playerVeh) then
        return false
    end

    return IsVehicleAttachedToTowTruck(mechanicVeh, playerVeh)
end

local function GetTowTruckModelForPlayerVehicle()
    return Config.MechanicVehicle
end

local function WaitForCondition(checkFn, timeoutMs, intervalMs)
    local startedAt = GetGameTimer()
    intervalMs = intervalMs or 500

    while GetGameTimer() - startedAt < timeoutMs do
        if checkFn() then
            return true
        end

        Wait(intervalMs)
    end

    return false
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)

    return WaitForCondition(function()
        return HasAnimDictLoaded(dict)
    end, 10000, 100)
end

local function LoadModel(modelName)
    local modelHash = type(modelName) == 'number' and modelName or joaat(modelName)
    RequestModel(modelHash)

    local loaded = WaitForCondition(function()
        return HasModelLoaded(modelHash)
    end, 10000, 100)

    if not loaded then
        return nil
    end

    return modelHash
end

local function DeleteCarriedServiceProp()
    if carriedServiceProp and DoesEntityExist(carriedServiceProp) then
        DeleteEntity(carriedServiceProp)
    end

    carriedServiceProp = nil
end

local function PlayMechanicSpeech(speechName)
    if not speechName or speechName == '' or not mechanicPed or not DoesEntityExist(mechanicPed) then
        return
    end

    PlayPedAmbientSpeechNative(mechanicPed, speechName, Config.MechanicSpeechParam or 'SPEECH_PARAMS_FORCE_NORMAL')
end

local function GetTowtruckServicePointCoords()
    local servicePoint = GetOffsetFromEntityInWorldCoords(
        mechanicVeh,
        Config.ServiceItemPickupOffset.x,
        Config.ServiceItemPickupOffset.y,
        Config.ServiceItemPickupOffset.z
    )

    return vector3(servicePoint.x, servicePoint.y, servicePoint.z)
end

local function GoToTowtruckServicePoint()
    local servicePoint = GetTowtruckServicePointCoords()
    TaskGoToCoordAnyMeans(mechanicPed, servicePoint.x, servicePoint.y, servicePoint.z, 1.0, 0, 0, DRIVING_STYLE, 0)

    local reachedServicePoint = WaitForCondition(function()
        local pedCoords = GetEntityCoords(mechanicPed)
        return #(pedCoords - servicePoint) <= Config.ServiceItemReachRadius
    end, 15000, 250)

    return reachedServicePoint, servicePoint
end

local function EquipServiceProp(modelName, boneIndex, offset, rotation)
    DeleteCarriedServiceProp()

    local modelHash = LoadModel(modelName)
    if not modelHash then
        return false
    end

    local pedCoords = GetEntityCoords(mechanicPed)
    carriedServiceProp = CreateObject(modelHash, pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not carriedServiceProp or not DoesEntityExist(carriedServiceProp) then
        carriedServiceProp = nil
        return false
    end

    AttachEntityToEntity(
        carriedServiceProp,
        mechanicPed,
        GetPedBoneIndex(mechanicPed, boneIndex),
        offset.x,
        offset.y,
        offset.z,
        rotation.x,
        rotation.y,
        rotation.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    return true
end

local function CollectServiceItem(modelName, boneIndex, offset, rotation)
    local reachedServicePoint = GoToTowtruckServicePoint()
    if not reachedServicePoint then
        return false
    end

    TaskTurnPedToFaceEntity(mechanicPed, mechanicVeh, 1000)
    Wait(350)

    return EquipServiceProp(modelName, boneIndex, offset, rotation)
end

local function StowServiceItem()
    if not carriedServiceProp or not DoesEntityExist(carriedServiceProp) then
        return true
    end

    local reachedServicePoint = GoToTowtruckServicePoint()
    if not reachedServicePoint then
        DeleteCarriedServiceProp()
        return false
    end

    TaskTurnPedToFaceEntity(mechanicPed, mechanicVeh, 1000)
    Wait(350)
    DeleteCarriedServiceProp()
    return true
end

local function SetTowtruckWarningLights(enabled)
    if not mechanicVeh or not DoesEntityExist(mechanicVeh) then
        return
    end

    if not Config.WarningLightsEnabled then
        enabled = false
    end

    warningLightsActive = enabled

    if Config.UseTowtruckSirenLights then
        SetVehicleSiren(mechanicVeh, enabled)
        SetVehicleHasMutedSirens(mechanicVeh, Config.MuteTowtruckSirenSound)
        SetVehicleLights(mechanicVeh, enabled and 2 or 0)
    end

    if not enabled then
        SetVehicleIndicatorLights(mechanicVeh, 0, false)
        SetVehicleIndicatorLights(mechanicVeh, 1, false)
        SetVehicleLights(mechanicVeh, 0)
        SetVehicleFullbeam(mechanicVeh, false)
        SetVehicleBrakeLights(mechanicVeh, false)
        return
    end

    if warningLightsThreadRunning then
        return
    end

    warningLightsThreadRunning = true

    CreateThread(function()
        while warningLightsActive and mechanicVeh and DoesEntityExist(mechanicVeh) do
            if Config.UseTowtruckSirenLights then
                SetVehicleSiren(mechanicVeh, true)
                SetVehicleHasMutedSirens(mechanicVeh, Config.MuteTowtruckSirenSound)
                SetVehicleLights(mechanicVeh, 2)
            end

            SetVehicleIndicatorLights(mechanicVeh, 0, true)
            SetVehicleIndicatorLights(mechanicVeh, 1, true)
            SetVehicleFullbeam(mechanicVeh, false)
            SetVehicleBrakeLights(mechanicVeh, false)

            if Config.WarningLightExtras then
                for _, extraId in ipairs(Config.WarningLightExtras) do
                    if DoesExtraExist(mechanicVeh, extraId) then
                        SetVehicleExtra(mechanicVeh, extraId, 0)
                    end
                end
            end

            Wait(Config.WarningLightInterval)
        end

        if mechanicVeh and DoesEntityExist(mechanicVeh) then
            SetVehicleIndicatorLights(mechanicVeh, 0, false)
            SetVehicleIndicatorLights(mechanicVeh, 1, false)
            SetVehicleLights(mechanicVeh, 0)
            SetVehicleFullbeam(mechanicVeh, false)
            SetVehicleBrakeLights(mechanicVeh, false)
            if Config.UseTowtruckSirenLights then
                SetVehicleSiren(mechanicVeh, false)
                SetVehicleHasMutedSirens(mechanicVeh, Config.MuteTowtruckSirenSound)
            end

            if Config.WarningLightExtras then
                for _, extraId in ipairs(Config.WarningLightExtras) do
                    if DoesExtraExist(mechanicVeh, extraId) then
                        SetVehicleExtra(mechanicVeh, extraId, 1)
                    end
                end
            end
        end

        warningLightsThreadRunning = false
    end)
end

local function StartLongrangeDrive(destination, speed, stopRange)
    TaskVehicleDriveToCoordLongrange(
        mechanicPed,
        mechanicVeh,
        destination.x,
        destination.y,
        destination.z,
        speed,
        DRIVING_STYLE,
        stopRange
    )
end

local function StartDirectDrive(destination, speed, stopRange)
    TaskVehicleDriveToCoord(
        mechanicPed,
        mechanicVeh,
        destination.x,
        destination.y,
        destination.z,
        speed,
        0,
        GetEntityModel(mechanicVeh),
        DRIVING_STYLE,
        stopRange,
        true
    )
end

local function NormalizeHeading(heading)
    heading = heading % 360.0
    if heading < 0.0 then
        heading = heading + 360.0
    end

    return heading
end

local function HeadingDelta(a, b)
    local delta = math.abs(NormalizeHeading(a) - NormalizeHeading(b))
    if delta > 180.0 then
        delta = 360.0 - delta
    end

    return delta
end

local function GetSpawnHeadingTowardPlayer(spawnCoords, fallbackHeading, targetCoords)
    local headingToPlayer = GetHeadingFromVector_2d(
        targetCoords.x - spawnCoords.x,
        targetCoords.y - spawnCoords.y
    )

    local candidateA = NormalizeHeading(fallbackHeading)
    local candidateB = NormalizeHeading(fallbackHeading + 180.0)

    if HeadingDelta(candidateA, headingToPlayer) <= HeadingDelta(candidateB, headingToPlayer) then
        return candidateA
    end

    return candidateB
end

local function IsTowHeadingAligned(destination)
    if not mechanicVeh or not DoesEntityExist(mechanicVeh) then
        return false
    end

    local towCoords = GetEntityCoords(mechanicVeh)
    local headingToDestination = GetHeadingFromVector_2d(
        destination.x - towCoords.x,
        destination.y - towCoords.y
    )
    local currentHeading = GetEntityHeading(mechanicVeh)

    return HeadingDelta(currentHeading, headingToDestination) <= Config.TowRouteRealignAngle
end

local function GetTowForwardRoadTarget()
    local towCoords = GetEntityCoords(mechanicVeh)
    local towForward = GetEntityForwardVector(mechanicVeh)
    local aheadDistance = math.max(Config.TowFollowRoadMinDistance, 35.0)
    local aheadCoords = vector3(
        towCoords.x + (towForward.x * aheadDistance),
        towCoords.y + (towForward.y * aheadDistance),
        towCoords.z
    )

    local found, nodeCoords = GetClosestVehicleNodeWithHeading(
        aheadCoords.x,
        aheadCoords.y,
        aheadCoords.z,
        1,
        3.0,
        0
    )

    if found then
        return vector3(nodeCoords.x, nodeCoords.y, nodeCoords.z)
    end

    return aheadCoords
end

local function FollowRoadUntilAligned(destination)
    local startedAt = GetGameTimer()
    local startCoords = GetEntityCoords(mechanicVeh)
    local forwardTarget = GetTowForwardRoadTarget()

    StartDirectDrive(forwardTarget, Config.TowRecoverySpeed, 8.0)

    local followCompleted = WaitForCondition(function()
        if not mechanicVeh or not DoesEntityExist(mechanicVeh) then
            return false
        end

        local currentCoords = GetEntityCoords(mechanicVeh)
        local traveledDistance = #(currentCoords - startCoords)
        return
            (GetGameTimer() - startedAt) >= Config.TowFollowRoadMinTime and
            traveledDistance >= Config.TowFollowRoadMinDistance
    end, Config.TowRecoveryDuration, Config.TowRecoveryCheckInterval)

    if followCompleted and mechanicPed and DoesEntityExist(mechanicPed) then
        ClearPedTasks(mechanicPed)
        ClearPedSecondaryTask(mechanicPed)
    end

    return followCompleted
end

local function ReacquireDepotRoute(destination, forceRoadFollow)
    if not mechanicVeh or not DoesEntityExist(mechanicVeh) then
        return false
    end

    if forceRoadFollow or not IsTowHeadingAligned(destination) then
        local followedRoad = FollowRoadUntilAligned(destination)
        if not followedRoad then
            DebugPrint('Saubere Strassenfolge nicht bestaetigt, versuche trotzdem direkte Depot-Route')
        end
    end

    if mechanicPed and DoesEntityExist(mechanicPed) then
        ClearPedTasks(mechanicPed)
        ClearPedSecondaryTask(mechanicPed)
    end

    StartLongrangeDrive(destination, Config.TowSpeed, Config.DepotStopRadius)
    return true
end

local function GetPlayerServiceStopCoords()
    local sideOffset = math.abs(Config.PlayerStopSideOffset or 0.0)
    local forwardOffset = Config.PlayerStopForwardOffset or 0.0

    local rightSideCoords = GetOffsetFromEntityInWorldCoords(playerVeh, sideOffset, forwardOffset, 0.0)
    local leftSideCoords = GetOffsetFromEntityInWorldCoords(playerVeh, -sideOffset, forwardOffset, 0.0)

    if mechanicVeh and DoesEntityExist(mechanicVeh) then
        local towCoords = GetEntityCoords(mechanicVeh)

        if #(towCoords - leftSideCoords) < #(towCoords - rightSideCoords) then
            return vector3(leftSideCoords.x, leftSideCoords.y, leftSideCoords.z)
        end
    end

    return vector3(rightSideCoords.x, rightSideCoords.y, rightSideCoords.z)
end

local function GetUnsafeZoneAtCoords(coords)
    for _, zone in ipairs(Config.UnsafeZones or {}) do
        local zoneCoords = zone.coords
        local radius = zone.radius or 0.0

        if zoneCoords and #(coords - zoneCoords) <= radius then
            return zone
        end
    end

    return nil
end

local function LeaveSpawnPoint()
    local startCoords = GetEntityCoords(mechanicVeh)
    local forward = GetEntityForwardVector(mechanicVeh)
    local departureTarget = vector3(
        startCoords.x + (forward.x * Config.SpawnDepartureDistance),
        startCoords.y + (forward.y * Config.SpawnDepartureDistance),
        startCoords.z
    )

    StartDirectDrive(departureTarget, Config.SpawnDepartureSpeed, Config.SpawnDepartureStopRadius)

    return WaitForCondition(function()
        local currentCoords = GetEntityCoords(mechanicVeh)
        return #(currentCoords - startCoords) >= Config.SpawnDepartureMinTravel
    end, Config.SpawnDepartureTimeout, 250)
end

local function RetryMechanicSpawn(reason)
    if spawnRetryCount < Config.SpawnRetryAttempts then
        spawnRetryCount = spawnRetryCount + 1
        DebugPrint(('%s, neuer Spawnversuch %s/%s'):format(reason, spawnRetryCount, Config.SpawnRetryAttempts))
        CleanupSpawnedMechanic()
        serviceState = 'spawning'
        SpawnMechanic()
        return true
    end

    return false
end

local function WaitForPlayerApproachDistance(maxDistance)
    local intervalMs = Config.SpawnStuckCheckInterval or 500
    local timeoutAt = GetGameTimer() + Config.PlayerDriveTimeout
    local movedSince = GetGameTimer()
    local lastCoords = GetEntityCoords(mechanicVeh)

    while GetGameTimer() < timeoutAt do
        if not DoesEntityExist(mechanicVeh) or not DoesEntityExist(playerVeh) then
            return 'failed'
        end

        local towCoords = GetEntityCoords(mechanicVeh)
        local unsafeZone = GetUnsafeZoneAtCoords(towCoords)
        if unsafeZone then
            DebugPrint(('Unsichere Zone erkannt waehrend Spieler-Anfahrt: %s'):format(unsafeZone.reason or 'unknown'))
            return 'unsafe_zone'
        end

        local vehicleCoords = GetEntityCoords(playerVeh)
        local distanceToPlayer = #(towCoords - vehicleCoords)
        if distanceToPlayer <= maxDistance then
            return 'reached'
        end

        local movedDistance = #(towCoords - lastCoords)
        local currentSpeed = GetEntitySpeed(mechanicVeh) * 3.6
        if movedDistance >= Config.SpawnStuckMinTravel or currentSpeed > Config.SpawnStuckSpeedThreshold then
            movedSince = GetGameTimer()
            lastCoords = towCoords
        elseif
            not Config.UseFixedSpawnPoints and
            distanceToPlayer > Config.SpawnRetryMinDistanceToPlayer and
            GetGameTimer() - movedSince >= Config.SpawnStuckTimeout
        then
            return 'stuck'
        end

        Wait(intervalMs)
    end

    return 'failed'
end

local function ApplyMechanicDriverSettings()
    if not mechanicPed or not DoesEntityExist(mechanicPed) then
        return
    end

    SetDriverAbility(mechanicPed, Config.DriverAbility)
    SetDriverAggressiveness(mechanicPed, Config.DriverAggressiveness)
    SetPedFleeAttributes(mechanicPed, 0, false)
    SetPedCombatAttributes(mechanicPed, 3, false)
    SetPedCombatAttributes(mechanicPed, 5, false)
end

local function SetPlayerApproachDrivingMode(enabled)
    if not mechanicPed or not DoesEntityExist(mechanicPed) then
        return
    end

    SetDriverAbility(mechanicPed, Config.DriverAbility)
    SetDriverAggressiveness(
        mechanicPed,
        enabled and Config.PlayerApproachAggressiveness or Config.DriverAggressiveness
    )
end

local function SetTowDrivingMode(enabled)
    if not mechanicPed or not DoesEntityExist(mechanicPed) then
        return
    end

    if enabled then
        SetDriverAbility(mechanicPed, Config.TowDriverAbility)
        SetDriverAggressiveness(mechanicPed, Config.TowDriverAggressiveness)
        return
    end

    SetDriverAbility(mechanicPed, Config.DriverAbility)
    SetDriverAggressiveness(mechanicPed, Config.DriverAggressiveness)
end

local function CleanupTarget()
    if targetAdded and mechanicPed and DoesEntityExist(mechanicPed) then
        exports['qb-target']:RemoveTargetEntity(mechanicPed)
    end

    targetAdded = false
    targetZone = nil
end

local function CleanupBlips()
    if mechanicBlip and DoesBlipExist(mechanicBlip) then
        RemoveBlip(mechanicBlip)
        mechanicBlip = nil
    end

    if depotBlip and DoesBlipExist(depotBlip) then
        RemoveBlip(depotBlip)
        depotBlip = nil
    end
end

local function ClearSpawnDebugBlips()
    for _, blip in ipairs(spawnDebugBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    spawnDebugBlips = {}
end

local function GetUnsafeZoneDebugColor(reason)
    local colors = Config.UnsafeZoneDebugColors or {}
    return colors[reason] or colors.default or 1
end

local function ClearUnsafeZoneDebugBlips()
    for _, blip in ipairs(unsafeZoneDebugBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    for _, blip in ipairs(unsafeZoneDebugRadiusBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    unsafeZoneDebugBlips = {}
    unsafeZoneDebugRadiusBlips = {}
end

local function ToggleUnsafeZoneDebugBlips()
    if #unsafeZoneDebugBlips > 0 or #unsafeZoneDebugRadiusBlips > 0 then
        ClearUnsafeZoneDebugBlips()
        MechanicAlert(L('unsafe_zones_hidden'), true)
        return
    end

    local zones = Config.UnsafeZones or {}
    if #zones == 0 then
        MechanicAlert(L('unsafe_zones_none'), true)
        return
    end

    for index, zone in ipairs(zones) do
        local zoneCoords = zone.coords
        local reason = zone.reason or 'unknown'
        local color = GetUnsafeZoneDebugColor(reason)

        if zoneCoords then
            local blip = AddBlipForCoord(zoneCoords.x, zoneCoords.y, zoneCoords.z)
            SetBlipSprite(blip, Config.UnsafeZoneDebugBlipSprite or 161)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.UnsafeZoneDebugBlipScale or 0.8)
            SetBlipColour(blip, color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(L('unsafe_zone_label', { reason = GetUnsafeReasonLabel(reason), index = index }))
            EndTextCommandSetBlipName(blip)
            unsafeZoneDebugBlips[#unsafeZoneDebugBlips + 1] = blip

            local radiusBlip = AddBlipForRadius(zoneCoords.x, zoneCoords.y, zoneCoords.z, zone.radius or 0.0)
            SetBlipColour(radiusBlip, color)
            SetBlipAlpha(radiusBlip, Config.UnsafeZoneDebugRadiusAlpha or 90)
            unsafeZoneDebugRadiusBlips[#unsafeZoneDebugRadiusBlips + 1] = radiusBlip
        end
    end

    MechanicAlert(L('unsafe_zones_shown', { count = #unsafeZoneDebugBlips }), true)
end

local function ToggleSpawnDebugBlips()
    if #spawnDebugBlips > 0 then
        ClearSpawnDebugBlips()
        MechanicAlert(L('spawnpoints_hidden'), true)
        return
    end

    if not Config.MechanicSpawnPoints or #Config.MechanicSpawnPoints == 0 then
        MechanicAlert(L('spawnpoints_none'), true)
        return
    end

    for index, spawnPoint in ipairs(Config.MechanicSpawnPoints) do
        local blip = AddBlipForCoord(spawnPoint.x, spawnPoint.y, spawnPoint.z)
        SetBlipSprite(blip, Config.SpawnPointDebugBlip.sprite)
        SetBlipColour(blip, Config.SpawnPointDebugBlip.color)
        SetBlipScale(blip, Config.SpawnPointDebugBlip.scale)
        SetBlipAsShortRange(blip, false)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.floor((spawnPoint.w or 0.0) % 360.0))
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('%s #%s'):format(L(Config.SpawnPointDebugBlip.label), index))
        EndTextCommandSetBlipName(blip)
        spawnDebugBlips[#spawnDebugBlips + 1] = blip
    end

    MechanicAlert(L('spawnpoints_shown', { count = #spawnDebugBlips }), true)
end

CleanupSpawnedMechanic = function()
    CleanupTarget()
    CleanupBlips()
    DeleteCarriedServiceProp()

    if mechanicVeh and DoesEntityExist(mechanicVeh) and playerVeh and DoesEntityExist(playerVeh) and IsPlayerVehicleAttachedToServiceTruck() then
        DetachVehicleFromTowTruck(mechanicVeh, playerVeh)

        SetVehicleUndriveable(playerVeh, false)
        SetVehicleHandbrake(playerVeh, false)
        FreezeEntityPosition(playerVeh, false)
    end

    if mechanicPed and DoesEntityExist(mechanicPed) then
        DeletePed(mechanicPed)
    end

    if mechanicVeh and DoesEntityExist(mechanicVeh) then
        DeleteVehicle(mechanicVeh)
    end

    mechanicPed = nil
    mechanicVeh = nil
    warningLightsActive = false
    warningLightsThreadRunning = false
end

local function CleanupMechanic()
    CleanupSpawnedMechanic()

    mechanicPed = nil
    mechanicVeh = nil
    playerVeh = nil
    selectedPaymentMethod = nil
    selectedServiceType = nil
    selectedFuelType = nil
    selectedDepot = nil
    selectedTowTruckModel = nil
    quotedPrice = 0
    quotedTowPrice = 0
    quotedRepairPrice = 0
    quotedFuelPrice = 0
    repairAssessment = nil
    fuelAssessment = nil
    spawnRetryCount = 0
    trafficHoldThreadRunning = false
    serviceActive = false
    serviceState = 'idle'
end

local function AbortService(message)
    DebugPrint(message or 'Service abgebrochen')

    if message then
        MechanicAlert(message, true)
    end

    CleanupMechanic()
end

local function GetClosestDepot(coords)
    local closestDepot = nil
    local closestDistance = math.huge

    for _, depot in ipairs(Config.Depots) do
        local distance = CalculateTravelDistanceBetweenPoints(
            coords.x,
            coords.y,
            coords.z,
            depot.coords.x,
            depot.coords.y,
            depot.coords.z
        )

        if distance == -1 or distance == 0 then
            distance = #(coords - depot.coords)
        end

        if distance < closestDistance then
            closestDistance = distance
            closestDepot = depot
        end
    end

    return closestDepot, closestDistance
end

local function CalculateTowPrice(vehicle, depot)
    local distanceKm = #(GetEntityCoords(vehicle) - depot.coords) / 1000.0
    return math.floor(Config.BaseCalloutPrice + (distanceKm * Config.PricePerKM))
end

local function GetRepairAssessment(vehicle)
    local engineHealth = math.max(GetVehicleEngineHealth(vehicle), 0.0)
    local bodyHealth = math.max(GetVehicleBodyHealth(vehicle), 0.0)
    local tankHealth = math.max(GetVehiclePetrolTankHealth(vehicle), 0.0)

    local engineDamage = math.max(1000.0 - engineHealth, 0.0)
    local bodyDamage = math.max(1000.0 - bodyHealth, 0.0)
    local tankDamage = math.max(1000.0 - tankHealth, 0.0)
    local totalDamage = engineDamage + bodyDamage + tankDamage

    local repairable =
        engineHealth >= Config.RepairMinEngineHealth and
        bodyHealth >= Config.RepairMinBodyHealth and
        tankHealth >= Config.RepairMinTankHealth

    local price = math.floor(
        Config.RepairBasePrice +
        (engineDamage * Config.RepairPricePerEngineDamage) +
        (bodyDamage * Config.RepairPricePerBodyDamage) +
        (tankDamage * Config.RepairPricePerTankDamage)
    )

    local duration = math.min(
        Config.RepairMaxDuration,
        Config.RepairDurationBase + math.floor(totalDamage * Config.RepairDurationPerDamagePoint)
    )

    return {
        repairable = repairable,
        engineHealth = engineHealth,
        bodyHealth = bodyHealth,
        tankHealth = tankHealth,
        totalDamage = totalDamage,
        price = price,
        duration = duration
    }
end

local function GetVehicleServiceFuelLevel(vehicle)
    if not DoesEntityExist(vehicle) then
        return 0.0
    end

    if GetResourceState('qb-fuel') == 'started' then
        local fuel = exports['qb-fuel']:GetFuel(vehicle)
        if fuel ~= nil then
            return math.max(fuel, 0.0)
        end
    end

    return math.max(GetVehicleFuelLevel(vehicle), 0.0)
end

local function SetVehicleServiceFuelLevel(vehicle, fuelLevel)
    local clampedFuel = math.min(100.0, math.max(fuelLevel or 0.0, 0.0))

    if GetResourceState('qb-fuel') == 'started' then
        exports['qb-fuel']:SetFuel(vehicle, clampedFuel)
        return
    end

    SetVehicleFuelLevel(vehicle, clampedFuel)
end

local function GetFuelAssessment(vehicle)
    local currentFuel = GetVehicleServiceFuelLevel(vehicle)
    local usesFuel = DoesVehicleUseFuel(vehicle)
    local missingFuel = math.max(100.0 - currentFuel, 0.0)
    local refuelAmount = math.min(Config.RefuelCanAmount or 20.0, missingFuel)
    local targetFuel = math.min(currentFuel + refuelAmount, 100.0)
    local refuelable = usesFuel and currentFuel <= (Config.RefuelMaxStartingFuel or 25.0) and refuelAmount >= (Config.RefuelMinMissingFuel or 5.0)

    local price = math.floor(
        Config.RefuelBasePrice +
        (refuelAmount * Config.RefuelPricePerUnit)
    )

    local duration = math.min(
        Config.RefuelMaxDuration,
        Config.RefuelDurationBase + math.floor(refuelAmount * Config.RefuelDurationPerUnit)
    )

    return {
        refuelable = refuelable,
        usesFuel = usesFuel,
        currentFuel = currentFuel,
        missingFuel = missingFuel,
        refuelAmount = refuelAmount,
        targetFuel = targetFuel,
        price = price,
        duration = duration
    }
end

local function ResolveRoadSpawn(baseCoords, playerZ)
    local heading = 0.0
    local roadCoords = nil
    local bestCandidate = nil
    local bestNearestVehicleDistance = -1.0

    local found, nodeCoords, nodeHeading = GetClosestVehicleNodeWithHeading(baseCoords.x, baseCoords.y, baseCoords.z, 1, 3.0, 0)
    if found then
        roadCoords = vector3(nodeCoords.x, nodeCoords.y, nodeCoords.z)
        heading = nodeHeading
    else
        local fallbackFound, fallbackNode = GetNthClosestVehicleNode(baseCoords.x, baseCoords.y, baseCoords.z, 1, 0, 0, 0)
        if fallbackFound then
            roadCoords = vector3(fallbackNode.x, fallbackNode.y, fallbackNode.z)
        end
    end

    if not roadCoords then
        return nil, nil
    end

    local possibleSpawns = {
        roadCoords,
        vector3(roadCoords.x + Config.SpawnLaneOffset, roadCoords.y, roadCoords.z),
        vector3(roadCoords.x - Config.SpawnLaneOffset, roadCoords.y, roadCoords.z)
    }

    for _, testCoords in ipairs(possibleSpawns) do
        local groundFound, groundZ = GetGroundZFor_3dCoord(testCoords.x, testCoords.y, testCoords.z + 25.0, false)
        if groundFound then
            local groundedCoords = vector3(testCoords.x, testCoords.y, groundZ)
            local sameHeightBand = math.abs(groundZ - playerZ) <= Config.MaxSpawnHeightDifference
            local clear = true
            local nearestVehicleDistance = math.huge

            if sameHeightBand then
                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if DoesEntityExist(veh) then
                        local distanceToVeh = #(GetEntityCoords(veh) - groundedCoords)
                        nearestVehicleDistance = math.min(nearestVehicleDistance, distanceToVeh)

                        if distanceToVeh < Config.SpawnClearRadius then
                            clear = false
                        end
                    end
                end
            end

            if sameHeightBand and clear then
                return groundedCoords, heading
            end

            if sameHeightBand and nearestVehicleDistance > bestNearestVehicleDistance then
                bestNearestVehicleDistance = nearestVehicleDistance
                bestCandidate = groundedCoords
            end
        end
    end

    if bestCandidate and bestNearestVehicleDistance >= Config.RelaxedSpawnClearance then
        return bestCandidate, heading
    end

    return nil, nil
end

local function IsDriveableSurface(coords, playerZ)
    if not coords then
        return false
    end

    if math.abs(coords.z - playerZ) > Config.MaxSpawnHeightDifference + Config.LastResortHeightBonus then
        return false
    end

    return IsPointOnRoad(coords.x, coords.y, coords.z, 0)
end

local function ResolveAlternateSpawn(ped, playerZ)
    for _, distance in ipairs(Config.LastResortSpawnDistances) do
        for _, offset in ipairs(Config.LastResortSpawnOffsets) do
            local fallbackOffset = GetOffsetFromEntityInWorldCoords(
                ped,
                offset.x * distance,
                offset.y * distance,
                0.0
            )
            local groundFound, groundZ = GetGroundZFor_3dCoord(fallbackOffset.x, fallbackOffset.y, fallbackOffset.z + 50.0, false)

            if groundFound and math.abs(groundZ - playerZ) <= Config.MaxSpawnHeightDifference + Config.LastResortHeightBonus then
                local fallbackCoords = vector3(fallbackOffset.x, fallbackOffset.y, groundZ)
                local clear = true

                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if DoesEntityExist(veh) and #(GetEntityCoords(veh) - fallbackCoords) < Config.LastResortSpawnClearRadius then
                        clear = false
                        break
                    end
                end

                if clear and IsDriveableSurface(fallbackCoords, playerZ) then
                    return fallbackCoords, GetEntityHeading(ped)
                end
            end
        end
    end

    return nil, nil
end

local function ResolveLooseGroundSpawn(ped, playerZ)
    for _, distance in ipairs(Config.LooseGroundSpawnDistances) do
        for _, offset in ipairs(Config.LastResortSpawnOffsets) do
            local testOffset = GetOffsetFromEntityInWorldCoords(
                ped,
                offset.x * distance,
                offset.y * distance,
                0.0
            )
            local groundFound, groundZ = GetGroundZFor_3dCoord(testOffset.x, testOffset.y, testOffset.z + 50.0, false)

            if groundFound and math.abs(groundZ - playerZ) <= Config.MaxSpawnHeightDifference + Config.LooseGroundHeightBonus then
                local groundedCoords = vector3(testOffset.x, testOffset.y, groundZ)
                local clear = true

                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if DoesEntityExist(veh) and #(GetEntityCoords(veh) - groundedCoords) < Config.LooseGroundSpawnClearRadius then
                        clear = false
                        break
                    end
                end

                if clear and IsDriveableSurface(groundedCoords, playerZ) then
                    return groundedCoords, GetEntityHeading(ped)
                end
            end
        end
    end

    return nil, nil
end

local function ResolveRandomRoadSpawn(ped, playerZ)
    for _ = 1, Config.RandomRoadSpawnAttempts do
        local distance = math.random(Config.RandomRoadSpawnMinDistance, Config.RandomRoadSpawnMaxDistance)
        local angle = math.rad(math.random(0, 359))
        local baseCoords = GetEntityCoords(ped)
        local randomCoords = vector3(
            baseCoords.x + (math.cos(angle) * distance),
            baseCoords.y + (math.sin(angle) * distance),
            baseCoords.z
        )

        local spawnCoords, spawnHeading = ResolveRoadSpawn(randomCoords, playerZ)
        if spawnCoords then
            return spawnCoords, spawnHeading
        end
    end

    return nil, nil
end

local function FindConfiguredSpawnPoint(playerCoords)
    if not Config.MechanicSpawnPoints or #Config.MechanicSpawnPoints == 0 then
        return nil, nil
    end

    local bestCandidate = nil
    local bestDistance = math.huge

    for _, spawnPoint in ipairs(Config.MechanicSpawnPoints) do
        local spawnCoords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
        local distanceToPlayer = #(spawnCoords - playerCoords)
        local distanceForFilter = distanceToPlayer
        local minDistance = Config.MinSpawnDistance
        local maxDistance = Config.RandomRoadSpawnMaxDistance

        if distanceForFilter >= minDistance and distanceForFilter <= maxDistance then
            local clear = true

            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) and #(GetEntityCoords(veh) - spawnCoords) < Config.SpawnClearRadius then
                    clear = false
                    break
                end
            end

            if clear then
                if distanceForFilter < bestDistance then
                    bestDistance = distanceForFilter
                    bestCandidate = spawnPoint
                end
            end
        end
    end

    if not bestCandidate then
        return nil, nil
    end

    return vector3(bestCandidate.x, bestCandidate.y, bestCandidate.z), bestCandidate.w
end

local function FindSpawnPoint(ped, playerCoords)
    if Config.UseFixedSpawnPoints then
        local configuredCoords, configuredHeading = FindConfiguredSpawnPoint(playerCoords)
        if configuredCoords then
            DebugPrint(('Configured spawn point selected at %.2f %.2f %.2f'):format(configuredCoords.x, configuredCoords.y, configuredCoords.z))
            return configuredCoords, configuredHeading
        end

        DebugPrint('Keine passenden festen Spawnpunkte gefunden')
        return nil, nil
    end

    local spawnCoords = nil
    local spawnHeading = 0.0

    for attempt = 1, Config.SpawnSearchPasses do
        DebugPrint(('Spawn search pass %s/%s'):format(attempt, Config.SpawnSearchPasses))

        for distance = Config.MinSpawnDistance, Config.MaxSpawnDistance, Config.SpawnDistanceStep do
            local searchOffsets = {
                vector3(0.0, -distance, 0.0),
                vector3(18.0, -distance, 0.0),
                vector3(-18.0, -distance, 0.0),
                vector3(0.0, distance, 0.0)
            }

            for _, offset in ipairs(searchOffsets) do
                local baseOffset = GetOffsetFromEntityInWorldCoords(ped, offset.x, offset.y, offset.z)
                spawnCoords, spawnHeading = ResolveRoadSpawn(baseOffset, playerCoords.z)

                if spawnCoords then
                    return spawnCoords, spawnHeading
                end
            end

            Wait(25)
        end

        for _, distance in ipairs(Config.AdditionalSpawnDistances) do
            local fallbackOffset = GetOffsetFromEntityInWorldCoords(ped, 0.0, -distance, 0.0)
            spawnCoords, spawnHeading = ResolveRoadSpawn(fallbackOffset, playerCoords.z)
            if spawnCoords then
                DebugPrint(('Extended spawn found on pass %s at %.0fm'):format(attempt, distance))
                return spawnCoords, spawnHeading
            end
        end

        spawnCoords, spawnHeading = ResolveRandomRoadSpawn(ped, playerCoords.z)
        if spawnCoords then
            DebugPrint(('Random road spawn found on pass %s'):format(attempt))
            return spawnCoords, spawnHeading
        end

        Wait(Config.SpawnSearchPassDelay)
    end

    return nil, nil
end

local function CreateMechanicBlip()
    mechanicBlip = AddBlipForEntity(mechanicVeh)
    SetBlipSprite(mechanicBlip, Config.MechanicBlip.sprite)
    SetBlipScale(mechanicBlip, Config.MechanicBlip.scale)
    SetBlipColour(mechanicBlip, Config.MechanicBlip.color)
    SetBlipAsShortRange(mechanicBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(L(Config.MechanicBlip.label))
    EndTextCommandSetBlipName(mechanicBlip)
end

local function CreateDepotBlip()
    if depotBlip and DoesBlipExist(depotBlip) then
        RemoveBlip(depotBlip)
    end

    depotBlip = AddBlipForCoord(selectedDepot.coords.x, selectedDepot.coords.y, selectedDepot.coords.z)
    SetBlipSprite(depotBlip, Config.DepotBlip.sprite)
    SetBlipScale(depotBlip, Config.DepotBlip.scale)
    SetBlipColour(depotBlip, Config.DepotBlip.color)
    SetBlipRoute(depotBlip, true)
    SetBlipRouteColour(depotBlip, Config.DepotBlip.routeColor)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(GetDepotLabel(selectedDepot))
    EndTextCommandSetBlipName(depotBlip)
end

local function EnsurePlayerNearMechanic()
    return WaitForCondition(function()
        if not DoesEntityExist(mechanicPed) then
            return false
        end

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local mechanicCoords = GetEntityCoords(mechanicPed)
        return not IsPedInAnyVehicle(ped, false) and #(pedCoords - mechanicCoords) <= Config.TargetRadius + 1.0
    end, Config.PlayerWalkToMechanicTimeout, 500)
end

local function EnsurePlayerInVehicleForHook()
    local deadline = GetGameTimer() + Config.PlayerEnterVehicleTimeout
    local nextReminder = 0

    while GetGameTimer() < deadline do
        if GetVehiclePedIsIn(PlayerPedId(), false) == playerVeh then
            return true
        end

        if GetGameTimer() >= nextReminder then
            MechanicAlert(L('enter_vehicle_for_hook'), true)
            nextReminder = GetGameTimer() + Config.PlayerReminderInterval
        end

        Wait(500)
    end

    return false
end

local function EnsurePlayerEngineOnForTow()
    local deadline = GetGameTimer() + Config.PlayerEngineStartTimeout
    local nextReminder = 0

    while GetGameTimer() < deadline do
        if not DoesEntityExist(playerVeh) then
            return false
        end

        if GetVehiclePedIsIn(PlayerPedId(), false) ~= playerVeh then
            if GetGameTimer() >= nextReminder then
                MechanicAlert(L('stay_in_vehicle_engine'), true)
                nextReminder = GetGameTimer() + Config.PlayerReminderInterval
            end

            Wait(500)
        elseif GetIsVehicleEngineRunning(playerVeh) then
            return true
        else
            if GetGameTimer() >= nextReminder then
                MechanicAlert(L('start_engine_for_tow'), true)
                nextReminder = GetGameTimer() + Config.PlayerReminderInterval
            end

            Wait(500)
        end
    end

    return false
end

local function EnsurePlayerOutOfVehicleForRepair()
    local deadline = GetGameTimer() + Config.PlayerExitVehicleTimeout
    local nextReminder = 0

    while GetGameTimer() < deadline do
        if GetVehiclePedIsIn(PlayerPedId(), false) ~= playerVeh then
            return true
        end

        if GetGameTimer() >= nextReminder then
            MechanicAlert(L('exit_vehicle_for_repair'), true)
            nextReminder = GetGameTimer() + Config.PlayerReminderInterval
        end

        Wait(500)
    end

    return false
end

local function EnsurePlayerOutOfVehicleForRefuel()
    local deadline = GetGameTimer() + Config.PlayerExitVehicleTimeout
    local nextReminder = 0

    while GetGameTimer() < deadline do
        if GetVehiclePedIsIn(PlayerPedId(), false) ~= playerVeh then
            return true
        end

        if GetGameTimer() >= nextReminder then
            MechanicAlert(L('exit_vehicle_for_refuel'), true)
            nextReminder = GetGameTimer() + Config.PlayerReminderInterval
        end

        Wait(500)
    end

    return false
end

local function GetRepairHoodCoords(vehicle)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local frontCenter = GetOffsetFromEntityInWorldCoords(
        vehicle,
        0.0,
        maxDim.y + (Config.RepairFrontExtraOffset or 0.8),
        0.0
    )

    local hoodBone = GetEntityBoneIndexByName(vehicle, 'bonnet')
    if hoodBone ~= -1 then
        local hoodCoords = GetWorldPositionOfEntityBone(vehicle, hoodBone)
        return vector3(frontCenter.x, frontCenter.y, hoodCoords.z)
    end

    local fallback = GetOffsetFromEntityInWorldCoords(vehicle, Config.RepairWalkOffset.x, Config.RepairWalkOffset.y, Config.RepairWalkOffset.z)
    return vector3(fallback.x, fallback.y, fallback.z)
end

local function GetRefuelCoords(vehicle)
    local fuelBones = {
        'petrolcap',
        'petrolcap_l',
        'petrolcap_r',
        'petroltank',
        'petroltank_l',
        'petroltank_r'
    }

    for _, boneName in ipairs(fuelBones) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        if boneIndex ~= -1 then
            local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            return vector3(boneCoords.x, boneCoords.y, boneCoords.z)
        end
    end

    local minDim, _ = GetModelDimensions(GetEntityModel(vehicle))
    local fallback = GetOffsetFromEntityInWorldCoords(
        vehicle,
        Config.RefuelFallbackSideOffset,
        minDim.y + Config.RefuelFallbackRearExtraOffset,
        Config.RefuelFallbackHeightOffset
    )

    return vector3(fallback.x, fallback.y, fallback.z)
end

local function OpenFuelTypeMenu()
    local fuelPrice = quotedFuelPrice
    local currentFuel = fuelAssessment and math.floor(fuelAssessment.currentFuel) or 0
    local refuelAmount = fuelAssessment and math.floor(fuelAssessment.refuelAmount or 0) or 0

    exports['qb-menu']:openMenu({
        {
            header = L('fuel_type_title'),
            txt = L('fuel_type_status', { fuel = currentFuel, amount = refuelAmount, price = fuelPrice }),
            isMenuHeader = true
        },
        {
            header = L('fuel_type_petrol'),
            txt = L('fuel_type_petrol_desc'),
            params = {
                event = 'mechanic:client:chooseFuelType',
                args = { fuelType = 'benzin' }
            }
        },
        {
            header = L('fuel_type_diesel'),
            txt = L('fuel_type_diesel_desc'),
            params = {
                event = 'mechanic:client:chooseFuelType',
                args = { fuelType = 'diesel' }
            }
        },
        {
            header = L('close'),
            txt = L('close_desc')
        }
    })
end

local function OpenPaymentMenu(serviceType)
    local serviceLabel = L('service_tow')
    local servicePrice = quotedTowPrice

    if serviceType == 'repair' then
        serviceLabel = L('service_repair')
        servicePrice = quotedRepairPrice
    elseif serviceType == 'fuel' then
        serviceLabel = L('service_refuel', { fuelType = GetFuelTypeLabel(selectedFuelType) })
        servicePrice = quotedFuelPrice
    end

    exports['qb-menu']:openMenu({
        {
            header = L('pay_title', { service = serviceLabel }),
            txt = L('price_line', { price = servicePrice }),
            isMenuHeader = true
        },
        {
            header = L('pay_cash'),
            txt = L('pay_cash_desc', { service = serviceLabel }),
            params = {
                event = 'mechanic:client:chooseServicePayment',
                args = { serviceType = serviceType, method = 'cash' }
            }
        },
        {
            header = L('pay_bank'),
            txt = L('pay_bank_desc', { service = serviceLabel }),
            params = {
                event = 'mechanic:client:chooseServicePayment',
                args = { serviceType = serviceType, method = 'bank' }
            }
        },
        {
            header = L('close'),
            txt = L('close_desc')
        }
    })
end

OpenPaymentMenu = function(serviceType)
    local serviceLabel = GetServiceLabel(serviceType)
    local servicePrice = quotedTowPrice

    if serviceType == 'repair' then
        servicePrice = quotedRepairPrice
    elseif serviceType == 'fuel' then
        servicePrice = quotedFuelPrice
    end

    exports['qb-menu']:openMenu({
        {
            header = L('pay_title', { service = serviceLabel }),
            txt = L('price_line', { price = servicePrice }),
            isMenuHeader = true
        },
        {
            header = L('pay_cash'),
            txt = L('pay_cash_desc', { service = serviceLabel }),
            params = {
                event = 'mechanic:client:chooseServicePayment',
                args = { serviceType = serviceType, method = 'cash' }
            }
        },
        {
            header = L('pay_bank'),
            txt = L('pay_bank_desc', { service = serviceLabel }),
            params = {
                event = 'mechanic:client:chooseServicePayment',
                args = { serviceType = serviceType, method = 'bank' }
            }
        },
        {
            header = L('close'),
            txt = L('close_desc')
        }
    })
end

local function CreateTargetZone()
    CleanupTarget()

    local options = {}

    options[#options + 1] = {
        icon = 'fas fa-truck-ramp-box',
        label = L('target_tow', { price = quotedTowPrice }),
        canInteract = function()
            return serviceState == 'awaiting_payment'
        end,
        action = function()
            TriggerEvent('mechanic:client:openPaymentMenu', 'tow')
        end
    }

    if repairAssessment and repairAssessment.repairable then
        options[#options + 1] = {
            icon = 'fas fa-screwdriver-wrench',
            label = L('target_repair', { price = quotedRepairPrice }),
            canInteract = function()
                return serviceState == 'awaiting_payment'
            end,
            action = function()
                TriggerEvent('mechanic:client:openPaymentMenu', 'repair')
            end
        }
    else
        options[#options + 1] = {
            icon = 'fas fa-triangle-exclamation',
            label = L('target_repair_unavailable'),
            canInteract = function()
                return serviceState == 'awaiting_payment'
            end,
            action = function()
                MechanicAlert(L('vehicle_too_damaged'), true)
            end
        }
    end

    if fuelAssessment and fuelAssessment.refuelable then
        options[#options + 1] = {
            icon = 'fas fa-gas-pump',
            label = L('target_refuel', { price = quotedFuelPrice }),
            canInteract = function()
                return serviceState == 'awaiting_payment'
            end,
            action = function()
                TriggerEvent('mechanic:client:openFuelTypeMenu')
            end
        }
    else
        options[#options + 1] = {
            icon = 'fas fa-gas-pump',
            label = L('target_refuel_unavailable'),
            canInteract = function()
                return serviceState == 'awaiting_payment'
            end,
            action = function()
                MechanicAlert(L('vehicle_no_refuel_needed'), true)
            end
        }
    end

    exports['qb-target']:AddTargetEntity(mechanicPed, {
        options = options,
        distance = 2.0
    })

    targetAdded = true
end

RegisterNetEvent('mechanic:client:openPaymentMenu', function(serviceType)
    if serviceState ~= 'awaiting_payment' then
        return
    end

    if serviceType == 'repair' and (not repairAssessment or not repairAssessment.repairable) then
        MechanicAlert(L('vehicle_too_damaged'), true)
        return
    end

    OpenPaymentMenu(serviceType)
end)

RegisterNetEvent('mechanic:client:openFuelTypeMenu', function()
    if serviceState ~= 'awaiting_payment' then
        return
    end

    if not fuelAssessment or not fuelAssessment.refuelable then
        MechanicAlert(L('vehicle_no_refuel_needed'), true)
        return
    end

    OpenFuelTypeMenu()
end)

local function GetVehicleTowOffsets(vehicle)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleLength = math.abs(maxDim.y - minDim.y)
    local vehicleHeight = math.abs(maxDim.z - minDim.z)

    local preHookDistance = math.max(Config.MinimumPreHookDistance, vehicleLength + Config.PreHookExtraDistance)
    local attachX = Config.AttachBaseOffset.x
    local attachY = Config.AttachBaseOffset.y - (vehicleLength * Config.AttachLengthMultiplier)
    local attachZ = math.max(Config.MinimumAttachHeight, Config.AttachBaseOffset.z + (vehicleHeight * Config.AttachHeightMultiplier))

    return {
        preHook = vector3(0.0, -preHookDistance, Config.HookVehicleOffset.z),
        attach = vector3(attachX, attachY, attachZ),
        length = vehicleLength,
        height = vehicleHeight
    }
end

local function GetDynamicHookPosition(vehicle, towOffsets)
    return GetOffsetFromEntityInWorldCoords(vehicle, towOffsets.preHook.x, towOffsets.preHook.y, towOffsets.preHook.z)
end

local function EnsureMechanicInTruck()
    if mechanicPed and DoesEntityExist(mechanicPed) then
        ClearPedTasks(mechanicPed)
        ClearPedSecondaryTask(mechanicPed)
    end

    if IsPedInAnyVehicle(mechanicPed, false) then
        return true
    end

    TaskEnterVehicle(mechanicPed, mechanicVeh, 10000, -1, 1.0, 1, 0)

    local enteredVehicle = WaitForCondition(function()
        return IsPedInAnyVehicle(mechanicPed, false)
    end, 12000, 250)

    if not enteredVehicle then
        TaskWarpPedIntoVehicle(mechanicPed, mechanicVeh, -1)
        Wait(500)
    end

    return IsPedInAnyVehicle(mechanicPed, false)
end

local function EnsureMechanicOutOfTruck()
    if not IsPedInAnyVehicle(mechanicPed, false) then
        return true
    end

    TaskLeaveVehicle(mechanicPed, mechanicVeh, 0)

    local leftVehicle = WaitForCondition(function()
        return not IsPedInAnyVehicle(mechanicPed, false)
    end, 12000, 250)

    return leftVehicle
end

local function WaitForDepotArrival(destination)
    local deadline = GetGameTimer() + Config.DepotDriveTimeout
    local lastDistance = math.huge
    local stagnantTicks = 0
    local recoveryAttempts = 0

    while GetGameTimer() < deadline do
        if not DoesEntityExist(mechanicVeh) then
            return 'failed'
        end

        local towCoords = GetEntityCoords(mechanicVeh)
        local currentDistance = #(towCoords - destination)
        local towSpeedKmh = GetEntitySpeed(mechanicVeh) * 3.6
        local unsafeZone = GetUnsafeZoneAtCoords(towCoords)

        if currentDistance <= Config.DepotStopRadius + 8.0 then
            return 'reached'
        end

        if unsafeZone then
            DebugPrint(('Unsichere Zone erkannt waehrend Depot-Fahrt: %s'):format(unsafeZone.reason or 'unknown'))
            return 'unsafe_zone'
        end

        if DoesEntityExist(playerVeh) and not IsPlayerVehicleAttachedToServiceTruck() then
            return 'detached'
        end

        if currentDistance < lastDistance - Config.DepotProgressThreshold then
            lastDistance = currentDistance
            stagnantTicks = 0
            recoveryAttempts = 0
            deadline = math.max(deadline, GetGameTimer() + Config.DepotProgressExtension)
        else
            if towSpeedKmh <= Config.DepotStuckSpeedThreshold then
                stagnantTicks = stagnantTicks + 1
            else
                stagnantTicks = 0
            end
        end

        if stagnantTicks >= Config.DepotRepathTicks then
            recoveryAttempts = recoveryAttempts + 1
            DebugPrint(('Depot-Route wird neu gesetzt %s/%s'):format(recoveryAttempts, Config.DepotRecoveryAttempts))
            if recoveryAttempts > Config.DepotRecoveryAttempts then
                return 'failed'
            end

            ClearPedTasks(mechanicPed)
            ClearPedSecondaryTask(mechanicPed)
            StartLongrangeDrive(destination, Config.TowSpeed, Config.DepotStopRadius)
            stagnantTicks = 0
        end

        Wait(1000)
    end

    return 'failed'
end

local function FinishTow()
    if DoesEntityExist(mechanicVeh) and DoesEntityExist(playerVeh) then
        DetachVehicleFromTowTruck(mechanicVeh, playerVeh)

        SetVehicleUndriveable(playerVeh, false)
        SetVehicleHandbrake(playerVeh, false)
        SetVehicleBrakeLights(playerVeh, false)
        SetEntityHeading(playerVeh, GetEntityHeading(playerVeh))
        SetVehicleOnGroundProperly(playerVeh)
        FreezeEntityPosition(playerVeh, true)
        Wait(500)
        FreezeEntityPosition(playerVeh, false)
    end

    TriggerServerEvent('mechanic:pay', quotedPrice, selectedPaymentMethod)
    PlayMechanicSpeech(Config.MechanicGoodbyeSpeech)
    MechanicAlert(L('tow_finished', { price = quotedPrice, method = GetPaymentMethodLabel(selectedPaymentMethod) }), true)

    CleanupTarget()
    CleanupBlips()
    SetTowtruckWarningLights(false)
    SetTowDrivingMode(false)

    if DoesEntityExist(mechanicPed) and DoesEntityExist(mechanicVeh) then
        TaskVehicleDriveWander(mechanicPed, mechanicVeh, Config.DepartSpeed, DRIVING_STYLE)
    end

    Wait(Config.DespawnDelay)
    CleanupMechanic()
end

local function FinishRepair()
    TriggerServerEvent('mechanic:pay', quotedPrice, selectedPaymentMethod, 'repair')
    PlayMechanicSpeech(Config.MechanicGoodbyeSpeech)
    MechanicAlert(L('repair_success'), true)
    MechanicAlert(L('repair_finished', { price = quotedPrice, method = GetPaymentMethodLabel(selectedPaymentMethod) }), true)

    CleanupTarget()
    CleanupBlips()
    SetTowtruckWarningLights(false)
    SetTowDrivingMode(false)

    if DoesEntityExist(mechanicPed) and DoesEntityExist(mechanicVeh) then
        TaskVehicleDriveWander(mechanicPed, mechanicVeh, Config.DepartSpeed, DRIVING_STYLE)
    end

    Wait(Config.DespawnDelay)
    CleanupMechanic()
end

local function FinishRefuel()
    TriggerServerEvent('mechanic:pay', quotedPrice, selectedPaymentMethod, 'fuel')
    PlayMechanicSpeech(Config.MechanicGoodbyeSpeech)
    MechanicAlert(L('refuel_success', { fuelType = GetFuelTypeLabel(selectedFuelType) }), true)
    MechanicAlert(
        L('refuel_finished', {
            fuelType = GetFuelTypeLabel(selectedFuelType),
            amount = math.floor(fuelAssessment and fuelAssessment.refuelAmount or (Config.RefuelCanAmount or 20)),
            price = quotedPrice,
            method = GetPaymentMethodLabel(selectedPaymentMethod)
        }),
        true
    )

    CleanupTarget()
    CleanupBlips()
    SetTowtruckWarningLights(false)
    SetTowDrivingMode(false)

    if DoesEntityExist(mechanicPed) and DoesEntityExist(mechanicVeh) then
        TaskVehicleDriveWander(mechanicPed, mechanicVeh, Config.DepartSpeed, DRIVING_STYLE)
    end

    Wait(Config.DespawnDelay)
    CleanupMechanic()
end

local function StartRepairFlow()
    if serviceState ~= 'awaiting_payment' or not repairAssessment then
        return
    end

    if not repairAssessment.repairable then
        MechanicAlert(L('vehicle_too_damaged'), true)
        return
    end

    CleanupTarget()
    serviceState = 'repairing'
    MechanicAlert(L('repair_started'), true)

    if not EnsurePlayerOutOfVehicleForRepair() then
        AbortService(L('abort_repair_player_not_out'))
        return
    end

    if not EnsureMechanicOutOfTruck() then
        AbortService(L('abort_mechanic_cannot_exit_truck'))
        return
    end

    local hasRepairTool = CollectServiceItem(
        Config.RepairToolPropModel,
        Config.RepairToolCarryBone,
        Config.RepairToolCarryOffset,
        Config.RepairToolCarryRotation
    )

    if not hasRepairTool then
        DebugPrint('Reparaturwerkzeug konnte nicht geholt werden, setze Reparatur ohne Prop fort')
    end

    local hoodCoords = GetRepairHoodCoords(playerVeh)
    TaskGoToCoordAnyMeans(mechanicPed, hoodCoords.x, hoodCoords.y, hoodCoords.z, 1.0, 0, 0, DRIVING_STYLE, 0)

    local reachedHood = WaitForCondition(function()
        local pedCoords = GetEntityCoords(mechanicPed)
        return #(pedCoords - hoodCoords) <= Config.RepairReachRadius
    end, 20000, 500)

    if not reachedHood then
        AbortService(L('abort_mechanic_cannot_reach_hood'))
        return
    end

    SetVehicleDoorOpen(playerVeh, Config.RepairHoodDoorIndex, false, false)
    TaskTurnPedToFaceCoord(mechanicPed, hoodCoords.x, hoodCoords.y, hoodCoords.z, 1000)
    Wait(500)

    local animLoaded = LoadAnimDict(Config.RepairAnimDict)
    if animLoaded then
        TaskPlayAnim(
            mechanicPed,
            Config.RepairAnimDict,
            Config.RepairAnimName,
            8.0,
            -8.0,
            repairAssessment.duration,
            1,
            0.0,
            false,
            false,
            false
        )
    end

    Wait(repairAssessment.duration)
    ClearPedTasks(mechanicPed)

    SetVehicleFixed(playerVeh)
    SetVehicleDeformationFixed(playerVeh)
    SetVehicleEngineHealth(playerVeh, 1000.0)
    SetVehicleBodyHealth(playerVeh, 1000.0)
    SetVehiclePetrolTankHealth(playerVeh, 1000.0)
    SetVehicleUndriveable(playerVeh, false)
    SetVehicleHandbrake(playerVeh, false)
    SetVehicleDoorShut(playerVeh, Config.RepairHoodDoorIndex, false)

    if hasRepairTool and not StowServiceItem() then
        DebugPrint('Reparaturwerkzeug konnte nicht wieder verstaut werden, setze Ablauf fort')
    end

    if not EnsureMechanicInTruck() then
        AbortService(L('abort_mechanic_cannot_reenter_truck'))
        return
    end

    FinishRepair()
end

local function StartRefuelFlow()
    if serviceState ~= 'awaiting_payment' or not fuelAssessment then
        return
    end

    if not fuelAssessment.refuelable then
        MechanicAlert(L('vehicle_no_refuel_needed'), true)
        return
    end

    CleanupTarget()
    serviceState = 'refueling'
    MechanicAlert(L('refuel_started', { fuelType = GetFuelTypeLabel(selectedFuelType) }), true)

    if GetVehiclePedIsIn(PlayerPedId(), false) == playerVeh and not EnsurePlayerOutOfVehicleForRefuel() then
        AbortService(L('abort_refuel_player_not_out'))
        return
    end

    if not EnsureMechanicOutOfTruck() then
        AbortService(L('abort_mechanic_cannot_exit_truck'))
        return
    end

    local hasFuelCan = CollectServiceItem(
        Config.FuelCanPropModel,
        Config.FuelCanCarryBone,
        Config.FuelCanCarryOffset,
        Config.FuelCanCarryRotation
    )

    if not hasFuelCan then
        DebugPrint('Kanister konnte nicht geholt werden, setze Betankung ohne Prop fort')
    end

    local refuelCoords = GetRefuelCoords(playerVeh)
    TaskGoToCoordAnyMeans(mechanicPed, refuelCoords.x, refuelCoords.y, refuelCoords.z, 1.0, 0, 0, DRIVING_STYLE, 0)

    local reachedFuelSide = WaitForCondition(function()
        local pedCoords = GetEntityCoords(mechanicPed)
        return #(pedCoords - refuelCoords) <= Config.RefuelReachRadius
    end, 20000, 500)

    if not reachedFuelSide then
        AbortService(L('abort_mechanic_cannot_reach_tank'))
        return
    end

    TaskTurnPedToFaceCoord(mechanicPed, refuelCoords.x, refuelCoords.y, refuelCoords.z, 1000)
    Wait(500)

    local animLoaded = LoadAnimDict(Config.RefuelAnimDict)
    if animLoaded then
        TaskPlayAnim(
            mechanicPed,
            Config.RefuelAnimDict,
            Config.RefuelAnimName,
            8.0,
            -8.0,
            fuelAssessment.duration,
            1,
            0.0,
            false,
            false,
            false
        )
    end

    Wait(fuelAssessment.duration)
    ClearPedTasks(mechanicPed)

    SetVehicleServiceFuelLevel(playerVeh, fuelAssessment.targetFuel)

    if hasFuelCan and not StowServiceItem() then
        DebugPrint('Kanister konnte nicht wieder verstaut werden, setze Ablauf fort')
    end

    if not EnsureMechanicInTruck() then
        AbortService(L('abort_mechanic_cannot_reenter_truck'))
        return
    end

    FinishRefuel()
end

local function DriveToDepot()
    serviceState = 'to_depot'
    CreateDepotBlip()
    MechanicAlert(L('drive_to_depot', { depot = GetDepotLabel(selectedDepot) }), true)

    if DoesEntityExist(mechanicPed) then
        ClearPedTasks(mechanicPed)
        ClearPedSecondaryTask(mechanicPed)
    end

    if not EnsureMechanicInTruck() then
        AbortService(L('abort_mechanic_cannot_reenter_truck'))
        return
    end

    SetTowDrivingMode(true)
    SetTowtruckWarningLights(true)
    SetVehicleEngineOn(mechanicVeh, true, true, false)

    StartLongrangeDrive(selectedDepot.coords, Config.TowSpeed, Config.DepotStopRadius)

    while true do
        local depotResult = WaitForDepotArrival(selectedDepot.coords)

        if depotResult == 'reached' then
            break
        end

        if depotResult == 'detached' then
            SetTowDrivingMode(false)
            AbortService(L('abort_vehicle_detached'))
            return
        elseif depotResult == 'unsafe_zone' then
            SetTowDrivingMode(false)
            AbortService(L('abort_unsafe_route_end'))
            return
        else
            SetTowDrivingMode(false)
            AbortService(L('abort_depot_not_reached'))
            return
        end
    end

    TaskVehicleTempAction(mechanicPed, mechanicVeh, 27, 2500)
    Wait(Config.DepotArrivalPause)
    FinishTow()
end

local function AttachPlayerVehicle()
    local minDim, maxDim = GetModelDimensions(GetEntityModel(playerVeh))
    local vehicleLength = math.abs(maxDim.y - minDim.y)
    local towProfile = GetSelectedTowTruckProfile()
    local towCoords = GetEntityCoords(mechanicVeh)
    local towForward = GetEntityForwardVector(mechanicVeh)
    local desiredHeading = (GetEntityHeading(mechanicVeh) + 180.0) % 360.0
    local attachDistance = (vehicleLength / 2) + towProfile.attachVehicleBehindTowDistance
    local attachPos = towCoords - (towForward * attachDistance)

    DebugPrint(('Fahrzeugmasse erkannt | Laenge: %.2f | Towtruck: %s'):format(vehicleLength, selectedTowTruckModel or 'unknown'))

    local playerHookCoords = GetOffsetFromEntityInWorldCoords(playerVeh, Config.PlayerHookInteractionOffset.x, Config.PlayerHookInteractionOffset.y, Config.PlayerHookInteractionOffset.z)

    TaskGoToCoordAnyMeans(mechanicPed, playerHookCoords.x, playerHookCoords.y, playerHookCoords.z, 1.0, 0, 0, DRIVING_STYLE, 0)

    local reachedHook = WaitForCondition(function()
        local pedCoords = GetEntityCoords(mechanicPed)
        return #(pedCoords - playerHookCoords) <= Config.PlayerHookReachRadius
    end, 15000, 500)

    if not reachedHook then
        return false
    end

    TaskTurnPedToFaceCoord(mechanicPed, playerHookCoords.x, playerHookCoords.y, playerHookCoords.z, 1000)
    Wait(500)

    local animLoaded = LoadAnimDict(Config.AttachAnimDict)
    if animLoaded then
        TaskPlayAnim(
            mechanicPed,
            Config.AttachAnimDict,
            Config.AttachAnimName,
            8.0,
            -8.0,
            Config.AttachAnimTime,
            1,
            0.0,
            false,
            false,
            false
        )
        Wait(Config.AttachAnimTime)
        ClearPedTasks(mechanicPed)
    end

    SetVehicleUndriveable(playerVeh, true)
    SetVehicleHandbrake(playerVeh, false)
    SetVehicleBrakeLights(playerVeh, false)

    SetEntityCoords(playerVeh, attachPos.x, attachPos.y, attachPos.z, false, false, false, false)
    SetEntityHeading(playerVeh, desiredHeading)

    SetVehicleOnGroundProperly(playerVeh)
    Wait(500)

    AttachVehicleToTowTruck(
        mechanicVeh,
        playerVeh,
        false,
        towProfile.attachTowXOffset,
        -((vehicleLength / 2) + towProfile.attachTowYOffset),
        towProfile.attachTowZOffset
    )

    local attached = WaitForCondition(function()
        return IsPlayerVehicleAttachedToServiceTruck()
    end, 3000, 100)

    if not attached then
        DebugPrint('AttachVehicleToTowTruck hat keine Verbindung hergestellt')
        return false
    end

    SetVehicleHandbrake(playerVeh, false)
    SetVehicleUndriveable(playerVeh, true)
    SetVehicleBrakeLights(playerVeh, false)

    if DoesEntityExist(mechanicPed) then
        ClearPedTasks(mechanicPed)
        ClearPedSecondaryTask(mechanicPed)
    end

    return true
end

local function EnsureMechanicAtPlayerVehicleForTow()
    if not DoesEntityExist(mechanicPed) or not DoesEntityExist(playerVeh) then
        return false
    end

    if IsPedInAnyVehicle(mechanicPed, false) and not EnsureMechanicOutOfTruck() then
        return false
    end

    local serviceCoords = GetOffsetFromEntityInWorldCoords(playerVeh, 0.0, Config.PlayerVehicleTalkOffset, 0.0)
    TaskGoToCoordAnyMeans(mechanicPed, serviceCoords.x, serviceCoords.y, serviceCoords.z, 1.0, 0, 0, DRIVING_STYLE, 0)

    local reachedVehicle = WaitForCondition(function()
        local pedCoords = GetEntityCoords(mechanicPed)
        return #(pedCoords - serviceCoords) <= 2.2
    end, 12000, 250)

    if reachedVehicle then
        TaskTurnPedToFaceEntity(mechanicPed, playerVeh, 1000)
        Wait(250)
    end

    return reachedVehicle
end

local function StartTowFlow()
    if serviceState ~= 'awaiting_payment' then
        return
    end

    if not EnsurePlayerInVehicleForHook() then
        AbortService(L('abort_tow_player_not_in_vehicle'))
        return
    end

    CleanupTarget()
    serviceState = 'hooking'
    MechanicAlert(L('attaching_vehicle'), true)

    if not EnsureMechanicAtPlayerVehicleForTow() then
        AbortService(L('abort_mechanic_cannot_prepare_tow'))
        return
    end

    local attached = AttachPlayerVehicle()
    if not attached then
        DebugPrint('Erster Hook-Versuch fehlgeschlagen, versuche es erneut')
        if not EnsureMechanicAtPlayerVehicleForTow() then
            AbortService(L('abort_mechanic_cannot_prepare_tow'))
            return
        end

        attached = AttachPlayerVehicle()
    end

    if not attached then
        AbortService(L('abort_vehicle_could_not_attach'))
        return
    end

    if not EnsureMechanicInTruck() then
        AbortService(L('abort_mechanic_cannot_enter_truck'))
        return
    end

    if not EnsurePlayerEngineOnForTow() then
        AbortService(L('abort_tow_engine_not_started'))
        return
    end

    serviceState = 'towing'
    SetTowtruckWarningLights(true)
    DriveToDepot()
end

RegisterNetEvent('mechanic:client:chooseServicePayment', function(serviceType, method)
    if type(serviceType) == 'table' then
        method = serviceType.method
        serviceType = serviceType.serviceType
    end

    if serviceState ~= 'awaiting_payment' then
        return
    end

    local amount = quotedTowPrice
    if serviceType == 'repair' then
        amount = quotedRepairPrice
    elseif serviceType == 'fuel' then
        amount = quotedFuelPrice
    end
    if amount <= 0 then
        return
    end

    if serviceType == 'repair' and (not repairAssessment or not repairAssessment.repairable) then
        MechanicAlert(L('vehicle_too_damaged'), true)
        return
    end

    if serviceType == 'fuel' and (not fuelAssessment or not fuelAssessment.refuelable) then
        MechanicAlert(L('vehicle_no_refuel_needed'), true)
        return
    end

    QBCore.Functions.TriggerCallback('mechanic:server:canAfford', function(canAfford)
        if not canAfford then
            MechanicAlert(L('not_enough_money'), true)
            return
        end

        selectedServiceType = serviceType
        selectedPaymentMethod = method
        quotedPrice = amount
        MechanicNotify(L('payment_selected', { method = GetPaymentMethodLabel(method) }))
        if serviceType == 'repair' then
            StartRepairFlow()
        elseif serviceType == 'fuel' then
            StartRefuelFlow()
        else
            StartTowFlow()
        end
    end, amount, method)
end)

RegisterNetEvent('mechanic:client:chooseFuelType', function(data)
    local fuelType = data
    if type(data) == 'table' then
        fuelType = data.fuelType
    end

    if serviceState ~= 'awaiting_payment' then
        return
    end

    if not fuelAssessment or not fuelAssessment.refuelable then
        MechanicAlert(L('vehicle_no_refuel_needed'), true)
        return
    end

    if fuelType ~= 'diesel' then
        fuelType = 'benzin'
    end

    selectedFuelType = fuelType
    OpenPaymentMenu('fuel')
end)

local function BeginPaymentSelection()
    serviceState = 'awaiting_payment'
    CreateTargetZone()
end

local function WalkToPlayerVehicle()
    serviceState = 'at_vehicle'
    local serviceCoords = GetOffsetFromEntityInWorldCoords(playerVeh, 0.0, Config.PlayerVehicleTalkOffset, 0.0)

    TaskGoToCoordAnyMeans(mechanicPed, serviceCoords.x, serviceCoords.y, serviceCoords.z, 1.0, 0, 0, DRIVING_STYLE, 0)

    local reachedVehicle = WaitForCondition(function()
        local pedCoords = GetEntityCoords(mechanicPed)
        return #(pedCoords - serviceCoords) <= 2.2
    end, 20000, 500)

    if not reachedVehicle then
        AbortService(L('abort_mechanic_cannot_reach_vehicle'))
        return
    end

    TaskTurnPedToFaceEntity(mechanicPed, playerVeh, 2000)
    PlayMechanicSpeech(Config.MechanicGreetingSpeech)
    MechanicAlert(L('greeting'), true)

    if not EnsurePlayerNearMechanic() then
        AbortService(L('abort_player_not_near_mechanic'))
        return
    end

    BeginPaymentSelection()
end

local function DriveToPlayer()
    serviceState = 'driving_to_player'
    MechanicNotify(L('mechanic_on_way'))

    local leftSpawn = LeaveSpawnPoint()
    if not leftSpawn then
        if Config.UseFixedSpawnPoints then
            DebugPrint('Fester Spawnpunkt: Spawn-Abfahrt nicht bestaetigt, fahre trotzdem direkt zum Spieler weiter')
        else
            if spawnRetryCount < Config.SpawnRetryAttempts then
                spawnRetryCount = spawnRetryCount + 1
                DebugPrint(('Spawnpunkt blockiert, neuer Spawnversuch %s/%s'):format(spawnRetryCount, Config.SpawnRetryAttempts))
                CleanupSpawnedMechanic()
                serviceState = 'spawning'
                SpawnMechanic()
                return
            end

            AbortService(L('abort_mechanic_stuck_spawn'))
            return
        end
    end

    local stopCoords = GetPlayerServiceStopCoords()
    SetPlayerApproachDrivingMode(true)
    StartDirectDrive(stopCoords, Config.PlayerApproachSpeed, Config.PlayerStopRadius)

    local playerApproachResult = WaitForPlayerApproachDistance(Config.PlayerSlowdownDistance)
    if playerApproachResult == 'stuck' then
        if RetryMechanicSpawn('Mechaniker ist am Spawnpunkt zu lange stehen geblieben') then
            return
        end

        AbortService(L('abort_mechanic_stuck_spawn'))
        return
    end

    if playerApproachResult == 'unsafe_zone' then
        AbortService(L('abort_unsafe_route_job'))
        return
    end

    if playerApproachResult ~= 'reached' then
        AbortService(L('abort_mechanic_cannot_reach_you'))
        return
    end

    SetPlayerApproachDrivingMode(false)
    StartDirectDrive(stopCoords, Config.DriveSpeed, Config.PlayerStopRadius)

    local reachedPlayer = WaitForCondition(function()
        if not DoesEntityExist(mechanicVeh) or not DoesEntityExist(playerVeh) then
            return false
        end

        local towCoords = GetEntityCoords(mechanicVeh)
        local vehicleCoords = GetEntityCoords(playerVeh)
        return #(towCoords - vehicleCoords) <= Config.PlayerStopRadius + 6.0
    end, Config.PlayerDriveTimeout, 1000)

    if not reachedPlayer then
        AbortService(L('abort_mechanic_cannot_reach_you'))
        return
    end

    SetPlayerApproachDrivingMode(false)
    SetTowtruckWarningLights(true)
    TaskVehicleTempAction(mechanicPed, mechanicVeh, 27, 2000)
    Wait(1500)
    TaskLeaveVehicle(mechanicPed, mechanicVeh, 0)

    local leftVehicle = WaitForCondition(function()
        return not IsPedInAnyVehicle(mechanicPed, false)
    end, 10000, 250)

    if not leftVehicle then
        AbortService(L('abort_mechanic_cannot_exit'))
        return
    end

    WalkToPlayerVehicle()
end

SpawnMechanic = function()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local spawnCoords = nil
    local spawnHeading = 0.0

    DebugPrint('Suche Spawnpunkt fuer Towtruck')
    spawnCoords, spawnHeading = FindSpawnPoint(ped, playerCoords)

    if not spawnCoords then
        AbortService(L('abort_no_spawn_found'))
        return
    end

    if not Config.UseFixedSpawnPoints then
        spawnHeading = GetSpawnHeadingTowardPlayer(spawnCoords, spawnHeading, playerCoords)
    end

    selectedTowTruckModel = nil
    local towTruckModelName = GetTowTruckModelForPlayerVehicle()
    selectedTowTruckModel = towTruckModelName
    DebugPrint(('Towtruck-Auswahl | Modell: %s'):format(selectedTowTruckModel))

    local vehicleModel = GetHashKey(selectedTowTruckModel)
    local pedModel = GetHashKey(Config.MechanicPed)

    if not IsModelInCdimage(vehicleModel) or not IsModelAVehicle(vehicleModel) then
        AbortService(L('abort_invalid_towtruck_model', { model = selectedTowTruckModel }))
        return
    end

    if not IsModelInCdimage(pedModel) or not IsModelValid(pedModel) then
        AbortService(L('abort_invalid_mechanic_model', { model = Config.MechanicPed }))
        return
    end

    RequestModel(vehicleModel)
    RequestModel(pedModel)

    local loaded = WaitForCondition(function()
        return HasModelLoaded(vehicleModel) and HasModelLoaded(pedModel)
    end, 15000, 100)

    if not loaded then
        AbortService(L('abort_models_not_loaded'))
        return
    end

    mechanicVeh = CreateVehicle(vehicleModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, true, true)
    if not DoesEntityExist(mechanicVeh) then
        AbortService(L('abort_towtruck_not_created'))
        return
    end

    SetEntityAsMissionEntity(mechanicVeh, true, true)
    SetVehicleOnGroundProperly(mechanicVeh)

    mechanicPed = CreatePedInsideVehicle(mechanicVeh, 4, pedModel, -1, true, true)
    if not DoesEntityExist(mechanicPed) then
        mechanicPed = CreatePed(4, pedModel, spawnCoords.x, spawnCoords.y, spawnCoords.z + 1.0, spawnHeading, true, true)
    end

    if not DoesEntityExist(mechanicPed) then
        AbortService(L('abort_ped_not_created'))
        return
    end

    if not IsPedInAnyVehicle(mechanicPed, false) then
        TaskWarpPedIntoVehicle(mechanicPed, mechanicVeh, -1)
    end

    SetEntityAsMissionEntity(mechanicPed, true, true)
    SetBlockingOfNonTemporaryEvents(mechanicPed, true)
    SetPedKeepTask(mechanicPed, true)
    ApplyMechanicDriverSettings()
    StartTrafficHold()

    SetModelAsNoLongerNeeded(vehicleModel)
    SetModelAsNoLongerNeeded(pedModel)

    CreateMechanicBlip()
    DebugPrint(('Mechaniker gespawnt bei %.2f %.2f %.2f'):format(spawnCoords.x, spawnCoords.y, spawnCoords.z))

    CreateThread(function()
        DriveToPlayer()
    end)
end

RegisterCommand(Config.Command, function()
    local ped = PlayerPedId()

    if serviceActive then
        MechanicNotify(L('service_already_active'))
        return
    end

    if not IsPedInAnyVehicle(ped, false) then
        MechanicAlert(L('must_be_in_vehicle'), true)
        return
    end

    playerVeh = GetVehiclePedIsIn(ped, false)

    if playerVeh == 0 or not DoesEntityExist(playerVeh) then
        MechanicAlert(L('vehicle_not_detected'), true)
        return
    end

    selectedDepot = GetClosestDepot(GetEntityCoords(playerVeh))

    if not selectedDepot then
        MechanicAlert(L('no_depot_found'), true)
        return
    end

    quotedTowPrice = CalculateTowPrice(playerVeh, selectedDepot)
    repairAssessment = GetRepairAssessment(playerVeh)
    quotedRepairPrice = repairAssessment.price
    fuelAssessment = GetFuelAssessment(playerVeh)
    quotedFuelPrice = fuelAssessment.price
    quotedPrice = 0
    selectedServiceType = nil
    selectedFuelType = nil

    serviceActive = true
    serviceState = 'spawning'

    MechanicAlert(L('mechanic_called'), true)
    SpawnMechanic()
end, false)

CreateThread(function()
    Wait(1000)

    if Config.EnableSpawnPointDebug then
        ToggleSpawnDebugBlips()
    end

    if Config.EnableUnsafeZoneDebug then
        ToggleUnsafeZoneDebugBlips()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ClearSpawnDebugBlips()
    ClearUnsafeZoneDebugBlips()
end)

