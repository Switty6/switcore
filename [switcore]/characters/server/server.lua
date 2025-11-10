-- Încarcă locale-urile pentru caractere
CreateThread(function()
    while not exports.postgres:isReady() do
        Wait(100)
    end
    
    local resourceName = GetCurrentResourceName()
    exports.core:loadLocaleFile(resourceName, 'ro', 'locales/ro.lua')
    exports.core:loadLocaleFile(resourceName, 'en', 'locales/en.lua')
    
    print('[CHARACTERS] PostgreSQL este gata, sistemul de caractere inițializat')
end)

-- Hook în playerJoining pentru a intercepta după ce jucătorul s-a conectat
AddEventHandler('playerJoining', function(oldId)
    local source = source
    
    -- Așteaptă puțin pentru a permite core-ului să se inițializeze
    Wait(2000)
    
    if not exports.core or not exports.core:getPlayerId then
        return
    end
    
    local playerId = exports.core:getPlayerId(source)
    if not playerId then
        -- Așteaptă puțin mai mult și încearcă din nou
        Wait(2000)
        playerId = exports.core:getPlayerId(source)
        if not playerId then
            return
        end
    end
    
    local character = CharacterCache.getCharacter(source)
    if character then
        return
    end
    
    TriggerClientEvent('switcore:openCharacterSelection', source)
end)

-- Gestionează selecția personajului de la client
RegisterNetEvent('switcore:selectCharacter', function(characterId)
    local source = source
    local success, error, character = CharacterManager.selectCharacter(source, characterId)
    
    if success then
        TriggerClientEvent('switcore:characterSelected', source, character)
    else
        TriggerClientEvent('switcore:characterError', source, error or exports.core:translate('characters.error_selecting_character', source))
    end
end)

-- Gestionează crearea personajului de la client
RegisterNetEvent('switcore:createCharacter', function(firstName, lastName, age, appearance)
    local source = source
    local success, error, character = CharacterManager.createCharacterForPlayer(source, firstName, lastName, age, appearance)
    
    if success then
        TriggerClientEvent('switcore:characterCreated', source, character)
        TriggerClientEvent('switcore:characterSelected', source, character)
    else
        TriggerClientEvent('switcore:characterError', source, error or exports.core:translate('characters.error_creating_character', source))
    end
end)

-- Gestionează ștergerea personajului de la client
RegisterNetEvent('switcore:deleteCharacter', function(characterId)
    local source = source
    local success, error = CharacterManager.deleteCharacterForPlayer(source, characterId)
    
    if success then
        TriggerClientEvent('switcore:characterDeleted', source, characterId)
        local characters = CharacterManager.getPlayerCharacters(source)
        TriggerClientEvent('switcore:charactersList', source, characters)
    else
        TriggerClientEvent('switcore:characterError', source, error or exports.core:translate('characters.error_deleting_character', source))
    end
end)

-- Trimite lista de personaje când clientul o solicită
RegisterNetEvent('switcore:requestCharacters', function()
    local source = source
    local characters = CharacterManager.getPlayerCharacters(source)
    
    -- Trimite și locale-urile pentru UI
    local playerLanguage = exports.core:getPlayerLanguage(source) or 'ro'
    local localeData = exports.core:getLocaleData(playerLanguage)
    if localeData and localeData.characters then
        TriggerClientEvent('switcore:charactersLocale', source, localeData.characters)
    end
    
    TriggerClientEvent('switcore:charactersList', source, characters)
end)

-- Tracking pentru playtime-ul personajului
local characterPlaytime = {}

-- Pornește tracking-ul playtime pentru un personaj
function StartCharacterPlaytimeTracking(source)
    local character = CharacterCache.getCharacter(source)
    if character then
        characterPlaytime[source] = {
            characterId = character.id,
            startTime = os.time(),
            lastUpdate = os.time()
        }
    end
end

-- Oprește tracking-ul playtime pentru un personaj
function StopCharacterPlaytimeTracking(source)
    if characterPlaytime[source] then
        local tracking = characterPlaytime[source]
        local elapsed = os.time() - tracking.startTime
        local character = CharacterCache.getCharacter(source)
        
        if character then
            local newPlaytime = (character.playtime or 0) + elapsed
            CharacterCache.updateCharacter(source, {playtime = newPlaytime})
            CharacterDatabase.updateCharacterPlaytime(tracking.characterId, newPlaytime)
        end
        
        characterPlaytime[source] = nil
    end
end

