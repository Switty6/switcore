exports('GetShopByName', function(name)
    return ShopsDatabase.getShopByName(name)
end)

exports('GetShopItems', function(shopName)
    return ShopsDatabase.getShopItems(shopName)
end)

exports('BuyItem', function(source, shopName, itemName, quantity, paymentMethod, accountId)
    return ShopManager.buyItem(source, shopName, itemName, quantity, paymentMethod, accountId)
end)
