ShopManager = {}

local function GetCurrencyId(currencyCode)
    local currency = exports.banking:getCurrencyByCode(currencyCode)
    return currency and currency.id or nil
end

function ShopManager.buyItem(source, shopName, itemName, quantity, paymentMethod, accountId)
    local character = exports.characters:getActiveCharacter(source)
    if not character then
        return false, Sw.TP(source, 'shops.character_not_found')
    end
    local characterId = character.id

    quantity = tonumber(quantity) or 1
    local maxQty = exports.settings:GetSettingNumber('shops.max_buy_quantity', 99)
    if quantity < 1 or quantity > maxQty then
        return false, Sw.TP(source, 'shops.invalid_quantity')
    end

    local shop = ShopsDatabase.getShopByName(shopName)
    if not shop or not shop.is_open then
        return false, Sw.TP(source, 'shops.shop_unavailable')
    end

    local items = ShopsDatabase.getShopItems(shopName)
    local shopItem = nil
    for _, si in ipairs(items or {}) do
        if si.item_name == itemName then
            shopItem = si
            break
        end
    end

    if not shopItem then
        return false, Sw.TP(source, 'shops.item_not_found')
    end

    local totalCost = shopItem.price * quantity
    local currencyCode = shopItem.currency_code
    local currencyId = GetCurrencyId(currencyCode)
    if not currencyId then
        return false, Sw.TP(source, 'shops.currency_misconfigured')
    end

    if paymentMethod == 'cash' then
        local cash = exports.banking:getCharacterCash(characterId, currencyId) or 0
        if cash < totalCost then
            return false, Sw.TP(source, 'shops.insufficient_funds')
        end
        exports.banking:addCharacterCash(characterId, currencyId, -totalCost)
    elseif paymentMethod == 'account' then
        accountId = tonumber(accountId)
        if not accountId then
            return false, Sw.TP(source, 'shops.invalid_account')
        end
        local success, err = exports.banking:withdraw(characterId, accountId, totalCost, currencyId)
        if not success then
            return false, err or Sw.TP(source, 'shops.withdrawal_failed')
        end
    else
        return false, Sw.TP(source, 'shops.invalid_payment_method')
    end

    local invId = 'char:' .. characterId
    local added = exports.inventory:AddItem(invId, itemName, quantity)
    if not added then
        if paymentMethod == 'cash' then
            exports.banking:addCharacterCash(characterId, currencyId, totalCost)
        elseif paymentMethod == 'account' then
            exports.banking:deposit(characterId, accountId, totalCost, currencyId)
        end
        return false, Sw.TP(source, 'shops.inventory_full')
    end

    TriggerClientEvent('switcore:notify', source, 'success',
        Sw.TP(source, 'shops.purchase_success', quantity, shopItem.label), 4000)

    pcall(function()
        exports.government:AddIncome(totalCost, currencyCode,
            Sw.T('shops.income.sale_description', shopName), 'Magazine')
    end)

    return true, nil, { totalCost = totalCost, currencyCode = currencyCode }
end
