CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    while not exports.settings:IsReady() do Wait(100) end

    local resourceName = GetCurrentResourceName()
    exports.core:loadLocaleFile(resourceName, 'ro', 'locales/ro.lua')
    exports.core:loadLocaleFile(resourceName, 'en', 'locales/en.lua')

    InitializeBankingSystem()
end)

function InitializeBankingSystem()
    CreateDefaultBanks()
    
    CreateDefaultCurrencies()
    CreateDefaultFees()
    StartPeriodicTasks()
    OrgManager.ensureOrgAccount('police', 'MAZE')
    OrgManager.ensureOrgAccount('gov',    'MAZE')
    print('[BANKING] Sistemul de banking a fost inițializat cu succes!')
end

function CreateDefaultBanks()
    local defaultBanks = exports.settings:GetSettingList('banking.default_banks', {
        { name = 'Maze Bank',   code = 'MAZE', is_active = true },
        { name = 'Fleeca Bank', code = 'FLEC', is_active = true },
    })
    for _, bankData in ipairs(defaultBanks) do
        local existingBank = BankingDatabase.getBankByCode(bankData.code)
        if not existingBank then
            local bank = BankingDatabase.createBank(bankData.name, bankData.code, nil)
            if bank then
                print(string.format('[BANKING] Bancă creată: %s (%s)', bankData.name, bankData.code))
            end
        end
    end
end

function CreateDefaultCurrencies()
    local defaultCurrencies = exports.settings:GetSettingList('banking.default_currencies', {
        { code = 'USD', name = 'US Dollar', symbol = '$'  },
        { code = 'EUR', name = 'Euro',      symbol = 'EUR' },
    })
    for _, currencyData in ipairs(defaultCurrencies) do
        local existingCurrency = BankingDatabase.getCurrencyByCode(currencyData.code)
        if not existingCurrency then
            local success, err, currency = CurrencyManager.createCurrency(
                currencyData.code,
                currencyData.name,
                currencyData.symbol
            )
            if success then
                print(string.format('[BANKING] Valută creată: %s (%s)', currencyData.name, currencyData.code))
            end
        end
    end
end

function CreateDefaultFees()
    local banks = BankingDatabase.getActiveBanks()
    local currencies = BankingDatabase.getActiveCurrencies()

    if #currencies == 0 then return end

    local defaultCurrencyId = currencies[1].id
    local defaultFees = exports.settings:GetSettingJSON('banking.default_bank_fees', {
        transfer_same_bank      = { fee_type_value = 'fixed',      fee_amount = 0.0 },
        transfer_different_bank = { fee_type_value = 'percentage', fee_amount = 1.5 },
        withdrawal              = { fee_type_value = 'fixed',      fee_amount = 5.0 },
        deposit                 = { fee_type_value = 'fixed',      fee_amount = 0.0 },
        currency_exchange       = { fee_type_value = 'percentage', fee_amount = 2.0 },
    })

    for _, bank in ipairs(banks) do
        for feeType, feeData in pairs(defaultFees) do
            local existingFee = BankingDatabase.getBankFee(bank.id, feeType)
            if not existingFee then
                FeeManager.setBankFee(
                    bank.id,
                    feeType,
                    feeData.fee_type_value,
                    feeData.fee_amount,
                    defaultCurrencyId
                )
            end
        end
    end
end

RegisterNetEvent('banking:server:getProximityConfig', function()
    local src = source
    local atmModels = exports.settings:GetSettingList('banking.atm_models', {
        'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm',
    })
    local bankLocations = exports.settings:GetSettingList('banking.bank_locations', {})
    local atmDistance   = exports.settings:GetSettingNumber('banking.atm_distance', 1.5)
    local bankDistance  = exports.settings:GetSettingNumber('banking.bank_distance', 2.0)

    TriggerClientEvent('banking:client:proximityConfig', src, {
        atmModels     = atmModels,
        bankLocations = bankLocations,
        atmDistance   = atmDistance,
        bankDistance  = bankDistance,
    })
end)

