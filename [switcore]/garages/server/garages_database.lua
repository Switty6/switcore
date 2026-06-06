
GaragesDatabase = {}

local function getPostgres()
    return exports.postgres
end

local function ensurePostgres()
    local pg = getPostgres()
    if not pg or not pg:isReady() then
        error('[GARAGES] Postgres nu este disponibil!')
        return false
    end
    return true
end

local function serializeJson(data)
    if json and json.encode then return json.encode(data) end
    if type(data) ~= 'table' then return '"' .. tostring(data) .. '"' end
    local parts = {}
    for k, v in pairs(data) do
        local key = type(k) == 'string' and ('"' .. k .. '"') or tostring(k)
        local val
        if     type(v) == 'string'  then val = '"' .. v:gsub('"', '\\"') .. '"'
        elseif type(v) == 'table'   then val = serializeJson(v)
        elseif type(v) == 'boolean' then val = v and 'true' or 'false'
        else                             val = tostring(v) end
        table.insert(parts, key .. ':' .. val)
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

function GaragesDatabase.getGarageByCode(code)
    if not ensurePostgres() then return nil end
    return getPostgres():queryOne('SELECT * FROM garages WHERE code = $1 AND is_active = true', { code })
end

function GaragesDatabase.getGarageById(id)
    if not ensurePostgres() then return nil end
    return getPostgres():queryOne('SELECT * FROM garages WHERE id = $1', { id })
end

function GaragesDatabase.getActiveGarages()
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll('SELECT * FROM garages WHERE is_active = true ORDER BY name')
end

function GaragesDatabase.upsertGarage(code, name, type, coords, spawnPoint)
    if not ensurePostgres() then return nil end
    local pg = getPostgres()

    local result = pg:query([[
        INSERT INTO garages (name, code, type, coords, spawn_point)
        VALUES ($1, $2, $3, $4::jsonb, $5::jsonb)
        ON CONFLICT (code) DO UPDATE
            SET name = EXCLUDED.name,
                type = EXCLUDED.type,
                coords = EXCLUDED.coords,
                spawn_point = EXCLUDED.spawn_point
        RETURNING *
    ]], { name, code, type, serializeJson(coords), serializeJson(spawnPoint) })

    if result and result.rows and result.rows[1] then
        return result.rows[1]
    end
    return nil
end

function GaragesDatabase.logAction(vehicleId, characterId, garageId, action, fuel)
    if not ensurePostgres() then return false end
    local success = pcall(function()
        getPostgres():query([[
            INSERT INTO garage_logs (vehicle_id, character_id, garage_id, action, fuel_at_action)
            VALUES ($1, $2, $3, $4, $5)
        ]], { vehicleId, characterId, garageId, action, tonumber(fuel) or 0 })
    end)
    return success
end

function GaragesDatabase.parkVehicleAtomic(vehicleId, characterId, garageId)
    if not ensurePostgres() then return false end

    local ok, result = pcall(function()
        return getPostgres():query([[
            WITH parked AS (
                UPDATE owned_vehicles
                SET stored = TRUE, updated_at = NOW()
                WHERE id = $1
                RETURNING id, fuel
            )
            INSERT INTO garage_logs (vehicle_id, character_id, garage_id, action, fuel_at_action)
            SELECT $1, $2, $3, 'parked', COALESCE(fuel, 0) FROM parked
            RETURNING id
        ]], { vehicleId, characterId, garageId })
    end)

    if not ok or not result then return false end
    return result.rows and result.rows[1] ~= nil
end

function GaragesDatabase.getCharacterVehicles(characterId)
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll([[
        SELECT ov.*
        FROM owned_vehicles ov
        JOIN vehicle_keys vk ON vk.vehicle_id = ov.id
        WHERE vk.character_id = $1
        ORDER BY ov.purchased_at DESC
    ]], { characterId })
end

function GaragesDatabase.issueTicket(characterId, vehicleId, plate, fineAmount, reason, issuedBy)
    if not ensurePostgres() then return nil end
    local pg = getPostgres()

    local result = pg:query([[
        INSERT INTO parking_tickets (character_id, vehicle_id, plate, fine_amount, reason, issued_by)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
    ]], { characterId, vehicleId, plate, fineAmount, reason, issuedBy })

    if result and result.rows and result.rows[1] then
        return result.rows[1]
    end
    return nil
end

function GaragesDatabase.getCharacterTickets(characterId)
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll([[
        SELECT * FROM parking_tickets
        WHERE character_id = $1 AND paid = false
        ORDER BY issued_at DESC
    ]], { characterId })
end

function GaragesDatabase.getVehicleUnpaidTickets(vehicleId)
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll([[
        SELECT * FROM parking_tickets
        WHERE vehicle_id = $1 AND paid = false
        ORDER BY issued_at DESC
    ]], { vehicleId })
end

function GaragesDatabase.markTicketPaid(ticketId)
    if not ensurePostgres() then return false end
    local success = pcall(function()
        getPostgres():query([[
            UPDATE parking_tickets SET paid = true, paid_at = NOW() WHERE id = $1
        ]], { ticketId })
    end)
    return success
end

function GaragesDatabase.markAllVehicleTicketsPaid(vehicleId)
    if not ensurePostgres() then return false end
    local success = pcall(function()
        getPostgres():query([[
            UPDATE parking_tickets SET paid = true, paid_at = NOW()
            WHERE vehicle_id = $1 AND paid = false
        ]], { vehicleId })
    end)
    return success
end

return GaragesDatabase
