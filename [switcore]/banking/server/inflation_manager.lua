InflationManager = {}

local inflationCache = {}

function InflationManager.calculateInflation(currencyId)
    if not currencyId then
        return nil
    end
    
    local currentMoneySupply = BankingDatabase.calculateTotalMoneySupply(currencyId)
    
    local lastMetric = BankingDatabase.getLatestEconomyMetric('total_money_supply', currencyId)
    
    if not lastMetric then
        BankingDatabase.saveEconomyMetric('total_money_supply', currencyId, currentMoneySupply)
        BankingDatabase.saveEconomyMetric('inflation_rate', currencyId, 0.0)
        
        BankingDatabase.saveInflationHistory(currencyId, 0.0, currentMoneySupply)
        
        return 0.0
    end
    
    local previousMoneySupply = tonumber(lastMetric.value) or 0.0
    
    if previousMoneySupply <= 0 then
        return 0.0
    end
    
    local inflationRate = ((currentMoneySupply - previousMoneySupply) / previousMoneySupply) * 100.0
    
    BankingDatabase.saveEconomyMetric('total_money_supply', currencyId, currentMoneySupply)
    BankingDatabase.saveEconomyMetric('inflation_rate', currencyId, inflationRate)
    
    BankingDatabase.saveInflationHistory(currencyId, inflationRate, currentMoneySupply)
    
    inflationCache[currencyId] = nil
    
    return inflationRate
end

function InflationManager.getInflationRate(currencyId)
    if not currencyId then
        return nil
    end
    
    if inflationCache[currencyId] and inflationCache[currencyId].expiry > os.time() then
        return inflationCache[currencyId].rate
    end
    
    local metric = BankingDatabase.getLatestEconomyMetric('inflation_rate', currencyId)
    
    local rate = 0.0
    if metric then
        rate = tonumber(metric.value) or 0.0
    end
    
    inflationCache[currencyId] = {
        rate = rate,
        expiry = os.time() + 300
    }
    
    return rate
end

function InflationManager.applyInflation()
    if not exports.settings:GetSettingBool('banking.inflation_multiplier_enabled', true) then
        return
    end
    
    local currencies = BankingDatabase.getActiveCurrencies()
    
    for _, currency in ipairs(currencies) do
        local inflationRate = InflationManager.calculateInflation(currency.id)
        
        if inflationRate and inflationRate ~= 0 then
            local inflationDecimal = inflationRate / 100.0
            
            FeeManager.applyInflationToFees(currency.id, inflationDecimal)
            
            InflationManager.applyInflationToAccountInterestRates(currency.id, inflationDecimal)
            
        end
    end
end

function InflationManager.applyInflationToAccountInterestRates(currencyId, inflationRate)
    if not currencyId or not inflationRate then
        return false
    end
    
    local accounts = exports.postgres:queryAll(
        "SELECT * FROM bank_accounts WHERE account_type IN ('savings', 'deposit') AND interest_rate > 0"
    )
    for _, account in ipairs(accounts) do
        local newRate = (tonumber(account.interest_rate) or 0.0) * (1.0 + math.min(inflationRate, 0.5))
        exports.postgres:query(
            'UPDATE bank_accounts SET interest_rate = $1, updated_at = NOW() WHERE id = $2',
            {newRate, account.id}
        )
    end
    
    return true
end

function InflationManager.calculateAccountInterest()
    if not exports.settings:GetSettingBool('banking.auto_calculate_interest', true) then
        return
    end
    
    local accounts = exports.postgres:queryAll(
        "SELECT * FROM bank_accounts WHERE account_type IN ('savings', 'deposit') AND interest_rate > 0 AND (last_interest_calculation IS NULL OR last_interest_calculation < NOW() - INTERVAL '1 hour')"
    )
    for _, account in ipairs(accounts) do
        local balance = BankingHelpers.parseBalance(account.balance)
        
        if balance and next(balance) then
            local interestRate = tonumber(account.interest_rate) or 0.0
            local annualRate = interestRate / 100.0
            local hourlyRate = annualRate / (365 * 24) -- Dobândă pe oră
            
            for currencyIdStr, amount in pairs(balance) do
                local currencyId = tonumber(currencyIdStr)
                local amountNum = tonumber(amount) or 0.0
                
                if amountNum > 0 and currencyId then
                    local interest = amountNum * hourlyRate
                    
                    BankingManager.addAccountBalance(account.id, currencyId, interest)
                    
                    BankingDatabase.createTransaction(
                        account.character_id,
                        'interest',
                        account.id,
                        account.id,
                        interest,
                        currencyId,
                        0.0,
                        nil,
                        Sw.T('banking.tx.interest_desc'),
                        {account_type = account.account_type}
                    )
                end
            end
            
            exports.postgres:query(
                'UPDATE bank_accounts SET last_interest_calculation = NOW() WHERE id = $1',
                {account.id}
            )
        end
    end
end

function InflationManager.getInflationHistory(currencyId, limit)
    if not currencyId then
        return {}
    end
    
    limit = math.max(1, math.min(tonumber(limit) or 30, 1000))
    return exports.postgres:queryAll(
        'SELECT * FROM inflation_history WHERE currency_id = $1 ORDER BY calculated_at DESC LIMIT $2',
        {currencyId, limit}
    )
end

function InflationManager.getTotalMoneySupply(currencyId)
    if not currencyId then
        return 0.0
    end
    
    return BankingDatabase.calculateTotalMoneySupply(currencyId)
end

return InflationManager

