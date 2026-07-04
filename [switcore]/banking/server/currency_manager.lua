CurrencyManager = {}

local exchangeRateCache = {}
local cacheExpiry = 300 -- 5 minute

function CurrencyManager.createCurrency(code, name, symbol)
    if not code or not name or not symbol then
        return false, Sw.T('banking.error_invalid_parameters')
    end
    
    local currency = BankingDatabase.createCurrency(code, name, symbol)
    if not currency then
        return false, Sw.T('banking.currency_creation_failed')
    end
    
    exchangeRateCache = {}
    
    return true, nil, currency
end

function CurrencyManager.getCurrencyByCode(code)
    return BankingDatabase.getCurrencyByCode(code)
end

function CurrencyManager.getCurrencyById(currencyId)
    return BankingDatabase.getCurrencyById(currencyId)
end

function CurrencyManager.getActiveCurrencies()
    return BankingDatabase.getActiveCurrencies()
end

function CurrencyManager.setExchangeRate(currencyFromId, currencyToId, rate)
    if not currencyFromId or not currencyToId or not rate then
        return false, Sw.T('banking.error_invalid_parameters')
    end
    
    if currencyFromId == currencyToId then
        return false, Sw.T('banking.exchange_rate_same_currency')
    end
    
    local currencyFrom = BankingDatabase.getCurrencyById(currencyFromId)
    local currencyTo = BankingDatabase.getCurrencyById(currencyToId)
    
    if not currencyFrom or not currencyTo then
        return false, Sw.T('banking.error_currency_not_found')
    end
    
    local success1 = BankingDatabase.addExchangeRate(currencyFromId, currencyToId, rate)
    local success2 = BankingDatabase.addExchangeRate(currencyToId, currencyFromId, 1.0 / rate)
    
    if not success1 or not success2 then
        return false, Sw.T('banking.exchange_rate_save_failed')
    end
    
    exchangeRateCache = {}
    
    return true
end

function CurrencyManager.getExchangeRate(currencyFromId, currencyToId)
    if currencyFromId == currencyToId then
        return 1.0
    end
    
    local cacheKey = currencyFromId .. '_' .. currencyToId
    if exchangeRateCache[cacheKey] and exchangeRateCache[cacheKey].expiry > os.time() then
        return exchangeRateCache[cacheKey].rate
    end
    
    local rate = CurrencyManager.getDirectOrReverseRate(currencyFromId, currencyToId)

    if not rate then
        rate = CurrencyManager.getCrossRate(currencyFromId, currencyToId)
    end

    if not rate then
        print(string.format('[BANKING] Niciun curs de schimb pentru perechea %s -> %s (nici direct, nici invers, nici prin triangulare). Seteaza un curs cu setExchangeRate sau prin setarea banking.default_exchange_rates.', tostring(currencyFromId), tostring(currencyToId)))
    end

    if rate then
        local fluctuation = CurrencyManager.calculateVolumeFluctuation(currencyFromId, currencyToId)
        rate = rate * (1.0 + fluctuation)
        
        exchangeRateCache[cacheKey] = {
            rate = rate,
            expiry = os.time() + cacheExpiry
        }
    end
    
    return rate
end

function CurrencyManager.getDirectOrReverseRate(currencyFromId, currencyToId)
    local rate = CurrencyManager.getLatestExchangeRate(currencyFromId, currencyToId)
    if rate then return rate end

    local reverseRate = CurrencyManager.getLatestExchangeRate(currencyToId, currencyFromId)
    if reverseRate and reverseRate > 0 then
        return 1.0 / reverseRate
    end

    return nil
end

-- Triangulare printr-o valuta pivot cand nu exista curs direct intre cele doua.
function CurrencyManager.getCrossRate(currencyFromId, currencyToId)
    local currencies = BankingDatabase.getActiveCurrencies()
    if not currencies then return nil end

    for _, pivot in ipairs(currencies) do
        if pivot.id ~= currencyFromId and pivot.id ~= currencyToId then
            local fromToPivot = CurrencyManager.getDirectOrReverseRate(currencyFromId, pivot.id)
            local pivotToTo   = CurrencyManager.getDirectOrReverseRate(pivot.id, currencyToId)
            if fromToPivot and pivotToTo then
                return fromToPivot * pivotToTo
            end
        end
    end

    return nil
