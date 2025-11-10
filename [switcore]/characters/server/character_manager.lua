CharacterManager = {}

-- Verifica daca un jucator poate crea un caracter nou
function CharacterManager.canCreateCharacter(playerId)
    local count = CharacterDatabase.getPlayerCharacterCount(playerId)
    return count < Config.MAX_CHARACTERS_PER_PLAYER
end

-- Valideaza numele caracterului
function CharacterManager.validateCharacterName(firstName, lastName, source)
    source = source or nil
    
    if not firstName or firstName == '' then
        return false, exports.core:translate('characters.error_first_name_empty', source)
    end
    
    if not lastName or lastName == '' then
        return false, exports.core:translate('characters.error_last_name_empty', source)
    end
    
    local firstNameLen = #firstName
    if firstNameLen < Config.CHARACTER_FIRST_NAME_MIN_LENGTH then
        return false, exports.core:translate('characters.error_first_name_min', source, Config.CHARACTER_FIRST_NAME_MIN_LENGTH)
    end
    
    if firstNameLen > Config.CHARACTER_FIRST_NAME_MAX_LENGTH then
        return false, exports.core:translate('characters.error_first_name_max', source, Config.CHARACTER_FIRST_NAME_MAX_LENGTH)
    end
    
    local lastNameLen = #lastName
    if lastNameLen < Config.CHARACTER_LAST_NAME_MIN_LENGTH then
        return false, exports.core:translate('characters.error_last_name_min', source, Config.CHARACTER_LAST_NAME_MIN_LENGTH)
    end
    
    if lastNameLen > Config.CHARACTER_LAST_NAME_MAX_LENGTH then
        return false, exports.core:translate('characters.error_last_name_max', source, Config.CHARACTER_LAST_NAME_MAX_LENGTH)
    end
    
    if not firstName:match(Config.CHARACTER_NAME_PATTERN) then
        return false, exports.core:translate('characters.error_first_name_invalid', source)
    end
    
    if not lastName:match(Config.CHARACTER_NAME_PATTERN) then
        return false, exports.core:translate('characters.error_last_name_invalid', source)
    end
    
    firstName = firstName:match('^%s*(.-)%s*$')
    lastName = lastName:match('^%s*(.-)%s*$')
    
    if firstName == '' or lastName == '' then
        return false, exports.core:translate('characters.error_name_spaces_only', source)
    end
    
    return true, nil, firstName, lastName
end

-- Validează vârsta personajului
function CharacterManager.validateCharacterAge(age, source)
    source = source or nil
    
    if not age then
        return false, exports.core:translate('characters.error_age_required', source)
    end
    
    local ageNum = tonumber(age)
    if not ageNum then
        return false, exports.core:translate('characters.error_age_number', source)
    end
    
    if ageNum < Config.MIN_CHARACTER_AGE then
        return false, exports.core:translate('characters.error_age_min', source, Config.MIN_CHARACTER_AGE)
    end
    
    if ageNum > Config.MAX_CHARACTER_AGE then
        return false, exports.core:translate('characters.error_age_max', source, Config.MAX_CHARACTER_AGE)
    end
    
    return true, nil, math.floor(ageNum)
end

-- Selectează un personaj pentru un jucător
function CharacterManager.selectCharacter(source, characterId)
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return false, exports.core:translate('characters.error_player_not_found', source)
    end
    
    local character = CharacterDatabase.getCharacter(characterId)
    if not character then
        return false, exports.core:translate('characters.error_character_not_found', source)
    end
    
    if character.player_id ~= playerId then
        return false, exports.core:translate('characters.error_character_not_yours', source)
    end
    
    CharacterDatabase.updateCharacterLastPlayed(characterId)
    
    CharacterCache.setCharacter(source, character)
    
    TriggerEvent('switcore:characterSelected', source, characterId, character)
    
    return true, nil, character
end

-- Creeaza un caracter nou pentru un jucator
function CharacterManager.createCharacterForPlayer(source, firstName, lastName, age, appearance)
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return false, exports.core:translate('characters.error_player_not_found', source)
    end
    
    if not CharacterManager.canCreateCharacter(playerId) then
        return false, exports.core:translate('characters.error_character_limit', source, Config.MAX_CHARACTERS_PER_PLAYER)
    end
    
    local nameValid, nameError, cleanFirstName, cleanLastName = CharacterManager.validateCharacterName(firstName, lastName, source)
    if not nameValid then
        return false, nameError
    end
    
    local ageValid, ageError, cleanAge = CharacterManager.validateCharacterAge(age, source)
    if not ageValid then
        return false, ageError
    end
    
    local position = {
        x = Config.DEFAULT_SPAWN_POSITION.x,
        y = Config.DEFAULT_SPAWN_POSITION.y,
        z = Config.DEFAULT_SPAWN_POSITION.z,
        heading = Config.DEFAULT_SPAWN_POSITION.heading
    }
    
    local character = CharacterDatabase.createCharacter(
        playerId,
        cleanFirstName,
        cleanLastName,
        cleanAge,
        position,
        appearance or {},
        {},
        {}
    )
    
    if not character then
        return false, exports.core:translate('characters.error_creating_character', source)
    end
    
    CharacterManager.selectCharacter(source, character.id)
    
    return true, nil, character
end

-- Șterge un caracter pentru un jucător
function CharacterManager.deleteCharacterForPlayer(source, characterId)
    if not Config.ENABLE_CHARACTER_DELETION then
        return false, exports.core:translate('characters.error_deletion_disabled', source)
    end
    
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return false, exports.core:translate('characters.error_player_not_found', source)
    end
    
    local character = CharacterDatabase.getCharacter(characterId)
    if not character then
        return false, exports.core:translate('characters.error_character_not_found', source)
    end
    
    if character.player_id ~= playerId then
        return false, exports.core:translate('characters.error_character_not_yours', source)
    end
    
    local currentCharacter = CharacterCache.getCharacter(source)
    if currentCharacter and currentCharacter.id == characterId then
        CharacterCache.removeCharacter(source)
    end
    
    local success = CharacterDatabase.deleteCharacter(characterId)
    if not success then
        return false, exports.core:translate('characters.error_deleting_character', source)
    end
    
    return true, nil
end

-- Obține caracterele unui jucător
function CharacterManager.getPlayerCharacters(source)
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return {}
    end
    
    return CharacterDatabase.getPlayerCharacters(playerId)
end

return CharacterManager

