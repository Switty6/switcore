RegisterNetEvent('showroom:server:openDealership', function(dealershipCode)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local data, err = ShowroomManager.getDealershipCatalog(dealershipCode)
    if not data then
        TriggerClientEvent('switcore:notify', source, 'error', err or 'Eroare catalog', 3000)
        return
    end

    local activeDrive = ShowroomDatabase.getActiveTestDrive(character.id)

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

RegisterNetEvent('showroom:server:purchaseVehicle', function(catalogId, paymentMethod, customPlate, colorIndex)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local ok, err, vehicleId = ShowroomManager.purchaseVehicle(source, character.id, catalogId, paymentMethod, customPlate, colorIndex)
    if not ok then
        TriggerClientEvent('switcore:notify', source, 'error', err, 5000)
        TriggerClientEvent('showroom:client:purchaseResult', source, { success = false, error = err })
    else
        TriggerClientEvent('showroom:client:purchaseResult', source, { success = true, vehicleId = vehicleId })
    end
end)

RegisterNetEvent('showroom:server:startTestDrive', function(catalogId)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local ok, err, drive = ShowroomManager.startTestDrive(source, character.id, catalogId)
    if not ok then
        TriggerClientEvent('switcore:notify', source, 'error', err, 4000)
    end
end)

RegisterNetEvent('showroom:server:endTestDrive', function()
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    ShowroomManager.endTestDrive(source, character.id)
    TriggerClientEvent('switcore:notify', source, 'info', 'Test drive finalizat', 3000)
end)

AddEventHandler('playerDropped', function()
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if character then
        ShowroomDatabase.endTestDrive(character.id)
    end
end)
