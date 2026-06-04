local function GetCharacterId(source)
    local character = exports.characters:getActiveCharacter(source)
    return character and character.id or nil
end

Sw.SecureEvent('shops:server:getShops', {
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local shops = ShopsDatabase.getAllShops()
    TriggerClientEvent('shops:client:shopsData', ctx.source, shops or {})
end)

Sw.SecureEvent('shops:server:openShop', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'shopName', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local src         = ctx.source
    local characterId = ctx.character.id
    local shopName    = ctx.args.shopName

    local shop = ShopsDatabase.getShopByName(shopName)
    if not shop or not shop.is_open then
        return ctx.error('Magazin indisponibil', 3000)
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

Sw.SecureEvent('shops:server:buyItem', {
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'data', type = 'table' },
    },
}, function(ctx)
    local src  = ctx.source
    local data = ctx.args.data
    if not data.shopName or not data.itemName then return end

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
