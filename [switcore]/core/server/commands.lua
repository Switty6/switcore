CommandLogger = {}

local function shouldLogCommands()
    return Config and Config.LOG_COMMANDS ~= false
end

function CommandLogger.logCommand(source, commandName, args, metadata)
    if not shouldLogCommands() then
        return false
    end
    
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    local logMetadata = metadata or {}
    if args then
        logMetadata.args = args
    end
    
    return Database.logActivity(
        player.dbId,
        'command',
        commandName,
        logMetadata
    )
end

function CommandLogger.registerCommand(commandName, handler, restricted)
    RegisterCommand(commandName, function(source, args, rawCommand)
        handler(source, args, rawCommand)
        
        CommandLogger.logCommand(source, commandName, args, {
            rawCommand = rawCommand
        })
    end, restricted)
    
    return commandName
end

-- ==================== HELPER FUNCTIONS ====================

-- Helper pentru verificare permisiuni (elimină redundanța)
local function checkPermission(source, permissions)
    if type(permissions) == 'string' then
        return Permissions.hasPermission(source, permissions)
    elseif type(permissions) == 'table' then
        for _, perm in ipairs(permissions) do
            if Permissions.hasPermission(source, perm) then
                return true
            end
        end
    end
    return false
end

-- Helper pentru mesaje de chat (elimină redundanța)
local function sendChatMessage(source, color, message, multiline)
    TriggerClientEvent('chat:addMessage', source, {
        color = color,
        multiline = multiline or false,
        args = {'[CORE]', message}
    })
end

local function sendError(source, message)
    sendChatMessage(source, {255, 0, 0}, message)
end

local function sendSuccess(source, message)
    sendChatMessage(source, {0, 255, 0}, message)
end

local function sendInfo(source, message)
    sendChatMessage(source, {255, 255, 0}, message)
end

local function sendWarning(source, message)
    sendChatMessage(source, {255, 165, 0}, message)
end

-- Helper pentru validare argumente
local function validateDbId(arg)
    local dbId = tonumber(arg)
    return dbId and dbId > 0, dbId
end

-- Helper pentru a parsa argumentele de ban
local function parseBanArgs(args)
    if #args < 1 then
        return nil, nil, nil, 'Utilizare: /bansource [Source] [Durată] [Motiv]'
    end
    
    local target = args[1]
    local durationStr = args[2] or 'permanent'
    local reason = table.concat(args, ' ', 3) or 'Fără motiv'
    
    if tonumber(args[1]) and args[2] and not args[2]:match('^%d+[dhm]?$') and args[2] ~= 'permanent' and args[2] ~= 'perm' then
        durationStr = 'permanent'
        reason = table.concat(args, ' ', 2) or 'Fără motiv'
    end
    
    return target, durationStr, reason, nil
end

-- ==================== COMENZI MODERARE ====================

