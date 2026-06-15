-- IMPORTANT: PRIMUL server_script in fxmanifest - alte module se bazeaza pe Config global.
exports.core:registerModuleLocales(GetCurrentResourceName())

Config = {}

local function FixKeys(t)
    if type(t) ~= 'table' then return t end
    local result = {}
    for k, v in pairs(t) do
        local nk = tonumber(k) or k
        result[nk] = FixKeys(v)
    end
    return result
end

-- Aplicate sincron la load: alte module pot citi Config inainte ca settings DB sa fie gata.
local function ApplyDefaults()
    Config.SneezeTransmissionRadius  = 5.0
    Config.MaskProtectionMultiplier  = 0.10
    Config.VitaminImmunityMultiplier = 0.50
    Config.VitaminEffectDuration     = 3600
    Config.ProgressionLoopInterval   = 300

    Config.SevereDamagePerTick    = 2
    Config.SevereDamageInterval   = 30
    Config.CriticalDamagePerTick  = 5
    Config.CriticalDamageInterval = 15
    Config.InjuryBleedLoopInterval = 5

    Config.StageProgressionTime = { [1]=600, [2]=900, [3]=1200, [4]=1800 }
    Config.StageLabels          = { [1]='Incubatie', [2]='Usoara', [3]='Moderata', [4]='Severa', [5]='Critica' }

    Config.Conditions = {
        common_cold = {
            label='Raceala Comuna', type='virus', contagious=true, baseChance=0.20,
            symptoms={
                [2]={'sneezing','cough'},
                [3]={'sneezing','cough','headache','fever'},
                [4]={'sneezing','cough','headache','fever','weakness'},
                [5]={'sneezing','cough','headache','fever','weakness'},
            },
        },
        influenza = {
            label='Gripa', type='virus', contagious=true, baseChance=0.25,
            symptoms={
                [2]={'fever','chills','cough','sneezing','headache'},
                [3]={'fever','chills','cough','sneezing','headache','weakness'},
                [4]={'fever','chills','cough','headache','weakness','nausea'},
                [5]={'fever','chills','cough','headache','weakness','nausea','chest_pain'},
            },
        },
        covid_like = {
            label='Virus Respirator XB1', type='virus', contagious=true, baseChance=0.30,
            symptoms={
                [2]={'fever','cough','weakness','sneezing'},
                [3]={'fever','cough','weakness','sneezing','headache'},
                [4]={'fever','cough','weakness','headache','chest_pain','nausea'},
                [5]={'fever','cough','weakness','headache','chest_pain','nausea','bleeding'},
            },
        },
        salmonella = {
            label='Salmoneloza', type='bacteria', contagious=false, baseChance=0.05,
            symptoms={
                [2]={'nausea'},
                [3]={'nausea','vomiting','weakness'},
                [4]={'nausea','vomiting','weakness','fever'},
                [5]={'nausea','vomiting','weakness','fever','bleeding'},
            },
        },
        food_poisoning = {
            label='Toxiinfectie Alimentara', type='bacteria', contagious=false, baseChance=0.0,
            symptoms={
                [1]={'nausea'},
                [2]={'nausea','vomiting'},
                [3]={'nausea','vomiting','weakness'},
                [4]={'nausea','vomiting','weakness','fever'},
                [5]={'nausea','vomiting','weakness','fever'},
            },
        },
    }

    Config.SymptomEffects = {
        fever      = { timecycle='heat_exhaustion', timecycleStrength=0.3, screenEffect='DrugsMichaelAliensFight', screenStrength=0.2, intervalSeconds=120 },
        nausea     = { screenEffect='DrugsMichaelAliensFight', screenStrength=0.4, screenDuration=3000, intervalSeconds=60 },
        weakness   = { staminaValue=30.0 },
        bleeding   = { screenEffect='DeathFailOut', screenDuration=1500, intervalSeconds=15 },
        headache   = { screenEffect='SwitchHUDIn', screenStrength=0.15, screenDuration=1500, intervalSeconds=90 },
        cough      = { animDict='mp_common_ambient', animName='amb_rest_inhale', duration=3000, intervalSeconds=45 },
        sneezing   = { animDict='mp_common_ambient', animName='amb_rest_inhale', duration=2500, intervalSeconds=30 },
        vomiting   = { animDict='mp_arresting', animName='a_uncuff', duration=4000, intervalSeconds=90 },
        chills     = { timecycle='damage', timecycleStrength=0.2 },
        chest_pain = { screenEffect='DeathFailOut', screenStrength=0.25, screenDuration=2000, intervalSeconds=120 },
    }

    Config.Medications = {
        aspirin      = { treatsSymptom='fever',    suppressDuration=600, cooldown=60,   message='Ai luat o aspirina. Febra se reduce.' },
        paracetamol  = { treatsSymptom='headache', suppressDuration=600, cooldown=60,   message='Ai luat paracetamol. Durerea de cap se amelioreaza.' },
        antibiotics  = { treatsType='bacteria', stageReduction=1, cooldown=3600, message='Ai luat antibiotice. Infectia bacteriana cedeaza.', noCondMsg='Nu ai nicio infectie bacteriana activa.' },
        antivirals   = { treatsType='virus',    stageReduction=1, cooldown=7200, message='Ai luat antivirale. Virusul pierde teren.',           noCondMsg='Nu ai nicio infectie virala activa.' },
        cough_syrup  = { treatsSymptom='cough',   suppressDuration=900, cooldown=120,  message='Ai luat sirop de tuse. Tusea se calmeaza.' },
        vitamins     = { immunityBoost=true, immunityDuration=3600, cooldown=3600, message='Ai luat vitamine. Sistemul imunitar este mai rezistent.' },
        bandage      = { treatsSymptom='bleeding', suppressDuration=600, cooldown=30, injuryBleedSupress=600, message='Ai aplicat un bandaj. Sangerarea s-a oprit.' },
        antiemetic   = { treatsSymptom='nausea',   suppressDuration=600, cooldown=60,   message='Ai luat un antiemetic. Greata s-a redus.' },
        surgical_mask = { message='Masca a fost echipata/scoasa.' },
        splint       = { treatsInjury='broken_bone', cooldown=60, message='Ai aplicat atela. Durerea s-a redus.', noInjMsg='Nu ai niciun os rupt activ.' },
        morphine     = { suppressAllPain=true, suppressDuration=300, injuryBleedSupress=300, cooldown=1800, message='Ai administrat morfina. Durerea dispare.' },
    }

    Config.WeaponCategories = { gun=2, blunt=3, blade=4 }

    Config.BoneZones = {
        leg_left  = { 36864, 40269, 63931 },
        leg_right = { 51826, 57597, 14201 },
        spine     = { 24818, 24819, 24820, 24821, 11816 },
        arm_left  = { 61163, 2108,  58271 },
        arm_right = { 28252, 43017, 61163 },
    }

    Config.InjuryEffects = {
        gunshot_leg   = { movementClipset='move_m@injured@', bleedingPerTick=3, bleedInterval=8 },
        gunshot_chest = { ragdollOnHit=true, ragdollDuration=2000, bleedingPerTick=5, bleedInterval=6, requiresNoArmor=true },
        bruise        = { screenEffect='DrugsMichaelAliensFight', onSprint=true, painInterval=45 },
        broken_bone   = { staminaValue=20.0, screenEffect='DeathFailOut', painInterval=30 },
        stab          = { bleedingPerTick=4, bleedInterval=7, screenEffect='DeathFailOut', screenInterval=10 },
    }
