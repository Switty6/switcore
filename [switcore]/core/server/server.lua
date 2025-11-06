-- Așteaptă ca postgres să fie gata
CreateThread(function()
    while not exports.postgres:isReady() do
        Wait(100)
    end
    
    print('[CORE] PostgreSQL este gata, inițializăm core-ul...')
    InitializeCore()
end)

function InitializeCore()
    -- Setează intervalul de actualizare playtime
    if Config and Config.PLAYTIME_UPDATE_INTERVAL then
        PlaytimeTracker.setUpdateInterval(Config.PLAYTIME_UPDATE_INTERVAL)
    end
    
    -- Inițializează grupurile default
    Groups.initializeDefaults()
    
    print('[CORE] Core inițializat cu succes')
end

-- Helper pentru a verifica dacă un identifier este blocat
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

-- Obține TOȚI identifiers pentru un jucător (fără cele blocate)
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

-- Helper pentru a adăuga identifiers noi la playerData (dacă nu există deja)
local function mergeIdentifiers(playerData, newIdentifiers)
    for _, newId in ipairs(newIdentifiers) do
        local found = false
        for _, existingId in ipairs(playerData.identifiers) do
            if existingId == newId then
                found = true
                break
            end
        end
        if not found then
            table.insert(playerData.identifiers, newId)
        end
    end
end

-- Găsește sau creează un jucător bazat pe identifiers
local function findOrCreatePlayer(source, identifiers, name)
    for _, identifier in ipairs(identifiers) do
        if PlayerCache.hasIdentifier(identifier) then
            local dbId = PlayerCache.getDbIdByIdentifier(identifier)
            if dbId then
                local existingSource = PlayerCache.getSourceById(dbId)
                if existingSource then
                    local existingPlayer = PlayerCache.getFromCache(existingSource)
                    if existingPlayer then
                        mergeIdentifiers(existingPlayer, identifiers)
                        Database.updatePlayerIdentifiers(dbId, identifiers)
                        PlayerCache.setInCache(source, existingPlayer)
                        return existingPlayer
                    end
                end
                
                local playerData = Database.findPlayerByIdentifier(identifier)
                if playerData then
                    mergeIdentifiers(playerData, identifiers)
                    Database.updatePlayerIdentifiers(playerData.dbId, identifiers)
                    PlayerCache.setInCache(source, playerData)
                    return playerData
                end
            end
        end
    end
    
    for _, identifier in ipairs(identifiers) do
        if not PlayerCache.hasIdentifier(identifier) then
            local playerData = Database.findPlayerByIdentifier(identifier)
            if playerData then
                mergeIdentifiers(playerData, identifiers)
                Database.updatePlayerIdentifiers(playerData.dbId, identifiers)
                PlayerCache.setInCache(source, playerData)
                return playerData
            end
        end
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

-- Gestionează conectarea jucătorului
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    
    local identifiers = getPlayerIdentifiers(source)
    
    if #identifiers == 0 then
        print('[CORE] Jucătorul ' .. name .. ' nu are identifiers valizi')
        setKickReason('Eroare: Nu ai identifiers valizi')
        CancelEvent()
        return
    end
    
    for _, identifier in ipairs(identifiers) do
        local ban = Database.getActiveBanByIdentifier(identifier)
        if ban then
            local banMessage = 'Ai fost banat'
            if ban.reason then
                banMessage = banMessage .. ' pentru: ' .. ban.reason
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
                        banMessage = banMessage .. ' | Expiră în: ' .. days .. 'd ' .. hours .. 'h ' .. minutes .. 'm'
                    else
                        Database.unban(ban.id, nil, 'Ban expirat automat')
                        break
                    end
                end
            else
                banMessage = banMessage .. ' | Ban permanent'
            end
            
            print('[CORE] Jucător banat a încercat să se conecteze: ' .. name)
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
        PlayerCache.updateInCache(source, {
            groups = groups,
            permissions = permissions
        })
        
        PlaytimeTracker.startTracking(source)
        
        if not playerData._justCreated then
            Database.logActivity(playerData.dbId, 'join', nil, {
                identifiers = identifiers,
                source = source
            })
        end
        
        print('[CORE] Jucător încărcat: ' .. name .. ' (ID: ' .. playerData.dbId .. ')')
    else
        print('[CORE] Eroare la încărcarea jucătorului: ' .. name)
        setKickReason('Eroare la încărcarea datelor jucătorului')
        CancelEvent()
    end
end)

-- Gestionează jucătorul care intră în joc (după playerConnecting)
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
        print('[CORE] Warning: Jucătorul ' .. source .. ' nu a fost găsit în cache la playerJoining')
    end
end)

-- Gestionează deconectarea jucătorului
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
        
        print('[CORE] Jucător deconectat: ' .. player.name .. ' (ID: ' .. player.dbId .. ')')
    end
