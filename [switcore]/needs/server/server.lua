local playerNeeds = {}

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function syncNeeds(source)
    local needs = playerNeeds[source]
    if not needs then return end
    TriggerClientEvent('switcore:needsUpdate', source, needs.hunger, needs.thirst)
end

local function persistNeeds(source)
    local needs = playerNeeds[source]
    if not needs or not needs.characterId then return end
    pcall(function()
        exports.postgres:query(
            [[
                UPDATE characters
                SET stats = jsonb_set(
                        jsonb_set(COALESCE(stats, '{}'::jsonb), '{hunger}', to_jsonb($2::numeric)),
                        '{thirst}', to_jsonb($3::numeric)
                    ),
                    updated_at = NOW()
                WHERE id = $1
            ]],
            { needs.characterId, needs.hunger, needs.thirst }
        )
    end)
end

AddEventHandler('switcore:characterSelected', function(source, characterId, character)
    local stats   = (character and character.stats) or {}
    local hunger  = tonumber(stats.hunger) or 100.0
    local thirst  = tonumber(stats.thirst) or 100.0

    playerNeeds[source] = {
        hunger = clamp(hunger, 0.0, 100.0),
        thirst = clamp(thirst, 0.0, 100.0),
        characterId = characterId,
    }

    syncNeeds(source)
    print(string.format('[NEEDS] Personaj %d încărcat - hunger: %.1f, thirst: %.1f', characterId, hunger, thirst))
end)

AddEventHandler('playerDropped', function()
    local source = source
    persistNeeds(source)
    playerNeeds[source] = nil
end)

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    while not exports.settings:IsReady() do Wait(100) end

    local s = exports.settings

    exports.inventory:RegisterUsableItem('bread', function(source)
        if not playerNeeds[source] then return end
        playerNeeds[source].hunger = clamp(playerNeeds[source].hunger + 25.0, 0.0, 100.0)
        syncNeeds(source)
        TriggerClientEvent('switcore:notify', source, 'success', 'Ai mâncat o bucată de pâine. (+25 hunger)', 3000)
    end)

    exports.inventory:RegisterUsableItem('water', function(source)
        if not playerNeeds[source] then return end
        playerNeeds[source].thirst = clamp(playerNeeds[source].thirst + 35.0, 0.0, 100.0)
        syncNeeds(source)
        TriggerClientEvent('switcore:notify', source, 'info', 'Ai băut apă. (+35 thirst)', 3000)
    end)

    exports.inventory:RegisterUsableItem('burger', function(source)
        if not playerNeeds[source] then return end
        playerNeeds[source].hunger = clamp(playerNeeds[source].hunger + 50.0, 0.0, 100.0)
        playerNeeds[source].thirst = clamp(playerNeeds[source].thirst + 15.0, 0.0, 100.0)
        syncNeeds(source)
        TriggerClientEvent('switcore:notify', source, 'success', 'Ai mâncat un burger. (+50 hunger, +15 thirst)', 3000)
    end)

    while true do
        local updateInterval  = s:GetSettingNumber('needs.update_interval', 60)
        local hungerDecay     = s:GetSettingNumber('needs.hunger_decay_rate', 2.0)
        local thirstDecay     = s:GetSettingNumber('needs.thirst_decay_rate', 3.0)
        local damageThreshold = s:GetSettingNumber('needs.damage_threshold', 10.0)
        local damageAmount    = s:GetSettingNumber('needs.damage_amount', 2)

        Wait(updateInterval * 1000)

        for src, needs in pairs(playerNeeds) do
            needs.hunger = clamp(needs.hunger - hungerDecay, 0.0, 100.0)
            needs.thirst = clamp(needs.thirst - thirstDecay, 0.0, 100.0)

            syncNeeds(src)
            persistNeeds(src)

            if needs.hunger <= damageThreshold or needs.thirst <= damageThreshold then
                TriggerClientEvent('needs:client:applyDamage', src, damageAmount)
            end
        end
    end
end)

exports('GetHunger', function(source)
    return playerNeeds[source] and playerNeeds[source].hunger or nil
end)

exports('GetThirst', function(source)
    return playerNeeds[source] and playerNeeds[source].thirst or nil
end)

exports('SetHunger', function(source, value)
    if not playerNeeds[source] then return false end
    playerNeeds[source].hunger = clamp(tonumber(value) or 0, 0.0, 100.0)
    syncNeeds(source)
    return true
end)

exports('SetThirst', function(source, value)
    if not playerNeeds[source] then return false end
    playerNeeds[source].thirst = clamp(tonumber(value) or 0, 0.0, 100.0)
    syncNeeds(source)
    return true
end)

exports('AddHunger', function(source, amount)
    if not playerNeeds[source] then return false end
    playerNeeds[source].hunger = clamp(playerNeeds[source].hunger + (tonumber(amount) or 0), 0.0, 100.0)
    syncNeeds(source)
    return true
end)

exports('AddThirst', function(source, amount)
    if not playerNeeds[source] then return false end
    playerNeeds[source].thirst = clamp(playerNeeds[source].thirst + (tonumber(amount) or 0), 0.0, 100.0)
    syncNeeds(source)
    return true
end)

print('[NEEDS] Server module loading...')
