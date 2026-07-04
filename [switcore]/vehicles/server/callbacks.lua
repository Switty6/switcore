
local function GetCharacterId(source)
    local character = exports.characters:getActiveCharacter(source)
    return character and character.id
end

Sw.SecureEvent('vehicles:server:getMyVehicles', {
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local source = ctx.source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('vehicles:client:myVehicles', source, { success = false, error = Sw.TP(source, 'vehicles.no_character') })
        return
    end

    local vehicles = VehiclesManager.getCharacterVehicles(characterId)

    TriggerClientEvent('vehicles:client:myVehicles', source, {
        success  = true,
        vehicles = vehicles or {}
    })
end)

Sw.SecureEvent('vehicles:server:spawnVehicle', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
    },
}, function(ctx)
    local source      = ctx.source
    local characterId = ctx.character.id
    local vehicleId   = ctx.args.vehicleId

    local vehicle = VehiclesDatabase.getOwnedVehicleIfKeyed(vehicleId, characterId)
    if not vehicle then
        return ctx.error(Sw.TP(ctx.source, 'vehicles.no_key_or_missing'))
    end

    if vehicle.impounded then
        return ctx.error(Sw.TP(ctx.source, 'vehicles.vehicle_impounded'))
    end

    VehiclesDatabase.updateVehicleState(vehicleId, { stored = false })

    TriggerClientEvent('vehicles:client:spawnVehicle', source, VehiclesManager.buildSpawnData(vehicle))
end)

Sw.SecureEvent('vehicles:server:saveVehicleState', {
    character = true,
    silent = true,
    rateLimit = { max = 20, window = 3000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
        { name = 'state',     type = 'table' },
    },
}, function(ctx)
    local characterId = ctx.character.id
    local vehicleId   = ctx.args.vehicleId
    local state       = ctx.args.state

    if not KeysManager.hasKey(vehicleId, characterId) then return end

    VehiclesManager.saveVehicleState(vehicleId, state)

    if state.fuel then
        FuelManager.updateCache(vehicleId, state.fuel)
    end
end)

Sw.SecureEvent('vehicles:server:despawnVehicle', {
    character = true,
    silent = true,
    rateLimit = { max = 20, window = 3000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
        { name = 'state',     type = 'table', optional = true },
    },
}, function(ctx)
    local characterId = ctx.character.id
    local vehicleId   = ctx.args.vehicleId
    local state       = ctx.args.state

    if not KeysManager.hasKey(vehicleId, characterId) then return end

    if state then
        state.stored = true
        VehiclesManager.saveVehicleState(vehicleId, state)
    else
        VehiclesDatabase.updateVehicleState(vehicleId, { stored = true })
    end

    FuelManager.clearCache(vehicleId)
end)

local fuelTickCounters = {}

Sw.SecureEvent('vehicles:server:requestFuelMultiplier', {
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local source = ctx.source
    local mult   = exports.settings:GetSettingNumber('vehicles.fuel_consumption_rate', 1.0) or 1.0
    TriggerClientEvent('vehicles:client:setFuelMultiplier', source, mult)
    local mileageOn = exports.settings:GetSettingBool('vehicles.enable_mileage', true)
    TriggerClientEvent('vehicles:client:setMileageEnabled', source, mileageOn)
end)

local mileageBuffer = {}

Sw.SecureEvent('vehicles:server:requestMileage', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
    },
}, function(ctx)
    local source      = ctx.source
    local characterId = ctx.character.id
    local vehicleId   = ctx.args.vehicleId

    if not KeysManager.hasKey(vehicleId, characterId) then return end

    local vehicle = VehiclesManager.getOwnedVehicle(vehicleId)
    if not vehicle then return end
    local km = (tonumber(vehicle.mileage) or 0.0) + (mileageBuffer[vehicleId] or 0.0)
    TriggerClientEvent('vehicles:client:setCurrentMileage', source, vehicleId, km)
end)

Sw.SecureEvent('vehicles:server:mileageTick', {
    character = true,
    silent = true,
    rateLimit = { max = 15, window = 1000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
        { name = 'km',        type = 'number' },
    },
}, function(ctx)
    local characterId = ctx.character.id
    local vehicleId   = ctx.args.vehicleId
    local km          = ctx.args.km

    -- Sanity cap pe tick (anti-cheat: la 100ms tick max distanță fizic plauzibilă ~5km)
    if km <= 0 or km > 5.0 then return end

    if not KeysManager.hasKey(vehicleId, characterId) then return end

    mileageBuffer[vehicleId] = (mileageBuffer[vehicleId] or 0.0) + km
    if mileageBuffer[vehicleId] >= 0.05 then
        VehiclesManager.addMileage(vehicleId, mileageBuffer[vehicleId])
        mileageBuffer[vehicleId] = 0.0
    end
end)

local lastFuelByVeh = {}

