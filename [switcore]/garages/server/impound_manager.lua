
ImpoundManager = {}

function ImpoundManager.getTotalFine(vehicleId)
    local tickets = GaragesDatabase.getVehicleUnpaidTickets(vehicleId)
    local releaseFee = exports.settings:GetSettingNumber('garages.impound_release_fee', 2500)

    local ticketsTotal = 0.0
    for _, t in ipairs(tickets) do
        ticketsTotal = ticketsTotal + (tonumber(t.fine_amount) or 0.0)
    end

    return releaseFee + ticketsTotal, ticketsTotal, releaseFee
end

function ImpoundManager.impoundVehicle(vehicleId, reason, issuedBy)
    if not vehicleId then return false, Sw.T('garages.error_vehicle_id_missing') end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return false, Sw.T('garages.error_vehicle_not_found') end

    if reason and issuedBy then
        local baseFine = exports.settings:GetSettingNumber('garages.parking_ticket_base_fine', 500)
        GaragesDatabase.issueTicket(
            vehicle.character_id, vehicleId, vehicle.plate,
            baseFine, reason, issuedBy
        )
    end

    exports.vehicles:impoundVehicle(vehicleId, reason)

    print(string.format('[GARAGES] Vehicul %s sechestrat. Motiv: %s', vehicle.plate, reason or 'N/A'))
    return true, nil
end

function ImpoundManager.releaseVehicle(source, characterId, vehicleId)
    if not characterId or not vehicleId then
        return false, Sw.TP(source, 'garages.error_invalid_parameters')
    end

    if not exports.vehicles:hasVehicleKey(vehicleId, characterId) then
        return false, Sw.TP(source, 'garages.error_no_vehicle_key')
    end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return false, Sw.TP(source, 'garages.error_vehicle_not_found') end

    if not vehicle.impounded then
        return false, Sw.TP(source, 'garages.error_vehicle_not_impounded')
    end

    local totalFine, ticketsFine, releaseFee = ImpoundManager.getTotalFine(vehicleId)

    local currencies = exports.banking:getActiveCurrencies()
    if not currencies or #currencies == 0 then
        return false, Sw.TP(source, 'garages.error_banking_unavailable')
    end
    local currencyId = currencies[1].id

    if not exports.banking:tryDeductCharacterCash(characterId, currencyId, totalFine) then
        return false, Sw.TP(source, 'garages.error_insufficient_funds_release',
            string.format('%.0f', totalFine), string.format('%.0f', ticketsFine), string.format('%.0f', releaseFee))
    end

    GaragesDatabase.markAllVehicleTicketsPaid(vehicleId)

    exports.vehicles:releaseVehicle(vehicleId)

    local impoundCode = exports.settings:GetSetting('garages.impound_garage_code', 'IMPOUND_LSIA')
    local garage = GaragesDatabase.getGarageByCode(impoundCode)

    local spawnPoint = garage and GaragesManager.pickFreeSpawnPoint(GaragesManager.normalizeSpawnPoints(garage.spawn_point))
    local ok, err = exports.vehicles:spawnVehicleForPlayer(source, vehicleId, spawnPoint)
    if not ok then
        return false, Sw.TP(source, 'garages.error_paid_but_spawn_failed', err or '')
    end

    if garage then
        GaragesDatabase.logAction(vehicleId, characterId, garage.id, 'retrieved', tonumber(vehicle.fuel))
    end

    TriggerClientEvent('switcore:notify', source, 'success',
        Sw.TP(source, 'garages.vehicle_released', string.format('%.0f', totalFine)), 5000)

    return true, nil, totalFine
end

function ImpoundManager.payTicket(source, characterId, ticketId)
    if not characterId or not ticketId then
        return false, Sw.TP(source, 'garages.error_invalid_parameters')
    end

    local tickets = GaragesDatabase.getCharacterTickets(characterId)
    local ticket  = nil
    for _, t in ipairs(tickets) do
        if t.id == ticketId then ticket = t; break end
    end

    if not ticket then
        return false, Sw.TP(source, 'garages.error_ticket_not_found')
    end

    local amount = tonumber(ticket.fine_amount) or 0

    local currencies = exports.banking:getActiveCurrencies()
    if not currencies or #currencies == 0 then
        return false, Sw.TP(source, 'garages.error_banking_unavailable')
    end
    local currencyId = currencies[1].id

    if not exports.banking:tryDeductCharacterCash(characterId, currencyId, amount) then
        return false, Sw.TP(source, 'garages.error_insufficient_funds_ticket', string.format('%.0f', amount))
    end

    GaragesDatabase.markTicketPaid(ticketId)

    return true, nil
end

function ImpoundManager.getImpoundedVehicles(characterId)
    if not characterId then return {} end

    local allVehicles = GaragesDatabase.getCharacterVehicles(characterId)
    local impounded = {}

    for _, v in ipairs(allVehicles) do
        if v.impounded then
            local total, ticketsFine, releaseFee = ImpoundManager.getTotalFine(v.id)
            v.total_fine    = total
            v.tickets_fine  = ticketsFine
            v.release_fee   = releaseFee
            table.insert(impounded, v)
        end
    end

    return impounded
end

return ImpoundManager
