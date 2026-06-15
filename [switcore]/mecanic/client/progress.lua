local ServiceAnims = {
    inspect = {
        labelKey = 'mecanic.minigame.inspect',
        dict  = 'amb@world_human_car_park_attendant@male@idle_a',
        anim  = 'idle_c',
    },
    oil_change = {
        labelKey   = 'mecanic.minigame.oil_change',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    brakes = {
        labelKey   = 'mecanic.minigame.brakes',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    tire = {
        labelKey   = 'mecanic.minigame.tire',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    suspension = {
        labelKey   = 'mecanic.minigame.suspension',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    battery = {
        labelKey   = 'mecanic.minigame.battery',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    engine = {
        labelKey   = 'mecanic.minigame.engine',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    bodywork = {
        labelKey   = 'mecanic.minigame.bodywork',
        prop       = 'prop_tool_hammer',
        propBone   = 57005,
        propOffset = {x=0.06, y=0.03, z=-0.05},
        propRot    = {x=0.0,  y=0.0,  z=0.0},
        dict       = 'anim@amb@clubhouse@tools@hammer@',
        anim       = 'idle_a',
    },
    roadside_engine = {
        labelKey   = 'mecanic.minigame.roadside_engine',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    roadside_tire = {
        labelKey   = 'mecanic.minigame.roadside_tire',
        prop       = 'prop_tool_wrench',
        propBone   = 57005,
        propOffset = {x=0.13, y=0.05, z=0.0},
        propRot    = {x=10.0, y=160.0, z=0.0},
        dict       = 'mini@repair',
        anim       = 'fixing_a_ped',
    },
    roadside_battery = {
        labelKey = 'mecanic.minigame.roadside_battery',
        dict  = 'mini@repair',
        anim  = 'fixing_a_ped',
    },
    roadside_tow = {
        labelKey = 'mecanic.minigame.roadside_tow',
        dict  = 'mini@repair',
        anim  = 'fixing_a_ped',
    },
}

local MinigameCfg = {
    inspect          = { gameType='timing',    rounds=1, difficulty='easy'   },
    oil_change       = { gameType='timing',    rounds=3, difficulty='medium' },
    brakes           = { gameType='timing',    rounds=2, difficulty='medium' },
    tire             = { gameType='hammering', rounds=1, difficulty='medium' },
    suspension       = { gameType='sequence',  rounds=2, difficulty='hard'   },
    battery          = { gameType='timing',    rounds=2, difficulty='easy'   },
    engine           = { gameType='sequence',  rounds=2, difficulty='hard'   },
    bodywork         = { gameType='hammering', rounds=1, difficulty='hard'   },
    roadside_engine  = { gameType='sequence',  rounds=1, difficulty='medium' },
    roadside_tire    = { gameType='hammering', rounds=1, difficulty='easy'   },
    roadside_battery = { gameType='timing',    rounds=1, difficulty='easy'   },
    roadside_tow     = { gameType='timing',    rounds=1, difficulty='easy'   },
}

local activeMinigame = false
local minigameResult = nil

local function loadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) do
            Wait(50); t = t + 50
            if t > 5000 then return false end
        end
    end
    return true
end

local function spawnProp(propModel, ped, boneId, offset, rot)
    local hash = GetHashKey(propModel)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) do
        Wait(50); t = t + 50
        if t > 3000 then return nil end
    end
    local bone = GetPedBoneIndex(ped, boneId)
    local prop = CreateObject(hash, 0, 0, 0, true, true, false)
    AttachEntityToEntity(prop, ped, bone,
        offset.x, offset.y, offset.z,
        rot.x,    rot.y,    rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function faceToward(ped, vehicle)
    if not DoesEntityExist(vehicle) then return end
    local pp = GetEntityCoords(ped)
    local vp = GetEntityCoords(vehicle)
    local dx = vp.x - pp.x
    local dy = vp.y - pp.y
    local h  = math.deg(math.atan(dx, dy))
    if h < 0 then h = h + 360 end
    SetEntityHeading(ped, h)
end

local function loadPtfxAsset(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local t = 0
    while not HasNamedPtfxAssetLoaded(dict) do
        Wait(50); t = t + 50
        if t > 3000 then return false end
    end
    return true
end

local function startVehicleEffects(serviceType, vehicle)
    if not DoesEntityExist(vehicle) then return function() end end

    local handles     = {}
    local engineWasOn = false

    local function ptfx(dict, fx, ox, oy, oz, scale)
        if not loadPtfxAsset(dict) then return end
        local p = GetOffsetFromEntityInWorldCoords(vehicle, ox, oy, oz)
        UseParticleFxAssetNextCall(dict)
        local h = StartParticleFxLoopedAtCoord(fx, p.x, p.y, p.z, 0, 0, 0, scale, false, false, false, false)
        if h and h ~= -1 then table.insert(handles, h) end
    end

    if serviceType == 'inspect' then
        SetVehicleHazardLightsOn(vehicle, true)

    elseif serviceType == 'oil_change' then
        ptfx('core_mechanic', 'petrol_spray', 0.0, 0.3, -0.55, 0.35)

    elseif serviceType == 'brakes' then
        ptfx('core_mechanic', 'fix_sparks', 1.4, 0.6, 0.1, 0.25)

    elseif serviceType == 'tire' or serviceType == 'roadside_tire' then
        ptfx('cut_trevor1', 'cs_trev1_seq_smoke', 1.4, 0.6, 0.05, 0.3)

    elseif serviceType == 'suspension' then
        ptfx('core_mechanic', 'fix_sparks', 1.4, 0.2, 0.1, 0.25)

    elseif serviceType == 'battery' or serviceType == 'roadside_battery' then
        SetVehicleHazardLightsOn(vehicle, true)
        ptfx('core_mechanic', 'fix_sparks', 0.0, 2.0, 0.85, 0.2)

    elseif serviceType == 'engine' or serviceType == 'roadside_engine' then
        engineWasOn = GetIsVehicleEngineRunning(vehicle)
        SetVehicleEngineOn(vehicle, true, true, false)
        ptfx('core_mechanic',  'fix_sparks', 0.0,  2.0, 0.9,  0.55)
        ptfx('scr_recartheft', 'sparks',     0.35, 1.8, 0.85, 0.4)

    elseif serviceType == 'bodywork' then
        ptfx('scr_recartheft', 'sparks',     1.3, 0.0, 0.55, 0.5)
        ptfx('core_mechanic',  'fix_sparks', 1.1, 0.2, 0.45, 0.3)

    elseif serviceType == 'roadside_tow' then
        SetVehicleHazardLightsOn(vehicle, true)
    end

    return function()
        for _, h in ipairs(handles) do StopParticleFxLooped(h, false) end
        if not DoesEntityExist(vehicle) then return end
        SetVehicleHazardLightsOn(vehicle, false)
        if (serviceType == 'engine' or serviceType == 'roadside_engine') and not engineWasOn then
            SetVehicleEngineOn(vehicle, false, true, false)
        end
    end
end

function StartServiceMinigame(serviceType, vehicle, onComplete)
    if activeMinigame then
        TriggerEvent('notifications:client:send', {
            type='warning', title=Sw.T('mecanic.notify.busy_title'),
            message=Sw.T('mecanic.notify.busy_msg'), duration=3000
        })
        return
    end

    local animCfg = ServiceAnims[serviceType]
    if not animCfg then
        if onComplete then onComplete(true) end
        return
    end

    local mgCfg = MinigameCfg[serviceType] or { gameType='timing', rounds=1, difficulty='medium' }

    activeMinigame = true
    minigameResult = nil

    CreateThread(function()
        local ped = PlayerPedId()

        FreezeEntityPosition(ped, true)
        faceToward(ped, vehicle)

        local prop = nil
        if animCfg.prop then
            prop = spawnProp(animCfg.prop, ped, animCfg.propBone, animCfg.propOffset, animCfg.propRot)
        end

        if loadAnimDict(animCfg.dict) then
            TaskPlayAnim(ped, animCfg.dict, animCfg.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
        end

        local stopEffects = startVehicleEffects(serviceType, vehicle)

        SetNuiFocus(true, true)
        SendNUIMessage({
            action     = 'startMinigame',
            gameType   = mgCfg.gameType,
            rounds     = mgCfg.rounds,
            difficulty = mgCfg.difficulty,
            label      = animCfg.labelKey and Sw.T(animCfg.labelKey) or '',
        })

        while minigameResult == nil do Wait(100) end
        local success = (minigameResult == 'success')

        stopEffects()
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)

        if prop and DoesEntityExist(prop) then
            DetachEntity(prop, true, false)
            DeleteObject(prop)
        end

        activeMinigame = false
        minigameResult = nil

        if onComplete then onComplete(success) end
    end)
end

RegisterNUICallback('minigameResult', function(data, cb)
    minigameResult = data.result
    SetNuiFocus(false, false)
    cb('ok')
end)

function IsServiceInProgress()
    return activeMinigame
end
