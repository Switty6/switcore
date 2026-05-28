PlayerCache = {}

local players = {}
local playerById = {}
local identifierCache = {}

function PlayerCache.getFromCache(source)
    source = tostring(source)
    return players[source]
end

function PlayerCache.getSourceById(dbId)
    dbId = tostring(dbId)
    return playerById[dbId]
end

function PlayerCache.getDbIdByIdentifier(identifier)
    return identifierCache[identifier]
end

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
        permissions = playerData.permissions or {},
        language = playerData.language or 'ro'
    }
    
    playerById[dbId] = tonumber(source)
    
    if playerData.identifiers then
        for _, identifier in ipairs(playerData.identifiers) do
            identifierCache[identifier] = playerData.dbId
        end
    end
end

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
    if updates.language then
        player.language = updates.language
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

function PlayerCache.getAllPlayers()
    local result = {}
    for source, player in pairs(players) do
        result[tonumber(source)] = player
    end
    return result
end

function PlayerCache.hasIdentifier(identifier)
    return identifierCache[identifier] ~= nil
end

return PlayerCache
