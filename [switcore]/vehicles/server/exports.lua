
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

exports('spawnVehicleForPlayer', function(source, vehicleId)
    local character = exports.characters:getActiveCharacter(source)
    if not character then return false, 'No character' end

    local vehicle = VehiclesManager.getOwnedVehicle(vehicleId)
    if not vehicle then return false, 'Vehicul inexistent' end

    if not KeysManager.hasKey(vehicleId, character.id) then
        return false, 'Personajul nu are cheie pentru acest vehicul'
    end

    if vehicle.impounded then return false, 'Vehiculul este sechestrat' end

    VehiclesDatabase.updateVehicleState(vehicleId, { stored = false })
    if vehicle.plate then
        TriggerClientEvent('vehicles:client:addOwnedPlate', source, vehicle.plate)
    end
    TriggerClientEvent('vehicles:client:spawnVehicle', source, VehiclesManager.buildSpawnData(vehicle))
    return true, nil
end)
