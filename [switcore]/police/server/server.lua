
local PoliceSettings = {}

local activeJailTimers  = {}
local handcuffedCharacters = {}
local charIdToSource       = {}

function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

function notify(src, ntype, title, msg)
    TriggerClientEvent('notifications:client:send', src, {
        type     = ntype,
        title    = title,
        message  = msg,
        duration = 4000
    })
end

function isPoliceOnDuty(charId)
    local ok, job = pcall(function()
        return exports.jobs:GetCharacterJob(charId)
    end)
    return ok and job and job.name == 'police' and job.isOnDuty
end

function hasArrestPerm(charId)
    local ok, result = pcall(function()
        return exports.jobs:HasJobPermission(charId, 'arrest')
    end)
    return ok and result
end

function hasArmoryPerm(charId)
    local ok, result = pcall(function()
        return exports.jobs:HasJobPermission(charId, 'armory')
    end)
    return ok and result
end

function hasManagePerm(charId)
    local ok, result = pcall(function()
        return exports.jobs:HasJobPermission(charId, 'manage')
    end)
    return ok and result
end

function isAdmin(src)
    local ok, result = pcall(function()
        return exports.core:hasPermission(src, 'admin')
    end)
    return ok and result
end

function findArmoryWeapon(itemName)
    for _, w in ipairs(PoliceSettings.armoryWeapons or {}) do
        if w.itemName == itemName then return w end
    end
    return nil
end

function findArmoryEquipment(itemName)
    for _, e in ipairs(PoliceSettings.armoryEquipment or {}) do
        if e.itemName == itemName then return e end
    end
    return nil
end

function findOnlineSourceByCharId(characterId)
    return charIdToSource[characterId]
end

function JailCharacter(characterId, arrestedBy, reason, sentenceMinutes, bailAmount)
    local existing = PoliceDatabase.getActiveJailSentence(characterId)
    if existing then
        return false, 'Personajul este deja inchis.'
    end

    local row = PoliceDatabase.createJailSentence(characterId, arrestedBy, reason, sentenceMinutes, bailAmount)
    if not row then
        return false, 'Eroare baza de date.'
    end

    activeJailTimers[characterId] = {
        sentenceId = row.id,
        remaining  = sentenceMinutes * 60
    }

    local cell = PoliceSettings.jailCell or { x = 0, y = 0, z = 0, heading = 0 }
    local onlineSrc = findOnlineSourceByCharId(characterId)
    if onlineSrc then
        TriggerClientEvent('police:client:sendToJail', onlineSrc, {
            coords    = cell,
            remaining = sentenceMinutes * 60,
            reason    = reason
        })
    end

    return true, nil
end

function ReleaseFromJail(characterId, releaseReason)
    local data = activeJailTimers[characterId]
    if not data then
        local sentence = PoliceDatabase.getActiveJailSentence(characterId)
        if not sentence then return false end
        PoliceDatabase.releaseJailSentence(sentence.id, releaseReason)
    else
        PoliceDatabase.releaseJailSentence(data.sentenceId, releaseReason)
        activeJailTimers[characterId] = nil
    end

    local release = PoliceSettings.jailRelease or { x = 0, y = 0, z = 0, heading = 0 }
    local onlineSrc = findOnlineSourceByCharId(characterId)
    if onlineSrc then
        TriggerClientEvent('police:client:released', onlineSrc, { coords = release })
        notify(onlineSrc, 'success', 'Eliberat', 'Ai fost eliberat din inchisoare.')
    end

    return true
end

