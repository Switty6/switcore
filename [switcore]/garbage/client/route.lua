local activeSession    = nil
local spawnedVehicle   = nil
local waypointProxIds  = {}
local waypointBlips    = {}
local depotReturnBlip  = nil
local currentRouteBlip = nil
local bagData          = {}
local isCollecting     = false
local carryState       = nil

local BAG_MODELS = {
    'prop_rub_binbag_01',
    'prop_rub_binbag_sd_01',
    'prop_street_binbag_01',
}

local function notify(notifType, title, message)
    TriggerEvent('switcore:notify:local', notifType, title .. ': ' .. message, 4000)
end

local function spawnGarbageTruck(cb)
    local model = GetHashKey(Config.VehicleModel)
    RequestModel(model)
    local elapsed = 0
    while not HasModelLoaded(model) do
        Wait(50)
        elapsed = elapsed + 50
        if elapsed > 8000 then
            if cb then cb(nil) end
            return
        end
    end

    local c      = Config.HiringCoords
    local offset = Config.VehicleSpawnOffset
    local heading = GetEntityHeading(PlayerPedId())

    local vehicle = CreateVehicle(
        model,
        c.x + offset.x,
        c.y + offset.y,
        c.z,
        heading,
        true, false
    )
    SetVehicleOnGroundProperly(vehicle)
    SetModelAsNoLongerNeeded(model)

    -- Cheie temporara ca sa nu apara "vehicul incuiat"
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    pcall(function() exports.vehicles:GrantTempKey(plate) end)

    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    Wait(300)
    if cb then cb(vehicle) end
end