end

function CurrencyManager.getLatestExchangeRate(currencyFromId, currencyToId)
    local result = exports.postgres:queryOne(
        'SELECT rate FROM currency_exchange_rates WHERE currency_from_id = $1 AND currency_to_id = $2 ORDER BY timestamp DESC LIMIT 1',
        {currencyFromId, currencyToId}
    )
    if result and result.rate then return tonumber(result.rate) end
    return BankingDatabase.getAverageExchangeRate(currencyFromId, currencyToId, 24)
end

function CurrencyManager.calculateVolumeFluctuation(currencyFromId, currencyToId)
    local result = exports.postgres:queryOne(
        [[
            SELECT 
                COUNT(*) as transaction_count,
                COALESCE(SUM(amount), 0) as total_volume
            FROM transactions
            WHERE transaction_type = 'currency_exchange'
            AND currency_id = $1
            AND created_at > NOW() - INTERVAL '24 hours'
        ]],
        {currencyFromId}
    )
    
    if not result then
        return 0.0
    end
    
    local transactionCount = tonumber(result.transaction_count) or 0
    local totalVolume = tonumber(result.total_volume) or 0.0
    
    local maxFluctuation = exports.settings:GetSettingNumber('banking.max_dynamic_exchange_rate_fluctuation', 5.0) / 100.0
    local normalizedVolume = math.min(totalVolume / 1000000.0, 1.0) -- 1M = max
    local fluctuation = (normalizedVolume * maxFluctuation) - (maxFluctuation / 2.0) -- -2.5% to +2.5%
    
    local countFactor = math.min(transactionCount / 100.0, 1.0) -- 100 tranzacții = max
    fluctuation = fluctuation * (0.5 + countFactor * 0.5) -- 50% - 100% din fluctuație
    
    return fluctuation
end

function CurrencyManager.updateDynamicExchangeRate(currencyFromId, currencyToId, transactionAmount)
    local currentRate = CurrencyManager.getExchangeRate(currencyFromId, currencyToId)
    if not currentRate then
        return false
    end
    
    local volumeFactor = math.min(transactionAmount / 10000.0, 1.0) -- 10k = max impact
    local timeFactor = (os.time() % 3600) / 3600.0 -- Factor bazat pe timp (0-1)
    local fluctuation = (timeFactor - 0.5) * 0.01 * volumeFactor -- +/- 0.5% max per tranzacție
    
    local newRate = currentRate * (1.0 + fluctuation)
    
    BankingDatabase.addExchangeRate(currencyFromId, currencyToId, newRate)
    
    local cacheKey = currencyFromId .. '_' .. currencyToId
    exchangeRateCache[cacheKey] = nil
    
    return true
end

function CurrencyManager.exchangeCurrency(amount, currencyFromId, currencyToId)
    if amount <= 0 then
        return false, Sw.T('banking.error_invalid_amount'), 0.0
    end
    
    if currencyFromId == currencyToId then
        return true, nil, amount
    end
    
    local rate = CurrencyManager.getExchangeRate(currencyFromId, currencyToId)
    if not rate then
        return false, Sw.T('banking.exchange_rate_calculation_failed'), 0.0
    end
    
    local convertedAmount = amount * rate
    
    CurrencyManager.updateDynamicExchangeRate(currencyFromId, currencyToId, amount)
    
    return true, nil, convertedAmount
end

function CurrencyManager.getAllExchangeRates(currencyId)
    local currencies = BankingDatabase.getActiveCurrencies()
    local rates = {}
    
    for _, currency in ipairs(currencies) do
        if currency.id ~= currencyId then
            local rate = CurrencyManager.getExchangeRate(currencyId, currency.id)
            if rate then
                rates[currency.id] = {
                    currency = currency,
                    rate = rate
                }
            end
        end
    end
    
    return rates
end

return CurrencyManager