-- Actualizează playtime-ul periodic
CreateThread(function()
    while true do
        Wait(60000) -- Actualizează la fiecare minut
        
        for source, tracking in pairs(characterPlaytime) do
            local character = CharacterCache.getCharacter(source)
            if character then
                local elapsed = os.time() - tracking.lastUpdate
                if elapsed >= 60 then
                    local newPlaytime = (character.playtime or 0) + elapsed
                    CharacterCache.updateCharacter(source, {playtime = newPlaytime})
                    CharacterDatabase.updateCharacterPlaytime(tracking.characterId, newPlaytime)
                    tracking.startTime = tracking.startTime + elapsed
                    tracking.lastUpdate = os.time()
                end
            else
                characterPlaytime[source] = nil
            end
        end
    end
end)

-- Când un personaj este selectat, pornește tracking-ul
AddEventHandler('switcore:characterSelected', function(source, characterId, character)
    StartCharacterPlaytimeTracking(source)
end)

-- Când jucătorul se deconectează, oprește tracking-ul
AddEventHandler('playerDropped', function(reason)
    local source = source
    StopCharacterPlaytimeTracking(source)
    CharacterCache.removeCharacter(source)
end)

-- Tracking pentru distanța parcursă
local lastPositions = {}

-- Actualizează poziția personajului periodic
CreateThread(function()
    while true do
        Wait(5000) -- Verifică la fiecare 5 secunde
        
        for source, character in pairs(CharacterCache.getAllCharacters()) do
            local ped = GetPlayerPed(source)
            if ped and ped > 0 then
                local coords = GetEntityCoords(ped)
                local lastPos = lastPositions[source]
                
                if lastPos then
                    local distance = #(vector3(coords.x, coords.y, coords.z) - vector3(lastPos.x, lastPos.y, lastPos.z))
                    if distance > 0 then
                        CharacterDatabase.incrementCharacterStatistic(character.id, 'distance_traveled', distance)
                    end
                end
                
                lastPositions[source] = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }
                
                CharacterDatabase.updateCharacterPosition(character.id, {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = GetEntityHeading(ped)
                })
            end
        end
    end
end)

-- Când un personaj este selectat, inițializează poziția
AddEventHandler('switcore:characterSelected', function(source, characterId, character)
    if character and character.position then
        lastPositions[source] = {
            x = character.position.x,
            y = character.position.y,
            z = character.position.z
        }
    end
end)

-- Când jucătorul se deconectează, elimină poziția
AddEventHandler('playerDropped', function(reason)
    local source = source
    lastPositions[source] = nil
end)

-- ==================== EXPORTS ====================

-- Obține caracterul curent pentru un jucator
exports('getCharacter', function(source)
    return CharacterCache.getCharacter(source)
end)

-- Obține ID-ul caracterului curent
exports('getCharacterId', function(source)
    local character = CharacterCache.getCharacter(source)
    return character and character.id or nil
end)

-- Obține datele complete ale caracterului
exports('getCharacterData', function(source)
    local character = CharacterCache.getCharacter(source)
    if not character then
        return nil
    end
    
    local statistics = CharacterDatabase.getCharacterStatistics(character.id)
    
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
        playtime = character.playtime,
        last_played = character.last_played,
        created_at = character.created_at,
        statistics = statistics
    }
end)

-- Actualizeaza pozitia caracterului
exports('updateCharacterPosition', function(source, position)
    local character = CharacterCache.getCharacter(source)
    if not character then
        return false
    end
    
    CharacterCache.updateCharacter(source, {position = position})
    return CharacterDatabase.updateCharacterPosition(character.id, position)
end)

-- Actualizează o statistică
exports('updateCharacterStat', function(source, statName, value)
    local character = CharacterCache.getCharacter(source)
    if not character then
        return false
    end
    
    return CharacterDatabase.updateCharacterStatistic(character.id, statName, value)
end)

-- Incrementează o statistică
exports('incrementCharacterStat', function(source, statName, amount)
    local character = CharacterCache.getCharacter(source)
    if not character then
        return false
    end
    
    return CharacterDatabase.incrementCharacterStatistic(character.id, statName, amount or 1)
end)

-- Obține toate statisticile caracterului
exports('getCharacterStatistics', function(source)
    local character = CharacterCache.getCharacter(source)
    if not character then
        return {}
    end
    
    return CharacterDatabase.getCharacterStatistics(character.id)
end)

print('[CHARACTERS] Modulul de personaje a fost încărcat')

