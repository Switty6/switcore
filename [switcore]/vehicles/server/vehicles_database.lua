
VehiclesDatabase = {}

-- Returneaza:
--   row, nil           - succes
--   nil, 'plate_taken' - placuta deja folosita (UNIQUE conflict). Caller poate
--                        decide sa dea retry cu o placuta noua sau sa
--                        propage eroarea la player (pentru custom plates).
--   nil, 'db_error'    - alta eroare DB
function VehiclesDatabase.createOwnedVehicle(characterId, plate, model, label, category)
    local result = exports.postgres:query([[
        INSERT INTO owned_vehicles
            (character_id, plate, model, label, category, purchased_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        ON CONFLICT (plate) DO NOTHING
        RETURNING *
    ]], { characterId, plate, model, label or model, category or 'sedans' })

    if not result then return nil, 'db_error' end
    if not result.rows or not result.rows[1] then return nil, 'plate_taken' end
    return result.rows[1], nil
end

function VehiclesDatabase.getOwnedVehicleById(vehicleId)
    return exports.postgres:queryOne('SELECT * FROM owned_vehicles WHERE id = $1', { vehicleId })
end

function VehiclesDatabase.getOwnedVehicleByPlate(plate)
    return exports.postgres:queryOne('SELECT * FROM owned_vehicles WHERE plate = $1', { plate })
end

function VehiclesDatabase.getCharacterVehicles(characterId)
    return exports.postgres:queryAll(
        'SELECT * FROM owned_vehicles WHERE character_id = $1 ORDER BY purchased_at DESC',
        { characterId }
    )
end

function VehiclesDatabase.updateVehicleState(vehicleId, state)
    local updateParts = {}
    local params      = {}
    local n           = 0

    local function addField(col, val, typeCast)
        n = n + 1
        updateParts[#updateParts + 1] = col .. ' = $' .. n .. (typeCast or '')
        params[#params + 1] = val
    end

    if state.fuel ~= nil then
        addField('fuel',          math.max(0.0, math.min(100.0,  tonumber(state.fuel)          or 0.0)))
    end
    if state.mileage ~= nil then
        addField('mileage',       math.max(0.0,                  tonumber(state.mileage)        or 0.0))
    end
    if state.body_health ~= nil then
        addField('body_health',   math.max(0.0, math.min(1000.0, tonumber(state.body_health)   or 0.0)))
    end
    if state.engine_health ~= nil then
        addField('engine_health', math.max(0.0, math.min(1000.0, tonumber(state.engine_health) or 0.0)))
    end
    if state.modifications ~= nil then
        if state.replace_modifications then
            addField('modifications', json.encode(state.modifications), '::jsonb')
        else
            n = n + 1
            updateParts[#updateParts + 1] = "modifications = COALESCE(modifications, '{}'::jsonb) || $" .. n .. '::jsonb'
            params[#params + 1] = json.encode(state.modifications)
        end
    end
    if state.components ~= nil then
        addField('components',    json.encode(state.components),    '::jsonb')
    end
    if state.stored ~= nil then
        addField('stored',    state.stored)
    end
    if state.impounded ~= nil then
        addField('impounded', state.impounded)
    end
    if state.last_position ~= nil then
        addField('last_position', json.encode(state.last_position), '::jsonb')
    end

    if #updateParts == 0 then return false end

    n = n + 1
    updateParts[#updateParts + 1] = 'updated_at = NOW()'
    params[#params + 1] = vehicleId

    local query = 'UPDATE owned_vehicles SET ' .. table.concat(updateParts, ', ') .. ' WHERE id = $' .. n

    local ok, err = pcall(function()
        exports.postgres:query(query, params)
    end)
    if not ok then
        print(('[VEHICLES] updateVehicleState esuat pentru vehicul %s: %s'):format(tostring(vehicleId), tostring(err)))
    end
    return ok
end

function VehiclesDatabase.getNextPlateSequence()
    local result = exports.postgres:queryOne("SELECT nextval('plate_number_seq') AS seq")
    return result and tonumber(result.seq) or math.random(1, 99999)
end

function VehiclesDatabase.plateExists(plate)
    return exports.postgres:queryOne('SELECT id FROM owned_vehicles WHERE plate = $1', { plate }) ~= nil
end

function VehiclesDatabase.addVehicleKey(vehicleId, characterId, keyType)
    local kt = (keyType == 'owner') and 'owner' or 'standard'
    local success = pcall(function()
        exports.postgres:query([[
            INSERT INTO vehicle_keys (vehicle_id, character_id, key_type, given_at)
            VALUES ($1, $2, $3, NOW())
            ON CONFLICT (vehicle_id, character_id) DO NOTHING
        ]], { vehicleId, characterId, kt })
    end)
    return success
end

function VehiclesDatabase.removeVehicleKey(vehicleId, characterId)
    local success = pcall(function()
        exports.postgres:query(
            'DELETE FROM vehicle_keys WHERE vehicle_id = $1 AND character_id = $2',
            { vehicleId, characterId }
        )
    end)
    return success
end

function VehiclesDatabase.hasVehicleKey(vehicleId, characterId)
    return exports.postgres:queryOne(
        'SELECT id FROM vehicle_keys WHERE vehicle_id = $1 AND character_id = $2',
        { vehicleId, characterId }
    ) ~= nil
end

function VehiclesDatabase.getOwnedVehicleIfKeyed(vehicleId, characterId)
    return exports.postgres:queryOne([[
        SELECT ov.*
        FROM owned_vehicles ov
        JOIN vehicle_keys vk ON vk.vehicle_id = ov.id
        WHERE ov.id = $1 AND vk.character_id = $2
        LIMIT 1
    ]], { vehicleId, characterId })
end

function VehiclesDatabase.getVehicleKeys(vehicleId)
    return exports.postgres:queryAll(
        'SELECT * FROM vehicle_keys WHERE vehicle_id = $1 ORDER BY given_at',
        { vehicleId }
    )
end

function VehiclesDatabase.getCharacterVehicleKeys(characterId)
    return exports.postgres:queryAll([[
        SELECT vk.*, ov.plate, ov.model, ov.label, ov.category,
               ov.stored, ov.impounded, ov.fuel, ov.body_health, ov.engine_health
        FROM vehicle_keys vk
        JOIN owned_vehicles ov ON vk.vehicle_id = ov.id
        WHERE vk.character_id = $1
        ORDER BY vk.given_at DESC
    ]], { characterId })
end

function VehiclesDatabase.removeAllVehicleKeys(vehicleId)
    local success = pcall(function()
        exports.postgres:query('DELETE FROM vehicle_keys WHERE vehicle_id = $1', { vehicleId })
    end)
    return success
end

return VehiclesDatabase
