LocalizationServer = {}
local currentLanguage = 'ro'
local locales = {}
local registeredLocales = {}

function LocalizationServer.initialize()
    -- Prioritate: convar sw_locale > setarea core.default_language > Config > 'ro'
    local convarLanguage = GetConvar('sw_locale', '')
    local settingLanguage = exports.settings:GetSetting('core.default_language', nil)
    currentLanguage = (convarLanguage ~= '' and convarLanguage)
        or settingLanguage
        or Config.DEFAULT_LANGUAGE
        or 'ro'

    local localeFiles = {
        ro = 'locales/ro.lua',
        en = 'locales/en.lua'
    }

    local loadedCount = 0
    local defaultLoaded = false

    for lang, path in pairs(localeFiles) do
        local success, localeData = pcall(function()
            return LoadResourceFile(GetCurrentResourceName(), path)
        end)

        if not success then
            print('[LOCALIZATION] WARNING: Failed to read locale file for ' .. lang .. ' at ' .. path)
        elseif not localeData then
            print('[LOCALIZATION] WARNING: Locale file is empty or missing for ' .. lang .. ' at ' .. path)
        else
            local func, err = load(localeData)
            if func then
                if not locales[lang] then locales[lang] = {} end
                local newData = func()
                for k, v in pairs(newData) do
                    if type(v) == 'table' and type(locales[lang][k]) == 'table' then
                        for sk, sv in pairs(v) do locales[lang][k][sk] = sv end
                    else
                        locales[lang][k] = v
                    end
                end
                loadedCount = loadedCount + 1
                if lang == currentLanguage then defaultLoaded = true end
                print('[LOCALIZATION] Loaded locale: ' .. lang)
            else
                print('[LOCALIZATION] ERROR: Failed to parse locale file for ' .. lang .. ': ' .. tostring(err))
            end
        end
    end

    if not defaultLoaded then
        print('[LOCALIZATION] ERROR: Default language (' .. currentLanguage .. ') locale file failed to load!')
        if loadedCount == 0 then
            print('[LOCALIZATION] ERROR: No locale files loaded! Localization system is non-functional.')
        end
    end

    print('[LOCALIZATION] Initialized with language: ' .. currentLanguage .. ' (' .. loadedCount .. ' locales loaded)')
end

function LocalizationServer.getLanguage()
    return currentLanguage
end

function LocalizationServer.setLanguage(lang)
    if locales[lang] then
        currentLanguage = lang
        print('[LOCALIZATION] Language changed to: ' .. lang)
        return true
    end
    return false, 'Language not available: ' .. tostring(lang)
end

function LocalizationServer.getAvailableLocales()
    local available = {}
    for lang in pairs(locales) do
        table.insert(available, lang)
    end
    return available
end

function LocalizationServer.getLocaleData(language)
    return locales[language]
end

function LocalizationServer.registerLocale(localeCode, localeData)
    if type(localeData) ~= 'table' then
        return false, 'Locale data must be a table'
    end

    if not locales[localeCode] then locales[localeCode] = {} end

    for key, value in pairs(localeData) do
        if not locales[localeCode][key] then locales[localeCode][key] = {} end
        if type(value) == 'table' then
            for subKey, subValue in pairs(value) do
                locales[localeCode][key][subKey] = subValue
            end
        else
            locales[localeCode][key] = value
        end
    end

    registeredLocales[localeCode] = true
    return true
end

-- Limba folosita pentru un jucator. Pe public limba e unica pe server;
-- selectia per-jucator se activeaza doar cu Config.ALLOW_PLAYER_LANGUAGE (premium).
function LocalizationServer.resolvePlayerLanguage(source)
    if Config.ALLOW_PLAYER_LANGUAGE and source then
        local player = PlayerCache.getFromCache(source)
        if player and player.language and locales[player.language] then
            return player.language
        end
    end
    return currentLanguage
end

function LocalizationServer.sendLocaleToClient(source, language)
    local lang = (language and locales[language]) and language or currentLanguage
    local locale = locales[lang]
    if locale then
        TriggerClientEvent('switcore:localeData', source, lang, locale)
    end
end

local broadcastPending = false

