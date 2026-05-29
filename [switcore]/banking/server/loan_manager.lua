LoanManager = {}

function LoanManager.createLoan(characterId, bankId, loanType, principalAmount, termMonths, currencyId)
    if not characterId or not bankId or not loanType or not principalAmount or principalAmount <= 0 or not termMonths or not currencyId then
        return false, 'Parametri invalizi'
    end

    characterId = tonumber(characterId)
    bankId = tonumber(bankId)
    currencyId = tonumber(currencyId)
    if not characterId or characterId <= 0 or not bankId or bankId <= 0 or not currencyId or currencyId <= 0 then
        return false, 'ID-uri invalide'
    end
    
    if loanType ~= 'personal' and loanType ~= 'mortgage' and loanType ~= 'business' then
        return false, 'Tip credit invalid'
    end
    
    local minTerm = exports.settings:GetSettingNumber('banking.min_loan_term_months', 6)
    local maxTerm = exports.settings:GetSettingNumber('banking.max_loan_term_months', 60)
    if termMonths < minTerm or termMonths > maxTerm then
        return false, 'Termen credit invalid'
    end

    local interestRate = exports.settings:GetSettingNumber('banking.loan_rate_' .. loanType, 10.0)
    interestRate = interestRate / 100.0

    local monthlyRate = interestRate / 12.0
    local monthlyPayment = 0.0

    if monthlyRate > 0 then
        -- Formula anuitate: P * (r(1+r)^n) / ((1+r)^n - 1)
        local factor = (1 + monthlyRate) ^ termMonths
        monthlyPayment = principalAmount * (monthlyRate * factor) / (factor - 1)
    else
        monthlyPayment = principalAmount / termMonths
    end
    
    local totalAmount = monthlyPayment * termMonths
    local remainingAmount = totalAmount
    
    local nextPaymentDate = os.date('%Y-%m-%d', os.time() + 30 * 24 * 60 * 60)
    
    local loan = BankingDatabase.createLoan(
        characterId,
        bankId,
        loanType,
        principalAmount,
        interestRate * 100.0,
        remainingAmount,
        monthlyPayment,
        termMonths,
        nextPaymentDate,
        currencyId
    )
    
    if not loan then
        return false, 'Eroare la crearea creditului'
    end

    local accounts = BankingManager.getCharacterAccounts(characterId)
    if #accounts > 0 then
        BankingManager.addAccountBalance(accounts[1].id, currencyId, principalAmount)
    else
        BankingDatabase.addCharacterCash(characterId, currencyId, principalAmount)
    end
    
    BankingDatabase.createTransaction(
        characterId,
        'loan_payment',
        nil,
        nil,
        principalAmount,
        currencyId,
        0.0,
        nil,
        'Credit acordat',
        {loan_id = loan.id, loan_type = loanType}
    )
    
    TriggerEvent('banking:loanCreated', characterId, loan.id, principalAmount, currencyId)
    
    return true, nil, loan
end

function LoanManager.getLoanById(loanId)
    return BankingDatabase.getLoanById(loanId)
end

function LoanManager.getCharacterActiveLoans(characterId)
    return BankingDatabase.getCharacterActiveLoans(characterId)
end

