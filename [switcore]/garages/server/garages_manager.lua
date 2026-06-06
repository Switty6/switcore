
GaragesManager = {}

function GaragesManager.parkVehicle(source, characterId, vehicleId, garageCode, state)
    if not characterId or not vehicleId or not garageCode then
        return false, 'Parametri invalizi'
    end

    if not exports.vehicles:hasVehicleKey(vehicleId, characterId) then
        return false, 'Nu ai cheie pentru acest vehicul'
    end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return false, 'Vehicul inexistent' end

    if vehicle.impounded then
        return false, 'Vehiculul este sechestrat - mergi la impound'
    end

    local garage = GaragesDatabase.getGarageByCode(garageCode)
    if not garage then return false, 'Garaj inexistent' end

    if state then
        local stateCopy = {}
        for k, v in pairs(state) do stateCopy[k] = v end
        stateCopy.stored = nil
        exports.vehicles:saveVehicleState(vehicleId, stateCopy)
    end

    local ok = GaragesDatabase.parkVehicleAtomic(vehicleId, characterId, garage.id)
    if not ok then
        return false, 'Eroare la parcarea vehiculului'
    end

    TriggerClientEvent('vehicles:client:despawnVehicle', source, vehicle.plate)

    return true, nil
end

function GaragesManager.retrieveVehicle(source, characterId, vehicleId, garageCode)
    if not characterId or not vehicleId or not garageCode then
        return false, 'Parametri invalizi'
    end

    if not exports.vehicles:hasVehicleKey(vehicleId, characterId) then
        return false, 'Nu ai cheie pentru acest vehicul'
    end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return false, 'Vehicul inexistent' end

    if vehicle.impounded then
        return false, 'Vehiculul este sechestrat - mergi la impound pentru eliberare'
    end

    if not vehicle.stored then
        return false, 'Vehiculul nu este parcat'
    end

    local garage = GaragesDatabase.getGarageByCode(garageCode)
    if not garage then return false, 'Garaj inexistent' end

    if garage.type == 'impound' then
        return false, 'Folosește interfața de sechestru pentru a elibera vehiculul'
    end

    local ok, err = exports.vehicles:spawnVehicleForPlayer(source, vehicleId, garage.spawn_point)
    if not ok then return false, err end

    GaragesDatabase.logAction(vehicleId, characterId, garage.id, 'retrieved', tonumber(vehicle.fuel))

    return true, nil
end

function GaragesManager.getGarageVehicles(characterId)
    if not characterId then return {} end
    return GaragesDatabase.getCharacterVehicles(characterId)
end

return GaragesManager
