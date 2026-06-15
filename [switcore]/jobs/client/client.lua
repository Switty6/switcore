
local currentJob  = nil
local isUIOpen    = false
local jobBlip     = nil

local function Send(data)
    SendNUIMessage(data)
end

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

local function removeJobBlip()
    if jobBlip and DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
        jobBlip = nil
    end
end

local function createJobBlip(job)
    removeJobBlip()
    if not job or not job.blipCoords or not job.blipSprite then return end
    local c = job.blipCoords
    jobBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(jobBlip, job.blipSprite)
    SetBlipColour(jobBlip, job.blipColor or 0)
    SetBlipScale(jobBlip, 0.8)
    SetBlipAsShortRange(jobBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(job.label or job.name or Sw.T('jobs.blip.default_name'))
    EndTextCommandSetBlipName(jobBlip)
end

local function updateHUDJob(job)
    -- Forward to HUD resource via local event
    TriggerEvent('hud:setJobInfo', job)
end

local proximityId = nil

local function registerJobProximity(job)
    if proximityId then
        exports.proximity:RemoveInteraction(proximityId)
        proximityId = nil
    end
    if not job or not job.blipCoords then return end
    if job.name == 'unemployed' then return end

    local c      = job.blipCoords
    local coords = vector3(c.x, c.y, c.z)

    -- AddInteraction returneaza un id numeric; il capturam ca sa-l putem sterge corect
    -- (altfel se acumuleaza duplicate la fiecare refresh de job).
    proximityId = exports.proximity:AddInteraction(
        coords,
        Sw.T('jobs.proximity.base_suffix', job.label),
        'job_base_' .. job.name,
        {},
        function()
            if not isUIOpen then
                OpenTablet()
            end
        end
    )
end

function OpenTablet()
    TriggerServerEvent('jobs:server:openTablet')
end

RegisterNetEvent('jobs:client:tabletData', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    pushI18n()
    Send({ action = 'open', job = data.job, grades = data.grades, coworkers = data.coworkers, allJobs = data.allJobs })
end)

RegisterNetEvent('jobs:client:rosterData', function(data)
    Send({ action = 'rosterData', roster = data.roster, grades = data.grades, jobName = data.jobName })
end)

RegisterNetEvent('jobs:client:jobUpdated', function(job)
    currentJob = job
    updateHUDJob(job)
    createJobBlip(job)
    registerJobProximity(job)
    -- If tablet is open, refresh it
    if isUIOpen then
        Send({ action = 'jobUpdated', job = job })
    end
end)

AddEventHandler('switcore:characterLoaded', function(character)
    Wait(500) -- small delay so server character_jobs is ready
    TriggerServerEvent('jobs:server:getMyJob')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(1500)
        -- Serverul ignoră eventul dacă nu există character activ
        TriggerServerEvent('jobs:server:getMyJob')
    end
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('clockIn', function(_, cb)
    TriggerServerEvent('jobs:server:clockIn')
    cb('ok')
end)

RegisterNUICallback('getRoster', function(data, cb)
    local jobName = data and data.jobName or (currentJob and currentJob.name)
    if jobName then
        TriggerServerEvent('jobs:server:getRoster', jobName)
    end
    cb('ok')
end)

RegisterNUICallback('manageGrade', function(data, cb)
    if data and data.characterId and data.grade ~= nil then
        TriggerServerEvent('jobs:server:manageGrade', data.characterId, data.grade)
    end
    cb('ok')
end)

RegisterNUICallback('assignJob', function(data, cb)
    if data and data.targetSrc and data.jobName then
        TriggerServerEvent('jobs:server:adminAssign', data.targetSrc, data.jobName, data.grade or 0)
    end
    cb('ok')
end)

RegisterNUICallback('refreshRoster', function(data, cb)
    local jobName = data and data.jobName or (currentJob and currentJob.name)
    if jobName then
        TriggerServerEvent('jobs:server:getRoster', jobName)
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        removeJobBlip()
        if proximityId then
            exports.proximity:RemoveInteraction(proximityId)
            proximityId = nil
        end
    end
end)
