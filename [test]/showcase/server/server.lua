-- ══════════════════════════════════════════════════════════════
--  Showcase Server  -  vehicle cycle helpers + auto-group
-- ══════════════════════════════════════════════════════════════

local function getChar(source)
    local char = exports.characters:getActiveCharacter(source)
    return (char and char.id) and char or nil
end

local function getFirstCurrency()
    local list = exports.banking:getActiveCurrencies()
    return list and #list > 0 and list[1].id or nil
end

local function ok(src, msg)   TriggerClientEvent('switcore:notify', src, 'success', msg, 4000) end
local function err(src, msg)  TriggerClientEvent('switcore:notify', src, 'error',   msg, 4000) end
local function info(src, msg) TriggerClientEvent('switcore:notify', src, 'info',    msg, 4000) end


-- ── /sc_cash [suma] ───────────────────────────────────────────
RegisterCommand('sc_cash', function(source, args)
    local char = getChar(source)
    if not char then err(source, 'Personaj inactiv'); return end

    local amount = tonumber(args[1]) or 10000
    local currId = getFirstCurrency()
    if not currId then err(source, 'Banking indisponibil'); return end

    exports.banking:addCharacterCash(char.id, currId, amount)
    ok(source, ('Cash +$%s adăugat'):format(amount))
end, false)

-- ── /sc_car [model] ───────────────────────────────────────────
RegisterCommand('sc_car', function(source, args)
    local char = getChar(source)
    if not char then err(source, 'Personaj inactiv'); return end

    local model = args[1]
    if not model or model == '' then
        err(source, 'Folosire: /sc_car [model]  ex: /sc_car zentorno')
        return
    end

    local vehicle, createErr = exports.vehicles:createVehicle(char.id, model, 'showcase', model)
    if not vehicle then
        err(source, 'Creare eșuată: ' .. (createErr or '?'))
        return
    end

    local spawnOk = exports.vehicles:spawnVehicleForPlayer(source, vehicle.id)
    if spawnOk then
        ok(source, model .. ' spawnat!  (DB id: ' .. vehicle.id .. ')')
    else
        info(source, model .. ' creat în DB (id: ' .. vehicle.id .. '), caută-l în garaj')
    end
end, false)

-- ── /sc_fuel [0-100] ──────────────────────────────────────────
RegisterCommand('sc_fuel', function(source, args)
    local amount = tonumber(args[1]) or 100
    TriggerClientEvent('showcase:client:requestPlate', source, amount)
end, false)

RegisterNetEvent('showcase:server:setFuel', function(plate, amount)
    local source = source
    local vehicle = exports.vehicles:getOwnedVehicleByPlate(plate)
    if not vehicle then
        err(source, 'Vehicul negăsit în DB (placă: ' .. plate .. ')')
        return
    end
    local fuel = math.max(0, math.min(100, tonumber(amount) or 100))
    exports.vehicles:setVehicleFuel(vehicle.id, fuel)
    TriggerClientEvent('showcase:client:syncFuel', source, fuel)
    ok(source, ('Combustibil setat: %.0f%%'):format(fuel))
end)

RegisterNetEvent('showcase:server:fuelError', function(msg)
    err(source, msg)
end)

-- ── /sc_revive ────────────────────────────────────────────────
RegisterCommand('sc_revive', function(source)
    local ok_ems = pcall(function()
        if exports.ems:IsUnconscious(source) then
            exports.ems:RevivePlayer(source)
        end
    end)
    TriggerClientEvent('showcase:client:hardRevive', source)
    ok(source, 'Reinviat')
end, false)

-- ── /sc_needs ─────────────────────────────────────────────────
RegisterCommand('sc_needs', function(source)
    exports.needs:SetHunger(source, 100)
    exports.needs:SetThirst(source, 100)
    ok(source, 'Foame & sete → 100%')
end, false)

-- ── /sc_seedshowroom ──────────────────────────────────────────
local SHOWCASE_CARS = {
    { model = 'zentorno',  label = 'Grotti Zentorno',    cat = 'Super',    price = 725000,  fin = true,  vip = false, s = 1 },
    { model = 't20',       label = 'Progen T20',         cat = 'Super',    price = 2200000, fin = true,  vip = false, s = 2 },
    { model = 'adder',     label = 'Truffade Adder',     cat = 'Super',    price = 1000000, fin = true,  vip = true,  s = 3 },
    { model = 'banshee',   label = 'Bravado Banshee',    cat = 'Sports',   price = 105000,  fin = true,  vip = false, s = 4 },
    { model = 'sultan',    label = 'Karin Sultan RS',    cat = 'Sports',   price = 12000,   fin = false, vip = false, s = 5 },
    { model = 'coquette',  label = 'Invetero Coquette',  cat = 'Sports',   price = 145000,  fin = true,  vip = false, s = 6 },
    { model = 'akuma',     label = 'Dinka Akuma',        cat = 'Moto',     price = 9000,    fin = false, vip = false, s = 7 },
    { model = 'insurgent', label = 'HVY Insurgent',      cat = 'Militar',  price = 675000,  fin = true,  vip = true,  s = 8 },
}

