
VehiclesManager = {}

local function generateCandidatePlate(attempt)
    local pattern = exports.settings:GetSetting('vehicles.plate.pattern', 'SW-%05d')

    local tempPlate = pattern:gsub('%^', function()
        local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local rand = math.random(1, #letters)
        return letters:sub(rand, rand)
    end):gsub('#', function()
        return tostring(math.random(0, 9))
    end)

    local plate
    if tempPlate:match('%%.*d') then
        local seq = VehiclesDatabase.getNextPlateSequence()
        if attempt > 0 then seq = seq + math.random(10, 1000) end
        plate = string.format(tempPlate, seq)
    else
        plate = tempPlate
    end

    return plate:upper():sub(1, 8)
end

function VehiclesManager.createVehicle(characterId, model, category, label, customPlate)
    if not characterId or not model then
        return false, Sw.T('vehicles.invalid_parameters')
    end

    if customPlate and customPlate ~= '' then
        local cleanPlate = customPlate:upper():gsub('[^A-Z0-9%-]', ''):sub(1, 8)
        if #cleanPlate < 3 then
            return false, Sw.T('vehicles.custom_plate_min_length')
        end

        local vehicle, err = VehiclesDatabase.createOwnedVehicle(
            characterId, cleanPlate, model, label or model, category or 'sedans'
        )
        if err == 'plate_taken' then
            return false, Sw.T('vehicles.custom_plate_taken')
        elseif not vehicle then
            return false, Sw.T('vehicles.vehicle_create_db_error')
        end

        KeysManager.giveKey(vehicle.id, characterId, 'owner')
        return true, nil, vehicle
    end

    for attempt = 0, 99 do
        local plate = generateCandidatePlate(attempt)
        local vehicle, err = VehiclesDatabase.createOwnedVehicle(
            characterId, plate, model, label or model, category or 'sedans'
        )
        if vehicle then
            KeysManager.giveKey(vehicle.id, characterId, 'owner')
            print(string.format('[VEHICLES] Vehicul creat: %s (%s) pentru caracterul %d, plăcuță: %s',
                label or model, model, characterId, plate))
            return true, nil, vehicle
        end
        if err == 'db_error' then
            return false, Sw.T('vehicles.vehicle_create_db_error')
        end
        -- err == 'plate_taken' -> retry cu placuta noua
    end

    return false, Sw.T('vehicles.plate_generation_failed')
end

function VehiclesManager.saveVehicleState(vehicleId, state)
    if not vehicleId or not state then
        return false, Sw.T('vehicles.invalid_parameters')
    end

    local success = VehiclesDatabase.updateVehicleState(vehicleId, state)
    if not success then
        return false, Sw.T('vehicles.save_state_failed')
    end
    return true, nil
end

function VehiclesManager.getOwnedVehicle(vehicleId)
    return VehiclesDatabase.getOwnedVehicleById(vehicleId)
end

function VehiclesManager.getOwnedVehicleByPlate(plate)
    return VehiclesDatabase.getOwnedVehicleByPlate(plate)
end

function VehiclesManager.getCharacterVehicles(characterId)
    return VehiclesDatabase.getCharacterVehicles(characterId)
end

function VehiclesManager.impoundVehicle(vehicleId, reason)
    if not vehicleId then return false, Sw.T('vehicles.vehicle_id_missing') end

    local success = VehiclesDatabase.updateVehicleState(vehicleId, {
        impounded = true,
        stored    = true
    })

    if success then
        print(string.format('[VEHICLES] Vehicul %d sechestrat. Motiv: %s', vehicleId, reason or 'N/A'))
    end

    return success, success and nil or Sw.T('vehicles.impound_failed')
end

function VehiclesManager.releaseVehicle(vehicleId)
    if not vehicleId then return false, Sw.T('vehicles.vehicle_id_missing') end

    local success = VehiclesDatabase.updateVehicleState(vehicleId, {
        impounded = false
    })

    return success, success and nil or Sw.T('vehicles.release_failed')
end

function VehiclesManager.addMileage(vehicleId, km)
    if not vehicleId or not km or km <= 0 then return false end

    local vehicle = VehiclesDatabase.getOwnedVehicleById(vehicleId)
    if not vehicle then return false end

    local newMileage = (tonumber(vehicle.mileage) or 0.0) + km
    return VehiclesDatabase.updateVehicleState(vehicleId, { mileage = newMileage })
end

function VehiclesManager.buildSpawnData(vehicle)
    return {
        vehicleId    = vehicle.id,
        model        = vehicle.model,
        plate        = vehicle.plate,
        label        = vehicle.label,
        fuel         = tonumber(vehicle.fuel) or 100.0,
        bodyHealth   = tonumber(vehicle.body_health) or 1000.0,
        engineHealth = tonumber(vehicle.engine_health) or 1000.0,
        modifications = vehicle.modifications or {},
        lastPosition  = vehicle.last_position
    }
end

return VehiclesManager
