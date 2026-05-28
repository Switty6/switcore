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
    AddTextComponentString('Compania de Taxi')
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
        label = 'Angajeaza-te la Compania de Taxi'
    elseif not isOnDuty then
        label = 'Intra in tura (Taxi)'
    else
        label = 'Deschide Tableta / Iesi din tura'
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
        notify('warning', 'Taxi', 'Esti sofer de taxi, nu poti suna un taxi.')
        return
    end
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('taxi:server:requestRide', { x = coords.x, y = coords.y, z = coords.z })
    notify('info', 'Taxi', 'Cererea a fost trimisa. Asteapta un sofer.')
end, false)

local activeOrderIdPassenger = nil

RegisterNetEvent('taxi:client:setDestination', function(data)
    activeOrderIdPassenger = data.orderId
    notify('info', 'Taxi', 'Soferul a confirmat pickupul. Seteaza destinatia cu /taxidest X Y Z sau din GPS.')
end)

RegisterCommand('taxidest', function(_, args)
    if not activeOrderIdPassenger then
        notify('warning', 'Taxi', 'Nu ai o cursa activa.')
        return
    end
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if not (x and y and z) then
        notify('error', 'Taxi', 'Foloseste: /taxidest X Y Z')
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
    notify('success', 'Cursa acceptata', 'Mergi la locul de pickup.')
end)

RegisterNetEvent('taxi:client:rideStarted', function(data)
    TriggerEvent('taxi:dispatch:rideStarted', data)
    notify('info', 'Taxi', 'Pasagerul a urcat. Asteapta destinatia.')
end)

RegisterNetEvent('taxi:client:gpsDropoff', function(dropoffCoords)
    SetNewWaypoint(dropoffCoords.x, dropoffCoords.y)
    TriggerEvent('taxi:dispatch:setDropoff', dropoffCoords)
    notify('info', 'Destinatie setata', 'Mergi la destinatie.')
end)

RegisterNetEvent('taxi:client:rideCompleted', function(data)
    TriggerEvent('taxi:dispatch:cleanup')
    ClearGpsPlayerWaypoint()
    notify('success', 'Cursa finalizata!',
        string.format('Ai castigat %d lei (%.1f km).', data.pay, data.distanceKm))
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
