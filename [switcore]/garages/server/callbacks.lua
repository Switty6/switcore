
RegisterNetEvent('garages:server:openGarage', function(garageCode)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end
    local characterId = character.id

    local garage = GaragesDatabase.getGarageByCode(garageCode)
    if not garage then
        TriggerClientEvent('switcore:notify', source, 'error', 'Garaj inexistent', 3000)
        return
    end

    local vehicles  = GaragesManager.getGarageVehicles(characterId)
    local impounded = ImpoundManager.getImpoundedVehicles(characterId)
    local tickets   = GaragesDatabase.getCharacterTickets(characterId)

    TriggerClientEvent('garages:client:openUI', source, {
        garage    = garage,
        vehicles  = vehicles,
        impounded = impounded,
        tickets   = tickets,
    })
end)

RegisterNetEvent('garages:server:parkVehicle', function(vehicleId, garageCode, state)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local ok, err = GaragesManager.parkVehicle(source, character.id, vehicleId, garageCode, state)
    if not ok then
        TriggerClientEvent('switcore:notify', source, 'error', err, 4000)
    else
        TriggerClientEvent('switcore:notify', source, 'success', 'Vehicul parcat', 3000)
    end
end)

RegisterNetEvent('garages:server:retrieveVehicle', function(vehicleId, garageCode)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local ok, err = GaragesManager.retrieveVehicle(source, character.id, vehicleId, garageCode)
    if not ok then
        TriggerClientEvent('switcore:notify', source, 'error', err, 4000)
    end
end)

RegisterNetEvent('garages:server:releaseImpound', function(vehicleId)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local ok, err, paid = ImpoundManager.releaseVehicle(source, character.id, vehicleId)
    if not ok then
        TriggerClientEvent('switcore:notify', source, 'error', err, 5000)
    end
end)

RegisterNetEvent('garages:server:payTicket', function(ticketId)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local ok, err = ImpoundManager.payTicket(source, character.id, ticketId)
    if not ok then
        TriggerClientEvent('switcore:notify', source, 'error', err, 4000)
    else
        TriggerClientEvent('switcore:notify', source, 'success', 'Amendă achitată', 3000)
    end
end)

RegisterNetEvent('garages:server:refreshData', function(garageCode)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local characterId = character.id
    local vehicles  = GaragesManager.getGarageVehicles(characterId)
    local impounded = ImpoundManager.getImpoundedVehicles(characterId)
    local tickets   = GaragesDatabase.getCharacterTickets(characterId)

    TriggerClientEvent('garages:client:updateData', source, {
        vehicles  = vehicles,
        impounded = impounded,
        tickets   = tickets,
    })
end)
