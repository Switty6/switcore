local settings = {
    defaultDuration  = Config.DefaultDuration  or 5000,
    maxNotifications = Config.MaxNotifications or 5,
    position         = Config.Position         or 'right-middle',
}

local isReady = false
local pending = {}

local function flushPending()
    for _, msg in ipairs(pending) do SendNUIMessage(msg) end
    pending = {}
end

local function enqueue(msg)
    if isReady then
        SendNUIMessage(msg)
    else
        pending[#pending + 1] = msg
    end
end

local function SendNotif(notifType, message, duration)
    enqueue({
        action   = 'notify',
        type     = notifType or 'info',
        message  = message or '',
        duration = duration or settings.defaultDuration
    })
end

local function SendCashNotif(amount, currency, isAdd, duration)
    enqueue({
        action   = 'notifyCash',
        amount   = amount or 0,
        currency = currency or '$',
        isAdd    = isAdd ~= false,
        duration = duration or settings.defaultDuration
    })
end

local function applySettings()
    SendNUIMessage({
        action           = 'config',
        maxNotifications = settings.maxNotifications,
        position         = settings.position
    })
end

CreateThread(function()
    Wait(500)
    applySettings()
    isReady = true
    flushPending()
end)

RegisterNetEvent('notifications:client:settings', function(data)
    if not data then return end
    settings.defaultDuration  = data.defaultDuration  or settings.defaultDuration
    settings.maxNotifications = data.maxNotifications or settings.maxNotifications
    settings.position         = data.position         or settings.position
    applySettings()
end)

RegisterNetEvent('switcore:notify', function(notifType, message, duration)
    SendNotif(notifType, message, duration)
end)

AddEventHandler('switcore:notify:local', function(notifType, message, duration)
    SendNotif(notifType, message, duration)
end)

AddEventHandler('switcore:notifyCash', function(amount, currency, isAdd, duration)
    SendCashNotif(amount, currency, isAdd, duration)
end)

exports('Notify',     SendNotif)
exports('NotifyCash', SendCashNotif)
