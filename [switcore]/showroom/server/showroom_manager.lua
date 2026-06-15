
ShowroomManager = {}

function ShowroomManager.getDealershipCatalog(dealershipCode)
    local dealership = ShowroomDatabase.getDealershipByCode(dealershipCode)
    if not dealership then return nil, Sw.T('showroom.error_dealership_not_found') end
    local catalog = ShowroomDatabase.getDealershipCatalog(dealership.id)
    return { dealership = dealership, catalog = catalog }
end

local function getDealershipSpawnPoint(catalogId)
    local pg = exports.postgres
    local row = pg:queryOne([[
        SELECT d.code
        FROM vehicle_catalog vc
        JOIN dealerships d ON d.id = vc.dealership_id
        WHERE vc.id = $1
    ]], { catalogId })
    if not row or not row.code then return nil end

    local locations = exports.settings:GetSettingList('showroom.dealership_locations', {})
    for _, loc in ipairs(locations) do
        if loc.code == row.code and loc.testDriveSpawn then
            return loc.testDriveSpawn
        end
    end
    return nil
end

function ShowroomManager.purchaseVehicle(source, characterId, catalogId, paymentMethod, customPlate, colorIndex)
    if not characterId or not catalogId or not paymentMethod then
        return false, Sw.TP(source, 'showroom.error_invalid_params')
    end

    local item = ShowroomDatabase.getCatalogItem(catalogId)
    if not item then return false, Sw.TP(source, 'showroom.error_vehicle_not_in_catalog') end
    if not item.is_active then return false, Sw.TP(source, 'showroom.error_vehicle_unavailable') end

    if customPlate and customPlate ~= '' then
        local cleanPlate = customPlate:upper():gsub('[^A-Z0-9%-]', ''):sub(1, 8)
        if #cleanPlate < 3 then
            return false, Sw.TP(source, 'showroom.error_custom_plate_min')
        end
        if exports.vehicles:getOwnedVehicleByPlate(cleanPlate) then
            return false, Sw.TP(source, 'showroom.error_plate_taken')
        end
        customPlate = cleanPlate
    end

    if item.vip_only then
        if not exports.core:hasPermission(source, 'vip') then
            return false, Sw.TP(source, 'showroom.error_vip_only')
        end
    end

    if paymentMethod == 'finance' and not item.finance_eligible then
        return false, Sw.TP(source, 'showroom.error_not_finance_eligible')
    end

    local price = tonumber(item.price)

    local currencies = exports.banking:getActiveCurrencies()
    if not currencies or #currencies == 0 then
        return false, Sw.TP(source, 'showroom.error_banking_unavailable')
    end
    local currencyId = currencies[1].id

    local loanId        = nil
    local bankAccountId = nil

    if paymentMethod == 'cash' then
        if not exports.banking:tryDeductCharacterCash(characterId, currencyId, price) then
            return false, Sw.TP(source, 'showroom.error_insufficient_cash', ('%.0f'):format(price))
        end

    elseif paymentMethod == 'bank' then
        local accounts = exports.banking:getCharacterAccounts(characterId)
        if not accounts or #accounts == 0 then
            return false, Sw.TP(source, 'showroom.error_no_bank_account')
        end
        local account = accounts[1]
        bankAccountId = account.id
        if not exports.banking:removeAccountBalance(account.id, currencyId, price) then
            return false, Sw.TP(source, 'showroom.error_insufficient_bank', ('%.0f'):format(price))
        end

    elseif paymentMethod == 'finance' then
        local loanType   = exports.settings:GetSetting('showroom.default_loan_type', 'personal')
        local bankCode   = exports.settings:GetSetting('showroom.default_finance_bank_code', 'MAZE')
        local termMonths = exports.settings:GetSettingNumber('showroom.default_finance_term_months', 24)

        local bank = exports.banking:getBankByCode(bankCode)
        if not bank then
            return false, Sw.TP(source, 'showroom.error_finance_bank_missing', bankCode)
        end

        local loan, err = exports.banking:createLoan(characterId, bank.id, loanType, price, termMonths, currencyId)
        if not loan then
            return false, Sw.TP(source, 'showroom.error_finance_rejected', err or Sw.TP(source, 'showroom.error_finance_unknown'))
        end
        loanId = loan.id
    else
        return false, Sw.TP(source, 'showroom.error_invalid_payment_method')
    end

    local vehicle, err = exports.vehicles:createVehicle(characterId, item.model, item.category, item.label, customPlate)
    if not vehicle then
        if paymentMethod == 'cash' then
            exports.banking:addCharacterCash(characterId, currencyId, price)
        elseif paymentMethod == 'bank' and bankAccountId then
            exports.banking:addAccountBalance(bankAccountId, currencyId, price)
        end
        return false, Sw.TP(source, 'showroom.error_vehicle_create', err or '')
    end

    local vehicleId = vehicle.id

    ShowroomDatabase.logPurchase(characterId, catalogId, vehicleId, price, paymentMethod, loanId)

    -- Palette index range 0-159 (GTA vehicle paint IDs)
    local paint = tonumber(colorIndex)
    if paint and paint >= 0 then
        exports.vehicles:saveVehicleState(vehicleId, {
            modifications = {
                paint_primary   = paint,
                paint_secondary = paint,
            }
        })
    end

    local spawnPoint = getDealershipSpawnPoint(catalogId)
    if spawnPoint then
        exports.vehicles:saveVehicleState(vehicleId, {
            last_position = {
                x       = spawnPoint.x,
                y       = spawnPoint.y,
                z       = spawnPoint.z,
                heading = spawnPoint.heading or 0.0,
            }
        })
    end

    local spawnOk, spawnErr = exports.vehicles:spawnVehicleForPlayer(source, vehicleId)
    if not spawnOk then
        print(string.format('[SHOWROOM] Spawn eșuat după cumpărare (vehicleId=%d): %s', vehicleId, spawnErr or ''))
        TriggerClientEvent('switcore:notify', source, 'warning', Sw.TP(source, 'showroom.notify_purchased_garage'), 6000)
    end

    TriggerClientEvent('switcore:notify', source, 'success',
        Sw.TP(source, 'showroom.notify_purchased', item.label, ('%.0f'):format(price)), 6000)

    return true, nil, vehicleId
