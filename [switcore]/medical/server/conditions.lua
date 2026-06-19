local playerConditions = {}
local playerImmunity = {}

local function Notify(source, ntype, msg, dur)
    TriggerClientEvent('switcore:notify', source, ntype, msg, dur or 4000)
end

local function BuildSymptomList(source)
    local data = playerConditions[source]
    if not data then return {} end

    local now = os.time()
    local symSet = {}

    for condName, condData in pairs(data.conditions) do
        local cfg = Config.Conditions[condName]
        if not cfg then goto continue end

        local stageSymptoms = cfg.symptoms[condData.stage] or {}
        for _, sym in ipairs(stageSymptoms) do
            local suppressedUntil = condData.suppressedSymptoms[sym]
            if not suppressedUntil or suppressedUntil <= now then
                symSet[sym] = true
            end
        end

        ::continue::
    end

    local result = {}
    for sym in pairs(symSet) do result[#result + 1] = sym end
    return result
end

local function SyncToClient(source)
    local data = playerConditions[source]
    if not data then return end

    local condPayload = {}
    for condName, condData in pairs(data.conditions) do
        local cfg = Config.Conditions[condName]
        condPayload[condName] = {
            stage = condData.stage,
            label = cfg and cfg.label or condName,
        }
    end

    TriggerClientEvent('medical:client:syncConditions', source, {
        conditions = condPayload,
        symptoms   = BuildSymptomList(source),
    })
end

function GetActiveSymptoms(source)
    return BuildSymptomList(source)
end

function LoadPlayerConditions(source, characterId)
    playerConditions[source] = { characterId = characterId, conditions = {} }

    local rows = MedicalDB.getCharacterConditions(characterId)
    for _, row in ipairs(rows) do
        playerConditions[source].conditions[row.condition_name] = {
            stage              = row.current_stage,
            lastProgressed     = os.time(),
            suppressedSymptoms = {},
        }
    end

    SyncToClient(source)
end

function InfectCharacter(source, conditionName)
    local cfg = Config.Conditions[conditionName]
    if not cfg then return false end

    local data = playerConditions[source]
    if not data then return false end
    if data.conditions[conditionName] then return false end

    MedicalDB.infectCharacter(data.characterId, conditionName)

    data.conditions[conditionName] = {
        stage              = 1,
        lastProgressed     = os.time(),
        suppressedSymptoms = {},
    }

    SyncToClient(source)
    Notify(source, 'error', Sw.TP(source, 'medical.condition_contracted', cfg.label), 5000)
    return true
end

function CureCharacter(source, conditionName)
    local data = playerConditions[source]
    if not data or not data.conditions[conditionName] then return false end

    MedicalDB.cureCondition(data.characterId, conditionName)
    data.conditions[conditionName] = nil
    SyncToClient(source)
    return true
end

function CureAll(source)
    local data = playerConditions[source]
    if not data then return end

    MedicalDB.cureAll(data.characterId)
    data.conditions = {}
    SyncToClient(source)
end

function SuppressSymptom(source, symptomName, durationSeconds)
    local data = playerConditions[source]
    if not data then return end

    local expiry = os.time() + durationSeconds
    for _, condData in pairs(data.conditions) do
        condData.suppressedSymptoms[symptomName] = expiry
    end
    SyncToClient(source)
end

function SetImmunity(source, durationSeconds)
    playerImmunity[source] = os.time() + durationSeconds
end

function IsImmune(source)
    return playerImmunity[source] ~= nil and playerImmunity[source] > os.time()
end

function HasCondition(source, conditionName)
    local data = playerConditions[source]
    return data ~= nil and data.conditions[conditionName] ~= nil
end

function GetCharacterConditions(source)
    local data = playerConditions[source]
    return data and data.conditions or {}
end

function GetPlayerConditionsData()
    return playerConditions
end

function SyncConditionsToClient(source)
    SyncToClient(source)
end

exports('GetCharacterConditions',   GetCharacterConditions)
exports('InfectCharacter',          InfectCharacter)
exports('CureCharacter',            CureCharacter)
exports('CureAll',                  CureAll)
exports('HasCondition',             HasCondition)
exports('GetActiveSymptoms',        GetActiveSymptoms)
exports('IsImmune',                 IsImmune)
exports('SuppressSymptom',          SuppressSymptom)
exports('SyncConditionsToClient',   SyncConditionsToClient)

AddEventHandler('switcore:characterSelected', function(source, characterId)
    LoadPlayerConditions(source, characterId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerConditions[src] = nil
    playerImmunity[src]   = nil
end)

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    while not exports.settings:IsReady()  do Wait(100) end

    while true do
        Wait(Config.ProgressionLoopInterval * 1000)

        for src, data in pairs(playerConditions) do
            local charId = data.characterId

            for condName, condData in pairs(data.conditions) do
                local stage = condData.stage
                if stage >= 5 then goto nextCond end

                local progressTime = Config.StageProgressionTime[stage]
                if not progressTime then goto nextCond end

                if (os.time() - condData.lastProgressed) >= progressTime then
                    local newStage = stage + 1
                    condData.stage          = newStage
                    condData.lastProgressed = os.time()

                    MedicalDB.updateConditionStage(charId, condName, newStage)
                    SyncToClient(src)

                    local cfg   = Config.Conditions[condName]
                    local label = cfg and cfg.label or condName
                    Notify(src, 'error', Sw.TP(src, 'medical.condition_stage', label, Config.StageLabels[newStage] or newStage), 6000)
                end

                ::nextCond::
            end
        end
    end
end)

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    Wait(8000)

    while true do
        Wait(Config.SevereDamageInterval * 1000)

        for src, data in pairs(playerConditions) do
            local symptoms    = BuildSymptomList(src)
            local hasBleed    = false
            local hasCritical = false

            for _, sym in ipairs(symptoms) do
                if sym == 'bleeding' then hasBleed = true end
            end
            for _, condData in pairs(data.conditions) do
                if condData.stage == 5 then hasCritical = true; break end
            end

            if hasBleed then
                TriggerClientEvent('medical:client:applyDamage', src, Config.SevereDamagePerTick)
            end
            if hasCritical then
                TriggerClientEvent('medical:client:applyDamage', src, Config.CriticalDamagePerTick)
            end
        end
    end
end)
