local myJob         = nil
local isGarbage     = false
local isOnDuty      = false
local isUIOpen      = false
local hiringBlip    = nil
local hiringProxId  = nil
local returnProxId  = nil

local function notify(notifType, title, message)
    TriggerEvent('switcore:notify:local', notifType, title .. ': ' .. message, 5000)
end

RegisterNetEvent('jobs:client:jobUpdated')
AddEventHandler('jobs:client:jobUpdated', function(job)
    myJob     = job
    isGarbage = job and job.name == Config.JobName
    isOnDuty  = isGarbage and job.isOnDuty

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
    -- Serverul ignoră eventul dacă nu există character activ
    TriggerServerEvent('jobs:server:getMyJob')
end)

function SetupHiringBlip()
    if hiringBlip and DoesBlipExist(hiringBlip) then
        RemoveBlip(hiringBlip)
        hiringBlip = nil
    end
    local c = Config.HiringCoords
    hiringBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(hiringBlip, 318)
    SetBlipColour(hiringBlip, 4)
    SetBlipScale(hiringBlip, 0.85)
    SetBlipAsShortRange(hiringBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Depoul Salubritate')
    EndTextCommandSetBlipName(hiringBlip)
end

function SetupHiringProximity()
    if hiringProxId then
        exports.proximity:RemoveInteraction(hiringProxId)
        hiringProxId = nil
    end

    local c = Config.HiringCoords

    local label
    if not isGarbage then
        label = 'Angajeaza-te la Salubritate'
    elseif not isOnDuty then
        label = 'Intra in tura (Salubritate)'
    else
        label = 'Deschide Tableta Salubritate'
    end

    hiringProxId = exports.proximity:AddInteraction(
        vector3(c.x, c.y, c.z),
        label,
        'default',
        {},
        function()
            if not isGarbage then
                TriggerServerEvent('garbage:server:hire')
            elseif not isOnDuty then
                TriggerServerEvent('jobs:server:clockIn')
            else
                TriggerServerEvent('garbage:server:openTablet')
            end
        end
    )
end

RegisterNetEvent('garbage:client:routeStarted', function(data)
    TriggerEvent('garbage:route:start', data)

    if hiringProxId then
        exports.proximity:RemoveInteraction(hiringProxId)
        hiringProxId = nil
    end
    if returnProxId then
        exports.proximity:RemoveInteraction(returnProxId)
        returnProxId = nil
    end
    local c = Config.HiringCoords
    returnProxId = exports.proximity:AddInteraction(
        vector3(c.x, c.y, c.z),
        'Returneaza la Depou',
        'default',
        {},
        function()
            TriggerEvent('garbage:route:returnedToDepot')
        end
    )
end)

RegisterNetEvent('garbage:client:pointCollected', function(data)
    TriggerEvent('garbage:route:pointConfirmed', data)
end)

RegisterNetEvent('garbage:client:routeCompleted', function(data)
    TriggerEvent('garbage:route:cleanup')
    if returnProxId then
        exports.proximity:RemoveInteraction(returnProxId)
        returnProxId = nil
    end
    SetupHiringProximity()
    local bonusText = data.isComplete and ' + bonus' or ''
    notify('success', 'Ruta Finalizata!',
        string.format('Ai castigat %d lei (%d/%d containere%s).',
            data.pay, data.collected, data.total, bonusText))
    Wait(2000)
    TriggerServerEvent('garbage:server:openTablet')
end)

RegisterNetEvent('garbage:client:routeAbandoned', function(data)
    TriggerEvent('garbage:route:cleanup')
    if returnProxId then
        exports.proximity:RemoveInteraction(returnProxId)
        returnProxId = nil
    end
    SetupHiringProximity()
    if data.pay and data.pay > 0 then
        notify('warning', 'Ruta Abandonata',
            string.format('Plata partiala: %d lei (%d containere).', data.pay, data.collected or 0))
    else
        notify('info', 'Ruta Abandonata', 'Nicio plata (niciun container colectat).')
    end
end)

RegisterNetEvent('garbage:client:tabletData', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = 'open',
        stats      = data.stats,
        recent     = data.recent,
        routes     = data.routes,
        job        = data.job,
        hasSession = data.hasSession,
    })
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('startRoute', function(data, cb)
    local routeId = data and tonumber(data.routeId)
    if routeId then
        TriggerServerEvent('garbage:server:startRoute', routeId)
        isUIOpen = false
        SetNuiFocus(false, false)
    end
    cb('ok')
end)

RegisterNUICallback('abandonRoute', function(data, cb)
    local sessionId = data and tonumber(data.sessionId)
    if sessionId then
        TriggerServerEvent('garbage:server:abandonRoute', sessionId)
    end
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('clockIn', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('jobs:server:clockIn')
    cb('ok')
end)

RegisterNUICallback('quitJob', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('garbage:server:quit')
    cb('ok')
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    if hiringBlip and DoesBlipExist(hiringBlip) then RemoveBlip(hiringBlip) end
    if hiringProxId then exports.proximity:RemoveInteraction(hiringProxId) end
    if returnProxId then exports.proximity:RemoveInteraction(returnProxId) end
end)
