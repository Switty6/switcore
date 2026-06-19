LocalizationClient = {}
local currentLanguage = 'ro'
local localeCache = {}

function LocalizationClient.getLanguage()
    return currentLanguage
end

function LocalizationClient.setLanguage(language)
    if not language or type(language) ~= 'string' then
        return false
    end
    
    TriggerServerEvent('switcore:setLanguage', language)
    return true
end

function LocalizationClient.translate(key, ...)
    if not key or type(key) ~= 'string' then
        return tostring(key or '')
    end
    
    local args = {...}
    
    local locale = localeCache[currentLanguage]
    if locale then
        local translation = LocalizationClient.getNestedValue(locale, key)
        if translation then
            if #args > 0 then
                return Localization.interpolate(translation, table.unpack(args))
            end
            return translation
        end
    end
    
    if currentLanguage ~= 'ro' then
        locale = localeCache['ro']
        if locale then
            local translation = LocalizationClient.getNestedValue(locale, key)
            if translation then
                if #args > 0 then
                    return Localization.interpolate(translation, table.unpack(args))
                end
                return translation
            end
        end
    end
    
    return key
end

function LocalizationClient.getNestedValue(tbl, key)
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

function LocalizationClient.syncLocale(language, localeData)
    if not language or not localeData then
        return false
    end
    
    localeCache[language] = localeData
    
    return true
end

RegisterNetEvent('switcore:languageChanged', function(language)
    currentLanguage = language
end)

RegisterNetEvent('switcore:localeData', function(language, localeData)
    if LocalizationClient.syncLocale(language, localeData) then
        -- hook local pentru UI-uri: retrimit dictionarul catre NUI cand se schimba
        TriggerEvent('switcore:client:localeUpdated', language)
    end
end)

RegisterNetEvent('switcore:localizedMessage', function(message)
    print('[CORE] ' .. message)
end)

CreateThread(function()
    Wait(2000)
    if not localeCache[currentLanguage] then
        TriggerServerEvent('switcore:requestLocale', currentLanguage)
    end
end)

exports('translate', function(key, ...)
    return LocalizationClient.translate(key, ...)
end)

-- alias scurt, pereche cu exportul de server (folosit de Sw.T)
exports('t', function(key, ...)
    return LocalizationClient.translate(key, ...)
end)

-- dictionarul complet pentru limba curenta; UI-urile il trimit catre NUI (sw:i18n)
exports('getLocaleDict', function()
    return localeCache[currentLanguage] or localeCache['ro'] or {}
end)

exports('getLanguage', function()
    return LocalizationClient.getLanguage()
end)

exports('setLanguage', function(language)
    return LocalizationClient.setLanguage(language)
end)

return LocalizationClient

