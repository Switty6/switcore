BankingManager = {}

function BankingManager.generateAccountNumber(bankCode)
    if not bankCode then
        return nil
    end
    
    local sequence = BankingDatabase.getNextAccountSequence(bankCode)
    
    local seqStr = tostring(sequence)
    while #seqStr < 12 do
        seqStr = '0' .. seqStr
    end
    
    local part1 = seqStr:sub(1, 4)
    local part2 = seqStr:sub(5, 8)
    local part3 = seqStr:sub(9, 12)
    
    return bankCode .. '-' .. part1 .. '-' .. part2 .. '-' .. part3
end

function BankingManager.createAccount(characterId, bankId, accountType, interestRate, depositTermDays)
    if not characterId or not bankId or not accountType then
        return false, 'Parametri invalizi'
    end

    characterId = tonumber(characterId)
    bankId = tonumber(bankId)
    if not characterId or characterId <= 0 or not bankId or bankId <= 0 then
        return false, 'ID-uri invalide'
    end
    
    if accountType ~= 'current' and accountType ~= 'savings' and accountType ~= 'deposit' then
        return false, 'Tip cont invalid'
    end
    
    if accountType == 'deposit' then
        if not depositTermDays then
            return false, 'Termen depozit necesar'
        end
        local minTerm = exports.settings:GetSettingNumber('banking.min_deposit_term_days', 30)
        local maxTerm = exports.settings:GetSettingNumber('banking.max_deposit_term_days', 365)
        if depositTermDays < minTerm or depositTermDays > maxTerm then
            return false, 'Termen depozit invalid'
        end
    end
    
    local bank = BankingDatabase.getBankById(bankId)
    if not bank then
        return false, 'Bancă nu există'
    end
    
    local accountNumber = BankingManager.generateAccountNumber(bank.code)
    if not accountNumber then
        return false, 'Eroare la generarea numărului de cont'
    end
    
    if not interestRate then
        interestRate = exports.settings:GetSettingNumber('banking.interest_rate_' .. accountType, 0.0)
    end
    
    local account = BankingDatabase.createBankAccount(
        characterId,
        bankId,
        accountType,
        accountNumber,
        interestRate,
        depositTermDays
    )
    
    if not account then
        return false, 'Eroare la crearea contului'
    end
    
    TriggerEvent('banking:accountCreated', characterId, account.id, accountNumber)
    
    return true, nil, account
end

function BankingManager.getAccountByNumber(accountNumber)
    return BankingDatabase.getAccountByNumber(accountNumber)
end

function BankingManager.getAccountById(accountId)
    return BankingDatabase.getAccountById(accountId)
end

function BankingManager.getCharacterAccounts(characterId)
    return BankingDatabase.getCharacterAccounts(characterId)
end

function BankingManager.getAccountBalance(accountId, currencyId)
    local account = BankingDatabase.getAccountById(accountId)
    if not account then
        return nil
    end
    
    local balance = BankingHelpers.parseBalance(account.balance)
    return tonumber(balance[tostring(currencyId)]) or 0.0
end

function BankingManager.setAccountBalance(accountId, currencyId, amount)
    local account = BankingDatabase.getAccountById(accountId)
    if not account then
        return false
    end
    
    local balance = BankingHelpers.parseBalance(account.balance)
    balance[tostring(currencyId)] = amount
    
    return BankingDatabase.updateAccountBalance(accountId, balance)
end

function BankingManager.addAccountBalance(accountId, currencyId, amount)
    local currentBalance = BankingManager.getAccountBalance(accountId, currencyId) or 0.0
    return BankingManager.setAccountBalance(accountId, currencyId, currentBalance + amount)
end

function BankingManager.removeAccountBalance(accountId, currencyId, amount)
    return BankingDatabase.atomicSubtractAccountBalance(accountId, currencyId, amount)
end