function ResumeJailTimers()
    local sentences = PoliceDatabase.getAllActiveSentences()
    for _, s in ipairs(sentences) do
        activeJailTimers[s.character_id] = {
            sentenceId = s.id,
            remaining  = s.remaining_seconds
        }
        local onlineSrc = findOnlineSourceByCharId(s.character_id)
        if onlineSrc then
            local cell = PoliceSettings.jailCell or { x = 0, y = 0, z = 0, heading = 0 }
            TriggerClientEvent('police:client:sendToJail', onlineSrc, {
                coords    = cell,
                remaining = s.remaining_seconds,
                reason    = s.reason
            })
        end
    end
    print(('[POLICE] Reluate %d sentinte active.'):format(#sentences))
end

function StartJailLoop()
    CreateThread(function()
        while true do
            Wait(1000)
            for charId, data in pairs(activeJailTimers) do
                data.remaining = data.remaining - 1

                local onlineSrc = findOnlineSourceByCharId(charId)
                if onlineSrc then
                    TriggerClientEvent('police:client:jailTimer', onlineSrc, data.remaining)
                end

                if data.remaining <= 0 then
                    ReleaseFromJail(charId, 'expired')
                elseif data.remaining % 10 == 0 then
                    local ok = PoliceDatabase.updateRemainingTime(data.sentenceId, data.remaining)
                    if not ok then
                        print(('[POLICE] WARN: jail timer persist esuat char=%d sentence=%d remaining=%d')
                            :format(charId, data.sentenceId, data.remaining))
                    end
                end
            end
        end
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        while not exports.postgres:isReady() or not exports.settings:IsReady() do Wait(100) end

        PoliceSettings.jailCell        = exports.settings:GetSettingJSON('police.jail_cell',        { x = 0, y = 0, z = 0, heading = 0 })
        PoliceSettings.jailRelease     = exports.settings:GetSettingJSON('police.jail_release',     { x = 0, y = 0, z = 0, heading = 0 })
        PoliceSettings.armoryWeapons   = exports.settings:GetSettingJSON('police.armory_weapons',   {})
        PoliceSettings.armoryEquipment = exports.settings:GetSettingJSON('police.armory_equipment', {})
        PoliceSettings.uniformMale     = exports.settings:GetSettingJSON('police.uniform_male',     {})
        PoliceSettings.uniformFemale   = exports.settings:GetSettingJSON('police.uniform_female',   {})
        PoliceSettings.handcuffDist    = exports.settings:GetSettingNumber('police.handcuff_distance', 2.5)
        PoliceSettings.armoryCoords    = exports.settings:GetSettingJSON('police.armory_coords',    { x = 0, y = 0, z = 0 })
        PoliceSettings.armoryRadius    = exports.settings:GetSettingNumber('police.armory_radius',  1.5)
        PoliceSettings.cloakroomCoords = exports.settings:GetSettingJSON('police.cloakroom_coords', { x = 0, y = 0, z = 0 })
        PoliceSettings.cloakroomRadius = exports.settings:GetSettingNumber('police.cloakroom_radius', 1.5)
        PoliceSettings.mdtKey          = exports.settings:GetSetting('police.mdt_key', 'F6')
        PoliceSettings.stationBlip     = exports.settings:GetSettingJSON('police.station_blip',     {})
        PoliceSettings.jailBlip        = exports.settings:GetSettingJSON('police.jail_blip',        {})
        PoliceSettings.garageCoords    = exports.settings:GetSettingJSON('police.garage_coords',    { x = 0, y = 0, z = 0, heading = 0 })
        PoliceSettings.garageRadius    = exports.settings:GetSettingNumber('police.garage_radius',  5.0)
        PoliceSettings.garageSpawn     = exports.settings:GetSettingJSON('police.garage_spawn',     { x = 0, y = 0, z = 0, heading = 0 })
        PoliceSettings.fleetModels      = exports.settings:GetSettingJSON('police.fleet_models',      {})
        PoliceSettings.mileageUnit      = exports.settings:GetSetting('police.mileage_unit', 'km')
        PoliceSettings.vehicleSellRatio = exports.settings:GetSettingNumber('police.vehicle_sell_ratio',     0.6)
        PoliceSettings.vehicleCurrencyId= exports.settings:GetSettingNumber('police.vehicle_price_currency', 1)

        PoliceDatabase.ensureHandcuffSchema()
        ResumeJailTimers()
        for _, row in ipairs(PoliceDatabase.getAllHandcuffs() or {}) do
            handcuffedCharacters[row.target_character_id] = row.officer_character_id
        end
        StartJailLoop()
        SeedFleetIfEmpty()
        print(('[POLICE] Sistem de politie initializat. (%d catuse active recuperate)')
            :format(#PoliceDatabase.getAllHandcuffs()))
    end)
end)

local function generatePolicePlate(index)
    return ('POLIT%03d'):format(index)
end

function SeedFleetIfEmpty()
    if not PoliceDatabase.fleetIsEmpty() then return end
    local models = PoliceSettings.fleetModels or {}
    if #models == 0 then return end

    local idx = 1
    for _, m in ipairs(models) do
        local plate = generatePolicePlate(idx)
        PoliceDatabase.createFleetVehicle(m.model, m.label, m.category or 'emergency', plate, tonumber(m.price) or 0)
        idx = idx + 1
    end
    print(('[POLICE] Flota initiala creata: %d vehicule.'):format(#models))
end

RegisterNetEvent('switcore:characterLoaded', function(character)
    local src = source
    if character then charIdToSource[character.id] = src end
    TriggerClientEvent('police:client:syncConfig', src, {
        garageCoords    = PoliceSettings.garageCoords,
        garageRadius    = PoliceSettings.garageRadius,
        mileageUnit     = PoliceSettings.mileageUnit,
        armoryCoords    = PoliceSettings.armoryCoords,
        armoryRadius    = PoliceSettings.armoryRadius,
        cloakroomCoords = PoliceSettings.cloakroomCoords,
        cloakroomRadius = PoliceSettings.cloakroomRadius,
        mdtKey          = PoliceSettings.mdtKey,
        handcuffDist    = PoliceSettings.handcuffDist,
        stationBlip     = PoliceSettings.stationBlip,
        jailBlip        = PoliceSettings.jailBlip,
    })

    if character then
        local sentence = PoliceDatabase.getActiveJailSentence(character.id)
        if sentence and sentence.is_active then
            local cell = PoliceSettings.jailCell or { x = 0, y = 0, z = 0, heading = 0 }
            TriggerClientEvent('police:client:sendToJail', src, {
                coords    = cell,
                remaining = sentence.remaining_seconds,
                reason    = sentence.reason
            })
            if not activeJailTimers[character.id] then
                activeJailTimers[character.id] = {
                    sentenceId = sentence.id,
                    remaining  = sentence.remaining_seconds
                }
            end
        end

        if handcuffedCharacters[character.id] then
            TriggerClientEvent('police:client:handcuffed', src)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    charIdToSource[char.id] = nil

    local data = activeJailTimers[char.id]
    if data then
        PoliceDatabase.updateRemainingTime(data.sentenceId, data.remaining)
    end
end)

exports('IsPlayerJailed', function(characterId)
    return activeJailTimers[characterId] ~= nil
        or PoliceDatabase.getActiveJailSentence(characterId) ~= nil
end)

exports('JailCharacter', function(characterId, arrestedBy, reason, sentenceMinutes, bailAmount)
    return JailCharacter(characterId, arrestedBy, reason, sentenceMinutes, bailAmount)
end)

exports('ReleaseCharacter', function(characterId, releaseReason)
    return ReleaseFromJail(characterId, releaseReason or 'admin')
end)

exports('GetActiveWarrant', function(characterId)
    return PoliceDatabase.getActiveWarrant(characterId)
end)

exports('IsCharacterHandcuffed', function(characterId)
    return handcuffedCharacters[characterId] ~= nil
end)

exports('GetHandcuffedPlayers', function()
    local out = {}
    for targetCharId, officerCharId in pairs(handcuffedCharacters) do
        local targetSrc  = charIdToSource[targetCharId]
        local officerSrc = charIdToSource[officerCharId]
        if targetSrc then out[targetSrc] = officerSrc or true end
    end
    return out
end)

exports('IsHandcuffedBy', function(targetCharId, officerCharId)
    return handcuffedCharacters[targetCharId] == officerCharId
end)

exports('AddHandcuff', function(targetCharId, officerCharId)
    if not targetCharId or not officerCharId then return false end
    local ok = PoliceDatabase.addHandcuff(targetCharId, officerCharId)
    if ok then handcuffedCharacters[targetCharId] = officerCharId end
    return ok
end)

exports('RemoveHandcuff', function(targetCharId)
    if not targetCharId then return end
    PoliceDatabase.removeHandcuff(targetCharId)
    handcuffedCharacters[targetCharId] = nil
end)

exports('GetPoliceSettings', function()
    return PoliceSettings
end)
