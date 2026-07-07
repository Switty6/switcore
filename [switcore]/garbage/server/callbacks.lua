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

Sw.SecureEvent('garbage:server:hire', {
    character = true,
    silent = true,
    rateLimit = { max = 5, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    local job = getCharJob(char.id)
    if job and job.name == Config.JobName then
        notify(src, 'warning', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.already_hired'))
        return
    end

    exports.jobs:SetCharacterJob(char.id, Config.JobName, 0)
    GarbageDB.upsertStats(char.id, 0, 0, 0)

    local updated = exports.jobs:GetCharacterJob(char.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, updated)
    notify(src, 'success', Sw.TP(src, 'garbage.title_hired'), Sw.TP(src, 'garbage.welcome'))
end)

Sw.SecureEvent('garbage:server:quit', {
    character = true,
    silent = true,
    rateLimit = { max = 5, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

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
    notify(src, 'info', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.quit'))
end)

Sw.SecureEvent('garbage:server:startRoute', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'routeId', type = 'int', min = 1 },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local routeId = ctx.args.routeId

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then
        notify(src, 'error', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.not_hired'))
        return
    end
    if not job.isOnDuty then
        notify(src, 'error', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.not_on_duty'))
        return
    end

    local existing = GarbageDB.getActiveSession(char.id)
    if existing then
        notify(src, 'warning', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.already_active_route'))
        return
    end

    local route = getRouteById(routeId)
    if not route then
        notify(src, 'error', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.invalid_route'))
        return
    end

    local session = GarbageDB.createSession(char.id, routeId, #route.waypoints)
    if not session then
        notify(src, 'error', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.session_create_error'))
        return
    end

    collectedPoints[session.id] = {}

    TriggerClientEvent('garbage:client:routeStarted', src, {
        sessionId = session.id,
        route     = route,
    })
end)

Sw.SecureEvent('garbage:server:collectPoint', {
    character = true,
    silent = true,
    rateLimit = { max = 30, window = 3000 },
    args = {
        { name = 'sessionId',  type = 'int', min = 1 },
        { name = 'pointIndex', type = 'int', min = 1 },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local sessionId  = ctx.args.sessionId
    local pointIndex = ctx.args.pointIndex

    local session = GarbageDB.getSessionById(sessionId)
    if not session or session.character_id ~= char.id or session.status ~= 'active' then
        notify(src, 'error', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.invalid_session'))
        TriggerClientEvent('garbage:client:sessionInvalid', src)
        return
    end

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

Sw.SecureEvent('garbage:server:completeRoute', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'sessionId', type = 'int', min = 1 },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local sessionId = ctx.args.sessionId

    local session = GarbageDB.getSessionById(sessionId)
    if not session or session.character_id ~= char.id or session.status ~= 'active' then
        notify(src, 'error', Sw.TP(src, 'garbage.title_garbage'), Sw.TP(src, 'garbage.invalid_session'))
        TriggerClientEvent('garbage:client:sessionInvalid', src)
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

Sw.SecureEvent('garbage:server:abandonRoute', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'sessionId', type = 'int', min = 1 },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local sessionId = ctx.args.sessionId

    local session = GarbageDB.getSessionById(sessionId)
    if not session or session.character_id ~= char.id or session.status ~= 'active' then
        TriggerClientEvent('garbage:client:sessionInvalid', src)
        return
    end

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

Sw.SecureEvent('garbage:server:openTablet', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then return end

    local stats   = GarbageDB.getStats(char.id) or { total_sessions = 0, total_collected = 0, total_earned = 0 }
    local recent  = GarbageDB.getRecentSessions(char.id, 10)
    local session = GarbageDB.getActiveSession(char.id)

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
        sessionId  = session and session.id or nil,
    })
end)