function BankingManager.deposit(characterId, accountId, amount, currencyId)
    if not characterId or not accountId or not amount or amount <= 0 or not currencyId then
        return false, 'Parametri invalizi'
    end

    local valid, err, charId, accId, currId = BankingHelpers.validateIds(characterId, accountId, currencyId)
    if not valid then return false, err end
    characterId, accountId, currencyId = charId, accId, currId

    local amountValid, amountErr = BankingHelpers.validateTransactionAmount(amount)
    if not amountValid then return false, amountErr end

    local account = BankingDatabase.getAccountById(accountId)
    local ownershipValid, ownershipErr = BankingHelpers.validateAccountOwnership(account, characterId)
    if not ownershipValid then return false, ownershipErr end

    local fee, feeCurrencyId = FeeManager.calculateDepositFee(account.bank_id, amount, currencyId)
    fee = tonumber(fee) or 0

    if feeCurrencyId == currencyId or fee == 0 then
        local ok, depErr = BankingDatabase.atomicDepositSameCurrency(characterId, accountId, currencyId, amount, fee)
        if not ok then return false, depErr end
    else
        if not BankingDatabase.atomicSubtractCharacterCash(characterId, feeCurrencyId, fee) then
            return false, 'Fonduri insuficiente pentru comision'
        end
        local ok, depErr = BankingDatabase.atomicDepositSameCurrency(characterId, accountId, currencyId, amount, 0)
        if not ok then
            BankingDatabase.addCharacterCash(characterId, feeCurrencyId, fee)
            return false, depErr
        end
    end

    BankingDatabase.createTransaction(
        characterId, 'deposit', nil, accountId,
        amount, currencyId, fee, feeCurrencyId,
        'Depunere în cont', {account_number = account.account_number}
    )

    TriggerEvent('banking:transactionCompleted', characterId, 'deposit', accountId, amount, currencyId)
    return true
end

function BankingManager.withdraw(characterId, accountId, amount, currencyId)
    if not characterId or not accountId or not amount or amount <= 0 or not currencyId then
        return false, 'Parametri invalizi'
    end

    local valid, err, charId, accId, currId = BankingHelpers.validateIds(characterId, accountId, currencyId)
    if not valid then return false, err end
    characterId, accountId, currencyId = charId, accId, currId

    local amountValid, amountErr = BankingHelpers.validateTransactionAmount(amount)
    if not amountValid then return false, amountErr end

    local account = BankingDatabase.getAccountById(accountId)
    local ownershipValid, ownershipErr = BankingHelpers.validateAccountOwnership(account, characterId)
    if not ownershipValid then return false, ownershipErr end

    local fee, feeCurrencyId = FeeManager.calculateWithdrawalFee(account.bank_id, amount, currencyId)
    fee = tonumber(fee) or 0

    if feeCurrencyId == currencyId or fee == 0 then
        local ok, wErr = BankingDatabase.atomicWithdrawSameCurrency(characterId, accountId, currencyId, amount, fee)
        if not ok then return false, wErr end
    else
        local ok, wErr = BankingDatabase.atomicWithdrawSameCurrency(characterId, accountId, currencyId, amount, 0)
        if not ok then return false, wErr end
        if not BankingDatabase.atomicSubtractCharacterCash(characterId, feeCurrencyId, fee) then
            BankingDatabase.atomicSubtractCharacterCash(characterId, currencyId, amount)
            BankingDatabase.atomicAddAccountBalance(accountId, currencyId, amount)
            return false, 'Fonduri insuficiente pentru comision'
        end
    end

    BankingDatabase.createTransaction(
        characterId, 'withdrawal', accountId, nil,
        amount, currencyId, fee, feeCurrencyId,
        'Retragere din cont', {account_number = account.account_number}
    )

    TriggerEvent('banking:transactionCompleted', characterId, 'withdrawal', accountId, amount, currencyId)
    return true
end

