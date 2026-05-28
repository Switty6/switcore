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

return BankingHelpers
