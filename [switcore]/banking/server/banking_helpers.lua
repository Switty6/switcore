BankingHelpers = {}

function BankingHelpers.validateIds(characterId, accountId, currencyId)
    characterId = tonumber(characterId)
    accountId = tonumber(accountId)
    currencyId = tonumber(currencyId)
    
    if not characterId or characterId <= 0 or 
       not accountId or accountId <= 0 or 
       not currencyId or currencyId <= 0 then
        return false, 'ID-uri invalide'
    end
    
    return true, nil, characterId, accountId, currencyId
end

function BankingHelpers.validateCharacterAndCurrency(characterId, currencyId)
    characterId = tonumber(characterId)
    currencyId = tonumber(currencyId)
    
    if not characterId or characterId <= 0 or not currencyId or currencyId <= 0 then
        return false, 'ID-uri invalide'
    end
    
    return true, nil, characterId, currencyId
end

function BankingHelpers.validateTransactionAmount(amount)
    if not amount or amount <= 0 then
        return false, 'Sumă invalidă'
    end
    
    local minAmount = exports.settings:GetSettingNumber('banking.min_transaction_amount', 0.01)
    local maxAmount = exports.settings:GetSettingNumber('banking.max_transaction_amount', 999999999.99)
    if amount < minAmount or amount > maxAmount then
        return false, string.format('Sumă invalidă (trebuie să fie între %.2f și %.2f)', minAmount, maxAmount)
    end
    
    return true
end

function BankingHelpers.validateAccountOwnership(account, characterId)
    if not account then
        return false, 'Cont nu există'
    end
    
    if account.character_id ~= characterId then
        return false, 'Contul nu aparține caracterului'
    end
    
    return true
end

function BankingHelpers.parseBalance(balance)
    if type(balance) == 'string' then
        local success, decoded = pcall(json.decode, balance)
        if success then
            balance = decoded
        else
            balance = {}
        end
    end
    
    if not balance or type(balance) ~= 'table' then
        balance = {}
    end

    return balance
end

function BankingHelpers.lastDayOfMonth(year, month)
    local daysPerMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 then
        local isLeap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
        if isLeap then
            return 29
        end
    end
    return daysPerMonth[month]
end

-- Avanseaza o data 'YYYY-MM-DD' cu o luna, clampand ziua la ultima zi a lunii
-- noi. Fara clamp, o scadenta pe 31 ar produce date imposibile (ex: 2026-02-31)
-- pe care coloana DATE le respinge, blocand plata creditului.
function BankingHelpers.advanceOneMonth(dateStr)
    local year = tonumber(dateStr:sub(1, 4))
    local month = tonumber(dateStr:sub(6, 7))
    local day = tonumber(dateStr:sub(9, 10))
    if not year or not month or not day then
        return dateStr
    end

    month = month + 1
    if month > 12 then
        month = 1
        year = year + 1
    end

    local maxDay = BankingHelpers.lastDayOfMonth(year, month)
    if day > maxDay then
        day = maxDay
    end

    return string.format('%04d-%02d-%02d', year, month, day)
end

return BankingHelpers