function BankingManager.transfer(characterId, fromAccountId, toAccountId, amount, currencyId)
    if not characterId or not fromAccountId or not toAccountId or not amount or amount <= 0 or not currencyId then
        return false, 'Parametri invalizi'
    end

    characterId = tonumber(characterId)
    fromAccountId = tonumber(fromAccountId)
    toAccountId = tonumber(toAccountId)
    currencyId = tonumber(currencyId)
    if not characterId or characterId <= 0 or not fromAccountId or fromAccountId <= 0 or not toAccountId or toAccountId <= 0 or not currencyId or currencyId <= 0 then
        return false, 'ID-uri invalide'
    end

    local amountValid, amountErr = BankingHelpers.validateTransactionAmount(amount)
    if not amountValid then return false, amountErr end

    if fromAccountId == toAccountId then
        return false, 'Nu poți transfera în același cont'
    end

    local fromAccount = BankingDatabase.getAccountById(fromAccountId)
    local toAccount = BankingDatabase.getAccountById(toAccountId)
    if not fromAccount or not toAccount then
        return false, 'Cont nu există'
    end

    local ownershipValid, ownershipErr = BankingHelpers.validateAccountOwnership(fromAccount, characterId)
    if not ownershipValid then return false, ownershipErr end

    local fee, feeCurrencyId = FeeManager.calculateTransferFee(fromAccountId, toAccountId, amount, currencyId)
    fee = tonumber(fee) or 0

    if feeCurrencyId == currencyId or fee == 0 then
        local ok, tErr = BankingDatabase.atomicTransferSameCurrency(fromAccountId, toAccountId, currencyId, amount, fee)
        if not ok then return false, tErr end
    else
        local ok, tErr = BankingDatabase.atomicTransferSameCurrency(fromAccountId, toAccountId, currencyId, amount, 0)
        if not ok then return false, tErr end
        if not BankingDatabase.atomicSubtractCharacterCash(characterId, feeCurrencyId, fee) then
            BankingDatabase.atomicSubtractAccountBalance(toAccountId, currencyId, amount)
            BankingDatabase.atomicAddAccountBalance(fromAccountId, currencyId, amount)
            return false, 'Fonduri insuficiente pentru comision'
        end
    end

    BankingDatabase.createTransaction(
        characterId, 'transfer', fromAccountId, toAccountId,
        amount, currencyId, fee, feeCurrencyId,
        'Transfer între conturi',
        {from_account_number = fromAccount.account_number, to_account_number = toAccount.account_number}
    )

    TriggerEvent('banking:transactionCompleted', characterId, 'transfer', fromAccountId, amount, currencyId)
    return true
end

function BankingManager.exchangeCurrency(characterId, accountId, amount, currencyFromId, currencyToId)
    if not characterId or not accountId or not amount or amount <= 0 or not currencyFromId or not currencyToId then
        return false, 'Parametri invalizi'
    end

    local valid, err, charId, accId, currFromId = BankingHelpers.validateIds(characterId, accountId, currencyFromId)
    if not valid then return false, err end
    characterId, accountId, currencyFromId = charId, accId, currFromId

    currencyToId = tonumber(currencyToId)
    if not currencyToId or currencyToId <= 0 then
        return false, 'ID-uri invalide'
    end

    local amountValid, amountErr = BankingHelpers.validateTransactionAmount(amount)
    if not amountValid then return false, amountErr end

    if currencyFromId == currencyToId then
        return false, 'Nu poți schimba aceeași valută'
    end

    local account = BankingDatabase.getAccountById(accountId)
    local ownershipValid, ownershipErr = BankingHelpers.validateAccountOwnership(account, characterId)
    if not ownershipValid then return false, ownershipErr end

    local exchangeOk, exchangeErr, convertedAmount = CurrencyManager.exchangeCurrency(amount, currencyFromId, currencyToId)
    if not exchangeOk then
        return false, exchangeErr or 'Eroare la calcularea cursului'
    end

    local fee, feeCurrencyId = FeeManager.calculateCurrencyExchangeFee(account.bank_id, amount, currencyFromId)
    fee = tonumber(fee) or 0

    local totalDeduct = amount + (feeCurrencyId == currencyFromId and fee or 0)
    local ok, exErr = BankingDatabase.atomicExchangeInAccount(accountId, currencyFromId, currencyToId, totalDeduct, convertedAmount)
    if not ok then return false, exErr end

    if fee > 0 and feeCurrencyId ~= currencyFromId then
        if not BankingDatabase.atomicSubtractAccountBalance(accountId, feeCurrencyId, fee) then
            BankingDatabase.atomicAddAccountBalance(accountId, currencyFromId, amount)
            BankingDatabase.atomicSubtractAccountBalance(accountId, currencyToId, convertedAmount)
            return false, 'Fonduri insuficiente pentru comision'
        end
    end

    BankingDatabase.createTransaction(
        characterId, 'currency_exchange', accountId, accountId,
        amount, currencyFromId, fee, feeCurrencyId,
        'Schimb valutar',
        {currency_to_id = currencyToId, converted_amount = convertedAmount, exchange_rate = convertedAmount / amount}
    )

    TriggerEvent('banking:transactionCompleted', characterId, 'currency_exchange', accountId, amount, currencyFromId)
    return true, nil, convertedAmount
end

return BankingManager

