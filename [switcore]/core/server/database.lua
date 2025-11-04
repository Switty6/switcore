Database = {}

-- Helper pentru a obține export-ul postgres
local function getPostgres()
    return exports.postgres
end

-- Helper pentru a verifica dacă postgres e gata
local function ensurePostgres()
    local postgres = getPostgres()
    if not postgres then
        error('[CORE] Postgres resursa nu este disponibilă!')
        return false
    end
    
    if not postgres:isReady() then
        error('[CORE] Postgres nu este inițializat!')
        return false
    end
    
    return true
end

-- Helper pentru a construi lista de identifiers din rezultatul DB
local function buildIdentifierList(identifierRows)
    local identifierList = {}
    for _, idRow in ipairs(identifierRows) do
        table.insert(identifierList, idRow.type .. ':' .. idRow.value)
    end
    return identifierList
end

-- Găsește un jucător după identifier (query DB - pentru cold data)
function Database.findPlayerByIdentifier(identifier)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local result = postgres:queryOne(
        'SELECT player_id FROM player_identifiers WHERE value = $1',
        {identifier}
    )
    
    if not result then
        return nil
    end
    
    local playerId = result.player_id
    
    local player = postgres:queryOne(
        'SELECT * FROM players WHERE id = $1',
        {playerId}
    )
    
    if not player then
        return nil
    end
    
    local identifiers = postgres:queryAll(
        'SELECT type, value FROM player_identifiers WHERE player_id = $1',
        {playerId}
    )
    
    return {
        dbId = player.id,
        name = player.name,
        identifiers = buildIdentifierList(identifiers),
        last_seen = player.last_seen,
        playtime = player.playtime or 0,
        created_at = player.created_at
    }
end

-- Creează un jucător nou în DB (sync live: cache + DB)
function Database.createPlayer(identifiers, name)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    -- Verifică dacă unul dintre identifiers există deja în DB (race condition check)
    for _, identifier in ipairs(identifiers) do
        local existingPlayer = Database.findPlayerByIdentifier(identifier)
        if existingPlayer then
            print('[CORE] Jucătorul există deja (detectat în createPlayer): ID ' .. existingPlayer.dbId)
            return existingPlayer
        end
    end
    
    local playerResult = postgres:query(
        'INSERT INTO players (name, created_at, updated_at, last_seen, playtime) VALUES ($1, NOW(), NOW(), NOW(), 0) RETURNING *',
        {name}
    )
    
    if not playerResult or not playerResult.rows or not playerResult.rows[1] then
        print('[CORE] Eroare la crearea jucătorului în DB')
        return nil
    end
    
    local player = playerResult.rows[1]
    
    local playerId = player.id
    
    local identifierList = {}
    for _, identifier in ipairs(identifiers) do
        local idType, idValue = identifier:match('([^:]+):(.+)')
        if idType and idValue then
            local success, err = pcall(function()
                postgres:query(
                    'INSERT INTO player_identifiers (player_id, type, value, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (type, value) DO NOTHING',
                    {playerId, idType, idValue}
                )
            end)
            
            if not success then
                print('[CORE] Eroare la inserarea identifier-ului ' .. identifier .. ' pentru jucătorul ' .. playerId .. ': ' .. tostring(err))
            end
            
            table.insert(identifierList, identifier)
        end
    end
    
    return {
        dbId = player.id,
        name = player.name,
        identifiers = identifierList,
        last_seen = player.last_seen,
        playtime = player.playtime or 0,
        created_at = player.created_at
    }
end

-- Adaugă identifiers noi pentru un jucător (sync live)
function Database.updatePlayerIdentifiers(dbId, identifiers)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    for _, identifier in ipairs(identifiers) do
        local idType, idValue = identifier:match('([^:]+):(.+)')
        if idType and idValue then
            local success, err = pcall(function()
                postgres:query(
                    'INSERT INTO player_identifiers (player_id, type, value, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (type, value) DO NOTHING',
                    {dbId, idType, idValue}
                )
            end)
            
            if not success then
                print('[CORE] Eroare la actualizarea identifier-ului ' .. identifier .. ' pentru jucătorul ' .. dbId .. ': ' .. tostring(err))
            end
        end
    end
    
    return true
end

-- Actualizează last_seen pentru un jucător (sync live)
function Database.updatePlayerLastSeen(dbId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    postgres:query(
        'UPDATE players SET last_seen = NOW(), updated_at = NOW() WHERE id = $1',
        {dbId}
    )
    
    return true
end

-- Actualizează playtime pentru un jucător (sync live)
function Database.updatePlayerPlaytime(dbId, seconds)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    postgres:query(
        'UPDATE players SET playtime = $1, updated_at = NOW() WHERE id = $2',
        {seconds, dbId}
    )
    
    return true
end

-- Loghează activitate (sync live)
function Database.logActivity(dbId, eventType, command, metadata)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local metadataJson = nil
    if metadata then
        if json and json.encode then
            metadataJson = json.encode(metadata)
        else
            if type(metadata) == 'table' then
                local parts = {}
                for k, v in pairs(metadata) do
                    local value = type(v) == 'string' and ('"' .. v .. '"') or tostring(v)
                    table.insert(parts, '"' .. tostring(k) .. '":' .. value)
                end
                metadataJson = '{' .. table.concat(parts, ',') .. '}'
            else
                metadataJson = '"' .. tostring(metadata) .. '"'
            end
        end
    end
    
    -- Construiește query-ul și parametrii în funcție de ce date avem
    local query, params
    if metadataJson then
        if command then
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, metadata, created_at) VALUES ($1, $2, $3, $4::jsonb, NOW())'
            params = {dbId, eventType, command, metadataJson}
        else
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, metadata, created_at) VALUES ($1, $2, NULL, $3::jsonb, NOW())'
            params = {dbId, eventType, metadataJson}
        end
    else
        if command then
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, created_at) VALUES ($1, $2, $3, NOW())'
            params = {dbId, eventType, command}
        else
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, created_at) VALUES ($1, $2, NULL, NOW())'
            params = {dbId, eventType}
        end
    end
    
    postgres:query(query, params)
    
    return true
end

-- Obține identifiers pentru un jucător din DB (cold data)
function Database.getPlayerIdentifiers(dbId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local identifiers = postgres:queryAll(
        'SELECT type, value FROM player_identifiers WHERE player_id = $1',
        {dbId}
    )
    
    return buildIdentifierList(identifiers)
end

return Database

