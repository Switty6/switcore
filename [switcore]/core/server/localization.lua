LocalizationServer = {}
local currentLanguage = 'ro' -- Server-wide default (fallback)
local locales = {}
local registeredLocales = {} -- pentru scripturi externe

-- Initializeaza sistemul de localizare
function LocalizationServer.initialize()
    currentLanguage = Config.DEFAULT_LANGUAGE or 'ro'
    
    local localeFiles = {
        ro = 'locales/ro.lua',
        en = 'locales/en.lua'
    }
    
    local loadedCount = 0
    local defaultLang = Config.DEFAULT_LANGUAGE or 'ro'
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
                locales[lang] = func()
                loadedCount = loadedCount + 1
                if lang == defaultLang then
                    defaultLoaded = true
                end
                print('[LOCALIZATION] Loaded locale: ' .. lang)
            else
                print('[LOCALIZATION] ERROR: Failed to parse locale file for ' .. lang .. ': ' .. tostring(err))
            end
        end
    end
    
    if not defaultLoaded then
        print('[LOCALIZATION] ERROR: Default language (' .. defaultLang .. ') locale file failed to load!')
        print('[LOCALIZATION] ERROR: Localization system may not work correctly.')
        if loadedCount == 0 then
            print('[LOCALIZATION] ERROR: No locale files loaded! Localization system is non-functional.')
        end
    end
    
    print('[LOCALIZATION] Initialized with language: ' .. currentLanguage .. ' (' .. loadedCount .. ' locales loaded)')
end

-- Preia limba curenta
function LocalizationServer.getLanguage()
    return currentLanguage
end

-- Seteaza limba (pentru admini)
function LocalizationServer.setLanguage(lang)
    if locales[lang] then
        currentLanguage = lang
        print('[LOCALIZATION] Language changed to: ' .. lang)
        return true
    end
    return false, 'Language not available: ' .. tostring(lang)
end

-- Preia limbele disponibile
function LocalizationServer.getAvailableLocales()
    local available = {}
    for lang, _ in pairs(locales) do
        table.insert(available, lang)
    end
    return available
end

-- Preia datele locale complete pentru o limbă (pentru client-side sync)
function LocalizationServer.getLocaleData(language)
    return locales[language]
end

-- Inregistreaza datele locale de la scriptul extern
function LocalizationServer.registerLocale(localeCode, localeData)
    if type(localeData) ~= 'table' then
        return false, 'Locale data must be a table'
    end
    
    if not locales[localeCode] then
        locales[localeCode] = {}
    end
    
    for key, value in pairs(localeData) do
        if not locales[localeCode][key] then
            locales[localeCode][key] = {}
        end
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

-- Incarca fisierul locale de la alta resursa
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
    
    local localeTable = func()
    return LocalizationServer.registerLocale(localeCode, localeTable)
end

-- Aici nu mai stau să explic
local function getNestedValue(tbl, key)
    local keys = {}
    for k in key:gmatch('[^.]+') do
        table.insert(keys, k)
    end
    
    local current = tbl
    for _, k in ipairs(keys) do
        if type(current) == 'table' and current[k] then
            current = current[k]
        else
            return nil
        end
    end
    
    return current
end

-- Traduce o cheie cu argumente optionale
-- source: opțional - dacă este furnizat, folosește limba jucătorului, altfel folosește limba serverului
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
    else
        args = {source, ...}
    end
    
    local locale = locales[playerLanguage]
    if not locale then
        locale = locales['ro'] or {}
    end
    
    local translation = getNestedValue(locale, key)
    
    if not translation then
        local sourceInfo = source and (' (source: ' .. source .. ')') or ''
        local langInfo = ' (language: ' .. playerLanguage .. ')'
        print('[LOCALIZATION] Missing translation for key: ' .. key .. sourceInfo .. langInfo)
        return key
    end
    
    if #args > 0 then
        return Localization.interpolate(translation, table.unpack(args))
    end
    
    return translation
end

-- Helper intern pentru core scripts
-- Poate fi apelat cu sau fără source
function Localize(key, source, ...)
    if source and type(source) == 'number' then
        return LocalizationServer.translate(key, source, ...)
    else
        return LocalizationServer.translate(key, nil, source, ...)
    end
end

-- ==================== EXPORTS ====================

-- Preia stringul tradus (pentru scripturi externe)
-- Poate fi apelat cu sau fără source: translate(key, source, ...) sau translate(key, ...)
exports('translate', function(key, source, ...)
    if source and type(source) == 'number' then
        return LocalizationServer.translate(key, source, ...)
    else
        return LocalizationServer.translate(key, nil, source, ...)
    end
end)

-- Preia limba serverului
exports('getLanguage', function()
    return LocalizationServer.getLanguage()
end)

-- Seteaza limba serverului (doar pentru admini)
exports('setLanguage', function(lang)
    return LocalizationServer.setLanguage(lang)
end)

-- Inregistreaza datele locale de la scriptul extern
exports('registerLocale', function(localeCode, localeData)
    return LocalizationServer.registerLocale(localeCode, localeData)
end)

-- Incarca fisierul locale de la alta resursa
exports('loadLocaleFile', function(resourceName, localeCode, localePath)
    return LocalizationServer.loadLocaleFile(resourceName, localeCode, localePath)
end)

-- Preia limbele disponibile
exports('getAvailableLocales', function()
    return LocalizationServer.getAvailableLocales()
end)

return LocalizationServer


