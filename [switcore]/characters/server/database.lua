CharacterDatabase = {}

-- Helper pentru a obține export-ul postgres
local function getPostgres()
    return exports.postgres
end

-- Helper pentru a verifica dacă postgres e gata
local function ensurePostgres()
    local postgres = getPostgres()
    if not postgres then
        error('[CHARACTERS] Postgres resursa nu este disponibilă!')
        return false
    end
    
    if not postgres:isReady() then
        error('[CHARACTERS] Postgres nu este inițializat!')
        return false
    end
    
    return true
end

-- Helper pentru a serializa JSON
local function serializeJson(data)
    if json and json.encode then
        return json.encode(data)
    else
        if type(data) == 'table' then
            local parts = {}
            for k, v in pairs(data) do
                local key = type(k) == 'string' and ('"' .. k .. '"') or tostring(k)
                local value
                if type(v) == 'string' then
                    value = '"' .. v .. '"'
                elseif type(v) == 'table' then
                    value = serializeJson(v)
                else
                    value = tostring(v)
                end
                table.insert(parts, key .. ':' .. value)
            end
            return '{' .. table.concat(parts, ',') .. '}'
        else
            return '"' .. tostring(data) .. '"'
        end
    end
end

-- Creeaza un caracter nou
function CharacterDatabase.createCharacter(playerId, firstName, lastName, age, position, appearance, stats, metadata)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local positionJson = position and serializeJson(position) or nil
    local appearanceJson = appearance and serializeJson(appearance) or nil
    local statsJson = stats and serializeJson(stats) or nil
    local metadataJson = metadata and serializeJson(metadata) or nil
    
    local query = [[
        INSERT INTO characters (player_id, first_name, last_name, age, position, appearance, stats, metadata, playtime, last_played, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb, $8::jsonb, 0, NOW(), NOW(), NOW())
        RETURNING *
    ]]
    
    local result = postgres:query(query, {
        playerId,
        firstName,
        lastName,
        age,
        positionJson,
        appearanceJson,
        statsJson,
        metadataJson
    })
    
    if not result or not result.rows or not result.rows[1] then
        return nil
    end
    
    local character = result.rows[1]
    return {
        id = character.id,
        player_id = character.player_id,
        first_name = character.first_name,
        last_name = character.last_name,
        age = character.age,
        position = character.position,
        appearance = character.appearance,
        stats = character.stats,
        metadata = character.metadata,
        playtime = character.playtime or 0,
        last_played = character.last_played,
        created_at = character.created_at,
        updated_at = character.updated_at
    }
end

