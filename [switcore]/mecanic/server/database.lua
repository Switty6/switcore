MecanicDB = {}

local function pg()
    return exports.postgres
end

local function ensurePg()
    local p = pg()
    return p and p:isReady()
end

function MecanicDB.createCall(clientCharId, vehicleId, problemType, location)
    if not ensurePg() then return nil end
    local row = pg():queryOne([[
        INSERT INTO mechanic_service_calls
            (client_char_id, vehicle_id, problem_type, location)
        VALUES ($1, $2, $3, $4::jsonb)
        RETURNING *
    ]], { clientCharId, vehicleId, problemType, json.encode(location) })
    return row
end

function MecanicDB.getOpenCalls()
    if not ensurePg() then return {} end
    return pg():queryAll([[
        SELECT msc.*,
               c.first_name || ' ' || c.last_name AS client_name,
               ov.plate, ov.model
        FROM mechanic_service_calls msc
        JOIN characters c ON c.id = msc.client_char_id
        LEFT JOIN owned_vehicles ov ON ov.id = msc.vehicle_id
        WHERE msc.status = 'pending'
        ORDER BY msc.created_at ASC
    ]], {})
end

function MecanicDB.acceptCall(callId, mechanicCharId)
    if not ensurePg() then return false end
    local ok = pcall(function()
        pg():query([[
            UPDATE mechanic_service_calls
            SET status = 'accepted', mechanic_char_id = $1
            WHERE id = $2 AND status = 'pending'
        ]], { mechanicCharId, callId })
    end)
    return ok
end

function MecanicDB.completeCall(callId, price)
    if not ensurePg() then return false end
    local ok = pcall(function()
        pg():query([[
            UPDATE mechanic_service_calls
            SET status = 'completed', price = $1, completed_at = NOW()
            WHERE id = $2
        ]], { price, callId })
    end)
    return ok
end

function MecanicDB.cancelCall(callId)
    if not ensurePg() then return false end
    local ok = pcall(function()
        pg():query([[
            UPDATE mechanic_service_calls
            SET status = 'cancelled'
            WHERE id = $1 AND status IN ('pending','accepted')
        ]], { callId })
    end)
    return ok
end

function MecanicDB.getCallById(callId)
    if not ensurePg() then return nil end
    return pg():queryOne('SELECT * FROM mechanic_service_calls WHERE id = $1', { callId })
end

function MecanicDB.logService(mechanicCharId, clientCharId, vehicleId, serviceType, price, bonus)
    if not ensurePg() then return end
    pcall(function()
        pg():query([[
            INSERT INTO mechanic_service_log
                (mechanic_char_id, client_char_id, vehicle_id, service_type, price, bonus_paid)
            VALUES ($1, $2, $3, $4, $5, $6)
        ]], { mechanicCharId, clientCharId, vehicleId, serviceType, price, bonus or 0 })
    end)
end

function MecanicDB.getMechanicStats(charId)
    if not ensurePg() then return nil end
    return pg():queryOne([[
        SELECT
            COUNT(*)                          AS total_services,
            COALESCE(SUM(price), 0)           AS total_revenue,
            COALESCE(SUM(bonus_paid), 0)      AS total_bonus,
            COUNT(*) FILTER (WHERE completed_at > NOW() - INTERVAL '1 day') AS today_services
        FROM mechanic_service_log
        WHERE mechanic_char_id = $1
    ]], { charId })
end

function MecanicDB.getRecentServices(charId, limit)
    if not ensurePg() then return {} end
    return pg():queryAll([[
        SELECT msl.*, c.first_name || ' ' || c.last_name AS client_name,
               ov.plate, ov.model
        FROM mechanic_service_log msl
        JOIN characters c ON c.id = msl.client_char_id
        LEFT JOIN owned_vehicles ov ON ov.id = msl.vehicle_id
        WHERE msl.mechanic_char_id = $1
        ORDER BY msl.completed_at DESC
        LIMIT $2
    ]], { charId, limit or 20 })
end

function MecanicDB.getComponents(vehicleId)
    if not ensurePg() then return nil end
    local row = pg():queryOne('SELECT components FROM owned_vehicles WHERE id = $1', { vehicleId })
    if not row then return nil end
    local c = row.components
    if type(c) == 'string' then
        local ok, decoded = pcall(json.decode, c)
        if ok and type(decoded) == 'table' then return decoded end
        return {}
    end
    return c
end

function MecanicDB.saveComponents(vehicleId, components)
    if not ensurePg() then return false end
    local ok = pcall(function()
        pg():query(
            'UPDATE owned_vehicles SET components = $1::jsonb, updated_at = NOW() WHERE id = $2',
            { json.encode(components), vehicleId }
        )
    end)
    return ok
end

local cachedCurrencyId = nil

function MecanicDB.getRonCurrencyId()
    if cachedCurrencyId then return cachedCurrencyId end
    local ok, currency = pcall(function()
        return exports.banking:getCurrencyByCode('RON')
    end)
    if ok and currency then
        cachedCurrencyId = currency.id
    end
    return cachedCurrencyId
end
