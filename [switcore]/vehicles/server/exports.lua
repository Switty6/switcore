
local vehicleNetIds = {}

RegisterNetEvent('vehicles:server:vehicleSpawned', function(vehicleId, netId)
    vehicleId = tonumber(vehicleId)
    netId     = tonumber(netId)
    if vehicleId and netId then
        vehicleNetIds[vehicleId] = netId
    end
end)

exports('despawnVehicleEntity', function(vehicleId)
    local netId = vehicleNetIds[vehicleId]
    vehicleNetIds[vehicleId] = nil
    if not netId then return false end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
        return true
    end
    return false
end)

exports('getOwnedVehicle', function(vehicleId)
    return VehiclesManager.getOwnedVehicle(vehicleId)
end)

exports('getOwnedVehicleByPlate', function(plate)
    return VehiclesManager.getOwnedVehicleByPlate(plate)
end)

exports('getCharacterVehicles', function(characterId)
    return VehiclesManager.getCharacterVehicles(characterId)
end)

exports('createVehicle', function(characterId, model, category, label, customPlate)
    local ok, err, vehicle = VehiclesManager.createVehicle(characterId, model, category, label, customPlate)
    if ok then
        return vehicle
    else
        return nil, err
    end
end)

exports('saveVehicleState', function(vehicleId, state)
    return VehiclesManager.saveVehicleState(vehicleId, state)
end)

exports('giveVehicleKey', function(vehicleId, characterId, keyType)
    return KeysManager.giveKey(vehicleId, characterId, keyType)
end)

exports('removeVehicleKey', function(vehicleId, characterId)
    return KeysManager.removeKey(vehicleId, characterId)
end)

exports('hasVehicleKey', function(vehicleId, characterId)
    return KeysManager.hasKey(vehicleId, characterId)
end)

exports('getVehicleKeys', function(vehicleId)
    return KeysManager.getVehicleKeys(vehicleId)
end)

exports('transferOwnership', function(vehicleId, fromCharacterId, toCharacterId)
    return KeysManager.transferOwnership(vehicleId, fromCharacterId, toCharacterId)
end)

exports('impoundVehicle', function(vehicleId, reason)
    return VehiclesManager.impoundVehicle(vehicleId, reason)
end)

exports('releaseVehicle', function(vehicleId)
    return VehiclesManager.releaseVehicle(vehicleId)
end)

exports('getVehicleFuel', function(vehicleId)
    return FuelManager.getFuel(vehicleId)
end)

exports('setVehicleFuel', function(vehicleId, amount)
    return FuelManager.setFuel(vehicleId, amount)
end)

exports('addMileage', function(vehicleId, km)
    return VehiclesManager.addMileage(vehicleId, km)
end)

exports('getVehicleComponents', function(vehicleId)
    local v = VehiclesManager.getOwnedVehicle(vehicleId)
    if not v then return nil end
    local c = v.components
    if type(c) == 'string' then c = json.decode(c) end
    return c
end)

exports('saveVehicleComponents', function(vehicleId, components)
    return VehiclesManager.saveVehicleState(vehicleId, { components = components })
end)

local spawningVehicles = {}

exports('spawnVehicleForPlayer', function(source, vehicleId, spawnPoint)
    local character = exports.characters:getActiveCharacter(source)
    if not character then return false, Sw.TP(source, 'vehicles.no_character') end

    if spawningVehicles[vehicleId] then
        return false, Sw.TP(source, 'vehicles.already_out')
    end
    spawningVehicles[vehicleId] = true
    local function unlock() spawningVehicles[vehicleId] = nil end

    local vehicle = VehiclesManager.getOwnedVehicle(vehicleId)
    if not vehicle then unlock(); return false, Sw.TP(source, 'vehicles.vehicle_not_found') end

    if not KeysManager.hasKey(vehicleId, character.id) then
        unlock()
        return false, Sw.TP(source, 'vehicles.character_no_key')
    end

    if vehicle.impounded then unlock(); return false, Sw.TP(source, 'vehicles.vehicle_impounded') end

    if vehicle.stored == false then
        unlock()
        return false, Sw.TP(source, 'vehicles.already_out')
    end

    local sp = spawnPoint
    if type(sp) == 'string' then sp = json.decode(sp) end
    if sp and sp.x then
        vehicle.last_position = {
            x = sp.x, y = sp.y, z = sp.z,
            heading = sp.heading or sp.w or 0.0,
        }
        VehiclesDatabase.updateVehicleState(vehicleId, { stored = false, last_position = vehicle.last_position })
    else
        VehiclesDatabase.updateVehicleState(vehicleId, { stored = false })
    end

    if vehicle.plate then
        TriggerClientEvent('vehicles:client:addOwnedPlate', source, vehicle.plate)
    end
    TriggerClientEvent('vehicles:client:spawnVehicle', source, VehiclesManager.buildSpawnData(vehicle))
    unlock()
    return true, nil
end)