Sw.SecureEvent('vehicles:server:fuelTick', {
    silent = true,
    rateLimit = { max = 15, window = 1000 },
    args = {
        { name = 'vehicleId',   type = 'int', min = 1 },
        { name = 'currentFuel', type = 'number' },
    },
}, function(ctx)
    local source      = ctx.source
    local vehicleId   = ctx.args.vehicleId
    local currentFuel = ctx.args.currentFuel

    if not FuelManager.validateClientTick(vehicleId, currentFuel) then
        print(('[VEHICLES] WARN: fuel tick respins vehicle=%d src=%s fuel=%.2f')
            :format(vehicleId, tostring(source), currentFuel))
        return
    end

    FuelManager.updateCache(vehicleId, currentFuel)

    fuelTickCounters[vehicleId] = (fuelTickCounters[vehicleId] or 0) + 1
    if fuelTickCounters[vehicleId] >= 6 then
        fuelTickCounters[vehicleId] = 0
        VehiclesDatabase.updateVehicleState(vehicleId, { fuel = currentFuel })
    end
end)

Sw.SecureEvent('vehicles:server:onKeyItemGiven', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId',     type = 'int', min = 1 },
        { name = 'toCharacterId', type = 'int', min = 1 },
    },
}, function(ctx)
    local fromCharacterId = ctx.character.id
    local vehicleId       = ctx.args.vehicleId
    local toCharacterId   = ctx.args.toCharacterId

    if not KeysManager.hasKey(vehicleId, fromCharacterId) then return end

    VehiclesDatabase.addVehicleKey(vehicleId, toCharacterId, 'standard')
end)

AddEventHandler('playerDropped', function()
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end
    exports.postgres:query(
        'UPDATE owned_vehicles SET stored = true, updated_at = NOW() WHERE character_id = $1 AND stored = false AND impounded = false',
        { character.id }
    )
end)

Sw.SecureEvent('vehicles:server:onKeyItemLost', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
    },
}, function(ctx)
    local characterId = ctx.character.id
    local vehicleId   = ctx.args.vehicleId

    local keys = VehiclesDatabase.getVehicleKeys(vehicleId)
    for _, key in ipairs(keys) do
        if tonumber(key.character_id) == tonumber(characterId) and key.key_type == 'owner' then
            return
        end
    end

    VehiclesDatabase.removeVehicleKey(vehicleId, characterId)
end)

-- Rezultatul skill-check-ului e determinat client-side (minigame de indemanare,
-- nu are impact economic direct); serverul valideaza doar preconditiile
-- (jucatorul chiar detine o ranga, vehiculul e inregistrat si nu are deja
-- cheie) inainte sa acorde efectele (cheie temporara / ruperea rangii / alerta politie).
Sw.SecureEvent('vehicles:server:lockpickAttempt', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 5000 },
    args = {
        { name = 'plate',   type = 'string', minLen = 1, maxLen = 16 },
        { name = 'success', type = 'boolean' },
    },
}, function(ctx)
    local src         = ctx.source
    local characterId = ctx.character.id
    local plate       = ctx.args.plate:gsub('%s+', '')
    local success     = ctx.args.success

    local invId = 'char:' .. tostring(characterId)
    local hasLockpick = false
    local inv = exports.inventory:GetInventory(invId)
    if inv and inv.slots then
        for _, slotData in pairs(inv.slots) do
            if slotData.name == 'lockpick' then hasLockpick = true; break end
        end
    end
    if not hasLockpick then
        TriggerClientEvent('switcore:notify', src, 'error', Sw.TP(src, 'vehicles.no_lockpick'), 3000)
        return
    end

    local vehicle = VehiclesDatabase.getOwnedVehicleByPlate(plate)
    if not vehicle then return end
    if KeysManager.hasKey(vehicle.id, characterId) then return end

    if success then
        TriggerClientEvent('vehicles:client:lockpickResult', src, plate, true)
        exports.core:log('info', 'VEHICLES', string.format(
            'Lockpick reusit: characterId=%d plate=%s', characterId, plate))
        return
    end

    -- Esec: 25% sansa sa se rupa ranga
    if math.random(100) <= 25 then
        pcall(function() exports.inventory:RemoveItem(invId, 'lockpick', 1) end)
        TriggerClientEvent('switcore:notify', src, 'error', Sw.TP(src, 'vehicles.lockpick_broken'), 4000)
    end

    -- Alerteaza politistii aflati in tura despre o tentativa de furt vehicul
    local ok, roster = pcall(function() return exports.jobs:GetJobRoster('police') end)
    if ok and roster then
        for _, officer in ipairs(roster) do
            if officer.is_on_duty then
                local officerSrc = exports.characters:getSourceByCharacterId(officer.id)
                if officerSrc then
                    TriggerClientEvent('switcore:notify', officerSrc, 'warning',
                        Sw.TP(officerSrc, 'police.alert_vehicle_theft', plate), 6000)
                end
            end
        end
    end
end)
