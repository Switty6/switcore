LocalizationClient = {}
local currentLanguage = 'ro'
local localeCache = {}

-- Obține limba curentă
function LocalizationClient.getLanguage()
    return currentLanguage
end

-- Setează limba (se sincronizează cu serverul)
function LocalizationClient.setLanguage(language)
    if not language or type(language) ~= 'string' then
        return false
    end
    
    TriggerServerEvent('switcore:setLanguage', language)
    return true
end

-- Traduce o cheie (cu cache local și fallback la server)
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
    
    if exports.core and exports.core.translate then
        local result = exports.core:translate(key, ...)
        if result and result ~= key then
            return result
        end
    end
    
    return key
end

-- Helper pentru a obține valoarea nested dintr-un tabel
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

-- Sincronizează cache-ul cu serverul
function LocalizationClient.syncLocale(language, localeData)
    if not language or not localeData then
        return false
    end
    
    localeCache[language] = localeData
    
    return true
end

-- Event când limba este schimbată
RegisterNetEvent('switcore:languageChanged', function(language)
    currentLanguage = language
end)

-- Event pentru primirea locale-ului de la server
RegisterNetEvent('switcore:localeData', function(language, localeData)
    LocalizationClient.syncLocale(language, localeData)
end)

-- Event pentru mesaj localizat de la server (pentru logging)
RegisterNetEvent('switcore:localizedMessage', function(message)
    print('[CORE] ' .. message)
end)

-- Cere locale-ul la conectare (fallback dacă serverul nu l-a trimis automat)
CreateThread(function()
    Wait(2000)
    if not localeCache[currentLanguage] then
        TriggerServerEvent('switcore:requestLocale', currentLanguage)
    end
end)

-- Export pentru scripturi externe
exports('translate', function(key, ...)
    return LocalizationClient.translate(key, ...)
end)

exports('getLanguage', function()
    return LocalizationClient.getLanguage()
end)

exports('setLanguage', function(language)
    return LocalizationClient.setLanguage(language)
end)

return LocalizationClient

