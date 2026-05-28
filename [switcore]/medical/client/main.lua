activeConditions = {}
activeSymptoms = {}

local effectsRunning = false
local painSuppressedUntil = 0

-- Config-ul vine de la server prin event; pana atunci o tabela goala previne nil crash
Config = {}

RegisterNetEvent('medical:client:config')
AddEventHandler('medical:client:config', function(cfg)
    Config = cfg
    -- Injuries pot ajunge inainte de config; re-aplica efectele acum cand avem cfg
    if #activeInjuries > 0 then
        ApplyInjuryEffects()
    end
end)

RegisterNetEvent('medical:client:syncConditions')
AddEventHandler('medical:client:syncConditions', function(data)
    activeConditions = data.conditions or {}
    activeSymptoms   = data.symptoms   or {}

    if #activeSymptoms > 0 and not effectsRunning then
        StartEffectsLoop()
    elseif #activeSymptoms == 0 then
        StopAllEffects()
    end
end)

RegisterNetEvent('medical:client:applyDamage')
AddEventHandler('medical:client:applyDamage', function(amount)
    local ped     = PlayerPedId()
    local current = GetEntityHealth(ped)
    -- 100 = mort in GTA, oprim la 101 ca damage-ul medical sa nu omoare direct
    local newHP = math.max(101, current - (amount or 2))
    SetEntityHealth(ped, newHP)
end)

RegisterNetEvent('medical:client:equipMask')
AddEventHandler('medical:client:equipMask', function()
    local ped     = PlayerPedId()
    local current = GetPedDrawableVariation(ped, 1)
    if current > 0 then
        SetPedComponentVariation(ped, 1, 0, 0, 2)
        exports.notifications:Notify('info', 'Masca scoasa.', 3000)
    else
        SetPedComponentVariation(ped, 1, 1, 0, 2)
        exports.notifications:Notify('success', 'Masca echipata.', 3000)
    end
end)

RegisterNetEvent('medical:client:suppressPain')
AddEventHandler('medical:client:suppressPain', function(durationSec)
    painSuppressedUntil = GetGameTimer() + (durationSec * 1000)
end)

function IsPainSuppressed()
    return GetGameTimer() < painSuppressedUntil
end

function StartEffectsLoop()
    if effectsRunning then return end
    effectsRunning = true

    CreateThread(function()
        while effectsRunning do
            Wait(1000)
            if #activeSymptoms == 0 then
                StopAllEffects()
                effectsRunning = false
                break
            end
            MedicalSymptoms.Tick(activeSymptoms, activeConditions)
        end
    end)
end

function StopAllEffects()
    effectsRunning = false
    ClearTimecycleModifier()
    AnimpostfxStopAll()
    ResetPlayerStamina(PlayerId())
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    StopAllEffects()
    ResetPedMovementClipset(PlayerPedId(), 1.0)
end)
