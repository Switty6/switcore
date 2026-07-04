
GaragesManager = {}

function GaragesManager.parkVehicle(source, characterId, vehicleId, garageCode, state)
    if not characterId or not vehicleId or not garageCode then
        return false, Sw.TP(source, 'garages.error_invalid_parameters')
    end

    if not exports.vehicles:hasVehicleKey(vehicleId, characterId) then
        return false, Sw.TP(source, 'garages.error_no_vehicle_key')
    end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return false, Sw.TP(source, 'garages.error_vehicle_not_found') end

    if vehicle.impounded then
        return false, Sw.TP(source, 'garages.error_vehicle_impounded_go_impound')
    end

    local garage = GaragesDatabase.getGarageByCode(garageCode)
    if not garage then return false, Sw.TP(source, 'garages.error_garage_not_found') end

    if state then
        local stateCopy = {}
        for k, v in pairs(state) do stateCopy[k] = v end
        stateCopy.stored = nil
        exports.vehicles:saveVehicleState(vehicleId, stateCopy)
    end

    local ok = GaragesDatabase.parkVehicleAtomic(vehicleId, characterId, garage.id)
    if not ok then
        return false, Sw.TP(source, 'garages.error_park_failed')
    end

    -- Stergere server-side (autoritara, are nevoie de OneSync) - nu depinde
    -- de cache-ul client-side al jucatorului care a parcat, care poate lipsi
    -- daca acesta s-a reconectat intre timp si lasa masina fantoma in lume.
    exports.vehicles:despawnVehicleEntity(vehicleId)
    TriggerClientEvent('vehicles:client:despawnVehicle', source, vehicle.plate)

    return true, nil
end

function GaragesManager.retrieveVehicle(source, characterId, vehicleId, garageCode)
    if not characterId or not vehicleId or not garageCode then
        return false, Sw.TP(source, 'garages.error_invalid_parameters')
    end

    if not exports.vehicles:hasVehicleKey(vehicleId, characterId) then
        return false, Sw.TP(source, 'garages.error_no_vehicle_key')
    end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return false, Sw.TP(source, 'garages.error_vehicle_not_found') end

    if vehicle.impounded then
        return false, Sw.TP(source, 'garages.error_vehicle_impounded_go_impound_release')
    end

    if not vehicle.stored then
        return false, Sw.TP(source, 'garages.error_vehicle_not_parked')
    end

    local garage = GaragesDatabase.getGarageByCode(garageCode)
    if not garage then return false, Sw.TP(source, 'garages.error_garage_not_found') end

    if garage.type == 'impound' then
        return false, Sw.TP(source, 'garages.error_use_impound_interface')
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
