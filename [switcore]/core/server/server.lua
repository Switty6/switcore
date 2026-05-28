CreateThread(function()
    while not exports.postgres:isReady() do
        Wait(100)
    end
    while not exports.settings:IsReady() do
        Wait(100)
    end

    print('[CORE] PostgreSQL este gata, inițializăm core-ul...')
    InitializeCore()
end)

function InitializeCore()
    LocalizationServer.initialize()

    local updateInterval = exports.settings:GetSettingNumber('core.playtime_update_interval', 60)
    PlaytimeTracker.setUpdateInterval(updateInterval)
    
    Groups.initializeDefaults()
    
    if SetRoutingBucketDispatchEnabled then
        SetRoutingBucketDispatchEnabled(0, false)
    end
    
    print('[CORE] ' .. Localize('server.core_initialized'))
end

local function isIdentifierBlocked(identifier)
    if not Config or not Config.IDENTIFIER_BLOCKLIST then
        return false
    end
    
    local idType = identifier:match('([^:]+):')
    if not idType then
        return false
    end
    
    return Config.IDENTIFIER_BLOCKLIST[idType] == true
end

local function getPlayerIdentifiers(source)
    local allIdentifiers = GetPlayerIdentifiers(source)
    local validIdentifiers = {}
    
    for _, identifier in ipairs(allIdentifiers) do
        if not isIdentifierBlocked(identifier) then
            table.insert(validIdentifiers, identifier)
        end
    end
    
    return validIdentifiers
end

local function mergedIdentifiers(existing, incoming)
    local seen = {}
    local result = {}
    for _, id in ipairs(existing or {}) do
        if not seen[id] then
            seen[id] = true
            table.insert(result, id)
        end
    end
    for _, id in ipairs(incoming or {}) do
        if not seen[id] then
            seen[id] = true
            table.insert(result, id)
        end
    end
    return result
end

local function applyIdentifierMerge(playerData, identifiers)
    local merged = mergedIdentifiers(playerData.identifiers, identifiers)
    local ok = Database.updatePlayerIdentifiers(playerData.dbId, merged)
    if not ok then return false end
    playerData.identifiers = merged
    return true
end

local function findOrCreatePlayer(source, identifiers, name)
    local dbPlayer
    for _, identifier in ipairs(identifiers) do
        if PlayerCache.hasIdentifier(identifier) then
            local dbId = PlayerCache.getDbIdByIdentifier(identifier)
            if dbId then
                local existingSource = PlayerCache.getSourceById(dbId)
                local existingPlayer = existingSource and PlayerCache.getFromCache(existingSource)
                if existingPlayer then
                    if applyIdentifierMerge(existingPlayer, identifiers) then
                        PlayerCache.setInCache(source, existingPlayer)
                    end
                    return existingPlayer
                end
            end
        end
        if not dbPlayer then
            dbPlayer = Database.findPlayerByIdentifier(identifier)
        end
    end

    if dbPlayer then
        if applyIdentifierMerge(dbPlayer, identifiers) then
            PlayerCache.setInCache(source, dbPlayer)
        end
        return dbPlayer
    end

    local playerData = Database.createPlayer(identifiers, name)
    if playerData then
        playerData._justCreated = true
        PlayerCache.setInCache(source, playerData)
        Database.logActivity(playerData.dbId, 'join', nil, {
            identifiers = identifiers,
            source = source
        })
        return playerData
    end

    return nil
end

