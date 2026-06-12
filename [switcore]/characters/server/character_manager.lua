CharacterManager = {}

function CharacterManager.canCreateCharacter(playerId)
    local count = CharacterDatabase.getPlayerCharacterCount(playerId)
    return count < exports.settings:GetSettingNumber('characters.max_per_player', 3)
end

function CharacterManager.validateCharacterName(firstName, lastName, source)
    if not firstName or firstName == '' then
        return false, Sw.TP(source, 'characters.error_first_name_empty')
    end
    if not lastName or lastName == '' then
        return false, Sw.TP(source, 'characters.error_last_name_empty')
    end

    local s       = exports.settings
    local fnMin   = s:GetSettingNumber('characters.first_name_min_length', 2)
    local fnMax   = s:GetSettingNumber('characters.first_name_max_length', 20)
    local lnMin   = s:GetSettingNumber('characters.last_name_min_length', 2)
    local lnMax   = s:GetSettingNumber('characters.last_name_max_length', 20)
    local pattern = s:GetSetting('characters.name_pattern', '^[%w%s%-%\'%.]+$')

    local fnLen = #firstName
    if fnLen < fnMin then return false, Sw.TP(source, 'characters.error_first_name_min', fnMin) end
    if fnLen > fnMax then return false, Sw.TP(source, 'characters.error_first_name_max', fnMax) end

    local lnLen = #lastName
    if lnLen < lnMin then return false, Sw.TP(source, 'characters.error_last_name_min', lnMin) end
    if lnLen > lnMax then return false, Sw.TP(source, 'characters.error_last_name_max', lnMax) end

    if not firstName:match(pattern) then return false, Sw.TP(source, 'characters.error_first_name_invalid') end
    if not lastName:match(pattern)  then return false, Sw.TP(source, 'characters.error_last_name_invalid') end

    firstName = firstName:match('^%s*(.-)%s*$')
    lastName  = lastName:match('^%s*(.-)%s*$')

    if firstName == '' or lastName == '' then
        return false, Sw.TP(source, 'characters.error_name_spaces_only')
    end

    return true, nil, firstName, lastName
end

function CharacterManager.validateCharacterAge(age, source)
    if not age then
        return false, Sw.TP(source, 'characters.error_age_required')
    end

    local ageNum = tonumber(age)
    if not ageNum then
        return false, Sw.TP(source, 'characters.error_age_number')
    end

    local minAge = exports.settings:GetSettingNumber('characters.min_age', 18)
    local maxAge = exports.settings:GetSettingNumber('characters.max_age', 80)

    if ageNum < minAge then return false, Sw.TP(source, 'characters.error_age_min', minAge) end
    if ageNum > maxAge then return false, Sw.TP(source, 'characters.error_age_max', maxAge) end

    return true, nil, math.floor(ageNum)
end

function CharacterManager.selectCharacter(source, characterId)
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return false, Sw.TP(source, 'characters.error_player_not_found')
    end

    local character = CharacterDatabase.selectCharacterForPlayer(characterId, playerId)
    if not character then
        return false, Sw.TP(source, 'characters.error_character_not_yours')
    end

    CharacterCache.setCharacter(source, character)
    TriggerEvent('switcore:characterSelected', source, characterId, character)
    return true, nil, character
end

function CharacterManager.createCharacterForPlayer(source, firstName, lastName, age, appearance)
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return false, Sw.TP(source, 'characters.error_player_not_found')
    end

    if not CharacterManager.canCreateCharacter(playerId) then
        return false, Sw.TP(source, 'characters.error_character_limit', exports.settings:GetSettingNumber('characters.max_per_player', 3))
    end

    local nameValid, nameError, cleanFirstName, cleanLastName = CharacterManager.validateCharacterName(firstName, lastName, source)
    if not nameValid then return false, nameError end

    local ageValid, ageError, cleanAge = CharacterManager.validateCharacterAge(age, source)
    if not ageValid then return false, ageError end

    local s = exports.settings
    local position = {
        x       = s:GetSettingNumber('characters.spawn_x',       -269.4),
        y       = s:GetSettingNumber('characters.spawn_y',       -955.3),
        z       = s:GetSettingNumber('characters.spawn_z',         31.2),
        heading = s:GetSettingNumber('characters.spawn_heading',  205.8),
    }

    local character = CharacterDatabase.createCharacter(
        playerId, cleanFirstName, cleanLastName, cleanAge,
        position, appearance or {}, {}, {}
    )

    if not character then
        return false, Sw.TP(source, 'characters.error_creating_character')
    end

    CharacterManager.selectCharacter(source, character.id)
    return true, nil, character
end

function CharacterManager.deleteCharacterForPlayer(source, characterId)
    if not exports.settings:GetSettingBool('characters.enable_deletion', true) then
        return false, Sw.TP(source, 'characters.error_deletion_disabled')
    end

    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        return false, Sw.TP(source, 'characters.error_player_not_found')
    end

    local character = CharacterDatabase.getCharacter(characterId)
    if not character then
        return false, Sw.TP(source, 'characters.error_character_not_found')
    end

    if character.player_id ~= playerId then
        return false, Sw.TP(source, 'characters.error_character_not_yours')
    end

    local current = CharacterCache.getCharacter(source)
    if current and current.id == characterId then
        CharacterCache.removeCharacter(source)
    end

    if not CharacterDatabase.deleteCharacter(characterId) then
        return false, Sw.TP(source, 'characters.error_deleting_character')
    end

    return true, nil
end

function CharacterManager.getPlayerCharacters(source)
    local playerId = exports.core:getPlayerId(source)
    if not playerId then return {} end

    local characters = CharacterDatabase.getPlayerCharacters(playerId)

    if GetResourceState('banking') ~= 'started' then
        return characters
    end

    for _, char in ipairs(characters or {}) do
        local totalCash = 0
        local cashData  = exports.banking:getCharacterAllCash(char.id)
        if type(cashData) == 'table' then
            for _, c in ipairs(cashData) do totalCash = totalCash + (tonumber(c.amount) or 0) end
        elseif type(cashData) == 'number' then
            totalCash = cashData
        end

        local totalBank = 0
        local accounts  = exports.banking:getCharacterAccounts(char.id)
        if type(accounts) == 'table' then
            for _, acc in ipairs(accounts) do
                if acc.balance then
                    for _, amount in pairs(acc.balance) do
                        totalBank = totalBank + (tonumber(amount) or 0)
                    end
                end
            end
        end

        char.cash = totalCash
        char.bank = totalBank
    end

    return characters
end

return CharacterManager
