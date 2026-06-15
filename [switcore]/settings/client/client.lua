local isOpen = false

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

local function openPanel()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    -- Panel se deschide pe client doar dupa ce datele sosesc de la server (vezi 'allSettings')
    TriggerServerEvent('settings:server:getAll')
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('settings:client:allSettings', function(payload)
    pushI18n()
    SendNUIMessage({ action = 'open', payload = payload })
end)

RegisterNetEvent('settings:client:saveResult', function(data)
    SendNUIMessage({ action = 'saveResult', data = data })
end)

RegisterNetEvent('settings:client:reloaded', function()
    TriggerServerEvent('settings:server:getAll')
end)

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb('ok')
end)

RegisterNUICallback('save', function(data, cb)
    if data.key and data.value ~= nil then
        TriggerServerEvent('settings:server:save', data.key, data.value)
    end
    cb('ok')
end)

RegisterNUICallback('reload', function(_, cb)
    TriggerServerEvent('settings:server:reload')
    cb('ok')
end)

RegisterCommand('settings', function()
    openPanel()
end, false)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isOpen and IsControlJustReleased(0, 200) then -- ESC
            closePanel()
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isOpen then
        closePanel()
    end
end)
