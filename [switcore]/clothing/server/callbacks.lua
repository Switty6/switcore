local function GetCurrencyId(currencyCode)
    local currency = exports.banking:getCurrencyByCode(currencyCode)
    return currency and currency.id or nil
end

Sw.SecureEvent('clothing:getStoreData', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'storeName', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local character = ctx.character
    local storeName = ctx.args.storeName

    local gender = tonumber(character.appearance and character.appearance.gender) or -1
    local characterId = character.id
    local invId       = 'char:' .. tostring(characterId)

    ClothingDB.getStoreItems(storeName, gender, function(items)
        local ownedItemIds = {}
        local inv = exports.inventory:GetInventory(invId)
        if inv then
            for _, slot in pairs(inv.slots) do
                if slot and slot.metadata and slot.metadata.clothing_item_id then
                    ownedItemIds[tostring(slot.metadata.clothing_item_id)] = true
                end
            end
        end

        local equipped = ClothingManager.getEquipped(characterId)

        TriggerClientEvent('clothing:receiveStoreData', ctx.source, items, storeName, ownedItemIds, equipped)
    end)
end)

Sw.SecureEvent('clothing:buyItem', {
    character = true,
    rateLimit = { max = 5, window = 2000 },
    args = {
        { name = 'storeItemId', type = 'int', min = 1 },
        { name = 'texture',     type = 'int', min = 0, optional = true },
    },
}, function(ctx)
    local character   = ctx.character
    local storeItemId = ctx.args.storeItemId
    local texture     = ctx.args.texture

    ClothingDB.getItemById(storeItemId, function(item)
        if not item then
            return ctx.error(Sw.TP(ctx.source, 'clothing.item_not_found'))
        end

        local characterId = character.id
        local invId       = 'char:' .. tostring(characterId)

        local inv = exports.inventory:GetInventory(invId)
        if inv then
            for _, slot in pairs(inv.slots) do
                if slot and slot.name == item.item_name then
                    local meta = slot.metadata or {}
                    if tonumber(meta.clothing_item_id) == storeItemId then
                        return ctx.error(Sw.TP(ctx.source, 'clothing.item_already_owned'))
                    end
                end
            end
        end

        local currencyCode = exports.settings:GetSetting('clothing.currency', 'RON')
        local currencyId   = GetCurrencyId(currencyCode)
        if not currencyId then
            return ctx.error(Sw.TP(ctx.source, 'clothing.currency_config_error'))
        end

        local price = tonumber(item.price) or 0
        local cash  = exports.banking:getCharacterCash(characterId, currencyId) or 0

        if cash < price then
            return ctx.error(Sw.TP(ctx.source, 'clothing.insufficient_funds', price, currencyCode))
        end

        exports.banking:addCharacterCash(characterId, currencyId, -price)

        local finalTexture = texture or tonumber(item.default_texture) or 0
        local metadata = {
            clothing_item_id = storeItemId,
            component_type   = item.component_type,
            component_id     = tonumber(item.component_id),
            drawable         = tonumber(item.drawable),
            texture          = finalTexture,
            texture_count    = tonumber(item.texture_count) or 1,
            label            = item.label,
            store_name       = item.store_name,
            bonus_slots      = tonumber(item.bonus_slots)  or 0,
            bonus_weight     = tonumber(item.bonus_weight) or 0.0
        }

        local success, msg = exports.inventory:AddItem(invId, item.item_name, 1, metadata)
        if success then
            ctx.success(Sw.TP(ctx.source, 'clothing.item_bought', item.label), 5000)
            local updatedInv = exports.inventory:GetInventory(invId)
            if updatedInv then
                TriggerClientEvent('switcore:inventoryUpdated', ctx.source, invId, updatedInv)
                TriggerClientEvent('clothing:itemPurchased', ctx.source, storeItemId)
            end
        else
            exports.banking:addCharacterCash(characterId, currencyId, price)
            ctx.error(Sw.TP(ctx.source, 'clothing.inventory_full', msg or ''))
        end
    end)
end)

Sw.SecureEvent('clothing:equipItem', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'storeItemId', type = 'int', min = 1 },
        { name = 'texture',     type = 'int', min = 0, optional = true },
    },
}, function(ctx)
    ClothingManager.equipItem(ctx.source, ctx.character.id, ctx.args.storeItemId, ctx.args.texture)
end)

Sw.SecureEvent('clothing:unequipItem', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'componentType', type = 'string', minLen = 1, maxLen = 32 },
        { name = 'componentId',   type = 'int' },
    },
}, function(ctx)
    ClothingManager.unequipItem(ctx.source, ctx.character.id, ctx.args.componentType, ctx.args.componentId)
end)

Sw.SecureEvent('clothing:getOutfits', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    ClothingDB.getOutfits(ctx.character.id, function(outfits)
        TriggerClientEvent('clothing:receiveOutfits', ctx.source, outfits)
    end)
end)

Sw.SecureEvent('clothing:saveOutfit', {
    character = true,
    rateLimit = { max = 5, window = 2000 },
    args = {
        { name = 'name', type = 'string', minLen = 1, maxLen = 50 },
    },
}, function(ctx)
    local character = ctx.character
    local name = ctx.args.name

    local equipped = ClothingManager.getEquipped(character.id)
    ClothingDB.saveOutfit(character.id, name, equipped, function()
        ctx.success(Sw.TP(ctx.source, 'clothing.outfit_saved', name))
        ClothingDB.getOutfits(character.id, function(outfits)
            TriggerClientEvent('clothing:receiveOutfits', ctx.source, outfits)
        end)
    end)
end)

Sw.SecureEvent('clothing:loadOutfit', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'outfitId', type = 'int', min = 1 },
    },
}, function(ctx)
    local character = ctx.character

    ClothingDB.getOutfitById(ctx.args.outfitId, character.id, function(outfit)
        if not outfit then
            return ctx.error(Sw.TP(ctx.source, 'clothing.outfit_not_found'))
        end

        local components = outfit.components
        if type(components) == 'string' then components = json.decode(components) or {} end

        ClothingManager.setEquipped(character.id, components)
        ClothingManager.recalculateBonuses(character.id)
        ClothingDB.saveEquippedClothing(character.id, components)
        TriggerClientEvent('clothing:applyComponents', ctx.source, components)
        ctx.success(Sw.TP(ctx.source, 'clothing.outfit_applied', outfit.name))
    end)
end)

Sw.SecureEvent('clothing:deleteOutfit', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'outfitId', type = 'int', min = 1 },
    },
}, function(ctx)
    local character = ctx.character

    ClothingDB.deleteOutfit(character.id, ctx.args.outfitId, function()
        ctx.success(Sw.TP(ctx.source, 'clothing.outfit_deleted'))
        ClothingDB.getOutfits(character.id, function(outfits)
            TriggerClientEvent('clothing:receiveOutfits', ctx.source, outfits)
        end)
    end)
end)
