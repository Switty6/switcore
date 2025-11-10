CharacterCache = {}

-- Cache-uri în memorie
local characters = {}          -- characters[source] = {id, player_id, first_name, last_name, ...}
local characterById = {}       -- characterById[characterId] = source

-- Obține datele personajului din cache după source
function CharacterCache.getCharacter(source)
    source = tostring(source)
    return characters[source]
end

-- Obține source-ul după character ID
function CharacterCache.getSourceById(characterId)
    characterId = tostring(characterId)
    return characterById[characterId]
end

-- Setează personajul în cache
function CharacterCache.setCharacter(source, characterData)
    source = tostring(source)
    local characterId = tostring(characterData.id)
    local oldCharacter = characters[source]
    if oldCharacter then
        characterById[tostring(oldCharacter.id)] = nil
    end
    
    characters[source] = {
        id = characterData.id,
        player_id = characterData.player_id,
        first_name = characterData.first_name,
        last_name = characterData.last_name,
        age = characterData.age,
        position = characterData.position,
        appearance = characterData.appearance,
        stats = characterData.stats,
        metadata = characterData.metadata,
        playtime = characterData.playtime or 0,
        last_played = characterData.last_played,
        created_at = characterData.created_at,
        updated_at = characterData.updated_at
    }
    
    characterById[characterId] = tonumber(source)
end

-- Actualizează datele personajului în cache
function CharacterCache.updateCharacter(source, updates)
    source = tostring(source)
    local character = characters[source]
    
    if not character then
        return false
    end
    
    if updates.first_name then
        character.first_name = updates.first_name
    end
    if updates.last_name then
        character.last_name = updates.last_name
    end
    if updates.age then
        character.age = updates.age
    end
    if updates.position then
        character.position = updates.position
    end
    if updates.appearance then
        character.appearance = updates.appearance
    end
    if updates.stats then
        character.stats = updates.stats
    end
    if updates.metadata then
        character.metadata = updates.metadata
    end
    if updates.playtime then
        character.playtime = updates.playtime
    end
    if updates.last_played then
        character.last_played = updates.last_played
    end
    
    return true
end

-- Sterge un caracter din cache
function CharacterCache.removeCharacter(source)
    source = tostring(source)
    local character = characters[source]
    
    if not character then
        return false
    end
    
    local characterId = tostring(character.id)
    characterById[characterId] = nil
    characters[source] = nil
    
    return true
end

-- Obține toți caracterele din cache
function CharacterCache.getAllCharacters()
    local result = {}
    for source, character in pairs(characters) do
        result[tonumber(source)] = character
    end
    return result
end

-- Verifica daca un caracter exista in cache
function CharacterCache.hasCharacter(source)
    source = tostring(source)
    return characters[source] ~= nil
end

return CharacterCache

