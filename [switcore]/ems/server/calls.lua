local activeCalls = {}

local function Notify(source, ntype, msg, dur)
    TriggerClientEvent('switcore:notify', source, ntype, msg, dur or 4000)
end

function BroadcastToEMS(event, data)
    local ok, roster = pcall(function() return exports.jobs:GetJobRoster('ems') end)
    if not ok or not roster then return end

    local onDutySet = {}
    for _, m in ipairs(roster) do
        if m.is_on_duty then onDutySet[m.id] = true end
    end

    for _, p in ipairs(GetPlayers()) do
        local src    = tonumber(p)
        local charId = exports.characters:getCharacterId(src)
        if charId and onDutySet[charId] then
            TriggerClientEvent(event, src, data)
        end
    end
end

local function GetCharName(source)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(source)
    end)
    if ok and char then
        return (char.first_name or '') .. ' ' .. (char.last_name or '')
    end
    return 'Anonim'
end

local function FindSourceByCharId(charId)
    for _, p in ipairs(GetPlayers()) do
        local src = tonumber(p)
        if exports.characters:getCharacterId(src) == charId then
            return src
        end
    end
    return nil
end

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    Wait(3000)

    local rows = EmsDB.getActiveCalls()
    for _, row in ipairs(rows) do
        local coords = type(row.coords) == 'string' and json.decode(row.coords) or row.coords
        activeCalls[row.id] = {
            id          = row.id,
            callerId    = row.caller_id,
            callerName  = row.caller_name,
            message     = row.message,
            coords      = coords,
            status      = row.status,
            responderId = row.responder_id,
            createdAt   = tostring(row.created_at),
        }
    end
    print(('[EMS] %d apeluri active incarcate din DB.'):format(#rows))
end)

RegisterNetEvent('ems:server:call112')
AddEventHandler('ems:server:call112', function(message)
    local src    = source
    local charId = exports.characters:getCharacterId(src)
    if not charId then return end

    if not message or #message < 3 then
        TriggerClientEvent('switcore:notify', src, 'warning', 'Mesajul este prea scurt.', 3000)
        return
    end

    local name   = GetCharName(src)
    local ped    = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    local callId = EmsDB.createCall(charId, name, message, json.encode({
        x = coords.x, y = coords.y, z = coords.z
    }))
    if not callId then return end

    activeCalls[callId] = {
        id          = callId,
        callerId    = charId,
        callerName  = name,
        message     = message,
        coords      = { x = coords.x, y = coords.y, z = coords.z },
        status      = 'pending',
        responderId = nil,
        createdAt   = os.date('%Y-%m-%dT%H:%M:%S'),
    }

    BroadcastToEMS('ems:client:new112Call', activeCalls[callId])
    Notify(src, 'info', 'Apelul tau 112 a fost trimis. Asteapta EMS.', 6000)
    print(('[EMS] Apel 112 #%d de la %s: %s'):format(callId, name, message))
end)

RegisterNetEvent('ems:server:acceptCall')
AddEventHandler('ems:server:acceptCall', function(callId)
    local src    = source
    local charId = exports.characters:getCharacterId(src)
    if not charId then return end

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' or not job.isOnDuty then return end

    local call = activeCalls[callId]
    if not call or call.status ~= 'pending' then return end

    call.status      = 'active'
    call.responderId = charId

    EmsDB.updateCallStatus(callId, 'active', charId)
    BroadcastToEMS('ems:client:callsUpdated', activeCalls)

    local callerSrc = FindSourceByCharId(call.callerId)
    if callerSrc then
        Notify(callerSrc, 'success', 'EMS a acceptat apelul tau! Se indreapta spre tine.', 7000)
    end
end)

RegisterNetEvent('ems:server:resolveCall')
AddEventHandler('ems:server:resolveCall', function(callId)
    local src    = source
    local charId = exports.characters:getCharacterId(src)
    if not charId then return end

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' or not job.isOnDuty then return end

    if not activeCalls[callId] then return end

    EmsDB.resolveCall(callId)
    activeCalls[callId] = nil
    BroadcastToEMS('ems:client:callsUpdated', activeCalls)
end)

RegisterNetEvent('ems:server:getCalls')
AddEventHandler('ems:server:getCalls', function()
    local src    = source
    local charId = exports.characters:getCharacterId(src)
    if not charId then return end

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' then return end

    TriggerClientEvent('ems:client:callsData', src, activeCalls)
end)