local function playPickupAnimation(duration, cb)
    local ped  = PlayerPedId()
    local dict = 'pickup_object'

    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) do
            Wait(50); t = t + 50
            if t > 4000 then
                FreezeEntityPosition(ped, true)
                Wait(duration)
                FreezeEntityPosition(ped, false)
                if cb then cb() end
                return
            end
        end
    end

    TaskPlayAnim(ped, dict, 'pickup_low', 8.0, -8.0, duration, 0, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(ped)
    if cb then cb() end
end

local function clearCarryState()
    if not carryState then return end
    carryState.updaterActive = false
    if carryState.dropProxId then
        exports.proximity:RemoveInteraction(carryState.dropProxId)
    end
    if carryState.dropBlip and DoesBlipExist(carryState.dropBlip) then
        RemoveBlip(carryState.dropBlip)
    end
    if carryState.bag and carryState.bag.prop and DoesEntityExist(carryState.bag.prop) then
        DetachEntity(carryState.bag.prop, true, true)
        SetEntityAsMissionEntity(carryState.bag.prop, false, true)
        DeleteObject(carryState.bag.prop)
        carryState.bag.prop = nil
    end
    carryState = nil
end

local function finalizeBagAfterDrop(wpIndex, bagIndex)
    local bags = bagData[wpIndex]
    if not bags then return end
    local bag = bags[bagIndex]
    if not bag then return end

    bag.done = true
    SendNUIMessage({ action = 'stopCollecting' })
    isCollecting = false

    if not activeSession then return end

    local allDone = true
    for _, b in ipairs(bags) do
        if not b.done then allDone = false; break end
    end

    if allDone then
        activeSession.collectedSet[wpIndex] = true
        TriggerServerEvent('garbage:server:collectPoint', activeSession.sessionId, wpIndex)
        local b = waypointBlips[wpIndex]
        if b and DoesBlipExist(b) then RemoveBlip(b) end
        waypointBlips[wpIndex] = nil
        if currentRouteBlip == b then currentRouteBlip = nil end
        setNextWaypointGPS()
    end
end

local function isPedBehindTruck(ped, truck)
    if not (truck and DoesEntityExist(truck)) then return false end
    local p = GetEntityCoords(ped)
    local localPos = GetOffsetFromEntityGivenWorldCoords(truck, p.x, p.y, p.z)
    -- trash truck e lung, zona valida in spate: y∈[-5.5,-1.0], |x|<2.0
    return localPos.y < -1.0 and localPos.y > -5.5 and math.abs(localPos.x) < 2.0
end

local function performTossAnimation(bag)
    local ped = PlayerPedId()

    if DoesEntityExist(spawnedVehicle) then
        TaskTurnPedToFaceEntity(ped, spawnedVehicle, 500)
        Wait(500)

        -- index 5 = trunk/back door
        SetVehicleDoorOpen(spawnedVehicle, 5, false, false)
    end

    local dict = 'pickup_object'
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 2000 do Wait(50); t = t + 50 end
    end
    TaskPlayAnim(ped, dict, 'putdown_low', 8.0, -8.0, 900, 0, 0, false, false, false)
    Wait(450)

    if bag.prop and DoesEntityExist(bag.prop) then
        DetachEntity(bag.prop, true, true)
        SetEntityCollision(bag.prop, true, true)
        SetEntityDynamic(bag.prop, true)
        local fwd = GetEntityForwardVector(ped)
        ApplyForceToEntity(
            bag.prop, 1,
            fwd.x * 2.5, fwd.y * 2.5, 5.5,
            0.0, 0.0, 0.0,
            0, false, true, true, false, true
        )
        local prop = bag.prop
        SetTimeout(700, function()
            if DoesEntityExist(prop) then
                SetEntityAsMissionEntity(prop, false, true)
                DeleteObject(prop)
            end
        end)
        bag.prop = nil
    end

    Wait(500)
    ClearPedTasks(ped)

    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        SetVehicleDoorShut(spawnedVehicle, 5, false)
    end
end

local function startCarryAndDropoff(wpIndex, bagIndex, bag)
    local ped = PlayerPedId()

    -- bone PH_R_Hand = 60309
    if bag.prop and DoesEntityExist(bag.prop) then
        FreezeEntityPosition(bag.prop, false)
        AttachEntityToEntity(
            bag.prop, ped, GetPedBoneIndex(ped, 60309),
            0.12, 0.02, -0.02,
            -90.0, 0.0, 0.0,
            true, true, false, true, 1, true
        )
    end

    if not (spawnedVehicle and DoesEntityExist(spawnedVehicle)) then
        if bag.prop and DoesEntityExist(bag.prop) then
            DetachEntity(bag.prop, true, true)
            SetEntityAsMissionEntity(bag.prop, false, true)
            DeleteObject(bag.prop)
            bag.prop = nil
        end
        notify('warning', Sw.T('garbage.title_no_truck'), Sw.T('garbage.bag_tossed'))
        finalizeBagAfterDrop(wpIndex, bagIndex)
        return
    end

    local rear = GetOffsetFromEntityInWorldCoords(spawnedVehicle, 0.0, -3.8, 0.0)
    local dropBlip = AddBlipForCoord(rear.x, rear.y, rear.z)
    SetBlipSprite(dropBlip, 318)
    SetBlipColour(dropBlip, 3)
    SetBlipScale(dropBlip, 0.9)
    SetBlipAsMissionCreatorBlip(dropBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Sw.T('garbage.drop_bag_truck'))
    EndTextCommandSetBlipName(dropBlip)

    -- Suspenda ruta GPS curenta; se reia dupa drop
    if currentRouteBlip and DoesBlipExist(currentRouteBlip) then
        SetBlipRoute(currentRouteBlip, false)
    end
    SetBlipRoute(dropBlip, true)
    SetBlipRouteColour(dropBlip, 3)

    carryState = {
        bag           = bag,
        dropBlip      = dropBlip,
        dropProxId    = nil,
        updaterActive = true,
    }

    CreateThread(function()
        while carryState and carryState.updaterActive do
            Wait(500)
            if spawnedVehicle and DoesEntityExist(spawnedVehicle)
                and carryState and carryState.dropBlip and DoesBlipExist(carryState.dropBlip) then
                local r = GetOffsetFromEntityInWorldCoords(spawnedVehicle, 0.0, -3.8, 0.0)
                SetBlipCoords(carryState.dropBlip, r.x, r.y, r.z)
            end
        end
    end)

    carryState.dropProxId = exports.proximity:AddEntityInteraction(
        spawnedVehicle,
        Sw.T('garbage.drop_bag_truck'),
        'garbage_drop',
        {},
        function()
            if not carryState or carryState.bag ~= bag then return end

            if not isPedBehindTruck(PlayerPedId(), spawnedVehicle) then
                notify('warning', Sw.T('garbage.title_wrong_position'),
                    Sw.T('garbage.must_be_behind_truck'))
                return
            end

            carryState.updaterActive = false
            if carryState.dropProxId then
                exports.proximity:RemoveInteraction(carryState.dropProxId)
                carryState.dropProxId = nil
            end
            if carryState.dropBlip and DoesBlipExist(carryState.dropBlip) then
                RemoveBlip(carryState.dropBlip)
                carryState.dropBlip = nil
            end

            performTossAnimation(bag)
            carryState = nil

            setNextWaypointGPS()
            finalizeBagAfterDrop(wpIndex, bagIndex)
        end,
        nil, nil, 7.0  -- maxDistance override: camion lung, default 2m e insuficient
    )

    notify('info', Sw.T('garbage.title_toss_bag'), Sw.T('garbage.toss_bag_instruction'))
end

local function onBagCollect(wpIndex, bagIndex)
    if isCollecting then return end
    if carryState then return end
    if not activeSession then return end
    if activeSession.collectedSet[wpIndex] then return end

    local bags = bagData[wpIndex]
    if not bags then return end
    local bag = bags[bagIndex]
    if not bag or bag.done then return end

    isCollecting = true

    if bag.proxId then
        exports.proximity:RemoveInteraction(bag.proxId)
        bag.proxId = nil
    end

    SendNUIMessage({ action = 'startCollecting', duration = bag.collectTime })

    CreateThread(function()
        playPickupAnimation(bag.collectTime, function() end)
        startCarryAndDropoff(wpIndex, bagIndex, bag)
    end)
end

local function spawnBagsForWaypoint(wpIndex, wp)
    local bagCount = math.random(1, 4)
    bagData[wpIndex] = {}

    for i = 1, bagCount do
        local isHeavy     = math.random(100) <= 10
        local baseTime    = math.random(700, 2000)
        local collectTime = isHeavy and (baseTime * 3) or baseTime
        local radius      = 1.0 + math.random() * 1.5
        local angle       = math.rad(math.random(0, 359))
        local bx          = wp.x + math.cos(angle) * radius
        local by          = wp.y + math.sin(angle) * radius

        -- Forteaza incarcarea coliziunilor pentru ground Z fiabil
        RequestCollisionAtCoord(bx, by, wp.z)
        local groundZ = wp.z
        local foundGround = false
        for _ = 1, 12 do
            local ok, gz = GetGroundZFor_3dCoord_2(bx, by, wp.z + 5.0, false)
            if ok then groundZ = gz; foundGround = true; break end
            Wait(50)
        end

        local modelName = BAG_MODELS[math.random(#BAG_MODELS)]
        local model     = GetHashKey(modelName)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) do
            Wait(50); t = t + 50
            if t > 5000 then break end
        end

        if not HasModelLoaded(model) then
            SetModelAsNoLongerNeeded(model)
            -- Marcat done ca sa nu blocheze ruta daca modelul nu a putut fi incarcat
            bagData[wpIndex][i] = { prop = nil, proxId = nil, done = true, collectTime = collectTime }
        else
            local spawnZ = (foundGround and groundZ or wp.z) + 0.5
            local prop = CreateObject(model, bx, by, spawnZ, false, false, false)
            SetModelAsNoLongerNeeded(model)

            if DoesEntityExist(prop) then
                SetEntityAsMissionEntity(prop, true, true)
                Wait(50)
                PlaceObjectOnGroundProperly(prop)

                -- Daca dupa Place e tot sub sol, forteaza Z-ul calculat
                local pc = GetEntityCoords(prop)
                if foundGround and pc.z < groundZ - 0.2 then
                    SetEntityCoords(prop, bx, by, groundZ + 0.05, false, false, false, true)
                end

                FreezeEntityPosition(prop, true)

                local capturedWp  = wpIndex
                local capturedBag = i
                local label       = isHeavy
                    and Sw.T('garbage.bag_heavy', i, bagCount)
                    or  Sw.T('garbage.bag_light', i, bagCount)

                local proxId = exports.proximity:AddEntityInteraction(
                    prop,
                    label,
                    'default',
                    {},
                    function() onBagCollect(capturedWp, capturedBag) end
                )

                bagData[wpIndex][i] = {
                    prop        = prop,
                    proxId      = proxId,
                    done        = false,
                    collectTime = collectTime,
                    isHeavy     = isHeavy,
                }
            else
                bagData[wpIndex][i] = { prop = nil, proxId = nil, done = true, collectTime = collectTime }
            end
        end
    end
end

local function clearAllBags()
    for _, bags in pairs(bagData) do
        for _, bag in ipairs(bags) do
            if bag.proxId then
                exports.proximity:RemoveInteraction(bag.proxId)
            end
            if bag.prop and DoesEntityExist(bag.prop) then
                SetEntityAsMissionEntity(bag.prop, false, true)
                DeleteObject(bag.prop)
            end
        end
    end
    bagData = {}
end

local function clearWaypointProximities()
    for _, id in pairs(waypointProxIds) do
        exports.proximity:RemoveInteraction(id)
    end
    waypointProxIds = {}
end

local function createMissionBlip(coords, sprite, color, scale, label, asShortRange)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, color)
    SetBlipScale(b, scale)
    SetBlipAsShortRange(b, asShortRange == true)
    SetBlipAsMissionCreatorBlip(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(b)
    return b
end

local function clearAllBlips()
    for i, b in pairs(waypointBlips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
        waypointBlips[i] = nil
    end
    if depotReturnBlip and DoesBlipExist(depotReturnBlip) then
        RemoveBlip(depotReturnBlip)
    end
    depotReturnBlip  = nil
    currentRouteBlip = nil
end

local function spawnAllBlips()
    if not activeSession then return end
    for i, wp in ipairs(activeSession.route.waypoints) do
        if not activeSession.collectedSet[i] and not waypointBlips[i] then
            waypointBlips[i] = createMissionBlip(
                vector3(wp.x, wp.y, wp.z),
                318, 5, 0.9,
                Sw.T('garbage.container_blip', i),
                false
            )
        end
    end
end

function setNextWaypointGPS()
    if not activeSession then return end

    if currentRouteBlip and DoesBlipExist(currentRouteBlip) then
        SetBlipRoute(currentRouteBlip, false)
    end
    currentRouteBlip = nil

    for i = 1, #activeSession.route.waypoints do
        if not activeSession.collectedSet[i] then
            if depotReturnBlip and DoesBlipExist(depotReturnBlip) then
                RemoveBlip(depotReturnBlip)
                depotReturnBlip = nil
            end
            local b = waypointBlips[i]
            if b and DoesBlipExist(b) then
                SetBlipRoute(b, true)
                SetBlipRouteColour(b, 5)
                currentRouteBlip = b
            end
            return
        end
    end

    local c = Config.HiringCoords
    if not depotReturnBlip or not DoesBlipExist(depotReturnBlip) then
        depotReturnBlip = createMissionBlip(
            vector3(c.x, c.y, c.z),
            318, 2, 1.0,
            Sw.T('garbage.prox_return_depot'),
            false
        )
    end
    SetBlipRoute(depotReturnBlip, true)
    SetBlipRouteColour(depotReturnBlip, 5)
    currentRouteBlip = depotReturnBlip
end

local function spawnAllBags()
    if not activeSession then return end
    local route = activeSession.route
    for i, wp in ipairs(route.waypoints) do
        if not activeSession.collectedSet[i] then
            spawnBagsForWaypoint(i, wp)
            Wait(50)
        end
    end
end

AddEventHandler('garbage:route:start', function(data)
    activeSession = {
        sessionId    = data.sessionId,
        route        = data.route,
        collectedSet = {},
    }

    spawnGarbageTruck(function(vehicle)
        spawnedVehicle = vehicle

        CreateThread(function()
            spawnAllBags()
            spawnAllBlips()
            setNextWaypointGPS()

            local totalBags = 0
            for _, bags in pairs(bagData) do
                totalBags = totalBags + #bags
            end

            notify('info', Sw.T('garbage.title_route_start', data.route.name),
                Sw.T('garbage.route_start_detail', #data.route.waypoints, totalBags))
        end)
    end)
end)

AddEventHandler('garbage:route:pointConfirmed', function(data)
    SendNUIMessage({
        action    = 'updateProgress',
        collected = data.collected,
        total     = data.total,
    })

    local remaining = data.total - data.collected
    if remaining > 0 then
        notify('success', Sw.T('garbage.title_container_collected'),
            Sw.T('garbage.container_collected_detail', data.collected, data.total, remaining))
    else
        notify('success', Sw.T('garbage.title_all_collected'),
            Sw.T('garbage.return_to_depot'))
    end
end)

local completingRoute = false
AddEventHandler('garbage:route:returnedToDepot', function()
    if not activeSession then return end
    if completingRoute then return end
    completingRoute = true
    TriggerServerEvent('garbage:server:completeRoute', activeSession.sessionId)
end)

local function revokeTruckKey()
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        local plate = GetVehicleNumberPlateText(spawnedVehicle):gsub('%s+', '')
        pcall(function() exports.vehicles:RevokeTempKey(plate) end)
    end
end

AddEventHandler('garbage:route:cleanup', function()
    completingRoute = false
    isCollecting = false
    clearCarryState()
    clearWaypointProximities()
    clearAllBags()
    clearAllBlips()
    SendNUIMessage({ action = 'stopCollecting' })

    revokeTruckKey()
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        DeleteVehicle(spawnedVehicle)
        spawnedVehicle = nil
    end

    activeSession = nil
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    clearCarryState()
    clearWaypointProximities()
    clearAllBags()
    clearAllBlips()
    revokeTruckKey()
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        DeleteVehicle(spawnedVehicle)
    end
end)