local function sendLocaleToClient(source, language)
    local locale = LocalizationServer.getLocaleData(language)
    if locale then
        TriggerClientEvent('switcore:localeData', source, language, locale)
    else
        local defaultLanguage = exports.settings:GetSetting('core.default_language', 'ro') or 'ro'
        local defaultLocale = LocalizationServer.getLocaleData(defaultLanguage)
        if defaultLocale then
            TriggerClientEvent('switcore:localeData', source, defaultLanguage, defaultLocale)
        end
    end
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    
    local identifiers = getPlayerIdentifiers(source)
    
    if #identifiers == 0 then
        print('[CORE] ' .. Localize('server.player_no_valid_identifiers', name))
        setKickReason(Localize('server.error_no_valid_identifiers'))
        CancelEvent()
        return
    end
    
    for _, identifier in ipairs(identifiers) do
        local ban = Database.getActiveBanByIdentifier(identifier)
        if ban then
            local banMessage = Localize('server.you_were_banned')
            if ban.reason then
                banMessage = banMessage .. Localize('server.banned_for', ban.reason)
            end
            if ban.expires_at then
                local year, month, day, hour, min, sec = ban.expires_at:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
                if year and month and day and hour and min and sec then
                    local expiresTime = os.time({
                        year = tonumber(year),
                        month = tonumber(month),
                        day = tonumber(day),
                        hour = tonumber(hour),
                        min = tonumber(min),
                        sec = tonumber(sec)
                    })
                    local remaining = expiresTime - os.time()
                    if remaining > 0 then
                        local days = math.floor(remaining / 86400)
                        local hours = math.floor((remaining % 86400) / 3600)
                        local minutes = math.floor((remaining % 3600) / 60)
                        banMessage = banMessage .. Localize('server.expires_in', days, hours, minutes)
                    else
                        Database.unban(ban.id, nil, Localize('server.ban_expired_auto'))
                        break
                    end
                end
            else
                banMessage = banMessage .. Localize('server.ban_permanent')
            end
            
            print('[CORE] ' .. Localize('server.player_banned_attempt', name))
            setKickReason(banMessage)
            CancelEvent()
            return
        end
    end
    
    local playerData = findOrCreatePlayer(source, identifiers, name)
    
    if playerData then
        local currentTime = os.time()
        Database.updatePlayerLastSeen(playerData.dbId)
        PlayerCache.updateInCache(source, {last_seen = currentTime})
        
        local groups = Database.getPlayerGroups(playerData.dbId)
        local permissions = Database.getPlayerPermissions(playerData.dbId)
        local playerLanguage = playerData.language or exports.settings:GetSetting('core.default_language', 'ro') or 'ro'
        PlayerCache.updateInCache(source, {
            groups = groups,
            permissions = permissions,
            language = playerLanguage
        })
        
        TriggerClientEvent('switcore:languageChanged', source, playerLanguage)
        sendLocaleToClient(source, playerLanguage)
        
        PlaytimeTracker.startTracking(source)

        if not playerData._justCreated then
            Database.logActivity(playerData.dbId, 'join', nil, {
                identifiers = identifiers,
                source = source
            })
        end

        TriggerEvent('switcore:playerLoaded', source, playerData.dbId, PlayerCache.getFromCache(source))

        print('[CORE] ' .. Localize('server.player_loaded', name, playerData.dbId))
    else
        print('[CORE] ' .. Localize('server.error_loading_player', name))
        setKickReason(Localize('server.error_loading_player_data'))
        CancelEvent()
    end
end)

AddEventHandler('playerJoining', function(oldId)
    local source = source
    
    local existingPlayer = PlayerCache.getFromCache(source)
    if existingPlayer then
        return
    end
    
    local oldPlayer = PlayerCache.getFromCache(tostring(oldId))
    
    if oldPlayer then
        local partialPlaytime = PlaytimeTracker.stopTracking(tostring(oldId))
        if partialPlaytime and oldPlayer.dbId then
            Database.updatePlayerPlaytime(oldPlayer.dbId, partialPlaytime)
            oldPlayer.playtime = partialPlaytime
        end
        
        PlayerCache.setInCache(source, oldPlayer)
        PlayerCache.removeFromCache(tostring(oldId))
        
        PlaytimeTracker.startTracking(source)
    else
        print('[CORE] ' .. Localize('server.player_not_found_cache', source))
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local player = PlayerCache.getFromCache(source)
    
    if player then
        local finalPlaytime = PlaytimeTracker.stopTracking(source)
        if finalPlaytime then
            Database.updatePlayerPlaytime(player.dbId, finalPlaytime)
            PlayerCache.updateInCache(source, {playtime = finalPlaytime})
        end
        
        Database.updatePlayerLastSeen(player.dbId)
        PlayerCache.updateInCache(source, {last_seen = os.time()})
        
        Database.logActivity(player.dbId, 'quit', nil, {
            reason = reason or 'unknown'
        })
        
        PlayerCache.removeFromCache(source)
        
        print('[CORE] ' .. Localize('server.player_disconnected', player.name, player.dbId))
    end
end)

CreateThread(function()
    Wait(2000) 
    
    local allPlayers = GetPlayers()
    for _, playerId in ipairs(allPlayers) do
        local source = tonumber(playerId)
        if source then
            local existingPlayer = PlayerCache.getFromCache(source)
            if not existingPlayer then
                local identifiers = getPlayerIdentifiers(source)
                local name = GetPlayerName(source)
                findOrCreatePlayer(source, identifiers, name)
            end
            
            local player = PlayerCache.getFromCache(source)
            if player then
                if not player.permissions or not player.groups then
                    local groups = Database.getPlayerGroups(player.dbId)
                    local permissions = Database.getPlayerPermissions(player.dbId)
                    PlayerCache.updateInCache(source, {
                        groups = groups,
                        permissions = permissions
                    })
                end
                
                if not PlaytimeTracker.isTracking(source) then
                    PlaytimeTracker.startTracking(source)
                end
            end
        end
    end
end)

