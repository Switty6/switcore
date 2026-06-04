
Sw.SecureEvent('garages:server:openGarage', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'garageCode', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local source      = ctx.source
    local characterId = ctx.character.id
    local garageCode  = ctx.args.garageCode

    local garage = GaragesDatabase.getGarageByCode(garageCode)
    if not garage then
        return ctx.error('Garaj inexistent', 3000)
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

Sw.SecureEvent('garages:server:parkVehicle', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId',  type = 'int', min = 1 },
        { name = 'garageCode', type = 'string', minLen = 1, maxLen = 64 },
        { name = 'state',      type = 'table', optional = true },
    },
}, function(ctx)
    local ok, err = GaragesManager.parkVehicle(ctx.source, ctx.character.id, ctx.args.vehicleId, ctx.args.garageCode, ctx.args.state)
    if not ok then
        ctx.error(err, 4000)
    else
        ctx.success('Vehicul parcat', 3000)
    end
end)

Sw.SecureEvent('garages:server:retrieveVehicle', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId',  type = 'int', min = 1 },
        { name = 'garageCode', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local ok, err = GaragesManager.retrieveVehicle(ctx.source, ctx.character.id, ctx.args.vehicleId, ctx.args.garageCode)
    if not ok then
        ctx.error(err, 4000)
    end
end)

Sw.SecureEvent('garages:server:releaseImpound', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId', type = 'int', min = 1 },
    },
}, function(ctx)
    local ok, err = ImpoundManager.releaseVehicle(ctx.source, ctx.character.id, ctx.args.vehicleId)
    if not ok then
        ctx.error(err, 5000)
    end
end)

Sw.SecureEvent('garages:server:payTicket', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'ticketId', type = 'int', min = 1 },
    },
}, function(ctx)
    local ok, err = ImpoundManager.payTicket(ctx.source, ctx.character.id, ctx.args.ticketId)
    if not ok then
        ctx.error(err, 4000)
    else
        ctx.success('Amendă achitată', 3000)
    end
end)

Sw.SecureEvent('garages:server:refreshData', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'garageCode', type = 'string', minLen = 1, maxLen = 64, optional = true },
    },
}, function(ctx)
    local source      = ctx.source
    local characterId = ctx.character.id

    local vehicles  = GaragesManager.getGarageVehicles(characterId)
    local impounded = ImpoundManager.getImpoundedVehicles(characterId)
    local tickets   = GaragesDatabase.getCharacterTickets(characterId)

    TriggerClientEvent('garages:client:updateData', source, {
        vehicles  = vehicles,
        impounded = impounded,
        tickets   = tickets,
    })
end)