end)

-- Inițializează jucătorii deja conectați la restart resursă
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

-- ==================== EXPORTS ====================

-- Obține ID-ul jucătorului din DB (read din cache)
exports('getPlayerId', function(source)
    local player = PlayerCache.getFromCache(source)
    return player and player.dbId or nil
end)

-- Obține datele jucătorului după dbId (read din cache)
exports('getPlayerById', function(dbId)
    local source = PlayerCache.getSourceById(dbId)
    if source then
        return PlayerCache.getFromCache(source)
    end
    return nil
end)

-- Caută jucător după identifier (read din cache)
exports('getPlayerIdFromIdentifier', function(identifier)
    return PlayerCache.getDbIdByIdentifier(identifier)
end)

-- Obține identifiers pentru un jucător (read din cache)
exports('getPlayerIdentifiers', function(dbId)
    local player = exports.core:getPlayerById(dbId)
    return player and player.identifiers or {}
end)

-- Obține datele complete ale jucătorului (read din cache)
exports('getPlayerData', function(source)
    return PlayerCache.getFromCache(source)
end)

-- Loghează activitate manuală (write cache + DB)
exports('logPlayerActivity', function(source, eventType, metadata)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    return Database.logActivity(player.dbId, eventType, nil, metadata)
end)

-- Actualizează playtime manual (write cache + DB)
exports('updatePlayerPlaytime', function(source, seconds)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    PlayerCache.updateInCache(source, {playtime = seconds})
    return Database.updatePlayerPlaytime(player.dbId, seconds)
end)

-- ==================== FUNCȚII PERMISIUNI ====================

-- Adaugă grup la jucător (logică)
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
        print('[CORE] Grupul ' .. groupName .. ' nu există')
        return false
    end
    
    local assignedById = nil
    if assignedBy then
        local assignedByPlayer = PlayerCache.getFromCache(assignedBy)
        if assignedByPlayer then
            assignedById = assignedByPlayer.dbId
        end
    end
    
    local expiresAtTimestamp = nil
    if expiresAt then
        expiresAtTimestamp = expiresAt
    end
    
    local success = Database.addGroupToPlayer(player.dbId, group.id, assignedById, expiresAtTimestamp)
    
    if success then
        Permissions.reloadPlayerPermissions(source)
    end
    
    return success
end

-- Elimină grup de la jucător (logică)
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
        print('[CORE] Grupul ' .. groupName .. ' nu există')
        return false
    end
    
    local success = Database.removeGroupFromPlayer(player.dbId, group.id)
    
    if success then
        Permissions.reloadPlayerPermissions(source)
    end
    
    return success
end

-- ==================== EXPORTS PERMISIUNI ====================

-- Verifică dacă un jucător are o permisiune
exports('hasPermission', function(source, permission)
    return Permissions.hasPermission(source, permission)
end)

-- Verifică dacă un jucător are un grup
exports('hasGroup', function(source, groupName)
    return Permissions.hasGroup(source, groupName)
end)

-- Obține toate permisiunile unui jucător
exports('getPlayerPermissions', function(source)
    return Permissions.getPlayerPermissions(source)
end)

-- Obține toate grupurile unui jucător
exports('getPlayerGroups', function(source)
    return Permissions.getPlayerGroups(source)
end)

-- Adaugă grup la jucător
exports('addPlayerGroup', function(source, groupName, expiresAt, assignedBy)
    return addPlayerGroup(source, groupName, expiresAt, assignedBy)
end)

-- Elimină grup de la jucător
exports('removePlayerGroup', function(source, groupName)
    return removePlayerGroup(source, groupName)
end)

-- Creează un grup nou
exports('createGroup', function(groupName, displayName, priority, description)
    return Groups.createGroup(groupName, displayName, priority, description)
end)

-- Reîncarcă permisiunile unui jucător
exports('reloadPlayerPermissions', function(source)
    return Permissions.reloadPlayerPermissions(source)
end)

-- Obține toate grupurile
exports('getAllGroups', function()
    return Groups.getAllGroups()
end)

-- Șterge un grup
exports('deleteGroup', function(groupName)
    return Groups.deleteGroup(groupName)
end)

-- Actualizează un grup
exports('updateGroup', function(groupName, displayName, priority, description)
    return Groups.updateGroup(groupName, displayName, priority, description)
end)

-- Elimină permisiune dintr-un grup
exports('removePermissionFromGroup', function(groupName, permissionName)
    local group = Groups.getGroupByName(groupName)
    if not group then
        return false
    end
    
    local permission = Database.findPermission(permissionName)
    if not permission then
        print('[CORE] Permisiunea ' .. permissionName .. ' nu există')
        return false
    end
    
    return Database.removePermissionFromGroup(group.id, permission.id)
end)

