ShopsDatabase = {}

function ShopsDatabase.getAllShops()
    return exports.postgres:queryAll(
        'SELECT * FROM shops WHERE is_open = true ORDER BY name',
        {}
    )
end

function ShopsDatabase.getShopByName(name)
    return exports.postgres:queryOne(
        'SELECT * FROM shops WHERE name = $1',
        { name }
    )
end

function ShopsDatabase.getShopItems(shopName)
    return exports.postgres:queryAll(
        [[SELECT si.*, i.label, i.weight, i.type
          FROM shop_items si
          JOIN items i ON i.name = si.item_name
          WHERE si.shop_name = $1 AND si.is_available = true
          ORDER BY i.type, i.label]],
        { shopName }
    )
end
