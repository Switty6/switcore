local CLOTH_ITEM_TYPES = {
    {'cloth_mask',        'Mască',            0.10},
    {'cloth_torso',       'Tricou/Bustieră',  0.30},
    {'cloth_legs',        'Pantaloni',        0.30},
    {'cloth_feet',        'Încălțăminte',     0.30},
    {'cloth_accessories', 'Accesoriu',        0.10},
    {'cloth_undershirt',  'Tricou interior',  0.20},
    {'cloth_jacket',      'Jachetă',          0.40},
    {'cloth_bag',         'Geantă/Rucsac',    0.50},
    {'cloth_hat',         'Pălărie',          0.20},
    {'cloth_glasses',     'Ochelari',         0.10},
}

local DEMO_STORES = {
    {
        name        = 'suburban_vinewood',
        label       = 'Suburban - Vinewood',
        type        = 'casual',
        shop_coords  = {x = -13.5,  y = -1105.0, z = 29.8,  heading = 118.0},
        tryon_coords = {x = -25.0,  y = -1122.0, z = 29.8,  heading = 300.0}
    },
    {
        name        = 'ponsonbys',
        label       = 'Ponsonbys - Rockford Hills',
        type        = 'luxury',
        shop_coords  = {x = -707.0, y = -152.0,  z = 37.0,  heading = 120.0},
        tryon_coords = {x = -720.0, y = -165.0,  z = 37.0,  heading = 300.0}
    },
    {
        name        = 'sport_pro',
        label       = 'Sport Pro',
        type        = 'sport',
        shop_coords  = {x = 112.2,  y = -220.0,  z = 54.5,  heading = 250.0},
        tryon_coords = {x = 100.0,  y = -235.0,  z = 54.5,  heading = 70.0}
    },
}

-- {store_name, item_name, label, component_type, component_id, drawable, default_texture, texture_count, price, bonus_slots, bonus_weight}
local DEMO_ITEMS = {
    {'suburban_vinewood', 'cloth_jacket',      'Jachetă Casual Albastră',   'component', 11, 0,  0, 3,  80},
    {'suburban_vinewood', 'cloth_jacket',      'Jachetă Casual Verde',      'component', 11, 1,  0, 3,  90},
    {'suburban_vinewood', 'cloth_jacket',      'Bluza Casual',              'component', 11, 2,  0, 4,  75},
    {'suburban_vinewood', 'cloth_legs',        'Jeans Clasici',             'component',  4, 0,  0, 4,  70},
    {'suburban_vinewood', 'cloth_legs',        'Jeans Slim',                'component',  4, 1,  0, 3,  80},
    {'suburban_vinewood', 'cloth_feet',        'Sneakers Albi',             'component',  6, 1,  0, 3,  60},
    {'suburban_vinewood', 'cloth_feet',        'Sneakers Negri',            'component',  6, 2,  0, 3,  65},
    {'suburban_vinewood', 'cloth_undershirt',  'Tricou Alb',                'component',  8, 0,  0, 5,  40},
    {'suburban_vinewood', 'cloth_undershirt',  'Tricou Negru',              'component',  8, 1,  0, 3,  40},
    {'suburban_vinewood', 'cloth_hat',         'Șapcă Casual',              'prop',        0, 1,  0, 4,  35},
    {'suburban_vinewood', 'cloth_bag',         'Rucsac Casual',             'component',   5, 2,  0, 2, 120, 4, 10.0},
    {'suburban_vinewood', 'cloth_glasses',     'Ochelari de Soare',         'prop',        1, 1,  0, 3,  55},
    {'suburban_vinewood', 'cloth_mask',        'Mască Simplă',              'component',   1, 1,  0, 2,  30},

    {'ponsonbys', 'cloth_jacket',      'Costum Bleumarin',          'component', 11, 3,  0, 2, 450},
    {'ponsonbys', 'cloth_jacket',      'Costum Negru Clasic',       'component', 11, 4,  0, 3, 500},
    {'ponsonbys', 'cloth_jacket',      'Sacou Elegant',             'component', 11, 5,  0, 4, 380},
    {'ponsonbys', 'cloth_legs',        'Pantalon Elegant Negru',    'component',  4, 3,  0, 3, 300},
    {'ponsonbys', 'cloth_legs',        'Pantalon Elegant Gri',      'component',  4, 4,  0, 2, 280},
    {'ponsonbys', 'cloth_feet',        'Pantofi Eleganți Negri',    'component',  6, 3,  0, 2, 350},
    {'ponsonbys', 'cloth_feet',        'Pantofi Eleganți Maro',     'component',  6, 4,  0, 2, 350},
    {'ponsonbys', 'cloth_undershirt',  'Cămașă Albă',               'component',  8, 2,  0, 3, 200},
    {'ponsonbys', 'cloth_accessories', 'Cravată',                   'component',  7, 1,  0, 5, 150},
    {'ponsonbys', 'cloth_glasses',     'Ochelari Lux',              'prop',        1, 2,  0, 3, 250},
    {'ponsonbys', 'cloth_hat',         'Pălărie Elegantă',          'prop',        0, 2,  0, 3, 180},
    {'ponsonbys', 'cloth_bag',         'Servietă Elegantă',         'component',   5, 3,  0, 2, 600, 3,  8.0},

    {'sport_pro', 'cloth_jacket',      'Geacă Sport Roșie',         'component', 11, 6,  0, 4, 160},
    {'sport_pro', 'cloth_jacket',      'Geacă Sport Neagră',        'component', 11, 7,  0, 3, 160},
    {'sport_pro', 'cloth_legs',        'Pantaloni Jogger',           'component',  4, 5,  0, 4, 120},
    {'sport_pro', 'cloth_legs',        'Pantaloni Scurți',           'component',  4, 6,  0, 3, 100},
    {'sport_pro', 'cloth_feet',        'Adidași Running',            'component',  6, 5,  0, 5, 180},
    {'sport_pro', 'cloth_feet',        'Adidași Basketball',         'component',  6, 6,  0, 4, 200},
    {'sport_pro', 'cloth_undershirt',  'Tricou Sport Alb',           'component',  8, 3,  0, 4,  80},
    {'sport_pro', 'cloth_undershirt',  'Tricou Sport Negru',         'component',  8, 4,  0, 3,  80},
    {'sport_pro', 'cloth_hat',         'Bandană Sport',              'prop',        0, 3,  0, 3,  50},
    {'sport_pro', 'cloth_glasses',     'Ochelari Sport',             'prop',        1, 3,  0, 2, 120},
    {'sport_pro', 'cloth_bag',         'Duffle Bag',                 'component',   5, 4,  0, 2, 250, 6, 15.0},
    {'sport_pro', 'cloth_bag',         'Rucsac Sport',               'component',   5, 5,  0, 3, 180, 4, 10.0},
}