-- Retrimite dictionarele de locale tuturor clientilor, cu debounce ca sa grupeze
-- inregistrarile mai multor module la boot intr-un singur broadcast.
function LocalizationServer.broadcastLocales()
    if broadcastPending then return end
    broadcastPending = true
    CreateThread(function()
        Wait(500)
        broadcastPending = false
        for _, src in ipairs(GetPlayers()) do
            local s = tonumber(src)
            if s then
                LocalizationServer.sendLocaleToClient(s, LocalizationServer.resolvePlayerLanguage(s))
            end
        end
    end)
end

-- Conventia standard pentru module: locales/ro.lua + locales/en.lua cu
-- namespace-ul de top egal cu numele modulului.
function LocalizationServer.registerModuleLocales(resourceName)
    local okAny = false
    for _, lang in ipairs({ 'ro', 'en' }) do
        local ok = LocalizationServer.loadLocaleFile(resourceName, lang, ('locales/%s.lua'):format(lang))
        okAny = okAny or ok
    end
    if okAny then
        LocalizationServer.broadcastLocales()
    end
    return okAny
end

function LocalizationServer.loadLocaleFile(resourceName, localeCode, localePath)
    local success, localeData = pcall(function()
        return LoadResourceFile(resourceName, localePath)
    end)

    if not success or not localeData then
        return false, 'Failed to load locale file from resource: ' .. resourceName
    end

    local func, err = load(localeData)
    if not func then
        return false, 'Failed to parse locale file: ' .. tostring(err)
    end

    return LocalizationServer.registerLocale(localeCode, func())
end

local function getNestedValue(tbl, key)
    local current = tbl
    for k in key:gmatch('[^.]+') do
        if type(current) == 'table' and current[k] then
            current = current[k]
        else
            return nil
        end
    end
    return current
end

function LocalizationServer.translate(key, source, ...)
    if not key or type(key) ~= 'string' then
        return tostring(key or '')
    end

    local playerLanguage = currentLanguage
    local args = {...}

    if source and type(source) == 'number' then
        playerLanguage = LocalizationServer.resolvePlayerLanguage(source)
    elseif source ~= nil then
        args = {source, ...}
    end

    local locale = locales[playerLanguage] or locales['ro'] or {}
    local translation = getNestedValue(locale, key)

    if not translation then
        print('[LOCALIZATION] Missing translation for key: ' .. key .. ' (language: ' .. playerLanguage .. ')')
        return key
    end

    if #args > 0 then
        return Localization.interpolate(translation, table.unpack(args))
    end

    return translation
end

function Localize(key, source, ...)
    if source and type(source) == 'number' then
        return LocalizationServer.translate(key, source, ...)
    else
        return LocalizationServer.translate(key, nil, source, ...)
    end
end

-- API-ul recomandat: t (limba serverului) si tp (adresat unui jucator).
-- Spre deosebire de exportul istoric translate, nu ghiceste daca primul
-- argument numeric e un source sau un parametru de interpolare.
exports('t', function(key, ...)
    return LocalizationServer.translate(key, nil, ...)
end)

exports('tp', function(source, key, ...)
    return LocalizationServer.translate(key, tonumber(source), ...)
end)

exports('registerModuleLocales', function(resourceName)
    return LocalizationServer.registerModuleLocales(resourceName or GetInvokingResource())
end)

-- Export istoric, pastrat pentru compatibilitate. Nu migra cod nou pe el.
exports('translate', function(key, source, ...)
    if source and type(source) == 'number' then
        return LocalizationServer.translate(key, source, ...)
    else
        return LocalizationServer.translate(key, nil, source, ...)
    end
end)

exports('getLanguage', function()
    return LocalizationServer.getLanguage()
end)

exports('setLanguage', function(lang)
    return LocalizationServer.setLanguage(lang)
end)

exports('registerLocale', function(localeCode, localeData)
    return LocalizationServer.registerLocale(localeCode, localeData)
end)

exports('loadLocaleFile', function(resourceName, localeCode, localePath)
    return LocalizationServer.loadLocaleFile(resourceName, localeCode, localePath)
end)

exports('getAvailableLocales', function()
    return LocalizationServer.getAvailableLocales()
end)

exports('getLocaleData', function(language)
    return LocalizationServer.getLocaleData(language)
end)

return LocalizationServer
