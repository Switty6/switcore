MedicalDB = {}

local function CreateSchema()
    local path = GetResourcePath(GetCurrentResourceName()) .. '/schema.sql'
    local file = io.open(path, 'r')
    if not file then
        print('[MEDICAL] EROARE CRITICA: schema.sql lipseste la ' .. path)
        return false
    end
    local sql = file:read('*a')
    file:close()
    if not sql or sql == '' then
        print('[MEDICAL] EROARE CRITICA: schema.sql este gol')
        return false
    end
    exports.postgres:query(sql, {})
    print('[MEDICAL] Schema DB creata/verificata.')
    return true
end

local function SeedSettings()
    local defaults = {
        { 'medical.progression_interval', '300',  'Interval progresie boli (secunde)' },
        { 'medical.sneeze_radius',         '5.0',  'Raza transmitere stranut (unitati GTA)' },
        { 'medical.mask_protection',       '0.10', 'Multiplicator protectie masca (0.10 = 10%)' },
    }
    for _, row in ipairs(defaults) do
        exports.postgres:query(
            'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
            row
        )
    end
end

function MedicalDB.getCharacterConditions(characterId)
    return exports.postgres:queryAll(
        'SELECT * FROM character_conditions WHERE character_id = $1 AND is_active = TRUE',
        { characterId }
    ) or {}
end

function MedicalDB.infectCharacter(characterId, conditionName)
    exports.postgres:query(
        [[INSERT INTO character_conditions (character_id, condition_name, current_stage, contracted_at, last_progressed, is_active)
          VALUES ($1, $2, 1, NOW(), NOW(), TRUE)
          ON CONFLICT (character_id, condition_name)
          DO UPDATE SET is_active = TRUE, current_stage = 1, contracted_at = NOW(), last_progressed = NOW()
          WHERE character_conditions.is_active = FALSE]],
        { characterId, conditionName }
    )
end

function MedicalDB.updateConditionStage(characterId, conditionName, newStage)
    exports.postgres:query(
        [[UPDATE character_conditions SET current_stage = $1, last_progressed = NOW()
          WHERE character_id = $2 AND condition_name = $3 AND is_active = TRUE]],
        { newStage, characterId, conditionName }
    )
end

function MedicalDB.cureCondition(characterId, conditionName)
    exports.postgres:query(
        'UPDATE character_conditions SET is_active = FALSE, cured_at = NOW() WHERE character_id = $1 AND condition_name = $2',
        { characterId, conditionName }
    )
end

function MedicalDB.cureAll(characterId)
    exports.postgres:query(
        'UPDATE character_conditions SET is_active = FALSE, cured_at = NOW() WHERE character_id = $1 AND is_active = TRUE',
        { characterId }
    )
end

function MedicalDB.getLastMedicationUse(characterId, itemName)
    local row = exports.postgres:queryOne(
        [[SELECT EXTRACT(EPOCH FROM used_at)::BIGINT AS used_ts
          FROM character_medication_log
          WHERE character_id = $1 AND item_name = $2
          ORDER BY used_at DESC LIMIT 1]],
        { characterId, itemName }
    )
    return row and row.used_ts or nil
end

function MedicalDB.logMedication(characterId, itemName, stageBefore, stageAfter, conditionName)
    exports.postgres:query(
        [[INSERT INTO character_medication_log (character_id, item_name, stage_before, stage_after, condition_name)
          VALUES ($1, $2, $3, $4, $5)]],
        { characterId, itemName, stageBefore, stageAfter, conditionName }
    )
end

function MedicalDB.getCharacterInjuries(characterId)
    return exports.postgres:queryAll(
        'SELECT * FROM character_injuries WHERE character_id = $1 AND is_active = TRUE',
        { characterId }
    ) or {}
end

function MedicalDB.addInjury(characterId, injuryType, location, severity)
    local row = exports.postgres:queryOne(
        [[INSERT INTO character_injuries (character_id, injury_type, location, severity)
          VALUES ($1, $2, $3, $4) RETURNING id]],
        { characterId, injuryType, location, severity }
    )
    return row and row.id or nil
end

function MedicalDB.treatInjury(injuryId)
    exports.postgres:query(
        'UPDATE character_injuries SET is_active = FALSE, treated_at = NOW() WHERE id = $1',
        { injuryId }
    )
end

function MedicalDB.treatAllInjuries(characterId)
    exports.postgres:query(
        'UPDATE character_injuries SET is_active = FALSE, treated_at = NOW() WHERE character_id = $1 AND is_active = TRUE',
        { characterId }
    )
end

function MedicalDB.updateInjurySeverity(injuryId, severity)
    exports.postgres:query(
        'UPDATE character_injuries SET severity = $1 WHERE id = $2 AND is_active = TRUE',
        { severity, injuryId }
    )
end

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    if not CreateSchema() then
        print('[MEDICAL] FATAL: nu pornesc seed/init - schema lipseste sau e invalida.')
        return
    end
    SeedSettings()
    print('[MEDICAL] Modul baza de date initializat.')
end)
