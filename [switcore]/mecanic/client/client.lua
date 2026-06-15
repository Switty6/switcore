local isUIOpen      = false
local isMechanic    = false
local myJob         = nil
local workshopBlip  = nil
local proximityId   = nil

local function Send(data)
    SendNUIMessage(data)
end

function PushMecanicI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', PushMecanicI18n)

local function notify(notifType, title, message)
    TriggerEvent('notifications:client:send', { type = notifType, title = title, message = message, duration = 5000 })
end

RegisterNetEvent('jobs:client:jobUpdated')
AddEventHandler('jobs:client:jobUpdated', function(job)
    myJob      = job
    isMechanic = job and job.name == Config.JobName
    if isMechanic then
        SetupWorkshopBlip()
        SetupWorkshopProximity()
    else
        RemoveWorkshopBlip()
        RemoveWorkshopProximity()
    end
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

function SetupWorkshopBlip()
    RemoveWorkshopBlip()
    local c = Config.WorkshopCoords
    workshopBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(workshopBlip, 446)
    SetBlipColour(workshopBlip, 5)
    SetBlipScale(workshopBlip, 0.9)
    SetBlipAsShortRange(workshopBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Sw.T('mecanic.blip_workshop'))
    EndTextCommandSetBlipName(workshopBlip)
end

function RemoveWorkshopBlip()
    if workshopBlip and DoesBlipExist(workshopBlip) then
        RemoveBlip(workshopBlip)
        workshopBlip = nil
    end
end

function SetupWorkshopProximity()
    RemoveWorkshopProximity()
    if not isMechanic then return end

    local c = Config.WorkshopCoords
    proximityId = 'mecanic_workshop'

    exports.proximity:AddInteraction(
        vector3(c.x, c.y, c.z),
        Sw.T('mecanic.prox_open_tablet'),
        proximityId,
        {},
        function()
            if not isUIOpen then
                OpenTablet()
            end
        end
    )
end

function RemoveWorkshopProximity()
    if proximityId then
        exports.proximity:RemoveInteraction(proximityId)
        proximityId = nil
    end
end

function OpenTablet()
    TriggerServerEvent('mecanic:server:openTablet')
end

RegisterNetEvent('mecanic:client:tabletData', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    PushMecanicI18n()
    Send({ action = 'open', stats = data.stats, recent = data.recent,
           calls = data.calls, prices = data.prices, job = myJob })
end)

RegisterNetEvent('mecanic:client:openCalls', function(calls)
    Send({ action = 'updateCalls', calls = calls })
end)

RegisterNetEvent('mecanic:client:inspectResult', function(data)
    Send({ action = 'inspectResult', data = data })
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('acceptCall', function(data, cb)
    if data and data.callId then
        TriggerServerEvent('mecanic:server:acceptCall', tonumber(data.callId))
    end
    cb('ok')
end)

RegisterNUICallback('refreshCalls', function(_, cb)
    TriggerServerEvent('mecanic:server:getOpenCalls')
    cb('ok')
end)

RegisterNUICallback('buyParts', function(data, cb)
    if data then
        TriggerServerEvent('mecanic:server:buyParts', data)
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveWorkshopBlip()
    RemoveWorkshopProximity()
end)
