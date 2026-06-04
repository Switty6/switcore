Sw.SecureEvent('showroom:server:openDealership', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'dealershipCode', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local source = ctx.source

    local data, err = ShowroomManager.getDealershipCatalog(ctx.args.dealershipCode)
    if not data then
        return ctx.error(err or 'Eroare catalog', 3000)
    end

    local activeDrive = ShowroomDatabase.getActiveTestDrive(ctx.character.id)

    local financeMinPrice = exports.settings:GetSettingNumber('showroom.finance_min_price', 5000)
    local testDriveDuration = exports.settings:GetSettingNumber('showroom.test_drive_duration_minutes', 5)

    TriggerClientEvent('showroom:client:openUI', source, {
        dealership      = data.dealership,
        catalog         = data.catalog,
        activeDrive     = activeDrive,
        financeMinPrice = financeMinPrice,
        testDriveDuration = testDriveDuration,
    })
end)

Sw.SecureEvent('showroom:server:purchaseVehicle', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'catalogId',     type = 'int', min = 1 },
        { name = 'paymentMethod', type = 'string', minLen = 1, maxLen = 32 },
        { name = 'customPlate',   type = 'string', maxLen = 8, optional = true },
        { name = 'colorIndex',    type = 'int', min = 0, optional = true },
    },
}, function(ctx)
    local source = ctx.source

    local ok, err, vehicleId = ShowroomManager.purchaseVehicle(source, ctx.character.id, ctx.args.catalogId, ctx.args.paymentMethod, ctx.args.customPlate, ctx.args.colorIndex)
    if not ok then
        ctx.error(err, 5000)
        TriggerClientEvent('showroom:client:purchaseResult', source, { success = false, error = err })
    else
        TriggerClientEvent('showroom:client:purchaseResult', source, { success = true, vehicleId = vehicleId })
    end
end)

Sw.SecureEvent('showroom:server:startTestDrive', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'catalogId', type = 'int', min = 1 },
    },
}, function(ctx)
    local ok, err, drive = ShowroomManager.startTestDrive(ctx.source, ctx.character.id, ctx.args.catalogId)
    if not ok then
        ctx.error(err, 4000)
    end
end)

Sw.SecureEvent('showroom:server:endTestDrive', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
}, function(ctx)
    ShowroomManager.endTestDrive(ctx.source, ctx.character.id)
    ctx.notify('info', 'Test drive finalizat', 3000)
end)

AddEventHandler('playerDropped', function()
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if character then
        ShowroomDatabase.endTestDrive(character.id)
    end
end)
