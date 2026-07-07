exports.core:registerModuleLocales(GetCurrentResourceName())

EmsDB = {}

local function pg()
    return exports.postgres
end

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end

    local path = GetResourcePath(GetCurrentResourceName()) .. '/schema.sql'
    local f    = io.open(path, 'r')
    if f then
        local sql = f:read('*a')
        f:close()
        exports.postgres:query(sql, {})
        print('[EMS] Schema initializata.')
    else
        print('[EMS] EROARE: schema.sql nu a fost gasit la ' .. path)
    end

    pcall(function()
        exports.postgres:query([[
            UPDATE settings SET value = '298.8'  WHERE key = 'ems.hospital_x'       AND value = '295.5'
        ]])
        exports.postgres:query([[
            UPDATE settings SET value = '-584.9' WHERE key = 'ems.hospital_y'       AND value = '-1446.8'
        ]])
        exports.postgres:query([[
            UPDATE settings SET value = '43.3'   WHERE key = 'ems.hospital_z'       AND value = '29.9'
        ]])
        exports.postgres:query([[
            UPDATE settings SET value = '75.0'   WHERE key = 'ems.hospital_heading' AND value = '180.0'
        ]])
        exports.settings:ReloadSettings()
    end)
end)

function EmsDB.getActiveCalls()
    return pg():queryAll(
        "SELECT * FROM ems_calls WHERE status != 'resolved' ORDER BY created_at ASC",
        {}
    ) or {}
end

function EmsDB.createCall(callerId, callerName, message, coords)
    local row = pg():queryOne([[
        INSERT INTO ems_calls (caller_id, caller_name, message, coords)
        VALUES ($1, $2, $3, $4::jsonb)
        RETURNING id
    ]], { callerId, callerName, message, coords })
    return row and row.id or nil
end

function EmsDB.updateCallStatus(callId, status, responderId)
    pg():query([[
        UPDATE ems_calls SET status = $1, responder_id = $2 WHERE id = $3
    ]], { status, responderId, callId })
end

function EmsDB.resolveCall(callId)
    pg():query([[
        UPDATE ems_calls SET status = 'resolved', resolved_at = NOW() WHERE id = $1
    ]], { callId })
end

function EmsDB.logRecord(patientId, emsId, recordType, details)
    local detailsJson = json.encode(details or {})
    pg():query([[
        INSERT INTO ems_medical_records (patient_id, ems_id, record_type, details)
        VALUES ($1, $2, $3, $4::jsonb)
    ]], { patientId, emsId, recordType, detailsJson })
end

function EmsDB.getPatientHistory(characterId)
    return pg():queryAll([[
        SELECT r.*,
               ec.first_name AS ems_first, ec.last_name AS ems_last
        FROM ems_medical_records r
        LEFT JOIN characters ec ON ec.id = r.ems_id
        WHERE r.patient_id = $1
        ORDER BY r.created_at DESC
        LIMIT 50
    ]], { characterId }) or {}
end

function EmsDB.searchPatient(query)
    local pattern = '%' .. query .. '%'
    return pg():queryAll([[
        SELECT id, first_name, last_name, date_of_birth
        FROM characters
        WHERE (first_name ILIKE $1 OR last_name ILIKE $1)
        ORDER BY last_name ASC, first_name ASC
        LIMIT 20
    ]], { pattern }) or {}
end

function EmsDB.getVehicleInventory(plate)
    return pg():queryAll([[
        SELECT item_name, amount FROM ems_vehicle_inventory
        WHERE plate = $1 AND amount > 0
        ORDER BY item_name ASC
    ]], { plate }) or {}
end

function EmsDB.setVehicleItem(plate, itemName, amount)
    pg():query([[
        INSERT INTO ems_vehicle_inventory (plate, item_name, amount)
        VALUES ($1, $2, $3)
        ON CONFLICT (plate, item_name) DO UPDATE SET amount = $3
    ]], { plate, itemName, amount })
end

function EmsDB.removeVehicleItem(plate, itemName, qty)
    pg():query([[
        UPDATE ems_vehicle_inventory
        SET amount = GREATEST(0, amount - $1)
        WHERE plate = $2 AND item_name = $3
    ]], { qty, plate, itemName })
end

function EmsDB.tryDeductVehicleItem(plate, itemName, qty)
    local row = pg():queryOne([[
        UPDATE ems_vehicle_inventory
        SET amount = amount - $1
        WHERE plate = $2 AND item_name = $3 AND amount >= $1
        RETURNING amount
    ]], { qty, plate, itemName })
    return row ~= nil
end

function EmsDB.getVehicleItemAmount(plate, itemName)
    local row = pg():queryOne([[
        SELECT amount FROM ems_vehicle_inventory WHERE plate = $1 AND item_name = $2
    ]], { plate, itemName })
    return row and (tonumber(row.amount) or 0) or 0
end