function StartPeriodicTasks()
    local inflationInterval = exports.settings:GetSettingNumber('banking.inflation_calculation_interval', 3600) * 1000
    local interestInterval  = exports.settings:GetSettingNumber('banking.interest_calculation_interval', 3600) * 1000

    CreateThread(function()
        while true do Wait(inflationInterval) InflationManager.applyInflation() end
    end)
    CreateThread(function()
        while true do Wait(interestInterval) InflationManager.calculateAccountInterest() end
    end)
    CreateThread(function()
        while true do Wait(3600000) LoanManager.processOverdueLoans() end
    end)
end

AddEventHandler('switcore:characterSelected', function(source, characterId, character)
    if not characterId then return end
    TriggerEvent('banking:characterLoaded', source, characterId)
end)

AddEventHandler('banking:accountCreated', function(characterId, accountId, accountNumber)
    print(string.format('[BANKING] Cont creat: %s pentru caracterul %d', accountNumber, characterId))
end)

AddEventHandler('banking:transactionCompleted', function(characterId, transactionType, accountId, amount, currencyId)
    if exports.settings:GetSettingBool('banking.log_transactions', true) then
        print(string.format('[BANKING] Tranzacție: %s - %s pentru caracterul %d, suma: %.2f', 
            transactionType, accountId and tostring(accountId) or 'N/A', characterId, amount))
    end
end)

RegisterCommand('banking:createcurrency', function(source, args)
    if not exports.core:hasPermission(source, 'admin.all') then
        return
    end
    
    local code = args[1]
    local name = args[2]
    local symbol = args[3]
    
    if not code or not name or not symbol then
        print('Utilizare: banking:createcurrency <code> <name> <symbol>')
        return
    end
    
    local success, err, currency = CurrencyManager.createCurrency(code, name, symbol)
    if success then
        print(string.format('[BANKING] Valută creată: %s (%s)', name, code))
    else
        print(string.format('[BANKING] Eroare: %s', err or 'Necunoscută'))
    end
end, true)

RegisterCommand('banking:setexchangerate', function(source, args)
    if not exports.core:hasPermission(source, 'admin.all') then
        return
    end
    
    local currencyFromId = tonumber(args[1])
    local currencyToId = tonumber(args[2])
    local rate = tonumber(args[3])
    
    if not currencyFromId or not currencyToId or not rate then
        print('Utilizare: banking:setexchangerate <from_currency_id> <to_currency_id> <rate>')
        return
    end
    
    local success, err = CurrencyManager.setExchangeRate(currencyFromId, currencyToId, rate)
    if success then
        print('[BANKING] Curs de schimb actualizat')
    else
        print(string.format('[BANKING] Eroare: %s', err or 'Necunoscută'))
    end
end, true)

RegisterCommand('banking:setfee', function(source, args)
    if not exports.core:hasPermission(source, 'admin.all') then
        return
    end
    
    local bankId = tonumber(args[1])
    local feeType = args[2]
    local feeTypeValue = args[3]
    local feeAmount = tonumber(args[4])
    local currencyId = tonumber(args[5])
    
    if not bankId or not feeType or not feeTypeValue or not feeAmount or not currencyId then
        print('Utilizare: banking:setfee <bank_id> <fee_type> <percentage|fixed> <amount> <currency_id>')
        return
    end
    
    local success, err = FeeManager.setBankFee(bankId, feeType, feeTypeValue, feeAmount, currencyId)
    if success then
        print('[BANKING] Comision actualizat')
    else
        print(string.format('[BANKING] Eroare: %s', err or 'Necunoscută'))
    end
end, true)

RegisterCommand('banking:calculateinflation', function(source, args)
    if not exports.core:hasPermission(source, 'admin.all') then
        return
    end
    
    local currencyId = tonumber(args[1])
    if not currencyId then
        print('Utilizare: banking:calculateinflation <currency_id>')
        return
    end
    
    local inflationRate = InflationManager.calculateInflation(currencyId)
    if inflationRate then
        print(string.format('[BANKING] Inflație calculată: %.2f%%', inflationRate))
    else
        print('[BANKING] Eroare la calcularea inflației')
    end
end, true)
