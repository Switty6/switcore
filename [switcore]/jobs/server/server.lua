
CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    JobsDatabase.ensureSalarySchema()
    print('[JOBS] Sistem joburi inițializat')
    StartSalaryLoop()
end)

function StartSalaryLoop()
    CreateThread(function()
        while true do
            local interval = exports.settings:GetSettingNumber('jobs.salary_interval', 1800000)
            Wait(interval)
            PaySalaries()
        end
    end)
end

local function sourceForCharacterId(charId)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local ok, character = pcall(function()
            return exports.characters:getActiveCharacter(src)
        end)
        if ok and character and character.id == charId then return src end
    end
end

function PaySalaries()
    local intervalMs   = exports.settings:GetSettingNumber('jobs.salary_interval', 1800000)
    local intervalSecs = math.max(1, math.floor((intervalMs * 0.9) / 1000))
    local toPay = JobsDatabase.claimSalaryBatch(intervalSecs)
    if not toPay or #toPay == 0 then return end

    for _, row in ipairs(toPay) do
        local salary    = tonumber(row.salary) or 0
        local jobLabel  = row.job_label or row.job_name
        local charLabel = (row.first_name or '') .. ' ' .. (row.last_name or '')

        local okExp, errExp = pcall(function()
            exports.government:AddExpense(salary, 'RON',
                'Salariu ' .. jobLabel .. ' - ' .. charLabel, 'Salarii')
        end)
        if not okExp then
            print(('[JOBS] AddExpense eroare pentru %s: %s'):format(charLabel, tostring(errExp)))
        end

        local okPay, errPay = pcall(function()
            exports.banking:addCash(row.character_id, salary, 'Salariu - ' .. jobLabel)
        end)
        if not okPay then
            print(('[JOBS] addCash eroare pentru char %d: %s'):format(row.character_id, tostring(errPay)))
        end

        local src = sourceForCharacterId(row.character_id)
        if src then
            TriggerClientEvent('notifications:client:send', src, {
                type = 'success', title = 'Salariu',
                message = 'Ai primit $' .. salary .. ' salariu.',
                duration = 5000
            })
        end
    end
end

function BuildJobPayload(job)
    if not job then return nil end
    local perms = job.permissions
    if type(perms) == 'string' then
        perms = json.decode(perms) or {}
    end
    local coords = job.blip_coords
    if type(coords) == 'string' then
        coords = json.decode(coords)
    end
    return {
        name        = job.job_name,
        label       = job.job_label,
        type        = job.job_type,
        grade       = job.grade,
        gradeLabel  = job.grade_label,
        salary      = job.salary or 0,
        canManage   = job.can_manage == true,
        permissions = perms or {},
        isOnDuty    = job.is_on_duty == true,
        blipSprite  = job.blip_sprite,
        blipColor   = job.blip_color,
        blipCoords  = coords,
    }
end

local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function isAdmin(src)
    local ok, result = pcall(function()
        return exports.core:hasPermission(src, 'admin')
    end)
    return ok and result == true
end

local function notify(src, notifType, title, message)
    TriggerClientEvent('notifications:client:send', src, {
        type = notifType, title = title, message = message, duration = 4000
    })
end

exports('GetCharacterJob', function(characterId)
    local job = JobsDatabase.getCharacterJob(characterId)
    return BuildJobPayload(job)
end)

exports('SetCharacterJob', function(characterId, jobName, grade)
    JobsDatabase.upsertCharacterJob(characterId, jobName, grade or 0)
    -- Push update to player if online
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local char = getActiveChar(src)
        if char and char.id == characterId then
            local updated = JobsDatabase.getCharacterJob(characterId)
            if updated then
                TriggerClientEvent('jobs:client:jobUpdated', src, BuildJobPayload(updated))
            end
            break
        end
    end
    return true
end)

exports('SetCharacterGrade', function(characterId, grade)
    JobsDatabase.setGrade(characterId, grade)
    return true
end)

exports('HasJobPermission', function(characterId, permission)
    local job = JobsDatabase.getCharacterJob(characterId)
    if not job then return false end
    local perms = job.permissions
    if type(perms) == 'string' then perms = json.decode(perms) or {} end
    for _, p in ipairs(perms or {}) do
        if p == permission then return true end
    end
    return false
end)

exports('GetJobRoster', function(jobName)
    return JobsDatabase.getRoster(jobName)
end)

exports('IsJobManager', function(characterId)
    local job = JobsDatabase.getCharacterJob(characterId)
    return job ~= nil and job.can_manage == true
end)

