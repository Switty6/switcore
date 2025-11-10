-- Obține limba curentă
local function getCurrentLanguage()
    if LocalizationClient and LocalizationClient.getLanguage then
        return LocalizationClient.getLanguage()
    end
    return 'ro'
end

-- Setează limba jucătorului
local function setLanguage(language)
    if LocalizationClient and LocalizationClient.setLanguage then
        return LocalizationClient.setLanguage(language)
    end
    return false
end

-- Event când limba este schimbată cu succes
RegisterNetEvent('switcore:languageChanged', function(language)
    TriggerServerEvent('switcore:getLocalizedMessage', 'language.changed', language)
end)

-- Event pentru erori
RegisterNetEvent('switcore:languageError', function(error)
    print('[CORE] Error changing language: ' .. tostring(error))
end)

-- Event pentru mesaj localizat de la server
RegisterNetEvent('switcore:localizedMessage', function(message)
    print('[CORE] ' .. message)
end)

-- Comandă pentru schimbarea limbii
RegisterCommand('language', function(source, args)
    if #args < 1 then
        print('Usage: /language [ro|en]')
        print('Current language: ' .. getCurrentLanguage())
        print('Available languages: ro (Romanian), en (English)')
        return
    end
    
    local lang = args[1]:lower()
    if lang == 'ro' or lang == 'en' then
        setLanguage(lang)
        print('[CORE] Changing language to: ' .. lang .. '...')
    else
        print('[CORE] Invalid language. Available: ro, en')
    end
end, false)


exports('setLanguage', setLanguage)
exports('getLanguage', getCurrentLanguage)

