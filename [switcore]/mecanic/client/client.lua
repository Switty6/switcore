local isUIOpen      = false
isMechanic    = false
myJob         = nil
local workshopBlip  = {}
local proximityId   = {}

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
    TriggerServerEvent('jobs:server:getMyJob')
end)

RegisterNetEvent('mecanic:client:workshopLocations', function(locations)
    if locations and #locations > 0 then
        Config.WorkshopLocations = locations
    end
    if isMechanic then
        SetupWorkshopBlip()
        SetupWorkshopProximity()
    end
end)

function SetupWorkshopBlip()
    RemoveWorkshopBlip()
    for _, c in ipairs(Config.WorkshopLocations) do
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, 446)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.9)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Sw.T('mecanic.blip_workshop'))
        EndTextCommandSetBlipName(blip)
        table.insert(workshopBlip, blip)
    end
end

function RemoveWorkshopBlip()
    for _, blip in ipairs(workshopBlip) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    workshopBlip = {}
end

function SetupWorkshopProximity()
    RemoveWorkshopProximity()
    if not isMechanic then return end

    for i, c in ipairs(Config.WorkshopLocations) do
        local id = 'mecanic_workshop_' .. i
        exports.proximity:AddInteraction(
            vector3(c.x, c.y, c.z),
            Sw.T('mecanic.prox_open_tablet'),
            id,
            {},
            function()
                if not isUIOpen then
                    OpenTablet()
                end
            end
        )
        table.insert(proximityId, id)
    end
end

function RemoveWorkshopProximity()
    for _, id in ipairs(proximityId) do
        exports.proximity:RemoveInteraction(id)
    end
    proximityId = {}
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
