local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function notify(src, ntype, title, msg)
    TriggerClientEvent('notifications:client:send', src, {
        type     = ntype,
        title    = title,
        message  = msg,
        duration = 4000
    })
end

local function hasArrestPerm(charId)
    local ok, result = pcall(function()
        return exports.jobs:HasJobPermission(charId, 'arrest')
    end)
    return ok and result
end

local function getJob(charId)
    local ok, job = pcall(function()
        return exports.jobs:GetCharacterJob(charId)
    end)
    return ok and job or nil
end

local function hasPoliceMDTAccess(charId)
    local job = getJob(charId)
    return job ~= nil and job.name == 'police'
end

local function isEMSOnDuty(charId)
    local job = getJob(charId)
    return job ~= nil and job.name == 'ems' and job.isOnDuty
end

local function sanitizeCharIdArray(input)
    if type(input) ~= 'table' then return {} end
    local clean = {}
    local count = 0
    for _, v in ipairs(input) do
        local n = tonumber(v)
        if n and n > 0 and n < 2147483647 then
            count = count + 1
            clean[count] = math.floor(n)
            if count >= 50 then break end
        end
    end
    return clean
end

local function sanitizeText(input, maxLen)
    if type(input) ~= 'string' then return nil end
    local trimmed = input:match('^%s*(.-)%s*$') or ''
    if #trimmed == 0 then return nil end
    if #trimmed > maxLen then trimmed = trimmed:sub(1, maxLen) end
    return trimmed
end

RegisterNetEvent('mdt:server:getCriminalHistory', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char or not data or not data.characterId then return end
    if not hasPoliceMDTAccess(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai acces la dosarele MDT.')
        return
    end

    local targetId = tonumber(data.characterId)
    if not targetId then return end

    MDTDatabase.getCriminalHistory(targetId, function(history)
        TriggerClientEvent('mdt:client:criminalHistory', src, history)
    end)
end)

RegisterNetEvent('mdt:server:createCitation', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa emiti citatii.')
        return
    end
    if not data or not data.characterId or not data.offense or not data.fineAmount then return end

    MDTDatabase.createCitation(char.id, data.characterId, data.offense, tonumber(data.fineAmount) or 500, function(row)
        if row then
            notify(src, 'success', 'Citatie emisa', 'Amenda de $' .. (data.fineAmount or 0) .. ' a fost emisa.')
            TriggerClientEvent('mdt:client:citationCreated', src, row)
        end
    end)
end)

RegisterNetEvent('mdt:server:getCitations', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasPoliceMDTAccess(char.id) then return end

    MDTDatabase.getCitations(function(rows)
        TriggerClientEvent('mdt:client:citationsData', src, rows)
    end)
end)

RegisterNetEvent('mdt:server:payCitationOfficer', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char or not data or not data.citationId then return end
    if not hasPoliceMDTAccess(char.id) then return end

    local citationId = tonumber(data.citationId)
    if not citationId then return end

    MDTDatabase.markCitationPaid(citationId, function(updated)
        if updated then
            notify(src, 'success', 'Citatie', 'Citatie marcata ca platita.')
        else
            notify(src, 'warning', 'Citatie', 'Citatia era deja platita.')
        end
    end)
end)

RegisterNetEvent('mdt:server:createBOLO', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa emiti BOLO.')
        return
    end
    if not data or not data.subjectName or not data.description then return end

    MDTDatabase.createBOLO(char.id, data.subjectName, data.description, data.vehicleInfo or '', function(row)
        if row then
            notify(src, 'success', 'BOLO emis', 'BOLO pentru ' .. data.subjectName .. ' a fost emis.')
            TriggerClientEvent('mdt:client:boloCreated', src, row)
        end
    end)
end)

RegisterNetEvent('mdt:server:getActiveBOLOs', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasPoliceMDTAccess(char.id) then return end

    MDTDatabase.getActiveBOLOs(function(rows)
        TriggerClientEvent('mdt:client:bolosData', src, rows)
    end)
end)

RegisterNetEvent('mdt:server:closeBOLO', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char or not data or not data.boloId then return end

    MDTDatabase.closeBOLO(data.boloId, char.id, function()
        notify(src, 'success', 'BOLO', 'BOLO inchis.')
    end)
end)

RegisterNetEvent('mdt:server:createIncident', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa creezi incidente.')
        return
    end
    if not data then return end

    local title       = sanitizeText(data.title, 200)
    local description = sanitizeText(data.description, 5000)
    if not title or not description then return end

    local involved     = sanitizeCharIdArray(data.involvedCharacters)
    local involvedJson = json.encode(involved)

    MDTDatabase.createIncident(char.id, title, description, involvedJson, function(row)
        if row then
            notify(src, 'success', 'Incident', 'Raport de incident salvat.')
            TriggerClientEvent('mdt:client:incidentCreated', src, row)
        end
    end)
end)

RegisterNetEvent('mdt:server:getIncidents', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasPoliceMDTAccess(char.id) then return end

    MDTDatabase.getIncidents(function(rows)
        TriggerClientEvent('mdt:client:incidentsData', src, rows)
    end)
end)

RegisterNetEvent('mdt:server:impoundVehicle', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa sechestru vehicule.')
        return
    end
    if not data or not data.plate or not data.reason then return end

    local fee = tonumber(data.fee) or 2500
    MDTDatabase.createImpound(char.id, data.plate:upper(), data.model or '', data.reason, fee, function(row)
        if row then
            notify(src, 'success', 'Sechestru', 'Vehiculul ' .. data.plate .. ' a fost sechestrat.')
            TriggerClientEvent('mdt:client:impoundCreated', src, row)
        end
    end)
end)

RegisterNetEvent('mdt:server:getImpounds', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end
    if not hasPoliceMDTAccess(char.id) then return end

    MDTDatabase.getImpounds(function(rows)
        TriggerClientEvent('mdt:client:impoundsData', src, rows)
    end)
end)

RegisterNetEvent('mdt:server:retrieveImpound', function(data)
    local src  = source
    local char = getActiveChar(src)
    if not char or not data or not data.impoundId then return end
    if not hasPoliceMDTAccess(char.id) then return end

    local impoundId = tonumber(data.impoundId)
    if not impoundId then return end

    MDTDatabase.retrieveImpound(impoundId, function()
        notify(src, 'success', 'Sechestru', 'Vehicul eliberat din sechestru.')
    end)
end)
