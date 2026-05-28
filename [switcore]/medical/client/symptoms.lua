MedicalSymptoms = {}

local symptomTimers = {}

local function TimerReady(key, intervalSec)
    local now = os.clock()
    if not symptomTimers[key] or (now - symptomTimers[key]) >= intervalSec then
        symptomTimers[key] = now
        return true
    end
    return false
end

local function PlayScreenEffect(effectName, durationMs)
    if not effectName then return end
    CreateThread(function()
        AnimpostfxPlay(effectName, 0, false)
        Wait(durationMs or 1500)
        AnimpostfxStop(effectName)
    end)
end

local function PlayAnimation(animDict, animName, durationMs)
    CreateThread(function()
        local ped = PlayerPedId()
        RequestAnimDict(animDict)
        local timeout = 0
        while not HasAnimDictLoaded(animDict) and timeout < 50 do
            Wait(50); timeout = timeout + 1
        end
        if not HasAnimDictLoaded(animDict) then return end
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, durationMs, 0, 0.0, false, false, false)
        Wait(durationMs)
        ClearPedTasks(ped)
    end)
end

function MedicalSymptoms.Tick(symptoms, conditions)
    local symSet = {}
    for _, s in ipairs(symptoms) do symSet[s] = true end

    if symSet['fever'] then
        local ef = Config.SymptomEffects.fever
        SetTimecycleModifier(ef.timecycle)
        SetTimecycleModifierStrength(ef.timecycleStrength)
        if TimerReady('fever_fx', ef.intervalSeconds) then
            PlayScreenEffect(ef.screenEffect, 800)
        end
    elseif not symSet['chills'] then
        ClearTimecycleModifier()
    end

    if symSet['chills'] then
        local ef = Config.SymptomEffects.chills
        SetTimecycleModifier(ef.timecycle)
        SetTimecycleModifierStrength(ef.timecycleStrength)
    end

    if symSet['weakness'] then
        SetPlayerSprintStaminaRemaining(PlayerId(), Config.SymptomEffects.weakness.staminaValue)
    end

    if symSet['nausea'] and not IsPainSuppressed() then
        local ef = Config.SymptomEffects.nausea
        if TimerReady('nausea_fx', ef.intervalSeconds) then
            PlayScreenEffect(ef.screenEffect, ef.screenDuration)
        end
    end

    if symSet['headache'] and not IsPainSuppressed() then
        local ef = Config.SymptomEffects.headache
        if TimerReady('headache_fx', ef.intervalSeconds) then
            PlayScreenEffect(ef.screenEffect, ef.screenDuration)
        end
    end

    if symSet['chest_pain'] and not IsPainSuppressed() then
        local ef = Config.SymptomEffects.chest_pain
        if TimerReady('chest_pain_fx', ef.intervalSeconds) then
            PlayScreenEffect(ef.screenEffect, ef.screenDuration)
        end
    end

    if symSet['bleeding'] then
        local ef = Config.SymptomEffects.bleeding
        if TimerReady('bleeding_fx', ef.intervalSeconds) then
            PlayScreenEffect(ef.screenEffect, ef.screenDuration)
        end
    end

    if symSet['vomiting'] then
        local ef = Config.SymptomEffects.vomiting
        if TimerReady('vomiting_anim', ef.intervalSeconds) then
            PlayAnimation(ef.animDict, ef.animName, ef.duration)
        end
    end

end