function LoanManager.makeLoanPayment(characterId, loanId, amount)
    if not characterId or not loanId or not amount or amount <= 0 then
        return false, 'Parametri invalizi'
    end

    characterId = tonumber(characterId)
    loanId = tonumber(loanId)
    if not characterId or characterId <= 0 or not loanId or loanId <= 0 then
        return false, 'ID-uri invalide'
    end

    local amountValid, amountErr = BankingHelpers.validateTransactionAmount(amount)
    if not amountValid then
        return false, amountErr
    end
    
    local loan = BankingDatabase.getLoanById(loanId)
    if not loan then
        return false, 'Credit nu există'
    end
    
    if loan.character_id ~= characterId then
        return false, 'Creditul nu aparține caracterului'
    end
    
    if loan.status ~= 'active' then
        return false, 'Creditul nu este activ'
    end
    
    if amount < loan.monthly_payment then
        return false, 'Sumă insuficientă pentru plată'
    end
    
    local accounts = BankingManager.getCharacterAccounts(characterId)
    local balance = 0.0
    local accountId = nil
    
    if #accounts > 0 then
        for _, account in ipairs(accounts) do
            local accBalance = BankingManager.getAccountBalance(account.id, loan.currency_id)
            if accBalance >= amount then
                balance = accBalance
                accountId = account.id
                break
            end
        end
    end

    if not accountId then
        local cash = BankingDatabase.getCharacterCash(characterId, loan.currency_id)
        if cash >= amount then
            balance = cash
        else
            return false, 'Fonduri insuficiente'
        end
    else
        if balance < amount then
            return false, 'Fonduri insuficiente'
        end
    end
    
    local paymentAmount = math.min(amount, loan.remaining_amount)
    
    local isOnTime = true
    if loan.next_payment_date then
        local nextPaymentTimestamp = os.time({
            year = tonumber(loan.next_payment_date:sub(1, 4)),
            month = tonumber(loan.next_payment_date:sub(6, 7)),
            day = tonumber(loan.next_payment_date:sub(9, 10))
        })
        isOnTime = os.time() <= nextPaymentTimestamp
    end
    
    local success = pcall(function()
        exports.postgres:transaction(function(client)
            if accountId then
                BankingManager.removeAccountBalance(accountId, loan.currency_id, paymentAmount)
            else
                local cash = BankingDatabase.getCharacterCash(characterId, loan.currency_id)
                BankingDatabase.setCharacterCash(characterId, loan.currency_id, cash - paymentAmount)
            end
            
            local newRemaining = loan.remaining_amount - paymentAmount
            local newPaymentsMade = loan.payments_made + 1
            local newStatus = 'active'
            
            if newRemaining <= 0.01 then
                newRemaining = 0.0
                newStatus = 'paid'
            end
            
            local nextPaymentDate = loan.next_payment_date
            if newStatus == 'active' then
                local dateParts = {}
                dateParts.year = tonumber(loan.next_payment_date:sub(1, 4))
                dateParts.month = tonumber(loan.next_payment_date:sub(6, 7))
                dateParts.day = tonumber(loan.next_payment_date:sub(9, 10))
                
                dateParts.month = dateParts.month + 1
                if dateParts.month > 12 then
                    dateParts.month = 1
                    dateParts.year = dateParts.year + 1
                end
                
                nextPaymentDate = string.format('%04d-%02d-%02d', dateParts.year, dateParts.month, dateParts.day)
            end
            
            BankingDatabase.updateLoan(loanId, {
                remaining_amount = newRemaining,
                payments_made = newPaymentsMade,
                next_payment_date = nextPaymentDate,
                status = newStatus
            })
            
            BankingDatabase.addLoanPayment(loanId, paymentAmount, isOnTime)
            
            BankingDatabase.createTransaction(
                characterId,
                'loan_payment',
                accountId,
                nil,
                paymentAmount,
                loan.currency_id,
                0.0,
                nil,
                'Plată credit',
                {loan_id = loanId, is_on_time = isOnTime}
            )
        end)
    end)
    
    if not success then
        return false, 'Eroare la plată'
    end
    
    TriggerEvent('banking:loanPaymentMade', characterId, loanId, paymentAmount, loan.currency_id)
    
    return true
end

function LoanManager.processOverdueLoans()
    local result = exports.postgres:queryAll(
        "SELECT * FROM loans WHERE status = 'active' AND next_payment_date < CURRENT_DATE"
    )
    
    for _, loan in ipairs(result) do
        print(string.format('[BANKING] Credit %d este restant pentru caracterul %d', loan.id, loan.character_id))
    end
end

function LoanManager.getCharacterTotalDebt(characterId)
    local loans = BankingDatabase.getCharacterActiveLoans(characterId)
    local totalDebt = {}
    
    for _, loan in ipairs(loans) do
        if not totalDebt[loan.currency_id] then
            totalDebt[loan.currency_id] = 0.0
        end
        totalDebt[loan.currency_id] = totalDebt[loan.currency_id] + (tonumber(loan.remaining_amount) or 0.0)
    end
    
    return totalDebt
end

return LoanManager
