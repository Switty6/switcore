isUnconscious = false
isEMS         = false
emsOnDuty     = false
Cfg           = {}

function EmsPushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', EmsPushI18n)

CreateThread(function()
    Wait(1000)
    EmsPushI18n()
end)

RegisterNetEvent('ems:client:config')
AddEventHandler('ems:client:config', function(data)
    Cfg.respawnTimer        = data.respawnTimer
    Cfg.patientScanInterval = data.patientScanInterval
    Cfg.patientScanRange    = data.patientScanRange
    Cfg.stretcherRange      = data.stretcherRange
    Cfg.ambulanceModels     = data.ambulanceModels
    Cfg.mdtKey              = data.mdtKey
    Cfg.ivTreatments        = data.ivTreatments
end)

RegisterNetEvent('jobs:client:jobUpdated')
AddEventHandler('jobs:client:jobUpdated', function(job)
    if job and job.name == 'ems' then
        isEMS     = true
        emsOnDuty = job.isOnDuty
    else
        isEMS     = false
        emsOnDuty = false
    end
end)

local unconsciousThread = nil

RegisterNetEvent('ems:client:youAreUnconscious')
AddEventHandler('ems:client:youAreUnconscious', function(timerSec)
    isUnconscious = true
    local ped = PlayerPedId()

    SetPedToRagdoll(ped, -1, -1, 0, false, false, false)

    AnimpostfxPlay('DeathFailOut', 0, true)

    EmsPushI18n()
    SendNUIMessage({ action = 'showUnconsciousTimer', seconds = timerSec })

    unconsciousThread = true
    CreateThread(function()
        while isUnconscious do
            Wait(0)
            local p = PlayerPedId()
            DisableAllControlActions(0)
            if not IsPedRagdoll(p) then
                SetPedToRagdoll(p, 500, 500, 0, false, false, false)
            end
        end
    end)
end)

RegisterNetEvent('ems:client:revived')
AddEventHandler('ems:client:revived', function(hp)
    isUnconscious = false
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    AnimpostfxStop('DeathFailOut')
    SendNUIMessage({ action = 'hideUnconsciousTimer' })

    if hp and hp > 0 then
        local maxHP = GetEntityMaxHealth(ped)
        local target = math.min(hp, maxHP)
        SetEntityHealth(ped, target)
    end

    exports.notifications:Notify('success', Sw.T('ems.revived'), 5000)
end)

RegisterNetEvent('ems:client:teleportToHospital')
AddEventHandler('ems:client:teleportToHospital', function(coords)
    isUnconscious = false
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    AnimpostfxStop('DeathFailOut')
    SendNUIMessage({ action = 'hideUnconsciousTimer' })

    exports.core:SafeTeleport({ x = coords.x, y = coords.y, z = coords.z }, coords.h or 180.0)

    if coords.hp and coords.hp > 0 then
        local maxHP = GetEntityMaxHealth(ped)
        SetEntityHealth(ped, math.min(coords.hp, maxHP))
    end

    exports.notifications:Notify('info', Sw.T('ems.transported_hospital'), 7000)
end)

CreateThread(function()
    Wait(5000)

    while true do
        Wait(100)
        if isUnconscious then goto cont end

        local ped = PlayerPedId()
        local hp  = GetEntityHealth(ped)

        if hp <= 100 then
            TriggerServerEvent('ems:server:goUnconscious')
        end

        ::cont::
    end
end)

RegisterNUICallback('requestRespawn', function(data, cb)
    TriggerServerEvent('ems:server:requestRespawn')
    cb('ok')
end)

RegisterCommand('911', function(source, args)
    if isUnconscious then return end

    local message = table.concat(args, ' ')
    if not message or #message < 3 then
        exports.notifications:Notify('warning', Sw.T('ems.call_usage'), 3000)
        return
    end

    TriggerServerEvent('ems:server:call112', message)
end, false)

AddEventHandler('playerSpawned', function()
    isUnconscious = false
    AnimpostfxStop('DeathFailOut')
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    AnimpostfxStopAll()
    ClearTimecycleModifier()
end)