exports('getPlayerId', function(source)
    local player = PlayerCache.getFromCache(source)
    return player and player.dbId or nil
end)

exports('getPlayerById', function(dbId)
    local source = PlayerCache.getSourceById(dbId)
    if source then
        return PlayerCache.getFromCache(source)
    end
    return nil
end)

exports('getPlayerIdFromIdentifier', function(identifier)
    return PlayerCache.getDbIdByIdentifier(identifier)
end)

exports('getPlayerIdentifiers', function(dbId)
    local player = exports.core:getPlayerById(dbId)
    return player and player.identifiers or {}
end)

exports('getPlayerData', function(source)
    return PlayerCache.getFromCache(source)
end)

exports('logPlayerActivity', function(source, eventType, metadata)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    return Database.logActivity(player.dbId, eventType, nil, metadata)
end)

exports('updatePlayerPlaytime', function(source, seconds)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    PlayerCache.updateInCache(source, {playtime = seconds})
    return Database.updatePlayerPlaytime(player.dbId, seconds)
end)

local function addPlayerGroup(source, groupName, expiresAt, assignedBy)
    if not source or not groupName or type(groupName) ~= 'string' or groupName == '' then
        return false
    end
    
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    local group = Groups.getGroupByName(groupName)
    if not group then
        print('[CORE] ' .. Localize('server.group_not_exists', groupName))
        return false
    end
    
    local assignedById = nil
    if assignedBy then
        local assignedByPlayer = PlayerCache.getFromCache(assignedBy)
        if assignedByPlayer then
            assignedById = assignedByPlayer.dbId
        end
    end

    local success = Database.addGroupToPlayer(player.dbId, group.id, assignedById, expiresAt)
    
    if success then
        Permissions.reloadPlayerPermissions(source)
    end
    
    return success
end

local function removePlayerGroup(source, groupName)
    if not source or not groupName or type(groupName) ~= 'string' or groupName == '' then
        return false
    end
    
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    local group = Groups.getGroupByName(groupName)
    if not group then
        print('[CORE] ' .. Localize('server.group_not_exists', groupName))
        return false
    end
    
    local success = Database.removeGroupFromPlayer(player.dbId, group.id)
    
    if success then
        Permissions.reloadPlayerPermissions(source)
    end
    
    return success
end

exports('hasPermission', function(source, permission)
    return Permissions.hasPermission(source, permission)
end)

exports('hasGroup', function(source, groupName)
    return Permissions.hasGroup(source, groupName)
end)

exports('getPlayerPermissions', function(source)
    return Permissions.getPlayerPermissions(source)
end)

exports('getPlayerGroups', function(source)
    return Permissions.getPlayerGroups(source)
end)

exports('addPlayerGroup', function(source, groupName, expiresAt, assignedBy)
    return addPlayerGroup(source, groupName, expiresAt, assignedBy)
end)

exports('removePlayerGroup', function(source, groupName)
    return removePlayerGroup(source, groupName)
end)

exports('createGroup', function(groupName, displayName, priority, description)
    return Groups.createGroup(groupName, displayName, priority, description)
end)

exports('reloadPlayerPermissions', function(source)
    return Permissions.reloadPlayerPermissions(source)
end)

exports('getAllGroups', function()
    return Groups.getAllGroups()
end)

exports('deleteGroup', function(groupName)
    return Groups.deleteGroup(groupName)
end)

exports('updateGroup', function(groupName, displayName, priority, description)
    return Groups.updateGroup(groupName, displayName, priority, description)
end)

exports('removePermissionFromGroup', function(groupName, permissionName)
    local group = Groups.getGroupByName(groupName)
    if not group then
        return false
    end
    
    local permission = Database.findPermission(permissionName)
    if not permission then
        print('[CORE] ' .. Localize('server.permission_not_exists', permissionName))
        return false
    end
    
    return Database.removePermissionFromGroup(group.id, permission.id)
end)

exports('getAllPermissions', function()
    return Database.getAllPermissions()
end)

exports('deletePermission', function(permissionName)
    local permission = Database.findPermission(permissionName)
    if not permission then
        print('[CORE] ' .. Localize('server.permission_not_exists', permissionName))
        return false
    end
    
    return Database.deletePermission(permission.id)
end)

