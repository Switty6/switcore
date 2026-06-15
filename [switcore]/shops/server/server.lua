exports.core:registerModuleLocales(GetCurrentResourceName())

CreateThread(function()
    while not exports.postgres:isReady() do Wait(100) end
    while not exports.settings:IsReady() do Wait(100) end

    print('[SHOPS] PostgreSQL gata, inițializare magazine...')
    InitializeShops()
end)

function InitializeShops()
    exports.postgres:query(
        "INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING",
        { 'shops.default_currency', 'USD', 'Valuta implicită pentru magazine' }
    )
    exports.postgres:query(
        "INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING",
        { 'shops.max_buy_quantity', '99', 'Cantitate maximă per cumpărătură' }
    )

    SeedShops()
    print('[SHOPS] Sistem de magazine inițializat.')
end

function SeedShops()
    local defaultShops = {
        {
            name  = 'shop_247_strawberry',
            label = '24/7 Strawberry',
            type  = 'general',
            coords = { x = -1222.0, y = -908.5, z = 12.3 },
            blip_sprite = 52,
            blip_color  = 2
        },
        {
            name  = 'shop_247_downtown',
            label = '24/7 Downtown LS',
            type  = 'general',
            coords = { x = 25.7, y = -1346.7, z = 29.5 },
            blip_sprite = 52,
            blip_color  = 2
        },
        {
            name  = 'shop_247_sandy',
            label = '24/7 Sandy Shores',
            type  = 'general',
            coords = { x = 1729.0, y = 3724.0, z = 34.2 },
            blip_sprite = 52,
            blip_color  = 2
        },
        {
            name  = 'shop_ammu_davis',
            label = 'Ammu-Nation Davis',
            type  = 'gun',
            coords = { x = -330.2, y = -1297.7, z = 31.2 },
            blip_sprite = 110,
            blip_color  = 1
        },
        {
            name  = 'shop_pharmacy_pillbox',
            label = 'Farmacie Pillbox',
            type  = 'pharmacy',
            coords = { x = 307.8, y = -591.5, z = 43.3 },
            blip_sprite = 58,
            blip_color  = 3
        },
        {
            name  = 'shop_pharmacy_strawberry',
            label = 'Farmacie Strawberry',
            type  = 'pharmacy',
            coords = { x = -1185.4, y = -1565.3, z = 4.6 },
            blip_sprite = 58,
            blip_color  = 3
        },
    }

    for _, shop in ipairs(defaultShops) do
        local coordsJson = json.encode(shop.coords)
        exports.postgres:query(
            [[INSERT INTO shops (name, label, type, coords, blip_sprite, blip_color)
              VALUES ($1, $2, $3, $4::jsonb, $5, $6)
              ON CONFLICT (name) DO NOTHING]],
            { shop.name, shop.label, shop.type, coordsJson, shop.blip_sprite, shop.blip_color }
        )
    end

    SeedShopItems()
end

function SeedShopItems()
    local generalItems = {
        { item = 'water',   price = 2.00  },
        { item = 'bread',   price = 3.00  },
    }

    local gunItems = {
        { item = 'weapon_pistol', price = 500.00 },
        { item = 'ammo_9mm',      price = 1.50   },
    }

    local generalShops = { 'shop_247_strawberry', 'shop_247_downtown', 'shop_247_sandy' }
    for _, shopName in ipairs(generalShops) do
        for _, entry in ipairs(generalItems) do
            exports.postgres:query(
                [[INSERT INTO shop_items (shop_name, item_name, price, currency_code)
                  VALUES ($1, $2, $3, $4)
                  ON CONFLICT (shop_name, item_name) DO NOTHING]],
                { shopName, entry.item, entry.price, 'USD' }
            )
        end
    end

    for _, entry in ipairs(gunItems) do
        exports.postgres:query(
            [[INSERT INTO shop_items (shop_name, item_name, price, currency_code)
              VALUES ($1, $2, $3, $4)
              ON CONFLICT (shop_name, item_name) DO NOTHING]],
            { 'shop_ammu_davis', entry.item, entry.price, 'USD' }
        )
    end

    local pharmacyItems = {
        { item = 'bandage',        price = 8.00   },
        { item = 'painkillers',    price = 15.00  },
        { item = 'vitamins',       price = 12.00  },
        { item = 'medkit',         price = 120.00 },
        { item = 'antidepressants', price = 40.00 },
    }

    local pharmacyShops = { 'shop_pharmacy_pillbox', 'shop_pharmacy_strawberry' }
    for _, shopName in ipairs(pharmacyShops) do
        for _, entry in ipairs(pharmacyItems) do
            exports.postgres:query(
                [[INSERT INTO shop_items (shop_name, item_name, price, currency_code)
                  VALUES ($1, $2, $3, $4)
                  ON CONFLICT (shop_name, item_name) DO NOTHING]],
                { shopName, entry.item, entry.price, 'USD' }
            )
        end
    end
end
