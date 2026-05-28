local function GetCharacterId(source)
    local character = exports.characters:getActiveCharacter(source)
    if character and character.id then
        return character.id
    end
    return nil
end

local function GetDefaultCurrencyId()
    local currencies = BankingDatabase.getActiveCurrencies()
    if currencies and #currencies > 0 then
        return currencies[1].id
    end
    return nil
end

RegisterNetEvent('banking:server:getAccounts', function()
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:accountsData', source, { success = false, error = 'No character' })
        return
    end

    local accounts = BankingManager.getCharacterAccounts(characterId)
    local currencyId = GetDefaultCurrencyId()
    local currencyKey = tostring(currencyId)
    local accountsData = {}

    if accounts then
        for _, account in ipairs(accounts) do
            local balanceMap = BankingHelpers.parseBalance(account.balance)
            table.insert(accountsData, {
                id = account.id,
                accountNumber = account.account_number,
                accountType = account.account_type,
                balance = tonumber(balanceMap[currencyKey]) or 0.0,
                bankName = account.bank_name or 'Unknown',
                bankCode = account.bank_code or 'N/A',
                interestRate = account.interest_rate or 0.0,
                createdAt = account.created_at
            })
        end
    end

    TriggerClientEvent('banking:client:accountsData', source, {
        success = true,
        accounts = accountsData,
        currencyId = currencyId
    })
end)

RegisterNetEvent('banking:server:getCash', function()
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:cashData', source, { success = false, error = 'No character' })
        return
    end

    local currencyId = GetDefaultCurrencyId()
    local cash = BankingDatabase.getCharacterCash(characterId, currencyId)

    TriggerClientEvent('banking:client:cashData', source, {
        success = true,
        cash = cash or 0.0,
        currencyId = currencyId
    })
end)

