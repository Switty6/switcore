activeInjuries = {}

local lastHealth   = 200
local limpActive   = false
local injuryTimers = {}

local GUN_ZONE_MAP = {
    leg_left  = { 'gunshot_leg',   'left_leg'  },
    leg_right = { 'gunshot_leg',   'right_leg' },
    spine     = { 'gunshot_chest', 'chest'     },
}

RegisterNetEvent('medical:client:syncInjuries')
AddEventHandler('medical:client:syncInjuries', function(injuries)
    activeInjuries = injuries or {}
    ApplyInjuryEffects()
end)

RegisterNetEvent('medical:client:triggerRagdoll')
AddEventHandler('medical:client:triggerRagdoll', function(durationMs)
    local ped = PlayerPedId()
    if not IsPedRagdoll(ped) then
        SetPedToRagdoll(ped, durationMs, durationMs, 0, false, false, false)
    end
end)

local function GetBoneZone(bone)
    for zone, bones in pairs(Config.BoneZones) do
        for _, b in ipairs(bones) do
            if b == bone then return zone end
        end
    end
    return 'generic'
end

local function ClassifyInjury(ped, bone)
    local zone    = GetBoneZone(bone)
    local isGun   = HasEntityBeenDamagedByWeapon(ped, 0, Config.WeaponCategories.gun)
    local isBlunt = HasEntityBeenDamagedByWeapon(ped, 0, Config.WeaponCategories.blunt)
    local isBlade = HasEntityBeenDamagedByWeapon(ped, 0, Config.WeaponCategories.blade)
    ClearEntityLastDamageEntity(ped)

    if isGun then
        local mapped = GUN_ZONE_MAP[zone]
        if mapped then return mapped[1], mapped[2] end
        return 'gunshot_leg', 'arm'
    elseif isBlade then
        return 'stab', zone
    elseif isBlunt then
        if math.random() <= 0.40 then
            return 'broken_bone', zone
        else
            return 'bruise', zone
        end
    end

    return nil, nil
end

local function CalculateSeverity(hpLost)
    if hpLost >= 30 then return 3 end
    if hpLost >= 15 then return 2 end
    return 1
end

function ApplyInjuryEffects()
    if not Config.InjuryEffects then return end

    local hasLimp = false
    for _, inj in ipairs(activeInjuries) do
        if inj.type == 'gunshot_leg' then hasLimp = true; break end
    end

    local ped = PlayerPedId()
    if hasLimp and not limpActive then
        RequestAnimSet(Config.InjuryEffects.gunshot_leg.movementClipset)
        local timeout = 0
        while not HasAnimSetLoaded(Config.InjuryEffects.gunshot_leg.movementClipset) and timeout < 50 do
            Wait(50); timeout = timeout + 1
        end
        SetPedMovementClipset(ped, Config.InjuryEffects.gunshot_leg.movementClipset, 1.0)
        limpActive = true
    elseif not hasLimp and limpActive then
        ResetPedMovementClipset(ped, 1.0)
        limpActive = false
    end
end

CreateThread(function()
    while true do
        Wait(1000)

        if #activeInjuries == 0 then goto cont end
        if not Config.InjuryEffects then goto cont end

        local now    = GetGameTimer()
        local ped    = PlayerPedId()
        local player = PlayerId()

        local hasBrokenBone = false
        local hasBruise     = false
        local hasStab       = false

        for _, inj in ipairs(activeInjuries) do
            if inj.type == 'broken_bone' then hasBrokenBone = true end
            if inj.type == 'bruise'      then hasBruise     = true end
            if inj.type == 'stab'        then hasStab       = true end
        end

        if hasBrokenBone and not IsPainSuppressed() then
            local ef = Config.InjuryEffects.broken_bone
            SetPlayerSprintStaminaRemaining(player, ef.staminaValue)
            if not injuryTimers.bone_pain or (now - injuryTimers.bone_pain) >= ef.painInterval * 1000 then
                injuryTimers.bone_pain = now
                CreateThread(function()
                    AnimpostfxPlay(ef.screenEffect, 0, false)
                    Wait(1500)
                    AnimpostfxStop(ef.screenEffect)
                end)
            end
        end

        if hasBruise and not IsPainSuppressed() then
            local ef = Config.InjuryEffects.bruise
            if IsPedSprinting(ped) then
                if not injuryTimers.bruise_fx or (now - injuryTimers.bruise_fx) >= ef.painInterval * 1000 then
                    injuryTimers.bruise_fx = now
                    CreateThread(function()
                        AnimpostfxPlay(ef.screenEffect, 0, false)
                        Wait(1500)
                        AnimpostfxStop(ef.screenEffect)
                    end)
                end
            end
        end

        if hasStab and not IsPainSuppressed() then
            local ef = Config.InjuryEffects.stab
            if not injuryTimers.stab_fx or (now - injuryTimers.stab_fx) >= ef.screenInterval * 1000 then
                injuryTimers.stab_fx = now
                CreateThread(function()
                    AnimpostfxPlay(ef.screenEffect, 0, false)
                    Wait(1200)
                    AnimpostfxStop(ef.screenEffect)
                end)
            end
        end

        ::cont::
    end
end)

CreateThread(function()
    Wait(3000)

    lastHealth = GetEntityHealth(PlayerPedId())

    while true do
        Wait(100)

        local ped           = PlayerPedId()
        local currentHealth = GetEntityHealth(ped)

        if currentHealth < lastHealth and currentHealth > 100 then
            local hpLost            = lastHealth - currentHealth
            local bone              = GetPedLastDamageBone(ped)
            local injType, location = ClassifyInjury(ped, bone)

            if injType then
                TriggerServerEvent('medical:server:playerInjured', {
                    injuryType = injType,
                    location   = location,
                    severity   = CalculateSeverity(hpLost),
                })
            end
        end

        lastHealth = currentHealth
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 1.0)
    AnimpostfxStopAll()
end)