-- Obține toate permisiunile
exports('getAllPermissions', function()
    return Database.getAllPermissions()
end)

-- Șterge o permisiune
exports('deletePermission', function(permissionName)
    local permission = Database.findPermission(permissionName)
    if not permission then
        print('[CORE] Permisiunea ' .. permissionName .. ' nu există')
        return false
    end
    
    return Database.deletePermission(permission.id)
end)

-- Emite eveniment când jucătorul e încărcat
CreateThread(function()
    while true do
        Wait(1000)
        
        local allPlayers = GetPlayers()
        for _, playerId in ipairs(allPlayers) do
            local source = tonumber(playerId)
            if source then
                local player = PlayerCache.getFromCache(source)
                if player then
                    TriggerEvent('switcore:playerLoaded', source, player.dbId, player)
                end
            end
        end
    end
end)

-- Thread pentru curățarea ban-urilor expirate
CreateThread(function()
    while true do
        Wait(60000)
        
        if exports.postgres and exports.postgres:isReady() then
            local postgres = exports.postgres
            
            local expiredBans = postgres:queryAll(
                'SELECT id FROM bans WHERE is_active = true AND expires_at IS NOT NULL AND expires_at <= NOW()',
                {}
            )
            
            if expiredBans and #expiredBans > 0 then
                for _, ban in ipairs(expiredBans) do
                    Database.unban(ban.id, nil, 'Ban expirat automat')
                end
                print('[CORE] ' .. #expiredBans .. ' ban-uri expirate au fost dezactivate automat')
            end
        end
    end
end)

-- ==================== EXPORTS MODERARE ====================

-- Ban un jucător după source
exports('banPlayerBySource', function(source, bannedBySource, reason, durationStr)
    return Moderation.banPlayerBySource(source, bannedBySource, reason, durationStr)
end)

-- Ban un jucător după dbId
exports('banPlayerByDbId', function(dbId, bannedBySource, reason, durationStr)
    return Moderation.banPlayerByDbId(dbId, bannedBySource, reason, durationStr)
end)

-- Unban un jucător (compatibilitate)
exports('unbanPlayer', function(target, unbannedBySource, reason)
    return Moderation.unbanPlayer(target, unbannedBySource, reason)
end)

-- Unban un jucător după dbId
exports('unbanPlayerByDbId', function(dbId, unbannedBySource, reason)
    return Moderation.unbanPlayerByDbId(dbId, unbannedBySource, reason)
end)

-- Warn un jucător (compatibilitate)
exports('warnPlayer', function(target, warnedBySource, reason)
    return Moderation.warnPlayer(target, warnedBySource, reason)
end)

-- Warn un jucător după source
exports('warnPlayerBySource', function(source, warnedBySource, reason)
    return Moderation.warnPlayerBySource(source, warnedBySource, reason)
end)

-- Warn un jucător după dbId
exports('warnPlayerByDbId', function(dbId, warnedBySource, reason)
    return Moderation.warnPlayerByDbId(dbId, warnedBySource, reason)
end)

-- Remove warn
exports('removeWarn', function(warnId, removedBySource, reason)
    return Moderation.removeWarn(warnId, removedBySource, reason)
end)

-- Kick un jucător (compatibilitate)
exports('kickPlayer', function(target, kickedBySource, reason)
    return Moderation.kickPlayer(target, kickedBySource, reason)
end)

-- Kick un jucător după source
exports('kickPlayerBySource', function(source, kickedBySource, reason)
    return Moderation.kickPlayerBySource(source, kickedBySource, reason)
end)

-- Verifică dacă un jucător este banat (compatibilitate)
exports('isPlayerBanned', function(target)
    return Moderation.isPlayerBanned(target)
end)

-- Verifică dacă un jucător este banat după dbId
exports('isPlayerBannedByDbId', function(dbId)
    return Moderation.isPlayerBannedByDbId(dbId)
end)

-- Obține ban-urile unui jucător (compatibilitate)
exports('getPlayerBans', function(target, includeInactive)
    return Moderation.getPlayerBans(target, includeInactive)
end)

-- Obține ban-urile unui jucător după dbId
exports('getPlayerBansByDbId', function(dbId, includeInactive)
    return Moderation.getPlayerBansByDbId(dbId, includeInactive)
end)

-- Obține warn-urile unui jucător (compatibilitate)
exports('getPlayerWarns', function(target, includeInactive)
    return Moderation.getPlayerWarns(target, includeInactive)
end)

-- Obține warn-urile unui jucător după dbId
exports('getPlayerWarnsByDbId', function(dbId, includeInactive)
    return Moderation.getPlayerWarnsByDbId(dbId, includeInactive)
end)

print('[CORE] Server module încărcat')

