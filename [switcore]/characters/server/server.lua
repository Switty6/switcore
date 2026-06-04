CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    local res = GetCurrentResourceName()
    exports.core:loadLocaleFile(res, 'ro', 'locales/ro.lua')
    exports.core:loadLocaleFile(res, 'en', 'locales/en.lua')
    print('[CHARACTERS] PostgreSQL gata, sistem inițializat')
end)

AddEventHandler('playerJoining', function()
    local source = source

    local waited = 0
    while not exports.postgres:isReady() and waited < 15000 do
        Wait(200)
        waited = waited + 200
    end

    local playerId
    for _ = 1, 20 do
        if exports.core and exports.core.getPlayerId then
            playerId = exports.core:getPlayerId(source)
            if playerId then break end
        end
        Wait(500)
    end

    if not GetPlayerName(source) then return end
    if CharacterCache.getCharacter(source) then return end

    TriggerClientEvent('switcore:openCharacterSelection', source)
end)

-- Aceste evenimente ruleaza pe ecranul de selectie, inainte de a exista un
-- personaj activ, deci nu folosesc optiunea character=true.
Sw.SecureEvent('switcore:selectCharacter', {
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'characterId', type = 'int', min = 1 },
    },
}, function(ctx)
    local source = ctx.source
    local success, err, character = CharacterManager.selectCharacter(source, ctx.args.characterId)
    if success then
        TriggerClientEvent('switcore:characterSelected', source, character)
    else
        TriggerClientEvent('switcore:characterError', source, err or exports.core:translate('characters.error_selecting_character', source))
    end
end)

Sw.SecureEvent('switcore:createCharacter', {
    rateLimit = { max = 3, window = 5000 },
    args = {
        { name = 'firstName',  type = 'string', minLen = 1, maxLen = 32 },
        { name = 'lastName',   type = 'string', minLen = 1, maxLen = 32 },
        { name = 'age',        type = 'int', min = 1, max = 120 },
        { name = 'appearance', type = 'table' },
    },
}, function(ctx)
    local source = ctx.source
    local a = ctx.args
    local success, err, character = CharacterManager.createCharacterForPlayer(source, a.firstName, a.lastName, a.age, a.appearance)
    if success then
        TriggerClientEvent('switcore:characterCreated', source, character)
        TriggerClientEvent('switcore:characterSelected', source, character)
    else
        TriggerClientEvent('switcore:characterError', source, err or exports.core:translate('characters.error_creating_character', source))
    end
end)

Sw.SecureEvent('switcore:deleteCharacter', {
    rateLimit = { max = 3, window = 5000 },
    args = {
        { name = 'characterId', type = 'int', min = 1 },
    },
}, function(ctx)
    local source = ctx.source
    local id = ctx.args.characterId
    local success, err = CharacterManager.deleteCharacterForPlayer(source, id)
    if success then
        TriggerClientEvent('switcore:characterDeleted', source, id)
        TriggerClientEvent('switcore:charactersList', source, CharacterManager.getPlayerCharacters(source))
    else
        TriggerClientEvent('switcore:characterError', source, err or exports.core:translate('characters.error_deleting_character', source))
    end
end)

Sw.SecureEvent('switcore:requestCharacters', {
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local source = ctx.source
    local characters = CharacterManager.getPlayerCharacters(source)

    local lang = exports.core:getPlayerLanguage(source) or 'ro'
    local localeData = exports.core:getLocaleData(lang)
    if not localeData or not localeData.characters then
        exports.core:loadLocaleFile(GetCurrentResourceName(), lang, 'locales/' .. lang .. '.lua')
        localeData = exports.core:getLocaleData(lang)
    end
    if localeData and localeData.characters then
        TriggerClientEvent('switcore:charactersLocale', source, localeData.characters)
    end

    local creatorRoom = exports.settings:GetSettingJSON('characters.creator_room', nil)
    if creatorRoom then
        TriggerClientEvent('switcore:charactersConfig', source, { creatorRoom = creatorRoom })
    end

    TriggerClientEvent('switcore:charactersList', source, characters)
end)

local characterPlaytime = {}
local lastPositions     = {}

local function startPlaytimeTracking(source)
    local character = CharacterCache.getCharacter(source)
    if character then
        characterPlaytime[source] = { characterId = character.id, lastUpdate = os.time() }
    end
end

local function stopPlaytimeTracking(source)
    local tracking = characterPlaytime[source]
    if not tracking then return end

    local elapsed   = os.time() - tracking.lastUpdate
    local character = CharacterCache.getCharacter(source)
    if character and elapsed > 0 then
        local newPlaytime = (character.playtime or 0) + elapsed
        CharacterCache.updateCharacter(source, { playtime = newPlaytime })
        CharacterDatabase.updateCharacterPlaytime(tracking.characterId, newPlaytime)
    end

    characterPlaytime[source] = nil
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for source, tracking in pairs(characterPlaytime) do
            local character = CharacterCache.getCharacter(source)
            if not character then
                characterPlaytime[source] = nil
            else
                local elapsed = now - tracking.lastUpdate
                if elapsed >= 60 then
                    local newPlaytime = (character.playtime or 0) + elapsed
                    CharacterCache.updateCharacter(source, { playtime = newPlaytime })
                    CharacterDatabase.updateCharacterPlaytime(tracking.characterId, newPlaytime)
                    CharacterDatabase.updateCharacterLastPlayed(tracking.characterId)
                    tracking.lastUpdate = now
                end
            end
        end
    end
end)