RegisterNetEvent('banking:server:deposit', function(accountId, amount)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:depositResult', source, { success = false, error = 'No character' })
        return
    end

    accountId = tonumber(accountId)
    amount = tonumber(amount)
    if not accountId or not amount or amount <= 0 then
        TriggerClientEvent('banking:client:depositResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = BankingManager.deposit(characterId, accountId, amount, currencyId)

    TriggerClientEvent('banking:client:depositResult', source, {
        success = success,
        error = err
    })
end)

RegisterNetEvent('banking:server:withdraw', function(accountId, amount)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:withdrawResult', source, { success = false, error = 'No character' })
        return
    end

    accountId = tonumber(accountId)
    amount = tonumber(amount)
    if not accountId or not amount or amount <= 0 then
        TriggerClientEvent('banking:client:withdrawResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = BankingManager.withdraw(characterId, accountId, amount, currencyId)

    TriggerClientEvent('banking:client:withdrawResult', source, {
        success = success,
        error = err
    })
end)

RegisterNetEvent('banking:server:transfer', function(fromAccountId, toAccountNumber, amount)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:transferResult', source, { success = false, error = 'No character' })
        return
    end

    fromAccountId = tonumber(fromAccountId)
    amount = tonumber(amount)
    if not fromAccountId or not toAccountNumber or not amount or amount <= 0 then
        TriggerClientEvent('banking:client:transferResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local toAccount = BankingManager.getAccountByNumber(toAccountNumber)
    if not toAccount then
        TriggerClientEvent('banking:client:transferResult', source, { success = false, error = 'Cont destinatar inexistent' })
        return
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = BankingManager.transfer(characterId, fromAccountId, toAccount.id, amount, currencyId)

    TriggerClientEvent('banking:client:transferResult', source, {
        success = success,
        error = err
    })
end)

RegisterNetEvent('banking:server:getTransactions', function(limit)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:transactionsData', source, { success = false, error = 'No character' })
        return
    end

    limit = math.min(tonumber(limit) or 50, 500)
    local transactions = BankingDatabase.getCharacterTransactions(characterId, limit)

    TriggerClientEvent('banking:client:transactionsData', source, {
        success = true,
        transactions = transactions or {}
    })
end)

RegisterNetEvent('banking:server:getBanks', function()
    local source = source
    local banks = BankingDatabase.getActiveBanks()
    TriggerClientEvent('banking:client:banksData', source, {
        success = true,
        banks = banks or {}
    })
end)

RegisterNetEvent('banking:server:getCurrencies', function()
    local source = source
    local currencies = BankingDatabase.getActiveCurrencies()
    TriggerClientEvent('banking:client:currenciesData', source, {
        success = true,
        currencies = currencies or {}
    })
end)

RegisterNetEvent('banking:server:createAccount', function(bankCode, accountType)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:createAccountResult', source, { success = false, error = 'No character' })
        return
    end

    if not bankCode or not accountType then
        TriggerClientEvent('banking:client:createAccountResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local bank = BankingDatabase.getBankByCode(bankCode)
    if not bank then
        TriggerClientEvent('banking:client:createAccountResult', source, { success = false, error = 'Bancă inexistentă' })
        return
    end

    local success, err, account = BankingManager.createAccount(characterId, bank.id, accountType)

    TriggerClientEvent('banking:client:createAccountResult', source, {
        success = success,
        error = err,
        account = account and {
            id = account.id,
            accountNumber = account.account_number,
            accountType = account.account_type
        } or nil
    })
end)

RegisterNetEvent('banking:server:getLoans', function()
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:loansData', source, { success = false, error = 'No character' })
        return
    end

    local loans = LoanManager.getCharacterActiveLoans(characterId)
    local totalDebt = LoanManager.getCharacterTotalDebt(characterId)

    TriggerClientEvent('banking:client:loansData', source, {
        success = true,
        loans = loans or {},
        totalDebt = totalDebt or 0.0
    })
end)

RegisterNetEvent('banking:server:createLoan', function(bankCode, loanType, amount, termMonths)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:createLoanResult', source, { success = false, error = 'No character' })
        return
    end

    amount = tonumber(amount)
    termMonths = tonumber(termMonths)
    if not bankCode or not loanType or not amount or not termMonths then
        TriggerClientEvent('banking:client:createLoanResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local bank = BankingDatabase.getBankByCode(bankCode)
    if not bank then
        TriggerClientEvent('banking:client:createLoanResult', source, { success = false, error = 'Bancă inexistentă' })
        return
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err, loan = LoanManager.createLoan(characterId, bank.id, loanType, amount, termMonths, currencyId)

    TriggerClientEvent('banking:client:createLoanResult', source, {
        success = success,
        error = err
    })
end)

RegisterNetEvent('banking:server:payLoan', function(loanId, amount)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:payLoanResult', source, { success = false, error = 'No character' })
        return
    end

    loanId = tonumber(loanId)
    amount = tonumber(amount)
    if not loanId or not amount or amount <= 0 then
        TriggerClientEvent('banking:client:payLoanResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local success, err = LoanManager.makeLoanPayment(characterId, loanId, amount)

    TriggerClientEvent('banking:client:payLoanResult', source, {
        success = success,
        error = err
    })
end)

RegisterNetEvent('banking:server:exchangeCurrency', function(accountId, amount, currencyFromId, currencyToId)
    local source = source
    local characterId = GetCharacterId(source)
    if not characterId then
        TriggerClientEvent('banking:client:exchangeResult', source, { success = false, error = 'No character' })
        return
    end

    accountId = tonumber(accountId)
    amount = tonumber(amount)
    currencyFromId = tonumber(currencyFromId)
    currencyToId = tonumber(currencyToId)
    if not accountId or not amount or not currencyFromId or not currencyToId then
        TriggerClientEvent('banking:client:exchangeResult', source, { success = false, error = 'Parametri invalizi' })
        return
    end

    local success, err, convertedAmount = BankingManager.exchangeCurrency(characterId, accountId, amount, currencyFromId, currencyToId)

    TriggerClientEvent('banking:client:exchangeResult', source, {
        success = success,
        error = err,
        convertedAmount = convertedAmount
    })
end)