local function SeedItemTypes()
    for _, t in ipairs(CLOTH_ITEM_TYPES) do
        exports.postgres:query(
            'INSERT INTO items (name, label, weight, type, usable, stackable) VALUES ($1, $2, $3, $4, TRUE, FALSE) ON CONFLICT (name) DO NOTHING',
            {t[1], t[2], t[3], 'clothing'}
        )
    end
end

local function SeedStores()
    for _, s in ipairs(DEMO_STORES) do
        exports.postgres:query([[
            INSERT INTO clothing_stores (name, label, type, shop_coords, tryon_coords)
            VALUES ($1, $2, $3, $4::jsonb, $5::jsonb)
            ON CONFLICT (name) DO NOTHING
        ]], {s.name, s.label, s.type, json.encode(s.shop_coords), json.encode(s.tryon_coords)})
    end
end

local function SeedItems()
    for _, i in ipairs(DEMO_ITEMS) do
        local bonusSlots  = i[10] or 0
        local bonusWeight = i[11] or 0.0
        exports.postgres:query([[
            INSERT INTO clothing_items
                (store_name, item_name, label, component_type, component_id, drawable, default_texture, texture_count, price, bonus_slots, bonus_weight)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            ON CONFLICT (store_name, component_type, component_id, drawable) DO NOTHING
        ]], {i[1], i[2], i[3], i[4], i[5], i[6], i[7], i[8], i[9], bonusSlots, bonusWeight})
    end
end

local function SeedSettings()
    exports.postgres:query(
        "INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING",
        {'clothing.currency', 'RON', 'Valuta folosita in magazinele de haine'}
    )
end

local function RegisterClothingUsableItems()
    for _, t in ipairs(CLOTH_ITEM_TYPES) do
        local itemName = t[1]
        exports.inventory:RegisterUsableItem(itemName, function(source)
            local character = exports.characters:getActiveCharacter(source)
            if not character then return end

            local invId = 'char:' .. tostring(character.id)
            local inv   = exports.inventory:GetInventory(invId)
            if not inv then return end

            for _, slot in pairs(inv.slots) do
                if slot and slot.name == itemName then
                    local meta = slot.metadata or {}
                    if meta.clothing_item_id then
                        ClothingManager.equipItem(source, character.id, meta.clothing_item_id, meta.texture)
                        return
                    end
                end
            end

            TriggerClientEvent('switcore:notify', source, 'error', 'Articol invalid.', 4000)
        end)
    end
end

RegisterNetEvent('switcore:characterLoaded', function(character)
    if not character or not character.id then return end
    local source = source

    ClothingManager.loadCharacterClothing(character.id, function(equipped)
        TriggerClientEvent('clothing:applyComponents', source, equipped)
        ClothingManager.recalculateBonuses(character.id)
    end)

    ClothingDB.getStores(function(stores)
        if stores then TriggerClientEvent('clothing:receiveStores', source, stores) end
    end)
end)

AddEventHandler('playerDropped', function()
    local character = exports.characters:getActiveCharacter(source)
    if character then
        ClothingManager.clearCache(character.id)
    end
end)

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end

    SeedSettings()
    SeedItemTypes()
    SeedStores()
    SeedItems()
    RegisterClothingUsableItems()
    print('[CLOTHING] Initialized.')
end)