end

ApplyDefaults()

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    while not exports.settings:IsReady()  do Wait(100) end

    local S = exports.settings

    Config.SneezeTransmissionRadius  = S:GetSettingNumber('medical.sneeze_radius',              Config.SneezeTransmissionRadius)
    Config.MaskProtectionMultiplier  = S:GetSettingNumber('medical.mask_protection',            Config.MaskProtectionMultiplier)
    Config.VitaminImmunityMultiplier = S:GetSettingNumber('medical.vitamin_immunity_multiplier',Config.VitaminImmunityMultiplier)
    Config.VitaminEffectDuration     = S:GetSettingNumber('medical.vitamin_effect_duration',    Config.VitaminEffectDuration)
    Config.ProgressionLoopInterval   = S:GetSettingNumber('medical.progression_interval',       Config.ProgressionLoopInterval)
    Config.SevereDamagePerTick       = S:GetSettingNumber('medical.severe_damage_per_tick',     Config.SevereDamagePerTick)
    Config.SevereDamageInterval      = S:GetSettingNumber('medical.severe_damage_interval',     Config.SevereDamageInterval)
    Config.CriticalDamagePerTick     = S:GetSettingNumber('medical.critical_damage_per_tick',   Config.CriticalDamagePerTick)
    Config.CriticalDamageInterval    = S:GetSettingNumber('medical.critical_damage_interval',   Config.CriticalDamageInterval)
    Config.InjuryBleedLoopInterval   = S:GetSettingNumber('medical.injury_bleed_loop_interval', Config.InjuryBleedLoopInterval)

    -- JSON decodifica cheile numerice ca string-uri; FixKeys le converteste inapoi la int
    local stageTime = S:GetSettingJSON('medical.stage_progression_time', nil)
    if stageTime then Config.StageProgressionTime = FixKeys(stageTime) end

    local stageLabels = S:GetSettingJSON('medical.stage_labels', nil)
    if stageLabels then Config.StageLabels = FixKeys(stageLabels) end

    local conditions = S:GetSettingJSON('medical.conditions', nil)
    if conditions then
        for _, cond in pairs(conditions) do
            if cond.symptoms then
                cond.symptoms = FixKeys(cond.symptoms)
            end
        end
        Config.Conditions = conditions
    end

    local symptomEffects = S:GetSettingJSON('medical.symptom_effects', nil)
    if symptomEffects then Config.SymptomEffects = symptomEffects end

    local medications = S:GetSettingJSON('medical.medications', nil)
    if medications then Config.Medications = medications end

    local weaponCats = S:GetSettingJSON('medical.weapon_categories', nil)
    if weaponCats then Config.WeaponCategories = weaponCats end

    local boneZones = S:GetSettingJSON('medical.bone_zones', nil)
    if boneZones then Config.BoneZones = boneZones end

    local injEffects = S:GetSettingJSON('medical.injury_effects', nil)
    if injEffects then Config.InjuryEffects = injEffects end

    print('[MEDICAL] Config incarcat din settings DB.')
end)

local function SendConfigToClient(src)
    TriggerClientEvent('medical:client:config', src, Config)
end

AddEventHandler('switcore:characterSelected', function(src, characterId)
    CreateThread(function()
        while not exports.settings:IsReady() do Wait(100) end
        SendConfigToClient(src)
    end)
end)
