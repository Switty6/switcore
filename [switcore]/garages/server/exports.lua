
exports('getGarageByCode', function(code)
    return GaragesDatabase.getGarageByCode(code)
end)

exports('getGarageVehicles', function(characterId)
    return GaragesManager.getGarageVehicles(characterId)
end)

exports('parkVehicle', function(source, characterId, vehicleId, garageCode, state)
    return GaragesManager.parkVehicle(source, characterId, vehicleId, garageCode, state)
end)

exports('retrieveVehicle', function(source, characterId, vehicleId, garageCode)
    return GaragesManager.retrieveVehicle(source, characterId, vehicleId, garageCode)
end)

exports('impoundToGarage', function(vehicleId, reason, issuedBy)
    return ImpoundManager.impoundVehicle(vehicleId, reason, issuedBy)
end)

exports('getImpoundedVehicles', function(characterId)
    return ImpoundManager.getImpoundedVehicles(characterId)
end)

exports('issueTicket', function(characterId, vehicleId, plate, fineAmount, reason, issuedBy)
    return GaragesDatabase.issueTicket(characterId, vehicleId, plate, fineAmount, reason, issuedBy)
end)

exports('payTicket', function(source, characterId, ticketId)
    return ImpoundManager.payTicket(source, characterId, ticketId)
end)

exports('getCharacterTickets', function(characterId)
    return GaragesDatabase.getCharacterTickets(characterId)
end)

exports('getImpoundFineTotal', function(vehicleId)
    local total, ticketsFine, releaseFee = ImpoundManager.getTotalFine(vehicleId)
    return total, ticketsFine, releaseFee
end)
