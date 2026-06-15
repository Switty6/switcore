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

local function translate(key, ...)
    if LocalizationClient and LocalizationClient.translate then
        return LocalizationClient.translate(key, ...)
    end
    return key
end

RegisterNetEvent('switcore:languageChanged', function(language)
    TriggerServerEvent('switcore:getLocalizedMessage', 'language.changed', language)
end)

RegisterNetEvent('switcore:languageError', function(error)
    print('[CORE] ' .. tostring(error))
end)

RegisterNetEvent('switcore:localizedMessage', function(message)
    print('[CORE] ' .. message)
end)

RegisterCommand('language', function(source, args)
    if #args < 1 then
        print(translate('language.usage'))
        print(translate('language.current', getCurrentLanguage()))
        print(translate('language.available'))
        return
    end

    local lang = args[1]:lower()
    if lang == 'ro' or lang == 'en' then
        setLanguage(lang)
        print('[CORE] ' .. translate('language.changing', lang))
    else
        print('[CORE] ' .. translate('language.invalid'))
    end
end, false)

exports('setLanguage', setLanguage)
exports('getLanguage', getCurrentLanguage)
