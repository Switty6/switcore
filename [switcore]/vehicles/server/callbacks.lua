
local function GetCharacterId(source)
    local character = exports.characters:getActiveCharacter(source)
    return character and character.id
end

RegisterNetEvent('vehicles:server:getMyVehicles', function()
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('vehicles:client:myVehicles', source, { success = false, error = 'No character' })
        return
    end

    local vehicles = VehiclesManager.getCharacterVehicles(characterId)

    TriggerClientEvent('vehicles:client:myVehicles', source, {
        success  = true,
        vehicles = vehicles or {}
    })
end)

RegisterNetEvent('vehicles:server:spawnVehicle', function(vehicleId)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local vehicle = VehiclesDatabase.getOwnedVehicleIfKeyed(vehicleId, characterId)
    if not vehicle then
        TriggerClientEvent('switcore:notify', source, 'error', 'Nu ai cheie pentru acest vehicul sau este inexistent', 4000)
        return
    end

    if vehicle.impounded then
        TriggerClientEvent('switcore:notify', source, 'error', 'Vehiculul este sechestrat', 4000)
        return
    end

    VehiclesDatabase.updateVehicleState(vehicleId, { stored = false })

    TriggerClientEvent('vehicles:client:spawnVehicle', source, VehiclesManager.buildSpawnData(vehicle))
end)

RegisterNetEvent('vehicles:server:saveVehicleState', function(vehicleId, state)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId or not state then return end

    if not KeysManager.hasKey(vehicleId, characterId) then return end

    VehiclesManager.saveVehicleState(vehicleId, state)

    if state.fuel then
        FuelManager.updateCache(vehicleId, state.fuel)
    end
end)

RegisterNetEvent('vehicles:server:despawnVehicle', function(vehicleId, state)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

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

RegisterNetEvent('vehicles:server:requestFuelMultiplier', function()
    local source = source
    local mult   = exports.settings:GetSettingNumber('vehicles.fuel_consumption_rate', 1.0) or 1.0
    TriggerClientEvent('vehicles:client:setFuelMultiplier', source, mult)
    local mileageOn = exports.settings:GetSettingBool('vehicles.enable_mileage', true)
    TriggerClientEvent('vehicles:client:setMileageEnabled', source, mileageOn)
end)

local mileageBuffer = {}

RegisterNetEvent('vehicles:server:requestMileage', function(vehicleId)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end
    if not KeysManager.hasKey(vehicleId, characterId) then return end

    local vehicle = VehiclesManager.getOwnedVehicle(vehicleId)
    if not vehicle then return end
    local km = (tonumber(vehicle.mileage) or 0.0) + (mileageBuffer[vehicleId] or 0.0)
    TriggerClientEvent('vehicles:client:setCurrentMileage', source, vehicleId, km)
end)

RegisterNetEvent('vehicles:server:mileageTick', function(vehicleId, km)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then return end

    vehicleId = tonumber(vehicleId)
    km = tonumber(km)
    -- Sanity cap pe tick (anti-cheat: la 100ms tick max distanță fizic plauzibilă ~5km)
    if not vehicleId or not km or km <= 0 or km > 5.0 then return end

    if not KeysManager.hasKey(vehicleId, characterId) then return end

    mileageBuffer[vehicleId] = (mileageBuffer[vehicleId] or 0.0) + km
    if mileageBuffer[vehicleId] >= 0.05 then
        VehiclesManager.addMileage(vehicleId, mileageBuffer[vehicleId])
        mileageBuffer[vehicleId] = 0.0
    end
end)

local lastFuelByVeh = {}

RegisterNetEvent('vehicles:server:fuelTick', function(vehicleId, currentFuel)
    local source = source
    vehicleId    = tonumber(vehicleId)
    currentFuel  = tonumber(currentFuel)
    if not vehicleId or not currentFuel then return end

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

RegisterNetEvent('vehicles:server:onKeyItemGiven', function(vehicleId, toCharacterId)
    local source = source
    local fromCharacterId = GetCharacterId(source)
    if not fromCharacterId then return end

    vehicleId     = tonumber(vehicleId)
    toCharacterId = tonumber(toCharacterId)
    if not vehicleId or not toCharacterId then return end

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

RegisterNetEvent('vehicles:server:onKeyItemLost', function(vehicleId)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then return end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return end

    local keys = VehiclesDatabase.getVehicleKeys(vehicleId)
    for _, key in ipairs(keys) do
        if tonumber(key.character_id) == tonumber(characterId) and key.key_type == 'owner' then
            return
        end
    end

    VehiclesDatabase.removeVehicleKey(vehicleId, characterId)
end)