AddEventHandler('switcore:characterSelected', function(source, characterId, character)
    startPlaytimeTracking(source)
    if character and character.position then
        lastPositions[source] = { x = character.position.x, y = character.position.y, z = character.position.z }
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    stopPlaytimeTracking(source)

    local character = CharacterCache.getCharacter(source)
    if character then
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then
            local stats  = character.stats or {}
            stats.health = GetEntityHealth(ped)
            stats.armor  = GetPedArmour(ped)
            if GetResourceState('needs') == 'started' then
                stats.hunger = exports.needs:GetHunger(source) or 100.0
                stats.thirst = exports.needs:GetThirst(source) or 100.0
            end
            CharacterDatabase.updateCharacterStats(character.id, stats)
        end
    end

    CharacterCache.removeCharacter(source)
    lastPositions[source] = nil
end)

CreateThread(function()
    while true do
        Wait(5000)
        for source, character in pairs(CharacterCache.getAllCharacters()) do
            local ped = GetPlayerPed(source)
            if ped and ped > 0 then
                local coords = GetEntityCoords(ped)
                local last   = lastPositions[source]

                if last then
                    local dist = #(vector3(coords.x, coords.y, coords.z) - vector3(last.x, last.y, last.z))
                    if dist > 0 then
                        CharacterDatabase.incrementCharacterStatistic(character.id, 'distance_traveled', dist)
                    end
                end

                lastPositions[source] = { x = coords.x, y = coords.y, z = coords.z }

                CharacterDatabase.updateCharacterPosition(character.id, {
                    x = coords.x, y = coords.y, z = coords.z,
                    heading = GetEntityHeading(ped)
                })

                local stats  = character.stats or {}
                stats.health = GetEntityHealth(ped)
                stats.armor  = GetPedArmour(ped)

                if GetResourceState('needs') == 'started' then
                    stats.hunger = exports.needs:GetHunger(source) or 100.0
                    stats.thirst = exports.needs:GetThirst(source) or 100.0
                else
                    stats.hunger = stats.hunger or 100.0
                    stats.thirst = stats.thirst or 100.0
                end

                CharacterCache.updateCharacter(source, { stats = stats })
                CharacterDatabase.updateCharacterStats(character.id, stats)
            end
        end
    end
end)

exports('getCharacter',       function(src) return CharacterCache.getCharacter(src) end)
exports('getActiveCharacter', function(src) return CharacterCache.getCharacter(src) end)
exports('getCharacterId',     function(src) local c = CharacterCache.getCharacter(src); return c and c.id end)
exports('getSourceByCharacterId', function(characterId) return CharacterCache.getSourceById(characterId) end)

exports('getCharacterData', function(source)
    local character = CharacterCache.getCharacter(source)
    if not character then return nil end
    return {
        id          = character.id,
        player_id   = character.player_id,
        first_name  = character.first_name,
        last_name   = character.last_name,
        age         = character.age,
        position    = character.position,
        appearance  = character.appearance,
        stats       = character.stats,
        metadata    = character.metadata,
        playtime    = character.playtime,
        last_played = character.last_played,
        created_at  = character.created_at,
        statistics  = CharacterDatabase.getCharacterStatistics(character.id)
    }
end)

exports('updateCharacterPosition', function(source, position)
    local character = CharacterCache.getCharacter(source)
    if not character then return false end
    CharacterCache.updateCharacter(source, { position = position })
    return CharacterDatabase.updateCharacterPosition(character.id, position)
end)

exports('updateCharacterStat', function(source, statName, value)
    local character = CharacterCache.getCharacter(source)
    if not character then return false end
    return CharacterDatabase.updateCharacterStatistic(character.id, statName, value)
end)

exports('incrementCharacterStat', function(source, statName, amount)
    local character = CharacterCache.getCharacter(source)
    if not character then return false end
    return CharacterDatabase.incrementCharacterStatistic(character.id, statName, amount or 1)
end)

exports('getCharacterStatistics', function(source)
    local character = CharacterCache.getCharacter(source)
    if not character then return {} end
    return CharacterDatabase.getCharacterStatistics(character.id)
end)

print('[CHARACTERS] Modul inițializat')
