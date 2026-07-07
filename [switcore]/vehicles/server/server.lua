exports.core:registerModuleLocales(GetCurrentResourceName())

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(100)
    end
    print('[VEHICLES] PostgreSQL este gata, sistemul de vehicule se inițializează...')
    initialize()
end)

local function seedSettings()
    local defaults = {
        { 'vehicles.default_fuel',              '100',  'Nivel implicit combustibil vehicul nou (0-100)' },
        { 'vehicles.fuel_consumption_rate',     '1.0',  'Multiplicator global consum combustibil (1.0 = baseline, 2.0 = de 2x mai rapid, 0.5 = de 2x mai lent)' },
        { 'vehicles.fuel_tick_interval',        '5000', 'Interval (ms) între raportările de combustibil de la client' },
        { 'vehicles.save_interval',             '30000','Interval (ms) auto-save periodic al stării vehiculelor active' },
        { 'vehicles.impound_fee_per_day',       '500',  'Taxă zilnică de depozitare sechestru ($)' },
        { 'vehicles.delete_after_impound_days', '30',   'Zile după care un vehicul sechestrat este șters automat' },
        { 'vehicles.default_currency_code',     'USD',  'Codul valutei implicite pentru tranzacții vehicule' },
        { 'vehicles.enable_fuel_system',        'true', 'Activează sistemul de combustibil (true/false)' },
        { 'vehicles.enable_mileage',            'true', 'Activează urmărirea kilometrajului (true/false)' },
        { 'vehicles.fuel_price_per_liter',      '3.5',  'Prețul per litru la alimentare ($)' },
    }
    for _, row in ipairs(defaults) do
        local ok = pcall(function()
            exports.postgres:query(
                'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
                row
            )
        end)
        if not ok then
            print(string.format('[VEHICLES] Avertisment: nu s-a putut preincarca setarea: %s', row[1]))
        end
    end

    pcall(function()
        exports.postgres:query([[
            UPDATE settings
            SET value = '1.0',
                description = 'Multiplicator global consum combustibil (1.0 = baseline, 2.0 = de 2x mai rapid, 0.5 = de 2x mai lent)'
            WHERE key = 'vehicles.fuel_consumption_rate' AND value = '0.02'
        ]])
    end)

    pcall(function() exports.settings:ReloadSettings() end)

    print('[VEHICLES] Setări preincarcate în tabela settings')
end

local function seedVehicleKeyItem()
    local ok = pcall(function()
        exports.postgres:query([[
            INSERT INTO items (name, label, weight, type, usable, stackable, description)
            VALUES ('vehicle_key', 'Cheie Vehicul', 0.0, 'key', true, false,
                    'Cheia unui vehicul. Folosește-o pentru a gestiona accesul.')
            ON CONFLICT (name) DO UPDATE SET
                type = 'key',
                weight = 0.0,
                stackable = false
        ]])
    end)
    if ok then
        print('[VEHICLES] Item vehicle_key verificat/creat în tabela items')
    else
        print('[VEHICLES] Avertisment: eroare la preincarcarea itemului vehicle_key')
    end
end

local function seedLockpickItem()
    local ok = pcall(function()
        exports.postgres:query([[
            INSERT INTO items (name, label, weight, type, usable, stackable, description)
            VALUES ('lockpick', 'Rangă de spart broasca', 0.5, 'tool', false, true,
                    'Poate fi folosită pentru a forța încuietoarea unui vehicul fără cheie. Se poate rupe.')
            ON CONFLICT (name) DO NOTHING
        ]])
    end)
    if ok then
        print('[VEHICLES] Item lockpick verificat/creat în tabela items')
    else
        print('[VEHICLES] Avertisment: eroare la preincarcarea itemului lockpick')
    end
end

local function registerVehicleKeyUsable()
    local ok = pcall(function()
        exports.inventory:RegisterUsableItem('vehicle_key', function(source, item)
            local plate = item and item.metadata and item.metadata.plate
            local label = item and item.metadata and item.metadata.label
            if plate and label then
                TriggerClientEvent('switcore:notify', source, 'info',
                    Sw.TP(source, 'vehicles.key_item_info', label, plate), 4000)
            end
        end)
    end)
    if ok then
        print('[VEHICLES] Item vehicle_key înregistrat (info-only, spawn exclusiv din garaje)')
    end
end

local function parkVehiclesLeftOut()
    local ok, result = pcall(function()
        return exports.postgres:query(
            'UPDATE owned_vehicles SET stored = true, updated_at = NOW() WHERE stored = false AND impounded = false'
        )
    end)
    if ok then
        local count = (result and result.rowCount) or 0
        print(string.format('[VEHICLES] Vehicule rămase afară parcate automat după restart: %d', count))
    else
        print('[VEHICLES] Avertisment: eroare la parcarea vehiculelor rămase afară')
    end
end

