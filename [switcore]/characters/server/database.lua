CharacterDatabase = {}

local pg = exports.postgres

local function safeJson(v)
    if type(v) ~= 'string' then return v end
    local ok, decoded = pcall(json.decode, v)
    if ok then return decoded end
    return nil
end

local function mapChar(c)
    if not c then return nil end
    return {
        id          = c.id,
        player_id   = c.player_id,
        first_name  = c.first_name,
        last_name   = c.last_name,
        age         = tonumber(c.age)      or 0,
        position    = safeJson(c.position),
        appearance  = safeJson(c.appearance),
        stats       = safeJson(c.stats),
        metadata    = safeJson(c.metadata),
        playtime    = tonumber(c.playtime) or 0,
        last_played = c.last_played,
        created_at  = c.created_at,
        updated_at  = c.updated_at
    }
end

local function dbRun(query, params, label)
    local ok, err = pcall(pg.query, pg, query, params)
    if not ok then
        print('[CHARACTERS DB] ' .. (label or 'query') .. ': ' .. tostring(err))
    end
    return ok
end

function CharacterDatabase.createCharacter(playerId, firstName, lastName, age, position, appearance, stats, metadata)
    if not pg:isReady() then return nil end

    local result = pg:query([[
        INSERT INTO characters (player_id, first_name, last_name, age, position, appearance, stats, metadata, playtime, last_played, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb, $8::jsonb, 0, NOW(), NOW(), NOW())
        RETURNING *
    ]], {
        playerId, firstName, lastName, age,
        position   and json.encode(position)   or nil,
        appearance and json.encode(appearance) or nil,
        stats      and json.encode(stats)      or nil,
        metadata   and json.encode(metadata)   or nil,
    })

    return result and result.rows and mapChar(result.rows[1])
end

function CharacterDatabase.getPlayerCharacters(playerId)
    if not pg:isReady() then return {} end

    local rows = pg:queryAll(
        'SELECT * FROM characters WHERE player_id = $1 ORDER BY last_played DESC NULLS LAST, created_at DESC',
        {playerId}
    ) or {}

    local result = {}
    for _, c in ipairs(rows) do
        result[#result + 1] = mapChar(c)
    end
    return result
end

function CharacterDatabase.getCharacter(characterId)
    if not pg:isReady() then return nil end
    return mapChar(pg:queryOne('SELECT * FROM characters WHERE id = $1', {characterId}))
end

function CharacterDatabase.updateCharacter(characterId, updates)
    if not pg:isReady() then return false end

    local JSON_FIELDS = { position = true, appearance = true, stats = true, metadata = true }
    local FIELDS      = { 'first_name', 'last_name', 'age', 'position', 'appearance', 'stats', 'metadata' }
    local parts, params, n = {}, {}, 0

    for _, f in ipairs(FIELDS) do
        if updates[f] ~= nil then
            n = n + 1
            params[n] = JSON_FIELDS[f] and json.encode(updates[f]) or updates[f]
            parts[#parts + 1] = f .. ' = $' .. n .. (JSON_FIELDS[f] and '::jsonb' or '')
        end
    end

    if n == 0 then return false end

    n = n + 1
    params[n] = characterId
    parts[#parts + 1] = 'updated_at = NOW()'

    return dbRun('UPDATE characters SET ' .. table.concat(parts, ', ') .. ' WHERE id = $' .. n, params, 'updateCharacter')
end

function CharacterDatabase.deleteCharacter(characterId)
    if not pg:isReady() then return false end
    return dbRun('DELETE FROM characters WHERE id = $1', {characterId}, 'deleteCharacter')
end

function CharacterDatabase.updateCharacterPosition(characterId, position)
    if not pg:isReady() then return false end
    return dbRun(
        'UPDATE characters SET position = $1::jsonb, updated_at = NOW() WHERE id = $2',
        {json.encode(position), characterId}, 'updatePosition'
    )
end

function CharacterDatabase.updateCharacterStats(characterId, stats)
    if not pg:isReady() then return false end
    return dbRun(
        'UPDATE characters SET stats = $1::jsonb, updated_at = NOW() WHERE id = $2',
        {json.encode(stats), characterId}, 'updateStats'
    )
end

function CharacterDatabase.getCharacterStatistics(characterId)
    if not pg:isReady() then return {} end

    local rows = pg:queryAll(
        'SELECT stat_name, stat_value, updated_at FROM character_statistics WHERE character_id = $1',
        {characterId}
    ) or {}

    local result = {}
    for _, stat in ipairs(rows) do
        result[stat.stat_name] = { value = tonumber(stat.stat_value) or 0, updated_at = stat.updated_at }
    end
    return result
end

function CharacterDatabase.updateCharacterStatistic(characterId, statName, value)
    if not pg:isReady() then return false end
    return dbRun(
        'INSERT INTO character_statistics (character_id, stat_name, stat_value, updated_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (character_id, stat_name) DO UPDATE SET stat_value = $3, updated_at = NOW()',
        {characterId, statName, value}, 'updateStatistic'
    )
end

function CharacterDatabase.incrementCharacterStatistic(characterId, statName, amount)
    if not pg:isReady() then return false end
    return dbRun(
        'INSERT INTO character_statistics (character_id, stat_name, stat_value, updated_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (character_id, stat_name) DO UPDATE SET stat_value = character_statistics.stat_value + $3, updated_at = NOW()',
        {characterId, statName, amount or 1}, 'incrementStatistic'
    )
end

function CharacterDatabase.updateCharacterPlaytime(characterId, seconds)
    if not pg:isReady() then return false end
    return dbRun(
        'UPDATE characters SET playtime = $1, updated_at = NOW() WHERE id = $2',
        {seconds, characterId}, 'updatePlaytime'
    )
end

function CharacterDatabase.updateCharacterLastPlayed(characterId)
    if not pg:isReady() then return false end
    return dbRun(
        'UPDATE characters SET last_played = NOW(), updated_at = NOW() WHERE id = $1',
        {characterId}, 'updateLastPlayed'
    )
end

function CharacterDatabase.selectCharacterForPlayer(characterId, playerId)
    if not pg:isReady() then return nil end
    local result = pg:query([[
        UPDATE characters
        SET last_played = NOW(), updated_at = NOW()
        WHERE id = $1 AND player_id = $2
        RETURNING *
    ]], {characterId, playerId})
    return result and result.rows and mapChar(result.rows[1])
end

function CharacterDatabase.getPlayerCharacterCount(playerId)
    if not pg:isReady() then return 0 end
    local result = pg:queryOne('SELECT COUNT(*) as count FROM characters WHERE player_id = $1', {playerId})
    return result and tonumber(result.count) or 0
end

return CharacterDatabase
