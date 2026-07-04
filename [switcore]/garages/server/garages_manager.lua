
GaragesManager = {}

-- garage.spawn_point ramane un singur JSONB (fara migrare de schema): acceptam
-- fie un obiect unic {x,y,z,heading}, fie un array de asemenea obiecte, pentru
-- garaje cu mai multe locuri de parcare configurate manual in DB. Expuse pe
-- tabelul GaragesManager (nu 'local') ca sa fie folosite si din
-- impound_manager.lua, alt fisier din acelasi resource.
function GaragesManager.normalizeSpawnPoints(raw)
    if not raw then return {} end
    if raw.x then return { raw } end
    return raw
end

-- Necesita OneSync (obligatoriu pentru framework, vezi avertismentul din
-- core la pornire) ca GetAllVehicles()/GetEntityCoords server-side sa
-- returneze date corecte.
function GaragesManager.pickFreeSpawnPoint(points)
    if #points == 0 then return nil end
    for _, sp in ipairs(points) do
        local spCoords = vector3(sp.x, sp.y, sp.z)
        local blocked  = false
        for _, veh in ipairs(GetAllVehicles()) do
            if DoesEntityExist(veh) and #(spCoords - GetEntityCoords(veh)) <= 3.0 then
                blocked = true
                break
            end
        end
        if not blocked then return sp end
    end
    return points[1]
end

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

    local spawnPoint = GaragesManager.pickFreeSpawnPoint(GaragesManager.normalizeSpawnPoints(garage.spawn_point))
    local ok, err = exports.vehicles:spawnVehicleForPlayer(source, vehicleId, spawnPoint)
    if not ok then return false, err end

    GaragesDatabase.logAction(vehicleId, characterId, garage.id, 'retrieved', tonumber(vehicle.fuel))

    return true, nil
end

function GaragesManager.getGarageVehicles(characterId)
    if not characterId then return {} end
    return GaragesDatabase.getCharacterVehicles(characterId)
end

return GaragesManager