RegisterNetEvent('jobs:server:getMyJob', function()
    local src = source
    local character = getActiveChar(src)
    if not character then return end

    local job = JobsDatabase.ensureDefaultJob(character.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, BuildJobPayload(job))
end)

RegisterNetEvent('jobs:server:clockIn', function()
    local src = source
    local character = getActiveChar(src)
    if not character then return end

    local job = JobsDatabase.getCharacterJob(character.id)
    if not job then return end
    if job.job_type == 'illegal' then return end

    if job.is_on_duty == true then
        JobsDatabase.atomicClockOut(character.id)
    else
        JobsDatabase.atomicClockIn(character.id, job.job_name)
    end

    local updated = JobsDatabase.getCharacterJob(character.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, BuildJobPayload(updated))
end)

RegisterNetEvent('jobs:server:adminAssign', function(targetSrc, jobName, grade)
    local src = source
    local myChar = getActiveChar(src)
    if not myChar then return end

    grade = tonumber(grade) or 0

    if not isAdmin(src) then
        local myJob = JobsDatabase.getCharacterJob(myChar.id)
        if not myJob or not myJob.can_manage then
            notify(src, 'error', 'Acces interzis', 'Nu ai permisiunea să angajezi.')
            return
        end
        if myJob.job_name ~= jobName then
            notify(src, 'error', 'Acces interzis', 'Poți angaja doar în facțiunea ta.')
            return
        end
        if grade >= myJob.grade then
            notify(src, 'error', 'Acces interzis', 'Nu poți acorda un grad egal sau superior al tău.')
            return
        end
    end

    local targetChar = getActiveChar(tonumber(targetSrc))
    if not targetChar then
        notify(src, 'error', 'Eroare', 'Jucătorul nu a fost găsit.')
        return
    end

    JobsDatabase.upsertCharacterJob(targetChar.id, jobName, grade)
    local newJob = JobsDatabase.getCharacterJob(targetChar.id)
    TriggerClientEvent('jobs:client:jobUpdated', tonumber(targetSrc), BuildJobPayload(newJob))
    notify(tonumber(targetSrc), 'info', 'Job actualizat', 'Ai primit jobul: ' .. (newJob and newJob.job_label or jobName))
    notify(src, 'success', 'Job atribuit', 'Job atribuit cu succes.')
end)

RegisterNetEvent('jobs:server:manageGrade', function(targetCharId, newGrade)
    local src = source
    local myChar = getActiveChar(src)
    if not myChar then return end

    targetCharId = tonumber(targetCharId)
    newGrade     = tonumber(newGrade) or 0

    if not isAdmin(src) then
        local myJob = JobsDatabase.getCharacterJob(myChar.id)
        if not myJob or not myJob.can_manage then
            notify(src, 'error', 'Acces interzis', 'Nu ai permisiunea să promovezi membri.')
            return
        end
        local targetJob = JobsDatabase.getCharacterJob(targetCharId)
        if not targetJob or targetJob.job_name ~= myJob.job_name then
            notify(src, 'error', 'Acces interzis', 'Jucătorul nu face parte din același job.')
            return
        end
        if newGrade >= myJob.grade then
            notify(src, 'error', 'Acces interzis', 'Nu poți acorda un grad egal sau superior al tău.')
            return
        end
    end

    JobsDatabase.setGrade(targetCharId, newGrade)
    notify(src, 'success', 'Grad setat', 'Grad setat cu succes.')

    for _, playerId in ipairs(GetPlayers()) do
        local pSrc = tonumber(playerId)
        local char = getActiveChar(pSrc)
        if char and char.id == targetCharId then
            local updated = JobsDatabase.getCharacterJob(targetCharId)
            if updated then
                TriggerClientEvent('jobs:client:jobUpdated', pSrc, BuildJobPayload(updated))
                notify(pSrc, 'info', 'Grad actualizat', 'Gradul tău a fost modificat.')
            end
            break
        end
    end
end)

RegisterNetEvent('jobs:server:getRoster', function(jobName)
    local src = source
    local character = getActiveChar(src)
    if not character then return end

    if not isAdmin(src) then
        local myJob = JobsDatabase.getCharacterJob(character.id)
        if not myJob or myJob.job_name ~= jobName or not myJob.can_manage then
            notify(src, 'error', 'Acces interzis', 'Nu ai acces la evidența membrilor.')
            return
        end
    end

    local roster = JobsDatabase.getRoster(jobName)
    local grades  = JobsDatabase.getJobGrades(jobName)
    TriggerClientEvent('jobs:client:rosterData', src, { roster = roster, grades = grades, jobName = jobName })
end)
