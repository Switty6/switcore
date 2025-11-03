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

-- Găsește sau creează un jucător bazat pe identifiers
local function findOrCreatePlayer(source, identifiers, name)
    for _, identifier in ipairs(identifiers) do
        if PlayerCache.hasIdentifier(identifier) then
            local dbId = PlayerCache.getDbIdByIdentifier(identifier)
            if dbId then
                local cachedPlayer = PlayerCache.getFromCache(source)
                if not cachedPlayer or cachedPlayer.dbId ~= dbId then
                    local playerData = Database.findPlayerByIdentifier(identifier)
                    if playerData then
                        Database.updatePlayerIdentifiers(playerData.dbId, identifiers)
                        
                        for _, newId in ipairs(identifiers) do
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
                        
                        PlayerCache.setInCache(source, playerData)
                        
                        return playerData
                    end
                else
                    return cachedPlayer
                end
            end
        end
    end
    
    for _, identifier in ipairs(identifiers) do
        local playerData = Database.findPlayerByIdentifier(identifier)
        if playerData then
            Database.updatePlayerIdentifiers(playerData.dbId, identifiers)
            
            for _, newId in ipairs(identifiers) do
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
            
            PlayerCache.setInCache(source, playerData)
            return playerData
        end
    end
    
    for _, identifier in ipairs(identifiers) do
        if PlayerCache.hasIdentifier(identifier) then
            local dbId = PlayerCache.getDbIdByIdentifier(identifier)
            if dbId then
                local cachedPlayer = PlayerCache.getFromCache(source)
                if cachedPlayer then
                    return cachedPlayer
                end
                local sourceById = PlayerCache.getSourceById(dbId)
                if sourceById then
                    local player = PlayerCache.getFromCache(sourceById)
                    if player then
                        PlayerCache.setInCache(source, player)
                        return player
                    end
                end
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
        return
    end
    
    local playerData = findOrCreatePlayer(source, identifiers, name)
    
    if playerData then
        Database.updatePlayerLastSeen(playerData.dbId)
        PlayerCache.updateInCache(source, {last_seen = os.time()})
        
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
        PlayerCache.setInCache(source, oldPlayer)
        PlayerCache.removeFromCache(tostring(oldId))
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
                PlaytimeTracker.startTracking(source)
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

-- Emite eveniment când jucătorul e încărcat
CreateThread(function()
    while true do
        Wait(1000)
        
        local allPlayers = GetPlayers()
        for _, playerId in ipairs(allPlayers) do
            local source = tonumber(playerId)
            if source then
                local player = PlayerCache.getFromCache(source)
                if player and not player._eventEmitted then
                    player._eventEmitted = true
                    TriggerEvent('switcore:playerLoaded', source, player.dbId, player)
                end
            end
        end
    end
end)

print('[CORE] Server module încărcat')

