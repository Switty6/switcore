local function GetCharId(source)
    return exports.characters:getCharacterId(source)
end

local function Notify(source, ntype, msg, dur)
    TriggerClientEvent('switcore:notify', source, ntype, msg, dur or 3000)
end

local function CheckCooldown(charId, itemName, cooldownSec)
    local lastUseTs = MedicalDB.getLastMedicationUse(charId, itemName)
    if lastUseTs then
        local elapsed = os.time() - lastUseTs
        if elapsed < cooldownSec then
            return false, cooldownSec - elapsed
        end
    end
    return true, 0
end

local function RegisterMedication(itemName, handler)
    exports.inventory:RegisterUsableItem(itemName, function(source)
        local charId = GetCharId(source)
        if not charId then return end
        handler(source, charId)
    end)
end

local function RegisterDiseaseReducer(itemName, condType)
    RegisterMedication(itemName, function(src, charId)
        local cfg = Config.Medications[itemName]
        local ok, remaining = CheckCooldown(charId, itemName, cfg.cooldown)
        if not ok then Notify(src, 'warning', Sw.TP(src, 'medical.medication_cooldown', remaining)); return end

        local conditions = GetCharacterConditions(src)
        local affected   = false

        for condName, condData in pairs(conditions) do
            local condCfg = Config.Conditions[condName]
            if condCfg and condCfg.type == condType then
                local oldStage = condData.stage
                local newStage = math.max(1, oldStage - cfg.stageReduction)
                condData.stage          = newStage
                condData.lastProgressed = os.time()
                MedicalDB.updateConditionStage(charId, condName, newStage)
                MedicalDB.logMedication(charId, itemName, oldStage, newStage, condName)
                affected = true
            end
        end

        if affected then
            SyncConditionsToClient(src)
            Notify(src, 'success', cfg.message)
        else
            Notify(src, 'warning', cfg.noCondMsg)
        end
    end)
end

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    while not exports.settings:IsReady()  do Wait(100) end

    for _, name in ipairs({ 'aspirin', 'paracetamol', 'cough_syrup', 'antiemetic' }) do
        RegisterMedication(name, function(src, charId)
            local cfg = Config.Medications[name]
            local ok, remaining = CheckCooldown(charId, name, cfg.cooldown)
            if not ok then Notify(src, 'warning', Sw.TP(src, 'medical.medication_cooldown', remaining)); return end
            SuppressSymptom(src, cfg.treatsSymptom, cfg.suppressDuration)
            MedicalDB.logMedication(charId, name, nil, nil, nil)
            Notify(src, 'success', cfg.message)
        end)
    end

    RegisterDiseaseReducer('antibiotics', 'bacteria')
    RegisterDiseaseReducer('antivirals',  'virus')

    RegisterMedication('vitamins', function(src, charId)
        local cfg = Config.Medications.vitamins
        local ok, remaining = CheckCooldown(charId, 'vitamins', cfg.cooldown)
        if not ok then Notify(src, 'warning', Sw.TP(src, 'medical.medication_cooldown', remaining)); return end
        SetImmunity(src, cfg.immunityDuration)
        MedicalDB.logMedication(charId, 'vitamins', nil, nil, nil)
        Notify(src, 'success', cfg.message)
    end)

    RegisterMedication('bandage', function(src, charId)
        local cfg = Config.Medications.bandage
        local ok, remaining = CheckCooldown(charId, 'bandage', cfg.cooldown)
        if not ok then Notify(src, 'warning', Sw.TP(src, 'medical.medication_cooldown', remaining)); return end
        SuppressSymptom(src, 'bleeding', cfg.suppressDuration)
        SuppressInjuryBleeding(src, cfg.injuryBleedSupress)
        MedicalDB.logMedication(charId, 'bandage', nil, nil, nil)
        Notify(src, 'success', cfg.message)
    end)

    RegisterMedication('surgical_mask', function(src, charId)
        TriggerClientEvent('medical:client:equipMask', src)
        MedicalDB.logMedication(charId, 'surgical_mask', nil, nil, nil)
    end)

    RegisterMedication('splint', function(src, charId)
        local cfg = Config.Medications.splint
        local ok, remaining = CheckCooldown(charId, 'splint', cfg.cooldown)
        if not ok then Notify(src, 'warning', Sw.TP(src, 'medical.medication_cooldown', remaining)); return end
        local reduced = ReduceInjurySeverity(src, 'broken_bone')
        if reduced then
            MedicalDB.logMedication(charId, 'splint', nil, nil, 'broken_bone')
            Notify(src, 'success', cfg.message)
        else
            Notify(src, 'warning', cfg.noInjMsg)
        end
    end)

    RegisterMedication('morphine', function(src, charId)
        local cfg = Config.Medications.morphine
        local ok, remaining = CheckCooldown(charId, 'morphine', cfg.cooldown)
        if not ok then Notify(src, 'warning', Sw.TP(src, 'medical.medication_cooldown', remaining)); return end
        SuppressInjuryBleeding(src, cfg.injuryBleedSupress)
        SuppressSymptom(src, 'bleeding', cfg.suppressDuration)
        TriggerClientEvent('medical:client:suppressPain', src, cfg.suppressDuration)
        MedicalDB.logMedication(charId, 'morphine', nil, nil, nil)
        Notify(src, 'success', cfg.message)
    end)

    print('[MEDICAL] Medicamente inregistrate.')
end)
