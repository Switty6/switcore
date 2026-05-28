local function getNotifSettings()
    return {
        maxNotifications = exports.settings:GetSettingNumber('notifications.max_notifications', 5),
        defaultDuration  = exports.settings:GetSettingNumber('notifications.default_duration', 5000),
        position         = exports.settings:GetSetting('notifications.position', 'right-middle'),
    }
end

AddEventHandler('playerSpawned', function()
    local source = source
    TriggerClientEvent('notifications:client:settings', source, getNotifSettings())
end)

AddEventHandler('switcore:characterSelected', function(source)
    TriggerClientEvent('notifications:client:settings', source, getNotifSettings())
end)
