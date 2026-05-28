
ShowroomDatabase = {}

local function getPostgres()
    return exports.postgres
end

local function ensurePostgres()
    local pg = getPostgres()
    if not pg or not pg:isReady() then
        error('[SHOWROOM] Postgres nu este disponibil!')
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

function ShowroomDatabase.upsertDealership(code, name, coords, npcModel)
    if not ensurePostgres() then return nil end
    local result = getPostgres():query([[
        INSERT INTO dealerships (code, name, coords, npc_model)
        VALUES ($1, $2, $3::jsonb, $4)
        ON CONFLICT (code) DO UPDATE
            SET name      = EXCLUDED.name,
                coords    = EXCLUDED.coords,
                npc_model = EXCLUDED.npc_model
        RETURNING *
    ]], { code, name, serializeJson(coords), npcModel })
    return result and result.rows and result.rows[1]
end

function ShowroomDatabase.getActiveDealerships()
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll('SELECT * FROM dealerships WHERE is_active = true ORDER BY name')
end

function ShowroomDatabase.getDealershipByCode(code)
    if not ensurePostgres() then return nil end
    return getPostgres():queryOne('SELECT * FROM dealerships WHERE code = $1 AND is_active = true', { code })
end

function ShowroomDatabase.getDealershipCatalog(dealershipId)
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll([[
        SELECT * FROM vehicle_catalog
        WHERE dealership_id = $1 AND is_active = true
        ORDER BY sort_order, label
    ]], { dealershipId })
end

function ShowroomDatabase.getCatalogItem(catalogId)
    if not ensurePostgres() then return nil end
    return getPostgres():queryOne('SELECT * FROM vehicle_catalog WHERE id = $1', { catalogId })
end

function ShowroomDatabase.ensureCatalogUniqueIndex()
    if not ensurePostgres() then return end
    getPostgres():query([[
        CREATE UNIQUE INDEX IF NOT EXISTS uniq_vehicle_catalog_dealer_model
        ON vehicle_catalog (dealership_id, model)
    ]], {})
end

function ShowroomDatabase.seedCatalogItem(dealershipId, model, label, category, price, financeEligible, vipOnly, sortOrder)
    if not ensurePostgres() then return nil end

    local result = getPostgres():query([[
        INSERT INTO vehicle_catalog
            (dealership_id, model, label, category, price, finance_eligible, vip_only, sort_order)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (dealership_id, model) DO UPDATE
            SET label             = EXCLUDED.label,
                category          = EXCLUDED.category,
                price             = EXCLUDED.price,
                finance_eligible  = EXCLUDED.finance_eligible,
                vip_only          = EXCLUDED.vip_only,
                sort_order        = EXCLUDED.sort_order
        RETURNING *
    ]], { dealershipId, model, label, category, price, financeEligible, vipOnly, sortOrder })

    return result and result.rows and result.rows[1]
end

function ShowroomDatabase.logPurchase(characterId, catalogId, vehicleId, pricePaid, paymentMethod, loanId)
    if not ensurePostgres() then return nil end
    if loanId then
        local result = getPostgres():query([[
            INSERT INTO vehicle_purchases (character_id, catalog_id, vehicle_id, price_paid, payment_method, loan_id)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        ]], { characterId, catalogId, vehicleId, pricePaid, paymentMethod, loanId })
        return result and result.rows and result.rows[1]
    end
    local result = getPostgres():query([[
        INSERT INTO vehicle_purchases (character_id, catalog_id, vehicle_id, price_paid, payment_method)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
    ]], { characterId, catalogId, vehicleId, pricePaid, paymentMethod })
    return result and result.rows and result.rows[1]
end

function ShowroomDatabase.startTestDrive(characterId, catalogId, plate, durationMinutes)
    if not ensurePostgres() then return nil end
    local result = getPostgres():query([[
        INSERT INTO test_drives (character_id, catalog_id, plate, expires_at)
        VALUES ($1, $2, $3, NOW() + ($4 || ' minutes')::interval)
        RETURNING *
    ]], { characterId, catalogId, plate, tostring(durationMinutes) })
    return result and result.rows and result.rows[1]
end

function ShowroomDatabase.endTestDrive(characterId)
    if not ensurePostgres() then return false end
    local success = pcall(function()
        getPostgres():query([[
            UPDATE test_drives SET returned = true
            WHERE character_id = $1 AND returned = false
        ]], { characterId })
    end)
    return success
end

function ShowroomDatabase.getActiveTestDrive(characterId)
    if not ensurePostgres() then return nil end
    return getPostgres():queryOne([[
        SELECT td.*, vc.model, vc.label, vc.category
        FROM test_drives td
        JOIN vehicle_catalog vc ON vc.id = td.catalog_id
        WHERE td.character_id = $1 AND td.returned = false AND td.expires_at > NOW()
        ORDER BY td.started_at DESC
        LIMIT 1
    ]], { characterId })
end

function ShowroomDatabase.getExpiredTestDrives()
    if not ensurePostgres() then return {} end
    return getPostgres():queryAll([[
        SELECT * FROM test_drives
        WHERE returned = false AND expires_at <= NOW()
    ]])
end

return ShowroomDatabase
