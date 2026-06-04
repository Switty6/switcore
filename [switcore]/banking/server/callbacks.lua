local function GetDefaultCurrencyId()
    local currencies = BankingDatabase.getActiveCurrencies()
    if currencies and #currencies > 0 then
        return currencies[1].id
    end
    return nil
end

Sw.SecureEvent('banking:server:getAccounts', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local characterId = ctx.character.id

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

    TriggerClientEvent('banking:client:accountsData', ctx.source, {
        success = true,
        accounts = accountsData,
        currencyId = currencyId
    })
end)

Sw.SecureEvent('banking:server:getCash', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local currencyId = GetDefaultCurrencyId()
    local cash = BankingDatabase.getCharacterCash(ctx.character.id, currencyId)

    TriggerClientEvent('banking:client:cashData', ctx.source, {
        success = true,
        cash = cash or 0.0,
        currencyId = currencyId
    })
end)

Sw.SecureEvent('banking:server:deposit', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'accountId', type = 'int', min = 1 },
        { name = 'amount',    type = 'number' },
    },
}, function(ctx)
    local amount = ctx.args.amount
    if amount <= 0 then
        return TriggerClientEvent('banking:client:depositResult', ctx.source, { success = false, error = 'Parametri invalizi' })
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = BankingManager.deposit(ctx.character.id, ctx.args.accountId, amount, currencyId)

    TriggerClientEvent('banking:client:depositResult', ctx.source, {
        success = success,
        error = err
    })
end)

Sw.SecureEvent('banking:server:withdraw', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'accountId', type = 'int', min = 1 },
        { name = 'amount',    type = 'number' },
    },
}, function(ctx)
    local amount = ctx.args.amount
    if amount <= 0 then
        return TriggerClientEvent('banking:client:withdrawResult', ctx.source, { success = false, error = 'Parametri invalizi' })
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = BankingManager.withdraw(ctx.character.id, ctx.args.accountId, amount, currencyId)

    TriggerClientEvent('banking:client:withdrawResult', ctx.source, {
        success = success,
        error = err
    })
end)

Sw.SecureEvent('banking:server:transfer', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'fromAccountId',   type = 'int', min = 1 },
        { name = 'toAccountNumber', type = 'string', minLen = 1, maxLen = 64 },
        { name = 'amount',          type = 'number' },
    },
}, function(ctx)
    local amount = ctx.args.amount
    if amount <= 0 then
        return TriggerClientEvent('banking:client:transferResult', ctx.source, { success = false, error = 'Parametri invalizi' })
    end

    local toAccount = BankingManager.getAccountByNumber(ctx.args.toAccountNumber)
    if not toAccount then
        return TriggerClientEvent('banking:client:transferResult', ctx.source, { success = false, error = 'Cont destinatar inexistent' })
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = BankingManager.transfer(ctx.character.id, ctx.args.fromAccountId, toAccount.id, amount, currencyId)

    TriggerClientEvent('banking:client:transferResult', ctx.source, {
        success = success,
        error = err
    })
end)

Sw.SecureEvent('banking:server:getTransactions', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'limit', type = 'int', min = 1, max = 500, optional = true, default = 50 },
    },
}, function(ctx)
    local transactions = BankingDatabase.getCharacterTransactions(ctx.character.id, ctx.args.limit)

    TriggerClientEvent('banking:client:transactionsData', ctx.source, {
        success = true,
        transactions = transactions or {}
    })
end)

Sw.SecureEvent('banking:server:getBanks', {
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local banks = BankingDatabase.getActiveBanks()
    TriggerClientEvent('banking:client:banksData', ctx.source, {
        success = true,
        banks = banks or {}
    })
end)

Sw.SecureEvent('banking:server:getCurrencies', {
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local currencies = BankingDatabase.getActiveCurrencies()
    TriggerClientEvent('banking:client:currenciesData', ctx.source, {
        success = true,
        currencies = currencies or {}
    })
end)

Sw.SecureEvent('banking:server:createAccount', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'bankCode',    type = 'string', minLen = 1, maxLen = 32 },
        { name = 'accountType', type = 'string', minLen = 1, maxLen = 32 },
    },
}, function(ctx)
    local bank = BankingDatabase.getBankByCode(ctx.args.bankCode)
    if not bank then
        return TriggerClientEvent('banking:client:createAccountResult', ctx.source, { success = false, error = 'Bancă inexistentă' })
    end

    local success, err, account = BankingManager.createAccount(ctx.character.id, bank.id, ctx.args.accountType)

    TriggerClientEvent('banking:client:createAccountResult', ctx.source, {
        success = success,
        error = err,
        account = account and {
            id = account.id,
            accountNumber = account.account_number,
            accountType = account.account_type
        } or nil
    })
end)

Sw.SecureEvent('banking:server:getLoans', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local characterId = ctx.character.id
    local loans = LoanManager.getCharacterActiveLoans(characterId)
    local totalDebt = LoanManager.getCharacterTotalDebt(characterId)

    TriggerClientEvent('banking:client:loansData', ctx.source, {
        success = true,
        loans = loans or {},
        totalDebt = totalDebt or 0.0
    })
end)

Sw.SecureEvent('banking:server:createLoan', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'bankCode',   type = 'string', minLen = 1, maxLen = 32 },
        { name = 'loanType',   type = 'string', minLen = 1, maxLen = 32 },
        { name = 'amount',     type = 'number', min = 1 },
        { name = 'termMonths', type = 'int', min = 1 },
    },
}, function(ctx)
    local bank = BankingDatabase.getBankByCode(ctx.args.bankCode)
    if not bank then
        return TriggerClientEvent('banking:client:createLoanResult', ctx.source, { success = false, error = 'Bancă inexistentă' })
    end

    local currencyId = GetDefaultCurrencyId()
    local success, err = LoanManager.createLoan(ctx.character.id, bank.id, ctx.args.loanType, ctx.args.amount, ctx.args.termMonths, currencyId)

    TriggerClientEvent('banking:client:createLoanResult', ctx.source, {
        success = success,
        error = err
    })
end)

Sw.SecureEvent('banking:server:payLoan', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'loanId', type = 'int', min = 1 },
        { name = 'amount', type = 'number' },
    },
}, function(ctx)
    local amount = ctx.args.amount
    if amount <= 0 then
        return TriggerClientEvent('banking:client:payLoanResult', ctx.source, { success = false, error = 'Parametri invalizi' })
    end

    local success, err = LoanManager.makeLoanPayment(ctx.character.id, ctx.args.loanId, amount)

    TriggerClientEvent('banking:client:payLoanResult', ctx.source, {
        success = success,
        error = err
    })
end)

Sw.SecureEvent('banking:server:exchangeCurrency', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'accountId',      type = 'int', min = 1 },
        { name = 'amount',         type = 'number', min = 1 },
        { name = 'currencyFromId', type = 'int', min = 1 },
        { name = 'currencyToId',   type = 'int', min = 1 },
    },
}, function(ctx)
    local success, err, convertedAmount = BankingManager.exchangeCurrency(
        ctx.character.id, ctx.args.accountId, ctx.args.amount, ctx.args.currencyFromId, ctx.args.currencyToId)

    TriggerClientEvent('banking:client:exchangeResult', ctx.source, {
        success = success,
        error = err,
        convertedAmount = convertedAmount
    })
end)
