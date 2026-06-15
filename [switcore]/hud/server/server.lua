exports.core:registerModuleLocales(GetCurrentResourceName())

local function getPrimaryCurrency()
    return exports.settings:GetSetting('hud.primary_currency', 'USD')
end

local function getPrimarySymbol()
    return exports.settings:GetSetting('hud.primary_symbol', '$')
end

local function sendHudConfig(source)
    TriggerClientEvent('hud:client:config', source, {
        hideNativeHUD = exports.settings:GetSettingBool('hud.hide_native_hud', true),
        tickInterval  = exports.settings:GetSettingNumber('hud.tick_interval', 333),
        primaryCurrency = getPrimaryCurrency(),
        primarySymbol   = getPrimarySymbol(),
        maxSpeed        = exports.settings:GetSettingNumber('hud.max_speed', 240),
        components = {
            stats        = exports.settings:GetSettingBool('hud.component_stats',       true),
            cash         = exports.settings:GetSettingBool('hud.component_cash',        true),
            time         = exports.settings:GetSettingBool('hud.component_time',        true),
            speedometer  = exports.settings:GetSettingBool('hud.component_speedometer', true),
        }
    })
end

RegisterNetEvent('switcore:characterLoaded', function(character)
    local source = source
    if not character or not character.id then return end

    sendHudConfig(source)

    local cashData = exports.banking:getCharacterAllCash(character.id)
    local primaryCash = 0
    local currency = getPrimaryCurrency()

    if cashData then
        for _, entry in ipairs(cashData) do
            if entry.currency_code == currency then
                primaryCash = tonumber(entry.amount) or 0
                break
            end
        end
    end

    TriggerClientEvent('hud:client:init', source, {
        cash   = primaryCash,
        symbol = getPrimarySymbol(),
        hunger = (character.stats and character.stats.hunger) or 100,
        thirst = (character.stats and character.stats.thirst) or 100,
    })
end)

AddEventHandler('banking:transactionCompleted', function(characterId, transactionData)
    local currency = getPrimaryCurrency()
    local symbol   = getPrimarySymbol()

    for _, playerId in ipairs(GetPlayers()) do
        local charId = exports.characters:getCharacterId(tonumber(playerId))
        if charId == characterId then
            local cashData = exports.banking:getCharacterAllCash(characterId)
            local newCash = 0
            if cashData then
                for _, entry in ipairs(cashData) do
                    if entry.currency_code == currency then
                        newCash = tonumber(entry.amount) or 0; break
                    end
                end
            end
            TriggerClientEvent('hud:client:cashUpdate', tonumber(playerId), newCash, symbol)
            break
        end
    end
end)