CreateThread(function()
    while true do
        Wait(60000)
        local count = Database.deactivateExpiredBans(Localize('server.ban_expired_auto'))
        if count > 0 then
            print('[CORE] ' .. Localize('server.expired_bans_deactivated', count))
        end
    end
end)

exports('banPlayerBySource', function(source, bannedBySource, reason, durationStr)
    return Moderation.banPlayerBySource(source, bannedBySource, reason, durationStr)
end)

exports('banPlayerByDbId', function(dbId, bannedBySource, reason, durationStr)
    return Moderation.banPlayerByDbId(dbId, bannedBySource, reason, durationStr)
end)

exports('unbanPlayer', function(target, unbannedBySource, reason)
    return Moderation.unbanPlayer(target, unbannedBySource, reason)
end)

exports('unbanPlayerByDbId', function(dbId, unbannedBySource, reason)
    return Moderation.unbanPlayerByDbId(dbId, unbannedBySource, reason)
end)

exports('warnPlayer', function(target, warnedBySource, reason)
    return Moderation.warnPlayer(target, warnedBySource, reason)
end)

exports('warnPlayerBySource', function(source, warnedBySource, reason)
    return Moderation.warnPlayerBySource(source, warnedBySource, reason)
end)

exports('warnPlayerByDbId', function(dbId, warnedBySource, reason)
    return Moderation.warnPlayerByDbId(dbId, warnedBySource, reason)
end)

exports('removeWarn', function(warnId, removedBySource, reason)
    return Moderation.removeWarn(warnId, removedBySource, reason)
end)

exports('kickPlayer', function(target, kickedBySource, reason)
    return Moderation.kickPlayer(target, kickedBySource, reason)
end)

exports('kickPlayerBySource', function(source, kickedBySource, reason)
    return Moderation.kickPlayerBySource(source, kickedBySource, reason)
end)

exports('isPlayerBanned', function(target)
    return Moderation.isPlayerBanned(target)
end)

exports('isPlayerBannedByDbId', function(dbId)
    return Moderation.isPlayerBannedByDbId(dbId)
end)

exports('getPlayerBans', function(target, includeInactive)
    return Moderation.getPlayerBans(target, includeInactive)
end)

exports('getPlayerBansByDbId', function(dbId, includeInactive)
    return Moderation.getPlayerBansByDbId(dbId, includeInactive)
end)

exports('getPlayerWarns', function(target, includeInactive)
    return Moderation.getPlayerWarns(target, includeInactive)
end)

exports('getPlayerWarnsByDbId', function(dbId, includeInactive)
    return Moderation.getPlayerWarnsByDbId(dbId, includeInactive)
end)

exports('setPlayerLanguage', function(source, language)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false, 'Player not found'
    end
    
    local availableLocales = LocalizationServer.getAvailableLocales()
    local isValid = false
    for _, lang in ipairs(availableLocales) do
        if lang == language then
            isValid = true
            break
        end
    end
    
    if not isValid then
        return false, 'Language not available: ' .. tostring(language)
    end
    
    PlayerCache.updateInCache(source, {language = language})
    Database.updatePlayerLanguage(player.dbId, language)
    
    return true
end)

exports('getPlayerLanguage', function(source)
    local player = PlayerCache.getFromCache(source)
    if player and player.language then
        return player.language
    end
    return exports.settings:GetSetting('core.default_language', 'ro') or 'ro'
end)

RegisterNetEvent('switcore:setLanguage', function(language)
    local source = source
    local success, error = exports.core:setPlayerLanguage(source, language)
    
    if success then
        TriggerClientEvent('switcore:languageChanged', source, language)
        sendLocaleToClient(source, language)
        
        local message = Localize('language.changed', source, language)
        TriggerClientEvent('switcore:localizedMessage', source, message)
    else
        TriggerClientEvent('switcore:languageError', source, error or 'Unknown error')
    end
end)

RegisterNetEvent('switcore:getLocalizedMessage', function(key, ...)
    local source = source
    local message = Localize(key, source, ...)
    TriggerClientEvent('switcore:localizedMessage', source, message)
end)

RegisterNetEvent('switcore:requestLocale', function(language)
    local source = source
    local player = PlayerCache.getFromCache(source)
    local playerLanguage = language or (player and player.language) or exports.settings:GetSetting('core.default_language', 'ro') or 'ro'
    sendLocaleToClient(source, playerLanguage)
end)

print('[CORE] Server module loading...')

