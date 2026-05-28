local function GetCurrencyId(currencyCode)
    local currency = exports.banking:getCurrencyByCode(currencyCode)
    return currency and currency.id or nil
end

RegisterNetEvent('clothing:getStoreData', function(storeName)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

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

        TriggerClientEvent('clothing:receiveStoreData', source, items, storeName, ownedItemIds, equipped)
    end)
end)

RegisterNetEvent('clothing:buyItem', function(storeItemId, texture)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    storeItemId = tonumber(storeItemId)
    if not storeItemId then return end

    ClothingDB.getItemById(storeItemId, function(item)
        if not item then
            TriggerClientEvent('switcore:notify', source, 'error', 'Articolul nu există.', 4000)
            return
        end

        local characterId = character.id
        local invId       = 'char:' .. tostring(characterId)

        local inv = exports.inventory:GetInventory(invId)
        if inv then
            for _, slot in pairs(inv.slots) do
                if slot and slot.name == item.item_name then
                    local meta = slot.metadata or {}
                    if tonumber(meta.clothing_item_id) == storeItemId then
                        TriggerClientEvent('switcore:notify', source, 'error', 'Deja deții acest articol.', 4000)
                        return
                    end
                end
            end
        end

        local currencyCode = exports.settings:GetSetting('clothing.currency', 'RON')
        local currencyId   = GetCurrencyId(currencyCode)
        if not currencyId then
            TriggerClientEvent('switcore:notify', source, 'error', 'Eroare configurare valută.', 4000)
            return
        end

        local price = tonumber(item.price) or 0
        local cash  = exports.banking:getCharacterCash(characterId, currencyId) or 0

        if cash < price then
            TriggerClientEvent('switcore:notify', source, 'error',
                string.format('Nu ai suficienți bani. Necesar: %d %s', price, currencyCode), 4000)
            return
        end

        exports.banking:addCharacterCash(characterId, currencyId, -price)

        local finalTexture = tonumber(texture) or tonumber(item.default_texture) or 0
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
            TriggerClientEvent('switcore:notify', source, 'success', 'Ai cumpărat: ' .. item.label, 5000)
            local updatedInv = exports.inventory:GetInventory(invId)
            if updatedInv then
                TriggerClientEvent('switcore:inventoryUpdated', source, invId, updatedInv)
                TriggerClientEvent('clothing:itemPurchased', source, storeItemId)
            end
        else
            exports.banking:addCharacterCash(characterId, currencyId, price)
            TriggerClientEvent('switcore:notify', source, 'error', 'Inventarul e plin: ' .. (msg or ''), 4000)
        end
    end)
end)

RegisterNetEvent('clothing:equipItem', function(storeItemId, texture)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    ClothingManager.equipItem(source, character.id, tonumber(storeItemId), texture)
end)

RegisterNetEvent('clothing:unequipItem', function(componentType, componentId)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    ClothingManager.unequipItem(source, character.id, componentType, tonumber(componentId))
end)

RegisterNetEvent('clothing:getOutfits', function()
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    ClothingDB.getOutfits(character.id, function(outfits)
        TriggerClientEvent('clothing:receiveOutfits', source, outfits)
    end)
end)

RegisterNetEvent('clothing:saveOutfit', function(name)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    name = tostring(name or ''):sub(1, 50)
    if #name < 1 then
        TriggerClientEvent('switcore:notify', source, 'error', 'Nume invalid.', 4000)
        return
    end

    local equipped = ClothingManager.getEquipped(character.id)
    ClothingDB.saveOutfit(character.id, name, equipped, function()
        TriggerClientEvent('switcore:notify', source, 'success', 'Outfit salvat: ' .. name, 4000)
        ClothingDB.getOutfits(character.id, function(outfits)
            TriggerClientEvent('clothing:receiveOutfits', source, outfits)
        end)
    end)
end)

RegisterNetEvent('clothing:loadOutfit', function(outfitId)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    ClothingDB.getOutfitById(tonumber(outfitId), character.id, function(outfit)
        if not outfit then
            TriggerClientEvent('switcore:notify', source, 'error', 'Outfit inexistent.', 4000)
            return
        end

        local components = outfit.components
        if type(components) == 'string' then components = json.decode(components) or {} end

        ClothingManager.setEquipped(character.id, components)
        ClothingManager.recalculateBonuses(character.id)
        ClothingDB.saveEquippedClothing(character.id, components)
        TriggerClientEvent('clothing:applyComponents', source, components)
        TriggerClientEvent('switcore:notify', source, 'success', 'Outfit aplicat: ' .. outfit.name, 4000)
    end)
end)

RegisterNetEvent('clothing:deleteOutfit', function(outfitId)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    ClothingDB.deleteOutfit(character.id, tonumber(outfitId), function()
        TriggerClientEvent('switcore:notify', source, 'success', 'Outfit șters.', 4000)
        ClothingDB.getOutfits(character.id, function(outfits)
            TriggerClientEvent('clothing:receiveOutfits', source, outfits)
        end)
    end)
end)
