local unconsciousPlayers = {}

local function GetCharId(source)
    return exports.characters:getCharacterId(source)
end

local function Notify(source, ntype, msg, dur)
    TriggerClientEvent('switcore:notify', source, ntype, msg, dur or 4000)
end

local function GetCharName(source)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(source)
    end)
    if ok and char then
        return (char.first_name or '') .. ' ' .. (char.last_name or '')
    end
    return 'Necunoscut'
end

local function BroadcastToEMS(event, data)
    for _, p in ipairs(GetPlayers()) do
        local src    = tonumber(p)
        local charId = exports.characters:getCharacterId(src)
        if charId then
            local job = exports.jobs:GetCharacterJob(charId)
            if job and job.name == 'ems' and job.isOnDuty then
                TriggerClientEvent(event, src, data)
            end
        end
    end
end

function SetUnconscious(source)
    local charId = GetCharId(source)
    if not charId then return end

    if unconsciousPlayers[source] then return end

    unconsciousPlayers[source] = {
        characterId = charId,
        startedAt   = os.time(),
        carrierId   = nil,
    }

    local respawnTimer = exports.settings:GetSettingNumber('ems.respawn_timer', 600)
    TriggerClientEvent('ems:client:youAreUnconscious', source, respawnTimer)

    local coords = GetEntityCoords(GetPlayerPed(source))
    local name   = GetCharName(source)

    BroadcastToEMS('ems:client:newUnconsciousPlayer', {
        source = source,
        name   = name,
        x      = coords.x,
        y      = coords.y,
        z      = coords.z,
    })

    print(('[EMS] %s (src=%d) a cazut inconstient.'):format(name, source))
end

function RevivePlayer(source, emsSrc)
    if not unconsciousPlayers[source] then return false end

    local charId    = unconsciousPlayers[source].characterId
    local emsCharId = emsSrc and GetCharId(emsSrc) or nil
    local reviveHP  = exports.settings:GetSettingNumber('ems.revive_hp', 150)

    unconsciousPlayers[source] = nil

    TriggerClientEvent('ems:client:revived', source, reviveHP)

    EmsDB.logRecord(charId, emsCharId, 'revive', { hp = reviveHP })

    Notify(source, 'success', 'Ai fost resuscitat de EMS.', 6000)
    if emsSrc then
        Notify(emsSrc, 'success', 'Pacient resuscitat cu succes.', 4000)
    end

    BroadcastToEMS('ems:client:playerRevived', { source = source })
    return true
end

function RespawnAtHospital(source)
    local data = unconsciousPlayers[source]
    if not data then return false end

    local respawnTimer = exports.settings:GetSettingNumber('ems.respawn_timer', 600)
    local elapsed      = os.time() - data.startedAt

    if elapsed < respawnTimer then
        local remaining = respawnTimer - elapsed
        Notify(source, 'warning', 'Mai ai ' .. remaining .. 's pana la optiunea de respawn.', 4000)
        return false
    end

    local charId      = data.characterId
    local bill        = exports.settings:GetSettingNumber('ems.hospital_bill', 5000)
    local hospitalX   = exports.settings:GetSettingNumber('ems.hospital_x',   295.5)
    local hospitalY   = exports.settings:GetSettingNumber('ems.hospital_y',  -1446.8)
    local hospitalZ   = exports.settings:GetSettingNumber('ems.hospital_z',    29.9)
    local hospitalH   = exports.settings:GetSettingNumber('ems.hospital_heading', 180.0)

    unconsciousPlayers[source] = nil

    if bill > 0 then
        exports.banking:removeCash(charId, bill, 'Spitalizare')
    end

    exports.medical:TreatAllInjuries(source)

    EmsDB.logRecord(charId, nil, 'hospital', { bill = bill })

    local reviveHP = exports.settings:GetSettingNumber('ems.revive_hp', 150)
    TriggerClientEvent('ems:client:teleportToHospital', source, {
        x = hospitalX,
        y = hospitalY,
        z = hospitalZ,
        h = hospitalH,
        hp = reviveHP,
    })

    print(('[EMS] charId=%d respawnat la spital. Cost: %d RON'):format(charId, bill))
    return true
end

function IsUnconscious(source)
    return unconsciousPlayers[source] ~= nil
end

function GetUnconsciousData(source)
    return unconsciousPlayers[source]
end

function TrySetCarrier(targetSrc, expectedCarrier, newCarrier)
    local data = unconsciousPlayers[targetSrc]
    if not data then return false end
    if data.carrierId ~= expectedCarrier then return false end
    data.carrierId = newCarrier
    return true
end

function GetAllUnconscious()
    return unconsciousPlayers
end

exports('IsUnconscious',      IsUnconscious)
exports('GetUnconsciousData', GetUnconsciousData)
exports('SetUnconscious',     SetUnconscious)
exports('RevivePlayer',       RevivePlayer)

Sw.SecureEvent('ems:server:goUnconscious', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
    silent = true,
}, function(ctx)
    SetUnconscious(ctx.source)
end)

Sw.SecureEvent('ems:server:requestRespawn', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
    silent = true,
}, function(ctx)
    RespawnAtHospital(ctx.source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if unconsciousPlayers[src] then
        unconsciousPlayers[src] = nil
        BroadcastToEMS('ems:client:playerRevived', { source = src })
    end
end)

local function SendConfigToClient(src)
    local cfg = {
        respawnTimer        = exports.settings:GetSettingNumber('ems.respawn_timer',         600),
        patientScanInterval = exports.settings:GetSettingNumber('ems.patient_scan_interval', 2),
        patientScanRange    = exports.settings:GetSettingNumber('ems.patient_scan_range',    3.5),
        stretcherRange      = exports.settings:GetSettingNumber('ems.stretcher_range',       2.0),
        mdtKey              = exports.settings:GetSetting('ems.mdt_key',               'F6'),
        ambulanceModels     = exports.settings:GetSettingJSON('ems.ambulance_models',        {}),
        ivTreatments        = exports.settings:GetSettingJSON('ems.iv_treatments',           {}),
    }
    TriggerClientEvent('ems:client:config', src, cfg)
end

AddEventHandler('switcore:characterSelected', function(src, characterId)
    CreateThread(function()
        while not exports.settings:IsReady() do Wait(100) end
        SendConfigToClient(src)
    end)
end)
