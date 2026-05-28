local function getCurrentLanguage()
    if LocalizationClient and LocalizationClient.getLanguage then
        return LocalizationClient.getLanguage()
    end
    return 'ro'
end

local function setLanguage(language)
    if LocalizationClient and LocalizationClient.setLanguage then
        return LocalizationClient.setLanguage(language)
    end
    return false
end

RegisterNetEvent('switcore:languageChanged', function(language)
    TriggerServerEvent('switcore:getLocalizedMessage', 'language.changed', language)
end)

RegisterNetEvent('switcore:languageError', function(error)
    print('[CORE] Error changing language: ' .. tostring(error))
end)

RegisterNetEvent('switcore:localizedMessage', function(message)
    print('[CORE] ' .. message)
end)

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