RegisterCommand('sc_seedshowroom', function(source)
    local pg     = exports.postgres
    local dealer = pg:queryOne('SELECT id FROM dealerships WHERE code = $1', { 'pdm' })
    if not dealer then
        err(source, 'PDM nu există în DB, mergi prima dată la dealership să se creeze')
        return
    end

    local count = 0
    for _, v in ipairs(SHOWCASE_CARS) do
        local existing = pg:queryOne(
            'SELECT id FROM vehicle_catalog WHERE dealership_id = $1 AND model = $2',
            { dealer.id, v.model }
        )
        if existing then
            pg:query([[
                UPDATE vehicle_catalog
                SET label=$1, category=$2, price=$3,
                    finance_eligible=$4, vip_only=$5, sort_order=$6, is_active=true
                WHERE id=$7
            ]], { v.label, v.cat, v.price, v.fin, v.vip, v.s, existing.id })
        else
            pg:query([[
                INSERT INTO vehicle_catalog
                    (dealership_id, model, label, category, price, finance_eligible, vip_only, sort_order)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ]], { dealer.id, v.model, v.label, v.cat, v.price, v.fin, v.vip, v.s })
        end
        count = count + 1
    end

    ok(source, count .. ' vehicule adăugate/actualizate în catalogul PDM!')
end, false)

-- ── /sc_clearshowroom ─────────────────────────────────────────
RegisterCommand('sc_clearshowroom', function(source)
    local pg     = exports.postgres
    local dealer = pg:queryOne('SELECT id FROM dealerships WHERE code = $1', { 'pdm' })
    if not dealer then err(source, 'PDM nu există în DB'); return end

    for _, v in ipairs(SHOWCASE_CARS) do
        pg:query(
            'DELETE FROM vehicle_catalog WHERE dealership_id = $1 AND model = $2',
            { dealer.id, v.model }
        )
    end
    ok(source, 'Vehicule showcase șterse din catalogul PDM')
end, false)

-- ══════════════════════════════════════════════════════════════
--  Auto-group: atribuie permisiuni admin (fara kick/ban/warn)
--  la fiecare jucator care se joineaza.
-- ══════════════════════════════════════════════════════════════

local AUTO_GROUP_NAME  = 'test_player'
local AUTO_GROUP_LABEL = 'Test Player'
local AUTO_GROUP_PERMS = {
    -- players (fara moderate = fara kick/ban/warn din meniu)
    'admin.players.view', 'admin.players.teleport', 'admin.players.freeze',
    'admin.players.spectate', 'admin.players.cash', 'admin.players.groups',
    'admin.players.bucket', 'admin.players.inventory', 'admin.players.needs',
    'admin.players.character', 'admin.players.vehicles', 'admin.players.jobs',
    -- self
    'admin.self.noclip', 'admin.self.godmode', 'admin.self.invisible',
    'admin.self.weapons', 'admin.self.cash', 'admin.self.heal',
    'admin.self.teleport', 'admin.self.overlay', 'admin.self.model',
    -- vehicle
    'admin.vehicle.spawn', 'admin.vehicle.delete', 'admin.vehicle.modify',
    -- world
    'admin.world.time', 'admin.world.weather', 'admin.world.announce',
    'admin.world.resources',
    -- items
    'admin.items.manage',
    -- client (deschide meniul)
    'admin.client',
}

local function seedAutoGroup()
    local pg = exports.postgres

    local existing = pg:queryOne('SELECT id FROM groups WHERE name = $1', { AUTO_GROUP_NAME })
    if not existing then
        pg:query(
            'INSERT INTO groups (name, display_name, priority, description, created_at) VALUES ($1, $2, $3, $4, NOW())',
            { AUTO_GROUP_NAME, AUTO_GROUP_LABEL, 5, 'Grup auto showcase - acces admin fara moderare' }
        )
    end

    for _, perm in ipairs(AUTO_GROUP_PERMS) do
        pg:query(
            'INSERT INTO permissions (name, created_at) VALUES ($1, NOW()) ON CONFLICT (name) DO NOTHING',
            { perm }
        )
        pg:query([[
            INSERT INTO group_permissions (group_id, permission_id, created_at)
            SELECT g.id, p.id, NOW()
            FROM groups g, permissions p
            WHERE g.name = $1 AND p.name = $2
            ON CONFLICT (group_id, permission_id) DO NOTHING
        ]], { AUTO_GROUP_NAME, perm })
    end
end

AddEventHandler('switcore:playerLoaded', function(source)
    if exports.core:hasGroup(source, AUTO_GROUP_NAME) then return end
    exports.core:addPlayerGroup(source, AUTO_GROUP_NAME, nil, nil)
end)

-- ── Init ──────────────────────────────────────────────────────
CreateThread(function()
    while not exports.postgres:isReady() do Wait(500) end
    seedAutoGroup()
    print('[SHOWCASE] Gata - /sc_help pentru lista comenzilor')
end)
