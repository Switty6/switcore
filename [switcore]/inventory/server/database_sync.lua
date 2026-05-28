InventoryDB = {}
local currentItems = {}

function InventoryDB.loadItems()
    local rows = exports.postgres:queryAll('SELECT * FROM items', {})
    currentItems = {}
    if rows then
        for _, item in ipairs(rows) do
            currentItems[item.name] = item
        end
        print('[INVENTORY] Loaded ' .. #rows .. ' item configurations.')
    end
end

function InventoryDB.getItemConfig(itemName)
    return currentItems[itemName]
end

function InventoryDB.getAllItems()
    return currentItems
end

function InventoryDB.loadInventory(inventoryId, callback)
    local rows = exports.postgres:queryAll(
        'SELECT * FROM inventory_items WHERE inventory_id = $1',
        { inventoryId }
    )

    local inventory = {}
    local maxSlots = exports.settings:GetSettingNumber('inventory.max_slots', 40)
    for i = 1, maxSlots do
        inventory[i] = nil
    end

    if rows then
        for _, item in ipairs(rows) do
            local metadata = {}
            if item.metadata then
                if type(item.metadata) == 'string' and item.metadata ~= '' then
                    metadata = json.decode(item.metadata) or {}
                elseif type(item.metadata) == 'table' then
                    metadata = item.metadata
                end
            end

            inventory[item.slot] = {
                id       = item.id,
                name     = item.item_name,
                amount   = item.amount,
                metadata = metadata,
            }
        end
    end

    if callback then callback(inventory) end
    return inventory
end

function InventoryDB.saveSlot(inventoryId, slot, item, callback)
    if not item then
        exports.postgres:query(
            'DELETE FROM inventory_items WHERE inventory_id = $1 AND slot = $2',
            { inventoryId, slot }
        )
        if callback then callback() end
        return
    end

    local metadataStr = json.encode(item.metadata or {})
    if item.id then
        exports.postgres:query(
            'UPDATE inventory_items SET item_name = $1, amount = $2, metadata = $3 WHERE id = $4',
            { item.name, item.amount, metadataStr, item.id }
        )
        if callback then callback() end
    else
        local row = exports.postgres:queryOne(
            'INSERT INTO inventory_items (inventory_id, item_name, amount, slot, metadata) VALUES ($1, $2, $3, $4, $5) RETURNING id',
            { inventoryId, item.name, item.amount, slot, metadataStr }
        )
        if row and row.id then item.id = row.id end
        if callback then callback(row) end
    end
end

function InventoryDB.getBonuses(characterId, callback)
    local row = exports.postgres:queryOne(
        'SELECT bonus_slots, bonus_weight FROM inventory_bonuses WHERE character_id = $1',
        { characterId }
    )
    local result = row or { bonus_slots = 0, bonus_weight = 0.0 }
    if callback then callback(result) end
    return result
end

function InventoryDB.setBonuses(characterId, bonusSlots, bonusWeight, callback)
    exports.postgres:query([[
        INSERT INTO inventory_bonuses (character_id, bonus_slots, bonus_weight)
        VALUES ($1, $2, $3)
        ON CONFLICT (character_id) DO UPDATE SET bonus_slots = $2, bonus_weight = $3
    ]], { characterId, bonusSlots, bonusWeight })
    if callback then callback() end
end

Citizen.CreateThread(function()
    while not exports.postgres:isReady() do Citizen.Wait(200) end
    InventoryDB.loadItems()
end)
