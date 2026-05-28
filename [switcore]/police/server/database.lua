
PoliceDatabase = {}

local function pg()
    return exports.postgres
end

local function ensurePg()
    local p = pg()
    if not p or not p:isReady() then
        error('[POLICE] Postgres nu este disponibil!')
    end
    return true
end

function PoliceDatabase.createJailSentence(characterId, arrestedBy, reason, sentenceMinutes, bailAmount)
    if not ensurePg() then return nil end
    local remainingSecs = sentenceMinutes * 60
    return pg():queryOne([[
        INSERT INTO police_jail_sentences
            (character_id, arrested_by, reason, sentence_minutes, remaining_seconds, bail_amount)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id
    ]], { characterId, arrestedBy, reason, sentenceMinutes, remainingSecs, bailAmount })
end

function PoliceDatabase.getActiveJailSentence(characterId)
    if not ensurePg() then return nil end
    return pg():queryOne(
        'SELECT * FROM police_jail_sentences WHERE character_id = $1 AND is_active = TRUE LIMIT 1',
        { characterId }
    )
end

function PoliceDatabase.getAllActiveSentences()
    if not ensurePg() then return {} end
    return pg():queryAll(
        'SELECT * FROM police_jail_sentences WHERE is_active = TRUE',
        {}
    )
end

