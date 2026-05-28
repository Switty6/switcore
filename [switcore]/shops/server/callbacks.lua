local function GetCharacterId(source)
    local character = exports.characters:getActiveCharacter(source)
    return character and character.id or nil
end

RegisterNetEvent('shops:server:getShops', function()
    local src = source
    local shops = ShopsDatabase.getAllShops()
    TriggerClientEvent('shops:client:shopsData', src, shops or {})
end)

RegisterNetEvent('shops:server:openShop', function(shopName)
    local src = source
    local characterId = GetCharacterId(src)
    if not characterId then return end

    local shop = ShopsDatabase.getShopByName(shopName)
    if not shop or not shop.is_open then
        TriggerClientEvent('switcore:notify', src, 'error', 'Magazin indisponibil', 3000)
        return
    end

    local items = ShopsDatabase.getShopItems(shopName)

    local accounts = exports.banking:getCharacterAccounts(characterId)
    local accountsData = {}
    if accounts then
        for _, account in ipairs(accounts) do
            local currencies = exports.banking:getActiveCurrencies()
            local currencyId = currencies and currencies[1] and currencies[1].id
            local balance = currencyId and exports.banking:getAccountBalance(account.id, currencyId) or 0
            local bank = exports.banking:getBankById(account.bank_id)
            table.insert(accountsData, {
                id = account.id,
                accountNumber = account.account_number,
                accountType = account.account_type,
                balance = balance,
                bankName = bank and bank.name or 'Bancă'
            })
        end
    end

    local currencies = exports.banking:getActiveCurrencies()
    local defaultCurrencyId = currencies and currencies[1] and currencies[1].id
    local cash = defaultCurrencyId and exports.banking:getCharacterCash(characterId, defaultCurrencyId) or 0

    TriggerClientEvent('shops:client:openShop', src, {
        shop = shop,
        items = items or {},
        cash = cash,
        accounts = accountsData
    })
end)

RegisterNetEvent('shops:server:buyItem', function(data)
    local src = source
    if not data or not data.shopName or not data.itemName then return end

    local quantity = tonumber(data.quantity) or 1
    local paymentMethod = data.paymentMethod or 'cash'
    local accountId = data.accountId

    local success, err, result = ShopManager.buyItem(src, data.shopName, data.itemName, quantity, paymentMethod, accountId)

    TriggerClientEvent('shops:client:buyResult', src, {
        success = success,
        error = err,
        result = result
    })
end)
