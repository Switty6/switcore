PlayerCache = {}

-- Cache-uri în memorie
local players = {}             -- players[source] = {dbId, name, identifiers, last_seen, playtime}
local playerById = {}          -- playerById[dbId] = source
local identifierCache = {}     -- identifierCache[identifier] = dbId

-- Obține datele jucătorului din cache după source
function PlayerCache.getFromCache(source)
    source = tostring(source)
    return players[source]
end

-- Obține source-ul după dbId
function PlayerCache.getSourceById(dbId)
    dbId = tostring(dbId)
    return playerById[dbId]
end

-- Obține dbId-ul dintr-un identifier
function PlayerCache.getDbIdByIdentifier(identifier)
    return identifierCache[identifier]
end

-- Setează date în cache
function PlayerCache.setInCache(source, playerData)
    source = tostring(source)
    local dbId = tostring(playerData.dbId)
    
    players[source] = {
        dbId = playerData.dbId,
        name = playerData.name,
        identifiers = playerData.identifiers or {},
        last_seen = playerData.last_seen,
        playtime = playerData.playtime or 0,
        join_time = playerData.join_time or os.time(),
        groups = playerData.groups or {},
        permissions = playerData.permissions or {}
    }
    
    playerById[dbId] = tonumber(source)
    
    if playerData.identifiers then
        for _, identifier in ipairs(playerData.identifiers) do
            identifierCache[identifier] = playerData.dbId
        end
    end
end

-- Actualizează datele jucătorului în cache
function PlayerCache.updateInCache(source, updates)
    source = tostring(source)
    local player = players[source]
    
    if not player then
        return false
    end
    
    if updates.name then
        player.name = updates.name
    end
    if updates.last_seen then
        player.last_seen = updates.last_seen
    end
    if updates.playtime then
        player.playtime = updates.playtime
    end
    if updates.groups then
        player.groups = updates.groups
    end
    if updates.permissions then
        player.permissions = updates.permissions
    end
    if updates.identifiers then
        if player.identifiers then
            for _, oldIdentifier in ipairs(player.identifiers) do
                identifierCache[oldIdentifier] = nil
            end
        end
        player.identifiers = updates.identifiers
        for _, identifier in ipairs(updates.identifiers) do
            identifierCache[identifier] = player.dbId
        end
    end
    
    return true
end

-- Elimină jucătorul din cache
function PlayerCache.removeFromCache(source)
    source = tostring(source)
    local player = players[source]
    if not player then
        return false
    end
    local dbId = tostring(player.dbId)
    if player.identifiers then
        for _, identifier in ipairs(player.identifiers) do
            identifierCache[identifier] = nil
        end
    end
    playerById[dbId] = nil
    players[source] = nil
    return true
end

-- Obține toți jucătorii din cache
function PlayerCache.getAllPlayers()
    local result = {}
    for source, player in pairs(players) do
        result[tonumber(source)] = player
    end
    return result
end

-- Verifică dacă un identifier există în cache
function PlayerCache.hasIdentifier(identifier)
    return identifierCache[identifier] ~= nil
end

return PlayerCache