-- Comandă ban
CommandLogger.registerCommand('bansource', function(source, args, rawCommand)
    if not checkPermission(source, 'admin.ban') then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    local target, durationStr, reason, errorMsg = parseBanArgs(args)
    
    if errorMsg then
        sendInfo(source, errorMsg)
        sendInfo(source, 'Exemple: /bansource 1 1d Cheating | /bansource John permanent RDM')
        return
    end
    
    local success, result = Moderation.banPlayerBySource(target, source, reason, durationStr)
    
    if success then
        sendSuccess(source, 'Jucătorul a fost banat cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă banid (ban după dbId)
CommandLogger.registerCommand('banid', function(source, args, rawCommand)
    if not checkPermission(source, 'admin.ban') then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 1 then
        sendInfo(source, 'Utilizare: /banid [DBID] [Durată] [Motiv]')
        sendInfo(source, 'Exemple: /banid 5 1d Cheating | /banid 10 permanent RDM')
        return
    end
    
    local valid, dbId = validateDbId(args[1])
    if not valid then
        sendError(source, 'DBID-ul trebuie să fie un număr')
        return
    end
    
    local durationStr = args[2] or 'permanent'
    local reason = table.concat(args, ' ', 3) or 'Fără motiv'
    
    local success, result = Moderation.banPlayerByDbId(dbId, source, reason, durationStr)
    
    if success then
        sendSuccess(source, 'Jucătorul (DBID: ' .. dbId .. ') a fost banat cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă unban
CommandLogger.registerCommand('unban', function(source, args, rawCommand)
    if not checkPermission(source, 'admin.ban') then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 1 then
        sendInfo(source, 'Utilizare: /unban [ID/Nume/DBID] [Motiv]')
        return
    end
    
    local target = args[1]
    local reason = table.concat(args, ' ', 2) or 'Unban manual'
    
    local success, result = Moderation.unbanPlayer(target, source, reason)
    
    if success then
        sendSuccess(source, 'Jucătorul a fost unbanat cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă warnid (warn după dbId)
CommandLogger.registerCommand('warnid', function(source, args, rawCommand)
    if not checkPermission(source, {'admin.warn', 'moderator.warn'}) then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 2 then
        sendInfo(source, 'Utilizare: /warnid [DBID] [Motiv]')
        return
    end
    
    local valid, dbId = validateDbId(args[1])
    if not valid then
        sendError(source, 'DBID-ul trebuie să fie un număr')
        return
    end
    
    local reason = table.concat(args, ' ', 2) or 'Fără motiv'
    
    local success, result = Moderation.warnPlayerByDbId(dbId, source, reason)
    
    if success then
        sendSuccess(source, 'Jucătorul (DBID: ' .. dbId .. ') a fost avertizat cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă warn source
CommandLogger.registerCommand('warn', function(source, args, rawCommand)
    if not checkPermission(source, {'admin.warn', 'moderator.warn'}) then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 2 then
        sendInfo(source, 'Utilizare: /warn [ID/Nume] [Motiv]')
        return
    end
    
    local target = args[1]
    local reason = table.concat(args, ' ', 2) or 'Fără motiv'
    
    local success, result = Moderation.warnPlayer(target, source, reason)
    
    if success then
        sendSuccess(source, 'Jucătorul a fost avertizat cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă unwarn (remove warn)
CommandLogger.registerCommand('unwarn', function(source, args, rawCommand)
    if not checkPermission(source, {'admin.warn', 'moderator.warn'}) then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 1 then
        sendInfo(source, 'Utilizare: /unwarn [Warn ID]')
        return
    end
    
    local warnId = tonumber(args[1])
    if not warnId then
        sendError(source, 'ID-ul warn-ului trebuie să fie un număr')
        return
    end
    
    local reason = table.concat(args, ' ', 2) or 'Eliminat manual'
    
    local success, result = Moderation.removeWarn(warnId, source, reason)
    
    if success then
        sendSuccess(source, 'Warn-ul a fost eliminat cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă kick
CommandLogger.registerCommand('kick', function(source, args, rawCommand)
    if not checkPermission(source, {'admin.kick', 'moderator.kick'}) then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 1 then
        sendInfo(source, 'Utilizare: /kick [ID/Nume] [Motiv]')
        return
    end
    
    local target = args[1]
    local reason = table.concat(args, ' ', 2) or 'Fără motiv'
    
    local success, result = Moderation.kickPlayer(target, source, reason)
    
    if success then
        sendSuccess(source, 'Jucătorul a fost dat afară cu succes')
    else
        sendError(source, 'Eroare: ' .. (result or 'Eroare necunoscută'))
    end
end, false)

-- Comandă checkban (verifică ban-urile unui jucător)
CommandLogger.registerCommand('checkban', function(source, args, rawCommand)
    if not checkPermission(source, {'admin.ban', 'moderator.ban'}) then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 1 then
        sendInfo(source, 'Utilizare: /checkban [ID/Nume/DBID]')
        return
    end
    
    local target = args[1]
    local isBanned, ban = Moderation.isPlayerBanned(target)
    
    if isBanned and ban then
        local banInfo = 'Jucătorul este banat | Motiv: ' .. ban.reason
        if ban.expires_at then
            banInfo = banInfo .. ' | Expiră: ' .. ban.expires_at
        else
            banInfo = banInfo .. ' | Ban permanent'
        end
        
        sendChatMessage(source, {255, 0, 0}, banInfo, true)
    else
        sendSuccess(source, 'Jucătorul nu este banat')
    end
end, false)

-- Comandă checkwarns (verifică warn-urile unui jucător)
CommandLogger.registerCommand('checkwarns', function(source, args, rawCommand)
    if not checkPermission(source, {'admin.warn', 'moderator.warn'}) then
        sendError(source, 'Nu ai permisiunea să folosești această comandă')
        return
    end
    
    if #args < 1 then
        sendInfo(source, 'Utilizare: /checkwarns [ID/Nume/DBID]')
        return
    end
    
    local target = args[1]
    local warns = Moderation.getPlayerWarns(target, false)
    
    if warns and #warns > 0 then
        sendWarning(source, 'Jucătorul are ' .. #warns .. ' warn-uri active:')
        
        for i, warn in ipairs(warns) do
            if i <= 5 then
                sendWarning(source, '#' .. warn.id .. ' - ' .. warn.reason .. ' (' .. warn.created_at .. ')')
            end
        end
        
        if #warns > 5 then
            sendWarning(source, '... și încă ' .. (#warns - 5) .. ' warn-uri')
        end
    else
        sendSuccess(source, 'Jucătorul nu are warn-uri active')
    end
end, false)

return CommandLogger