function PoliceDatabase.ensureHandcuffSchema()
    if not ensurePg() then return end
    pg():query([[
        CREATE TABLE IF NOT EXISTS police_handcuffs (
            target_character_id  INTEGER PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
            officer_character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
            applied_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    ]], {})
end

function PoliceDatabase.addHandcuff(targetCharId, officerCharId)
    if not ensurePg() then return false end
    local row = pg():queryOne([[
        INSERT INTO police_handcuffs (target_character_id, officer_character_id, applied_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (target_character_id) DO UPDATE
            SET officer_character_id = EXCLUDED.officer_character_id,
                applied_at           = NOW()
        RETURNING target_character_id
    ]], { targetCharId, officerCharId })
    return row ~= nil
end

function PoliceDatabase.removeHandcuff(targetCharId)
    if not ensurePg() then return end
    pg():query('DELETE FROM police_handcuffs WHERE target_character_id = $1', { targetCharId })
end

function PoliceDatabase.getHandcuff(targetCharId)
    if not ensurePg() then return nil end
    return pg():queryOne('SELECT * FROM police_handcuffs WHERE target_character_id = $1', { targetCharId })
end

function PoliceDatabase.getAllHandcuffs()
    if not ensurePg() then return {} end
    return pg():queryAll('SELECT * FROM police_handcuffs', {})
end

function PoliceDatabase.updateRemainingTime(sentenceId, remainingSeconds)
    if not ensurePg() then return false end
    local row = pg():queryOne([[
        UPDATE police_jail_sentences
        SET remaining_seconds = $1
        WHERE id = $2 AND is_active = TRUE
        RETURNING id
    ]], { math.max(0, math.floor(remainingSeconds or 0)), sentenceId })
    return row ~= nil
end

function PoliceDatabase.releaseJailSentence(sentenceId, releaseReason)
    if not ensurePg() then return end
    pg():query([[
        UPDATE police_jail_sentences
        SET is_active = FALSE, released_at = NOW(), release_reason = $1
        WHERE id = $2
    ]], { releaseReason, sentenceId })
end

function PoliceDatabase.getJailHistory(characterId, limit)
    if not ensurePg() then return {} end
    limit = limit or 10
    return pg():queryAll([[
        SELECT s.*,
               ac.first_name AS arrested_by_first, ac.last_name AS arrested_by_last
        FROM police_jail_sentences s
        LEFT JOIN characters ac ON ac.id = s.arrested_by
        WHERE s.character_id = $1
        ORDER BY s.arrested_at DESC
        LIMIT $2
    ]], { characterId, limit })
end

function PoliceDatabase.createWarrant(characterId, issuedBy, charges, bailAmount)
    if not ensurePg() then return nil end
    return pg():queryOne([[
        INSERT INTO police_warrants (character_id, issued_by, charges, bail_amount)
        VALUES ($1, $2, $3, $4)
        RETURNING *
    ]], { characterId, issuedBy, charges, bailAmount })
end

function PoliceDatabase.getActiveWarrant(characterId)
    if not ensurePg() then return nil end
    return pg():queryOne(
        'SELECT * FROM police_warrants WHERE character_id = $1 AND is_active = TRUE LIMIT 1',
        { characterId }
    )
end

function PoliceDatabase.getAllActiveWarrants()
    if not ensurePg() then return {} end
    return pg():queryAll([[
        SELECT w.*,
               c.first_name, c.last_name,
               ic.first_name AS issued_by_first, ic.last_name AS issued_by_last
        FROM police_warrants w
        JOIN characters c ON c.id = w.character_id
        LEFT JOIN characters ic ON ic.id = w.issued_by
        WHERE w.is_active = TRUE
        ORDER BY w.issued_at DESC
    ]], {})
end

function PoliceDatabase.closeWarrant(warrantId, closedBy)
    if not ensurePg() then return end
    pg():query([[
        UPDATE police_warrants
        SET is_active = FALSE, closed_at = NOW(), closed_by = $1
        WHERE id = $2
    ]], { closedBy, warrantId })
end

function PoliceDatabase.searchCharacter(likePattern)
    if not ensurePg() then return {} end
    return pg():queryAll([[
        SELECT id, first_name, last_name, age
        FROM characters
        WHERE first_name ILIKE $1 OR last_name ILIKE $1
        ORDER BY last_name ASC, first_name ASC
        LIMIT 20
    ]], { likePattern })
end

function PoliceDatabase.getFleet()
    if not ensurePg() then return {} end
    return pg():queryAll(
        'SELECT * FROM police_fleet ORDER BY label ASC',
        {}
    )
end

function PoliceDatabase.getAvailableFleet()
    if not ensurePg() then return {} end
    return pg():queryAll(
        'SELECT * FROM police_fleet WHERE is_available = TRUE ORDER BY label ASC',
        {}
    )
end

function PoliceDatabase.getFleetVehicle(vehicleId)
    if not ensurePg() then return nil end
    return pg():queryOne('SELECT * FROM police_fleet WHERE id = $1', { vehicleId })
end

function PoliceDatabase.getFleetVehicleByPlate(plate)
    if not ensurePg() then return nil end
    return pg():queryOne('SELECT * FROM police_fleet WHERE plate = $1', { plate })
end

function PoliceDatabase.getCharacterCheckout(characterId)
    if not ensurePg() then return nil end
    return pg():queryOne(
        'SELECT * FROM police_fleet WHERE checked_out_by = $1',
        { characterId }
    )
end

function PoliceDatabase.checkoutFleetVehicle(vehicleId, characterId)
    if not ensurePg() then return nil end
    return pg():queryOne([[
        UPDATE police_fleet
        SET is_available   = FALSE,
            checked_out_by = $1,
            checked_out_at = NOW(),
            updated_at     = NOW()
        WHERE id = $2 AND is_available = TRUE
        RETURNING *
    ]], { characterId, vehicleId })
end

function PoliceDatabase.returnFleetVehicle(vehicleId, fuel, mileage, bodyHealth, engineHealth)
    if not ensurePg() then return end
    pg():query([[
        UPDATE police_fleet
        SET is_available   = TRUE,
            checked_out_by = NULL,
            checked_out_at = NULL,
            fuel           = $1,
            mileage        = $2,
            body_health    = $3,
            engine_health  = $4,
            updated_at     = NOW()
        WHERE id = $5
    ]], { fuel, mileage, bodyHealth, engineHealth, vehicleId })
end

function PoliceDatabase.updateFleetMileage(vehicleId, mileage)
    if not ensurePg() then return false end
    local ok, err = pcall(function()
        pg():query(
            'UPDATE police_fleet SET mileage = $1, updated_at = NOW() WHERE id = $2',
            { mileage, vehicleId }
        )
    end)
    if not ok then
        print(('[POLICE] updateFleetMileage esuat vehicle=%s: %s'):format(tostring(vehicleId), tostring(err)))
    end
    return ok
end

function PoliceDatabase.updateFleetState(vehicleId, fuel, mileage, bodyHealth, engineHealth)
    if not ensurePg() then return false end
    local ok, err = pcall(function()
        pg():query([[
            UPDATE police_fleet
            SET fuel = $1, mileage = $2, body_health = $3, engine_health = $4, updated_at = NOW()
            WHERE id = $5
        ]], { fuel, mileage, bodyHealth, engineHealth, vehicleId })
    end)
    if not ok then
        print(('[POLICE] updateFleetState esuat vehicle=%s: %s'):format(tostring(vehicleId), tostring(err)))
    end
    return ok
end

function PoliceDatabase.createFleetVehicle(model, label, category, plate, purchasePrice)
    if not ensurePg() then return nil end
    return pg():queryOne([[
        INSERT INTO police_fleet (model, label, category, plate, purchase_price)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
    ]], { model, label, category, plate, purchasePrice or 0.0 })
end

function PoliceDatabase.deleteFleetVehicle(vehicleId)
    if not ensurePg() then return false end
    local ok = pcall(function()
        pg():query('DELETE FROM police_fleet WHERE id = $1', { vehicleId })
    end)
    return ok
end

function PoliceDatabase.logFleetAction(vehicleId, characterId, action, mileage, fuel)
    if not ensurePg() then return end
    pg():query([[
        INSERT INTO police_fleet_logs (vehicle_id, character_id, action, mileage_at, fuel_at)
        VALUES ($1, $2, $3, $4, $5)
    ]], { vehicleId, characterId, action, mileage, fuel })
end

function PoliceDatabase.fleetIsEmpty()
    if not ensurePg() then return true end
    local row = pg():queryOne('SELECT COUNT(*) AS cnt FROM police_fleet', {})
    return (not row) or (tonumber(row.cnt) or 0) == 0
end

function PoliceDatabase.logArmoryTake(characterId, itemName, amount)
    if not ensurePg() then return end
    pg():query(
        'INSERT INTO police_armory_logs (character_id, item_name, amount) VALUES ($1, $2, $3)',
        { characterId, itemName, amount }
    )
end
