local myJob         = nil
local isTaxi        = false
local isOnDuty      = false
local isUIOpen      = false
local hiringBlip    = nil
local hiringProxId  = nil

local function notify(notifType, title, message)
    TriggerEvent('notifications:client:send', {
        type = notifType, title = title, message = message, duration = 5000
    })
end

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

RegisterNetEvent('jobs:client:jobUpdated')
AddEventHandler('jobs:client:jobUpdated', function(job)
    myJob    = job
    isTaxi   = job and job.name == Config.JobName
    isOnDuty = isTaxi and job.isOnDuty

    SetupHiringBlip()
    SetupHiringProximity()
end)

AddEventHandler('switcore:characterLoaded', function()
    Wait(600)
    TriggerServerEvent('jobs:server:getMyJob')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    -- Server-side handler ignores this event when no character is active
    TriggerServerEvent('jobs:server:getMyJob')
end)

function SetupHiringBlip()
    if hiringBlip and DoesBlipExist(hiringBlip) then
        RemoveBlip(hiringBlip)
        hiringBlip = nil
    end
    local c = Config.HiringCoords
    hiringBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(hiringBlip, 198)
    SetBlipColour(hiringBlip, 2)
    SetBlipScale(hiringBlip, 0.85)
    SetBlipAsShortRange(hiringBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Sw.T('taxi.blip_company'))
    EndTextCommandSetBlipName(hiringBlip)
end

function SetupHiringProximity()
    if hiringProxId then
        exports.proximity:RemoveInteraction(hiringProxId)
        hiringProxId = nil
    end

    local c = Config.HiringCoords
    hiringProxId = 'taxi_hiring'

    local label
    if not isTaxi then
        label = Sw.T('taxi.prox_get_hired')
    elseif not isOnDuty then
        label = Sw.T('taxi.prox_clock_in')
    else
        label = Sw.T('taxi.prox_open_tablet')
    end

    exports.proximity:AddInteraction(
        vector3(c.x, c.y, c.z),
        label,
        hiringProxId,
        {},
        function()
            if not isTaxi then
                TriggerServerEvent('taxi:server:hire')
            elseif not isOnDuty then
                TriggerServerEvent('jobs:server:clockIn')
            else
                TriggerServerEvent('taxi:server:openTablet')
            end
        end
    )
end

RegisterCommand('taxi', function()
    if isTaxi then
        notify('warning', Sw.T('taxi.notify_title'), Sw.T('taxi.cannot_call_as_driver'))
        return
    end
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('taxi:server:requestRide', { x = coords.x, y = coords.y, z = coords.z })
    notify('info', Sw.T('taxi.notify_title'), Sw.T('taxi.request_sent'))
end, false)

local activeOrderIdPassenger = nil

RegisterNetEvent('taxi:client:setDestination', function(data)
    activeOrderIdPassenger = data.orderId
    notify('info', Sw.T('taxi.notify_title'), Sw.T('taxi.pickup_confirmed_set_dest'))
end)

RegisterCommand('taxidest', function(_, args)
    if not activeOrderIdPassenger then
        notify('warning', Sw.T('taxi.notify_title'), Sw.T('taxi.no_active_ride'))
        return
    end
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if not (x and y and z) then
        notify('error', Sw.T('taxi.notify_title'), Sw.T('taxi.taxidest_usage'))
        return
    end
    TriggerServerEvent('taxi:server:setDestination', activeOrderIdPassenger, { x = x, y = y, z = z })
    activeOrderIdPassenger = nil
end, false)

RegisterNetEvent('taxi:client:passengerDone', function()
    activeOrderIdPassenger = nil
end)

RegisterNetEvent('taxi:client:orderAccepted', function(orderData)
    TriggerEvent('taxi:dispatch:orderAccepted', orderData)
    local pickup = orderData.pickup_coords
    SetNewWaypoint(pickup.x, pickup.y)
    notify('success', Sw.T('taxi.ride_accepted_title'), Sw.T('taxi.ride_accepted_message'))
end)

RegisterNetEvent('taxi:client:rideStarted', function(data)
    TriggerEvent('taxi:dispatch:rideStarted', data)
    notify('info', Sw.T('taxi.notify_title'), Sw.T('taxi.passenger_boarded'))
end)

RegisterNetEvent('taxi:client:gpsDropoff', function(dropoffCoords)
    SetNewWaypoint(dropoffCoords.x, dropoffCoords.y)
    TriggerEvent('taxi:dispatch:setDropoff', dropoffCoords)
    notify('info', Sw.T('taxi.destination_set_title'), Sw.T('taxi.go_to_destination'))
end)

RegisterNetEvent('taxi:client:rideCompleted', function(data)
    TriggerEvent('taxi:dispatch:cleanup')
    ClearGpsPlayerWaypoint()
    notify('success', Sw.T('taxi.ride_finished_title'),
        Sw.T('taxi.ride_earned', data.pay, string.format('%.1f', data.distanceKm)))
    Wait(2000)
    TriggerServerEvent('taxi:server:openTablet')
end)

RegisterNetEvent('taxi:client:orderCancelled', function(orderId)
    TriggerEvent('taxi:dispatch:orderCancelled', orderId)
    ClearGpsPlayerWaypoint()
end)

RegisterNetEvent('taxi:client:orderTaken', function(orderId)
    TriggerEvent('taxi:dispatch:orderTaken', orderId)
end)

RegisterNetEvent('taxi:client:tabletData', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    pushI18n()
    SendNUIMessage({
        action  = 'open',
        stats   = data.stats,
        recent  = data.recent,
        pending = data.pending,
        job     = data.job,
    })
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('acceptOrder', function(data, cb)
    if data and data.orderId then
        TriggerServerEvent('taxi:server:acceptOrder', tonumber(data.orderId))
    end
    cb('ok')
end)

RegisterNUICallback('clockIn', function(_, cb)
    TriggerServerEvent('jobs:server:clockIn')
    cb('ok')
end)

RegisterNUICallback('quitJob', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('taxi:server:quit')
    cb('ok')
end)

RegisterNUICallback('cancelOrder', function(data, cb)
    if data and data.orderId then
        TriggerServerEvent('taxi:server:cancelOrder', tonumber(data.orderId))
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    if hiringBlip and DoesBlipExist(hiringBlip) then RemoveBlip(hiringBlip) end
    if hiringProxId then exports.proximity:RemoveInteraction(hiringProxId) end
end)
