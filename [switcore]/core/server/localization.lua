LocalizationServer = {}
local currentLanguage = 'ro'
local locales = {}
local registeredLocales = {}

function LocalizationServer.initialize()
    currentLanguage = Config.DEFAULT_LANGUAGE or 'ro'

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
        local player = PlayerCache.getFromCache(source)
        if player and player.language then
            playerLanguage = player.language
        end
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
