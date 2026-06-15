FeeManager = {}

local feeCache = {}
local cacheExpiry = 60 -- 1 minut

function FeeManager.setBankFee(bankId, feeType, feeTypeValue, feeAmount, currencyId)
    if not bankId or not feeType or not feeTypeValue or not feeAmount or not currencyId then
        return false, Sw.T('banking.error_invalid_parameters')
    end
    
    if feeTypeValue ~= 'percentage' and feeTypeValue ~= 'fixed' then
        return false, Sw.T('banking.fee_type_value_invalid')
    end
    
    local success = BankingDatabase.setBankFee(bankId, feeType, feeTypeValue, feeAmount, currencyId)
    if not success then
        return false, Sw.T('banking.fee_set_failed')
    end
    
    feeCache = {}
    
    return true
end

function FeeManager.getBankFee(bankId, feeType)
    if not bankId or not feeType then
        return nil
    end
    
    local cacheKey = bankId .. '_' .. feeType
    if feeCache[cacheKey] and feeCache[cacheKey].expiry > os.time() then
        return feeCache[cacheKey].fee
    end
    
    local fee = BankingDatabase.getBankFee(bankId, feeType)
    
    if fee then
        feeCache[cacheKey] = {
            fee = fee,
            expiry = os.time() + cacheExpiry
        }
    end
    
    return fee
end

function FeeManager.getBankFees(bankId)
    if not bankId then
        return {}
    end
    
    return BankingDatabase.getBankFees(bankId)
end

function FeeManager.calculateFee(bankId, feeType, amount, currencyId)
    if not bankId or not feeType or not amount or amount <= 0 then
        return 0.0
    end
    
    if feeType == 'transfer_same_bank' then
        return 0.0
    end
    
    local fee = FeeManager.getBankFee(bankId, feeType)
    if not fee or not fee.is_active then
        return 0.0
    end
    
    if fee.currency_id ~= currencyId then
        local exchangeRate = CurrencyManager.getExchangeRate(fee.currency_id, currencyId)
        if not exchangeRate then
            return 0.0
        end
        
        if fee.fee_type_value == 'fixed' then
            return tonumber(fee.fee_amount) * exchangeRate
        else
            local feeInOriginalCurrency = amount * (tonumber(fee.fee_amount) / 100.0)
            return feeInOriginalCurrency * exchangeRate
        end
    end
    
    if fee.fee_type_value == 'percentage' then
        return amount * (tonumber(fee.fee_amount) / 100.0)
    else
        return tonumber(fee.fee_amount)
    end
end

local function calculateOperationFee(bankId, feeType, amount, currencyId)
    if not bankId or not amount or amount <= 0 then return 0.0, nil end
    local fee = FeeManager.calculateFee(bankId, feeType, amount, currencyId)
    local bankFee = FeeManager.getBankFee(bankId, feeType)
    local feeCurrencyId = (bankFee and bankFee.currency_id ~= currencyId) and bankFee.currency_id or currencyId
    return fee, feeCurrencyId
end

function FeeManager.calculateTransferFee(fromAccountId, toAccountId, amount, currencyId)
    if not fromAccountId or not toAccountId or not amount or amount <= 0 then
        return 0.0, nil
    end
    
    local fromAccount = BankingDatabase.getAccountById(fromAccountId)
    local toAccount = BankingDatabase.getAccountById(toAccountId)
    
    if not fromAccount or not toAccount then
        return 0.0, nil
    end
    
    -- Dacă ambele conturi sunt la aceeași bancă, fără comision
    if fromAccount.bank_id == toAccount.bank_id then
        return 0.0, nil
    end
    
    local fee = FeeManager.calculateFee(fromAccount.bank_id, 'transfer_different_bank', amount, currencyId)
    local feeCurrencyId = currencyId
    
    local bankFee = FeeManager.getBankFee(fromAccount.bank_id, 'transfer_different_bank')
    if bankFee and bankFee.currency_id ~= currencyId then
        feeCurrencyId = bankFee.currency_id
    end
    
    return fee, feeCurrencyId
end

function FeeManager.calculateWithdrawalFee(bankId, amount, currencyId)
    return calculateOperationFee(bankId, 'withdrawal', amount, currencyId)
end

function FeeManager.calculateDepositFee(bankId, amount, currencyId)
    return calculateOperationFee(bankId, 'deposit', amount, currencyId)
end

function FeeManager.calculateCurrencyExchangeFee(bankId, amount, currencyId)
    return calculateOperationFee(bankId, 'currency_exchange', amount, currencyId)
end

function FeeManager.applyInflationToFees(currencyId, inflationRate)
    if not currencyId or not inflationRate then
        return false
    end
    
    local banks = BankingDatabase.getActiveBanks()
    
    for _, bank in ipairs(banks) do
        local fees = BankingDatabase.getBankFees(bank.id)
        
        for _, fee in ipairs(fees) do
            if fee.currency_id == currencyId then
                local newFeeAmount = tonumber(fee.fee_amount) * (1.0 + inflationRate)
                
                BankingDatabase.setBankFee(
                    bank.id,
                    fee.fee_type,
                    fee.fee_type_value,
                    newFeeAmount,
                    fee.currency_id
                )
            end
        end
    end
    
    feeCache = {}
    
    return true
end

return FeeManager

