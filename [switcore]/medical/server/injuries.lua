local playerInjuries = {}
local playerLastHP   = {}

local INJURY_LABELS = {
    gunshot_leg   = 'Impuscat in picior',
    gunshot_chest = 'Impuscat in piept',
    bruise        = 'Vanatai',
    broken_bone   = 'Os rupt',
    stab          = 'Injunghiat',
}

local VALID_INJURY_TYPES = {
    gunshot_leg = true, gunshot_chest = true,
    bruise = true, broken_bone = true, stab = true,
}

local function Notify(source, ntype, msg, dur)
    TriggerClientEvent('switcore:notify', source, ntype, msg, dur or 4000)
end

local function SyncInjuriesToClient(source)
    local data = playerInjuries[source]
    if not data then return end

    local payload = {}
    for id, inj in pairs(data.injuries) do
        payload[#payload + 1] = {
            id       = id,
            type     = inj.type,
            location = inj.location,
            severity = inj.severity,
        }
    end

    TriggerClientEvent('medical:client:syncInjuries', source, payload)
end

local function HasBleedingInjury(source)
    local data = playerInjuries[source]
    if not data then return false end

    for _, inj in pairs(data.injuries) do
        local cfg = Config.InjuryEffects[inj.type]
        if cfg and cfg.bleedingPerTick then
            local suppressed = inj.bleedSuppressedUntil and inj.bleedSuppressedUntil > os.time()
            if not suppressed then return true end
        end
    end
    return false
end

function LoadPlayerInjuries(source, characterId)
    playerInjuries[source] = { characterId = characterId, injuries = {} }

    local rows = MedicalDB.getCharacterInjuries(characterId)
    for _, row in ipairs(rows) do
        playerInjuries[source].injuries[row.id] = {
            type                = row.injury_type,
            location            = row.location,
            severity            = row.severity,
            bleedSuppressedUntil = nil,
        }
    end

    SyncInjuriesToClient(source)
end

function ApplyInjury(source, injuryType, location, severity)
    local data = playerInjuries[source]
    if not data then return nil end

    severity = math.max(1, math.min(3, severity or 1))

    local id = MedicalDB.addInjury(data.characterId, injuryType, location, severity)
    if not id then return nil end

    data.injuries[id] = {
        type                = injuryType,
        location            = location,
        severity            = severity,
        bleedSuppressedUntil = nil,
    }

    SyncInjuriesToClient(source)

    local label = INJURY_LABELS[injuryType] or injuryType
    Notify(source, 'error', label .. ' - Ai nevoie de ingrijiri medicale!', 6000)

    return id
end

function TreatInjury(source, injuryId)
    local data = playerInjuries[source]
    if not data or not data.injuries[injuryId] then return false end

    MedicalDB.treatInjury(injuryId)
    data.injuries[injuryId] = nil
    SyncInjuriesToClient(source)
    return true
end

function TreatAllInjuries(source)
    local data = playerInjuries[source]
    if not data then return end

    MedicalDB.treatAllInjuries(data.characterId)
    data.injuries = {}
    SyncInjuriesToClient(source)
end

function SuppressInjuryBleeding(source, durationSeconds)
    local data = playerInjuries[source]
    if not data then return end

    local expiry = os.time() + durationSeconds
    for _, inj in pairs(data.injuries) do
        inj.bleedSuppressedUntil = expiry
    end
end

function ReduceInjurySeverity(source, injuryType)
    local data = playerInjuries[source]
    if not data then return false end

    for id, inj in pairs(data.injuries) do
        if inj.type == injuryType then
            local newSeverity = inj.severity - 1
            if newSeverity <= 0 then
                MedicalDB.treatInjury(id)
                data.injuries[id] = nil
            else
                inj.severity = newSeverity
                MedicalDB.updateInjurySeverity(id, newSeverity)
            end
            SyncInjuriesToClient(source)
            return true
        end
    end
    return false
end

function HasInjury(source, injuryType)
    local data = playerInjuries[source]
    if not data then return false end

    for _, inj in pairs(data.injuries) do
        if inj.type == injuryType then return true end
    end
    return false
end

function GetActiveInjuries(source)
    local data = playerInjuries[source]
    if not data then return {} end

    local result = {}
    for id, inj in pairs(data.injuries) do
        result[#result + 1] = { id = id, type = inj.type, location = inj.location, severity = inj.severity }
    end
    return result
end

function GetPlayerInjuriesData()
    return playerInjuries
end

exports('GetActiveInjuries',       GetActiveInjuries)
exports('ApplyInjury',             ApplyInjury)
exports('TreatInjury',             TreatInjury)
exports('TreatAllInjuries',        TreatAllInjuries)
exports('HasInjury',               HasInjury)
exports('SuppressInjuryBleeding',  SuppressInjuryBleeding)

AddEventHandler('switcore:characterSelected', function(source, characterId)
    LoadPlayerInjuries(source, characterId)
    playerLastHP[source] = GetEntityHealth(GetPlayerPed(source))
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerInjuries[src] = nil
    playerLastHP[src]   = nil
end)

Sw.SecureEvent('medical:server:playerInjured', {
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'injuryData', type = 'table' },
    },
}, function(ctx)
    local src        = ctx.source
    local injuryData = ctx.args.injuryData
    if not playerInjuries[src] then return end

    if not VALID_INJURY_TYPES[injuryData.injuryType] then return end

    -- Anti-cheat: refuza injury daca serverul nu vede HP scazut (client poate trimite event fals)
    local pedHP = GetEntityHealth(GetPlayerPed(src))
    local lastHP = playerLastHP[src] or pedHP
    playerLastHP[src] = pedHP

    if pedHP >= lastHP then return end

    ApplyInjury(src, injuryData.injuryType, injuryData.location or 'generic', injuryData.severity or 1)

    if injuryData.injuryType == 'gunshot_chest' then
        local armor = GetPedArmour(GetPlayerPed(src))
        if armor == 0 then
            TriggerClientEvent('medical:client:triggerRagdoll', src, Config.InjuryEffects.gunshot_chest.ragdollDuration)
        end
    end
end)

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    Wait(8000)

    while true do
        Wait(Config.InjuryBleedLoopInterval * 1000)

        for src, data in pairs(playerInjuries) do
            local now           = os.time()
            local totalDamage   = 0

            for _, inj in pairs(data.injuries) do
                local cfg = Config.InjuryEffects[inj.type]
                if not cfg or not cfg.bleedingPerTick then goto nextInj end

                local suppressed = inj.bleedSuppressedUntil and inj.bleedSuppressedUntil > now
                if not suppressed then
                    totalDamage = totalDamage + cfg.bleedingPerTick
                end

                ::nextInj::
            end

            if totalDamage > 0 then
                TriggerClientEvent('medical:client:applyDamage', src, totalDamage)
            end
        end
    end
end)