-- Obține toate caracterele unui jucator
function CharacterDatabase.getPlayerCharacters(playerId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local characters = postgres:queryAll(
        'SELECT * FROM characters WHERE player_id = $1 ORDER BY last_played DESC NULLS LAST, created_at DESC',
        {playerId}
    )
    
    local result = {}
    for _, char in ipairs(characters) do
        table.insert(result, {
            id = char.id,
            player_id = char.player_id,
            first_name = char.first_name,
            last_name = char.last_name,
            age = char.age,
            position = char.position,
            appearance = char.appearance,
            stats = char.stats,
            metadata = char.metadata,
            playtime = char.playtime or 0,
            last_played = char.last_played,
            created_at = char.created_at,
            updated_at = char.updated_at
        })
    end
    
    return result
end

-- Obține un caracter după ID
function CharacterDatabase.getCharacter(characterId)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local character = postgres:queryOne(
        'SELECT * FROM characters WHERE id = $1',
        {characterId}
    )
    
    if not character then
        return nil
    end
    
    return {
        id = character.id,
        player_id = character.player_id,
        first_name = character.first_name,
        last_name = character.last_name,
        age = character.age,
        position = character.position,
        appearance = character.appearance,
        stats = character.stats,
        metadata = character.metadata,
        playtime = character.playtime or 0,
        last_played = character.last_played,
        created_at = character.created_at,
        updated_at = character.updated_at
    }
end

-- Actualizeaza datele unui caracter
function CharacterDatabase.updateCharacter(characterId, updates)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local updateParts = {}
    local params = {}
    local paramCount = 0
    
    if updates.first_name then
        paramCount = paramCount + 1
        table.insert(updateParts, 'first_name = $' .. paramCount)
        table.insert(params, updates.first_name)
    end
    
    if updates.last_name then
        paramCount = paramCount + 1
        table.insert(updateParts, 'last_name = $' .. paramCount)
        table.insert(params, updates.last_name)
    end
    
    if updates.age then
        paramCount = paramCount + 1
        table.insert(updateParts, 'age = $' .. paramCount)
        table.insert(params, updates.age)
    end
    
    if updates.position then
        paramCount = paramCount + 1
        table.insert(updateParts, 'position = $' .. paramCount .. '::jsonb')
        table.insert(params, serializeJson(updates.position))
    end
    
    if updates.appearance then
        paramCount = paramCount + 1
        table.insert(updateParts, 'appearance = $' .. paramCount .. '::jsonb')
        table.insert(params, serializeJson(updates.appearance))
    end
    
    if updates.stats then
        paramCount = paramCount + 1
        table.insert(updateParts, 'stats = $' .. paramCount .. '::jsonb')
        table.insert(params, serializeJson(updates.stats))
    end
    
    if updates.metadata then
        paramCount = paramCount + 1
        table.insert(updateParts, 'metadata = $' .. paramCount .. '::jsonb')
        table.insert(params, serializeJson(updates.metadata))
    end
    
    if #updateParts == 0 then
        return false
    end
    
    paramCount = paramCount + 1
    table.insert(updateParts, 'updated_at = NOW()')
    table.insert(params, characterId)
    
    local query = 'UPDATE characters SET ' .. table.concat(updateParts, ', ') .. ' WHERE id = $' .. paramCount
    
    local success, err = pcall(function()
        postgres:query(query, params)
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la actualizarea personajului: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Sterge un caracter
function CharacterDatabase.deleteCharacter(characterId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query('DELETE FROM characters WHERE id = $1', {characterId})
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la ștergerea personajului: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Actualizeaza pozitia unui caracter
function CharacterDatabase.updateCharacterPosition(characterId, position)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local positionJson = serializeJson(position)
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE characters SET position = $1::jsonb, updated_at = NOW() WHERE id = $2',
            {positionJson, characterId}
        )
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la actualizarea poziției: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Actualizeaza statisticile unui caracter (JSONB stats field)
function CharacterDatabase.updateCharacterStats(characterId, stats)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local statsJson = serializeJson(stats)
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE characters SET stats = $1::jsonb, updated_at = NOW() WHERE id = $2',
            {statsJson, characterId}
        )
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la actualizarea statisticilor: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Obține toate statisticile unui caracter din tabelul character_statistics
function CharacterDatabase.getCharacterStatistics(characterId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local stats = postgres:queryAll(
        'SELECT stat_name, stat_value, updated_at FROM character_statistics WHERE character_id = $1',
        {characterId}
    )
    
    local result = {}
    for _, stat in ipairs(stats) do
        result[stat.stat_name] = {
            value = tonumber(stat.stat_value) or 0,
            updated_at = stat.updated_at
        }
    end
    
    return result
end

-- Actualizeaza o statistica specifica
function CharacterDatabase.updateCharacterStatistic(characterId, statName, value)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'INSERT INTO character_statistics (character_id, stat_name, stat_value, updated_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (character_id, stat_name) DO UPDATE SET stat_value = $3, updated_at = NOW()',
            {characterId, statName, value}
        )
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la actualizarea statisticii: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Incrementează o statistică
function CharacterDatabase.incrementCharacterStatistic(characterId, statName, amount)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'INSERT INTO character_statistics (character_id, stat_name, stat_value, updated_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (character_id, stat_name) DO UPDATE SET stat_value = character_statistics.stat_value + $3, updated_at = NOW()',
            {characterId, statName, amount or 1}
        )
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la incrementarea statisticii: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Actualizeaza playtime-ul unui caracter
function CharacterDatabase.updateCharacterPlaytime(characterId, seconds)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE characters SET playtime = $1, updated_at = NOW() WHERE id = $2',
            {seconds, characterId}
        )
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la actualizarea playtime-ului: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Actualizeaza last_played timestamp
function CharacterDatabase.updateCharacterLastPlayed(characterId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE characters SET last_played = NOW(), updated_at = NOW() WHERE id = $1',
            {characterId}
        )
    end)
    
    if not success then
        print('[CHARACTERS] Eroare la actualizarea last_played: ' .. tostring(err))
        return false
    end
    
    return true
end

-- Obține numărul de caractere pentru un jucator
function CharacterDatabase.getPlayerCharacterCount(playerId)
    if not ensurePostgres() then
        return 0
    end
    
    local postgres = getPostgres()
    
    local result = postgres:queryOne(
        'SELECT COUNT(*) as count FROM characters WHERE player_id = $1',
        {playerId}
    )
    
    if not result then
        return 0
    end
    
    return tonumber(result.count) or 0
end

return CharacterDatabase

