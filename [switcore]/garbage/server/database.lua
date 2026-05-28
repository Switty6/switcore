
GarbageDB = {}

local function pg() return exports.postgres end

local cachedCurrencyId = nil

function GarbageDB.getCurrencyId()
    if cachedCurrencyId then return cachedCurrencyId end
    local ok, currency = pcall(function()
        return exports.banking:getCurrencyByCode('RON')
    end)
    if ok and currency then
        cachedCurrencyId = currency.id
    end
    return cachedCurrencyId
end

function GarbageDB.createSession(charId, routeId, totalWaypoints)
    local ok, result = pcall(function()
        return pg():queryOne(
            [[INSERT INTO garbage_sessions (character_id, route_id, total_waypoints)
              VALUES ($1, $2, $3) RETURNING *]],
            { charId, routeId, totalWaypoints }
        )
    end)
    return ok and result or nil
end

function GarbageDB.getActiveSession(charId)
    local ok, result = pcall(function()
        return pg():queryOne(
            [[SELECT * FROM garbage_sessions
              WHERE character_id = $1 AND status = 'active'
              ORDER BY started_at DESC LIMIT 1]],
            { charId }
        )
    end)
    return ok and result or nil
end

function GarbageDB.incrementCollected(sessionId)
    local ok, result = pcall(function()
        return pg():queryOne(
            [[UPDATE garbage_sessions
              SET collected_count = collected_count + 1
              WHERE id = $1
              RETURNING collected_count, total_waypoints]],
            { sessionId }
        )
    end)
    return ok and result or nil
end

function GarbageDB.completeSession(sessionId, payAmount)
    local ok = pcall(function()
        pg():query(
            [[UPDATE garbage_sessions
              SET status = 'completed', pay_amount = $2, completed_at = NOW()
              WHERE id = $1]],
            { sessionId, payAmount }
        )
    end)
    return ok
end

function GarbageDB.abandonSession(sessionId, payAmount)
    local ok = pcall(function()
        pg():query(
            [[UPDATE garbage_sessions
              SET status = 'abandoned', pay_amount = $2, completed_at = NOW()
              WHERE id = $1 AND status = 'active']],
            { sessionId, payAmount or 0 }
        )
    end)
    return ok
end

function GarbageDB.upsertStats(charId, sessionsAdd, collectedAdd, earnedAdd)
    local ok = pcall(function()
        pg():query(
            [[INSERT INTO garbage_stats (character_id, total_sessions, total_collected, total_earned)
              VALUES ($1, $2, $3, $4)
              ON CONFLICT (character_id) DO UPDATE SET
                  total_sessions  = garbage_stats.total_sessions  + EXCLUDED.total_sessions,
                  total_collected = garbage_stats.total_collected + EXCLUDED.total_collected,
                  total_earned    = garbage_stats.total_earned    + EXCLUDED.total_earned,
                  updated_at      = NOW()]],
            { charId, sessionsAdd, collectedAdd, earnedAdd }
        )
    end)
    return ok
end

function GarbageDB.getStats(charId)
    local ok, result = pcall(function()
        return pg():queryOne(
            'SELECT * FROM garbage_stats WHERE character_id = $1',
            { charId }
        )
    end)
    return ok and result or nil
end

function GarbageDB.getRecentSessions(charId, limit)
    local ok, rows = pcall(function()
        return pg():queryAll(
            [[SELECT id, route_id, status, collected_count, total_waypoints,
                     pay_amount, started_at, completed_at
              FROM garbage_sessions
              WHERE character_id = $1
              ORDER BY started_at DESC
              LIMIT $2]],
            { charId, limit or 10 }
        )
    end)
    return ok and rows or {}
end

function GarbageDB.abandonStaleSessions()
    pcall(function()
        pg():query(
            [[UPDATE garbage_sessions SET status = 'abandoned', completed_at = NOW()
              WHERE status = 'active']],
            {}
        )
    end)
end
