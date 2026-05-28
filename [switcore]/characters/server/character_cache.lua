CharacterCache = {}

local characters    = {}
local characterById = {}

local UPDATABLE = { 'first_name', 'last_name', 'age', 'position', 'appearance', 'stats', 'metadata', 'playtime', 'last_played' }

function CharacterCache.getCharacter(source)
    return characters[tostring(source)]
end

function CharacterCache.getSourceById(characterId)
    return characterById[tostring(characterId)]
end

function CharacterCache.setCharacter(source, d)
    source = tostring(source)
    local old = characters[source]
    if old then characterById[tostring(old.id)] = nil end

    characters[source] = {
        id          = d.id,
        player_id   = d.player_id,
        first_name  = d.first_name,
        last_name   = d.last_name,
        age         = d.age,
        position    = d.position,
        appearance  = d.appearance,
        stats       = d.stats,
        metadata    = d.metadata,
        playtime    = d.playtime or 0,
        last_played = d.last_played,
        created_at  = d.created_at,
        updated_at  = d.updated_at
    }

    characterById[tostring(d.id)] = tonumber(source)
end

function CharacterCache.updateCharacter(source, updates)
    local char = characters[tostring(source)]
    if not char then return false end
    for _, f in ipairs(UPDATABLE) do
        if updates[f] ~= nil then char[f] = updates[f] end
    end
    return true
end

function CharacterCache.removeCharacter(source)
    source = tostring(source)
    local char = characters[source]
    if not char then return false end
    characterById[tostring(char.id)] = nil
    characters[source] = nil
    return true
end

function CharacterCache.getAllCharacters()
    local result = {}
    for src, char in pairs(characters) do
        result[tonumber(src)] = char
    end
    return result
end

return CharacterCache