function initialize()
    seedSettings()
    exports.postgres:query('CREATE SEQUENCE IF NOT EXISTS plate_number_seq START WITH 1 INCREMENT BY 1')
    seedVehicleKeyItem()
    seedLockpickItem()
    registerVehicleKeyUsable()
    parkVehiclesLeftOut()
    print('[VEHICLES] Sistemul de vehicule a fost inițializat cu succes!')
end

AddEventHandler('switcore:characterSelected', function(source, characterId, character)
    if not characterId then return end
    CreateThread(function()
        local keysInvId = 'keys:' .. tostring(characterId)
        local attempts = 0
        while not exports.inventory:GetInventory(keysInvId) and attempts < 50 do
            Wait(100)
            attempts = attempts + 1
        end
        pcall(function() KeysManager.syncKeysToInventory(characterId) end)
        local keys = VehiclesDatabase.getCharacterVehicleKeys(characterId)
        local plates = {}
        for _, k in ipairs(keys) do
            if k.plate then
                plates[#plates + 1] = k.plate:gsub('%s+', '')
            end
        end
        TriggerClientEvent('vehicles:client:syncKeys', source, plates)
        print(string.format('[VEHICLES] Chei sincronizate pentru caracterul %d (%d chei)', characterId, #plates))
    end)
end)

local function checkAdmin(source)
    if not exports.core:hasPermission(source, 'admin.vehicle') then
        TriggerClientEvent('switcore:notify', source, 'error', Sw.TP(source, 'vehicles.access_denied'), 3000)
        return false
    end
    return true
end

RegisterCommand('vehicles:give', function(source, args)
    if not checkAdmin(source) then return end
    local targetId = tonumber(args[1])
    local model    = args[2]
    local category = args[3] or 'sedans'
    if not targetId or not model then
        print('Utilizare: vehicles:give <playerId> <model> [category]')
        return
    end
    local character = exports.characters:getActiveCharacter(targetId)
    if not character then
        print(string.format('[VEHICLES] Jucătorul %d nu are personaj activ', targetId))
        return
    end
    local success, err, vehicle = VehiclesManager.createVehicle(character.id, model, category, model)
    if success then
        TriggerClientEvent('switcore:notify', targetId, 'success',
            Sw.TP(targetId, 'vehicles.admin_vehicle_received', model, vehicle.plate), 6000)
        print(string.format('[VEHICLES] Admin %d a dat vehiculul %s lui %d (plăcuță: %s)',
            source, model, targetId, vehicle.plate))
        TriggerClientEvent('vehicles:client:spawnVehicle', targetId, VehiclesManager.buildSpawnData(vehicle))
    else
        print(string.format('[VEHICLES] Eroare la crearea vehiculului: %s', err or 'necunoscută'))
    end
end, true)

RegisterCommand('vehicles:impound', function(source, args)
    if not checkAdmin(source) then return end
    local plate  = args[1]
    local reason = table.concat(args, ' ', 2) or 'Sechestrat de admin'
    if not plate then
        print('Utilizare: vehicles:impound <plate> [reason]')
        return
    end
    local vehicle = VehiclesDatabase.getOwnedVehicleByPlate(plate)
    if not vehicle then
        print(string.format('[VEHICLES] Vehicul cu plăcuța %s nu există', plate))
        return
    end
    local success, err = VehiclesManager.impoundVehicle(vehicle.id, reason)
    if success then
        print(string.format('[VEHICLES] Vehicul %s sechestrat de admin %d. Motiv: %s', plate, source, reason))
    else
        print(string.format('[VEHICLES] Eroare sechestrare: %s', err or 'necunoscută'))
    end
end, true)

RegisterCommand('vehicles:release', function(source, args)
    if not checkAdmin(source) then return end
    local plate = args[1]
    if not plate then
        print('Utilizare: vehicles:release <plate>')
        return
    end
    local vehicle = VehiclesDatabase.getOwnedVehicleByPlate(plate)
    if not vehicle then
        print(string.format('[VEHICLES] Vehicul cu plăcuța %s nu există', plate))
        return
    end
    local success, err = VehiclesManager.releaseVehicle(vehicle.id)
    if success then
        print(string.format('[VEHICLES] Vehicul %s eliberat din sechestru de admin %d', plate, source))
    else
        print(string.format('[VEHICLES] Eroare eliberare: %s', err or 'necunoscută'))
    end
end, true)

RegisterCommand('vehicles:fuel', function(source, args)
    if not checkAdmin(source) then return end
    local plate  = args[1]
    local amount = tonumber(args[2])
    if not plate or not amount then
        print('Utilizare: vehicles:fuel <plate> <amount 0-100>')
        return
    end
    local vehicle = VehiclesDatabase.getOwnedVehicleByPlate(plate)
    if not vehicle then
        print(string.format('[VEHICLES] Vehicul cu plăcuța %s nu există', plate))
        return
    end
    FuelManager.setFuel(vehicle.id, amount)
    print(string.format('[VEHICLES] Combustibil setat la %.1f%% pentru vehiculul %s', amount, plate))
end, true)
