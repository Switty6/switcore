ShopManager = {}

local function GetCurrencyId(currencyCode)
    local currency = exports.banking:getCurrencyByCode(currencyCode)
    return currency and currency.id or nil
end

function ShopManager.buyItem(source, shopName, itemName, quantity, paymentMethod, accountId)
    local character = exports.characters:getActiveCharacter(source)
    if not character then
        return false, 'Personaj negăsit'
    end
    local characterId = character.id

    quantity = tonumber(quantity) or 1
    local maxQty = exports.settings:GetSettingNumber('shops.max_buy_quantity', 99)
    if quantity < 1 or quantity > maxQty then
        return false, 'Cantitate invalidă'
    end

    local shop = ShopsDatabase.getShopByName(shopName)
    if not shop or not shop.is_open then
        return false, 'Magazin indisponibil'
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
        return false, 'Produs negăsit în acest magazin'
    end

    local totalCost = shopItem.price * quantity
    local currencyCode = shopItem.currency_code
    local currencyId = GetCurrencyId(currencyCode)
    if not currencyId then
        return false, 'Valută configurată incorect'
    end

    if paymentMethod == 'cash' then
        local cash = exports.banking:getCharacterCash(characterId, currencyId) or 0
        if cash < totalCost then
            return false, 'Fonduri insuficiente'
        end
        exports.banking:addCharacterCash(characterId, currencyId, -totalCost)
    elseif paymentMethod == 'account' then
        accountId = tonumber(accountId)
        if not accountId then
            return false, 'Cont invalid'
        end
        local success, err = exports.banking:withdraw(characterId, accountId, totalCost, currencyId)
        if not success then
            return false, err or 'Retragere eșuată'
        end
    else
        return false, 'Metodă de plată invalidă'
    end

    local invId = 'char:' .. characterId
    local added = exports.inventory:AddItem(invId, itemName, quantity)
    if not added then
        if paymentMethod == 'cash' then
            exports.banking:addCharacterCash(characterId, currencyId, totalCost)
        elseif paymentMethod == 'account' then
            exports.banking:deposit(characterId, accountId, totalCost, currencyId)
        end
        return false, 'Inventarul este plin'
    end

    TriggerClientEvent('switcore:notify', source, 'success',
        'Ai cumpărat ' .. quantity .. 'x ' .. shopItem.label, 4000)

    pcall(function()
        exports.government:AddIncome(totalCost, currencyCode,
            'Vanzare magazin: ' .. shopName, 'Magazine')
    end)

    return true, nil, { totalCost = totalCost, currencyCode = currencyCode }
end