end

function ShowroomManager.startTestDrive(source, characterId, catalogId)
    if not characterId or not catalogId then return false, Sw.TP(source, 'showroom.error_invalid_params') end

    local existing = ShowroomDatabase.getActiveTestDrive(characterId)
    if existing then
        return false, Sw.TP(source, 'showroom.error_test_drive_active')
    end

    local item = ShowroomDatabase.getCatalogItem(catalogId)
    if not item then return false, Sw.TP(source, 'showroom.error_vehicle_not_in_catalog') end

    if item.vip_only then
        if not exports.core:hasPermission(source, 'vip') then
            return false, Sw.TP(source, 'showroom.error_vip_only')
        end
    end

    local durationMinutes = exports.settings:GetSettingNumber('showroom.test_drive_duration_minutes', 5)

    local plate = string.format('TD-%05d', math.random(1, 99999))

    local drive = ShowroomDatabase.startTestDrive(characterId, catalogId, plate, durationMinutes)
    if not drive then return false, Sw.TP(source, 'showroom.error_test_drive_create') end

    local dealership = ShowroomDatabase.getDealershipByCode(
        ShowroomManager.getDealershipCodeForCatalog(catalogId)
    )

    TriggerClientEvent('showroom:client:startTestDrive', source, {
        model         = item.model,
        label         = item.label,
        plate         = plate,
        durationSecs  = durationMinutes * 60,
        testDriveId   = drive.id,
    })

    return true, nil, drive
end

function ShowroomManager.endTestDrive(source, characterId)
    if not characterId then return false, Sw.TP(source, 'showroom.error_invalid_params') end
    ShowroomDatabase.endTestDrive(characterId)
    TriggerClientEvent('showroom:client:endTestDrive', source)
    return true, nil
end

function ShowroomManager.getDealershipCodeForCatalog(catalogId)
    local item = ShowroomDatabase.getCatalogItem(catalogId)
    if not item then return nil end
    local pg = exports.postgres
    local row = pg:queryOne('SELECT code FROM dealerships WHERE id = $1', { item.dealership_id })
    return row and row.code
end

function ShowroomManager.cleanupExpiredTestDrives()
    local expired = ShowroomDatabase.getExpiredTestDrives()
    for _, drive in ipairs(expired) do
        ShowroomDatabase.endTestDrive(drive.character_id)
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local character = exports.characters:getActiveCharacter(tonumber(playerId))
            if character and character.id == drive.character_id then
                TriggerClientEvent('showroom:client:endTestDrive', tonumber(playerId))
                TriggerClientEvent('switcore:notify', tonumber(playerId), 'warning', Sw.TP(tonumber(playerId), 'showroom.notify_test_drive_expired'), 4000)
                break
            end
        end
    end
end

return ShowroomManager
