-- sessionId -> set de waypoints colectate (anti-cheat in-memory; se reseteaza la restart)
local collectedPoints = {}

local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function getCharJob(characterId)
    local ok, job = pcall(function()
        return exports.jobs:GetCharacterJob(characterId)
    end)
    return ok and job or nil
end

local function notify(src, notifType, title, message)
    TriggerClientEvent('switcore:notify', src, notifType, title .. ': ' .. message, 5000)
end

local function getRouteById(routeId)
    for _, r in ipairs(Config.Routes) do
        if r.id == routeId then return r end
    end
    return nil
end

RegisterNetEvent('garbage:server:hire', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if job and job.name == Config.JobName then
        notify(src, 'warning', 'Salubritate', 'Esti deja angajat la Salubritate.')
        return
    end

    exports.jobs:SetCharacterJob(char.id, Config.JobName, 0)
    GarbageDB.upsertStats(char.id, 0, 0, 0)

    local updated = exports.jobs:GetCharacterJob(char.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, updated)
    notify(src, 'success', 'Angajat la Salubritate',
        'Bine ai venit! Ramai la depou si apasa ALT pentru a intra in tura, apoi alege o ruta din tableta.')
end)

RegisterNetEvent('garbage:server:quit', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then return end

    local session = GarbageDB.getActiveSession(char.id)
    if session then
        local pay = CalculateSessionPay(char.id, session.collected_count, false)
        if pay > 0 then
            local currencyId = GarbageDB.getCurrencyId()
            if currencyId then
                pcall(function() exports.banking:addCharacterCash(char.id, currencyId, pay) end)
            end
        end
        GarbageDB.abandonSession(session.id, pay)
        GarbageDB.upsertStats(char.id, 0, session.collected_count, pay)
        TriggerClientEvent('garbage:client:routeAbandoned', src, { pay = pay })
    end

    exports.jobs:SetCharacterJob(char.id, 'unemployed', 0)
    local updated = exports.jobs:GetCharacterJob(char.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, updated)
    notify(src, 'info', 'Salubritate', 'Ai parasit Salubritatea.')
end)

RegisterNetEvent('garbage:server:startRoute', function(routeId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then
        notify(src, 'error', 'Salubritate', 'Nu esti angajat la Salubritate.')
        return
    end
    if not job.isOnDuty then
        notify(src, 'error', 'Salubritate', 'Trebuie sa fii in tura.')
        return
    end

    local existing = GarbageDB.getActiveSession(char.id)
    if existing then
        notify(src, 'warning', 'Salubritate', 'Ai deja o ruta activa.')
        return
    end

    local route = getRouteById(routeId)
    if not route then
        notify(src, 'error', 'Salubritate', 'Ruta invalida.')
        return
    end

    local session = GarbageDB.createSession(char.id, routeId, #route.waypoints)
    if not session then
        notify(src, 'error', 'Salubritate', 'Eroare la crearea sesiunii.')
        return
    end

    collectedPoints[session.id] = {}

    TriggerClientEvent('garbage:client:routeStarted', src, {
        sessionId = session.id,
        route     = route,
    })
end)

RegisterNetEvent('garbage:server:collectPoint', function(sessionId, pointIndex)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local session = GarbageDB.getActiveSession(char.id)
    if not session or session.id ~= sessionId then
        notify(src, 'error', 'Salubritate', 'Sesiune invalida.')
        return
    end

    -- Anti-cheat: refuza dubla colectare a aceluiasi punct
    if not collectedPoints[sessionId] then collectedPoints[sessionId] = {} end
    if collectedPoints[sessionId][pointIndex] then return end

    local route = getRouteById(session.route_id)
    if not route or pointIndex < 1 or pointIndex > #route.waypoints then return end

    collectedPoints[sessionId][pointIndex] = true

    local updated = GarbageDB.incrementCollected(sessionId)
    if not updated then return end

    TriggerClientEvent('garbage:client:pointCollected', src, {
        sessionId = sessionId,
        collected = updated.collected_count,
        total     = updated.total_waypoints,
    })
end)

RegisterNetEvent('garbage:server:completeRoute', function(sessionId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local session = GarbageDB.getActiveSession(char.id)
    if not session or session.id ~= sessionId then
        notify(src, 'error', 'Salubritate', 'Sesiune invalida.')
        return
    end

    local isComplete = session.collected_count >= session.total_waypoints
    local pay        = CalculateSessionPay(char.id, session.collected_count, isComplete)

    local currencyId = GarbageDB.getCurrencyId()
    if currencyId and pay > 0 then
        pcall(function() exports.banking:addCharacterCash(char.id, currencyId, pay) end)
    end

    GarbageDB.completeSession(sessionId, pay)
    GarbageDB.upsertStats(char.id, 1, session.collected_count, pay)
    collectedPoints[sessionId] = nil

    TriggerClientEvent('garbage:client:routeCompleted', src, {
        pay        = pay,
        collected  = session.collected_count,
        total      = session.total_waypoints,
        isComplete = isComplete,
    })

    CheckGarbagePromotion(char.id, src)
end)

RegisterNetEvent('garbage:server:abandonRoute', function(sessionId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local session = GarbageDB.getActiveSession(char.id)
    if not session or session.id ~= sessionId then return end

    local pay = CalculateSessionPay(char.id, session.collected_count, false)

    local currencyId = GarbageDB.getCurrencyId()
    if currencyId and pay > 0 then
        pcall(function() exports.banking:addCharacterCash(char.id, currencyId, pay) end)
    end

    GarbageDB.abandonSession(sessionId, pay)
    GarbageDB.upsertStats(char.id, 0, session.collected_count, pay)
    collectedPoints[sessionId] = nil

    TriggerClientEvent('garbage:client:routeAbandoned', src, {
        pay       = pay,
        collected = session.collected_count,
    })
end)

RegisterNetEvent('garbage:server:openTablet', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then return end

    local stats   = GarbageDB.getStats(char.id) or { total_sessions = 0, total_collected = 0, total_earned = 0 }
    local recent  = GarbageDB.getRecentSessions(char.id, 10)
    local session = GarbageDB.getActiveSession(char.id)

    -- Doar metadata rutelor; waypoints raman pe server pentru anti-cheat
    local routeMeta = {}
    for _, r in ipairs(Config.Routes) do
        table.insert(routeMeta, {
            id    = r.id,
            name  = r.name,
            count = #r.waypoints,
        })
    end

    TriggerClientEvent('garbage:client:tabletData', src, {
        stats      = stats,
        recent     = recent,
        routes     = routeMeta,
        job        = job,
        hasSession = session ~= nil,
    })
end)
