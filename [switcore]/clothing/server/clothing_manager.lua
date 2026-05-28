ClothingManager = {}

local equippedCache = {}

local function removeBonus(characterId, comp)
    local bs = tonumber(comp.bonus_slots)  or 0
    local bw = tonumber(comp.bonus_weight) or 0.0
    if bs > 0 or bw > 0 then
        exports.inventory:RemoveInventoryBonus(characterId, bs, bw)
    end
end

function ClothingManager.loadCharacterClothing(characterId, callback)
    if equippedCache[characterId] then
        if callback then callback(equippedCache[characterId]) end
        return
    end

    ClothingDB.getEquippedClothing(characterId, function(components)
        equippedCache[characterId] = components or {}
        if callback then callback(equippedCache[characterId]) end
    end)
end

function ClothingManager.getEquipped(characterId)
    return equippedCache[characterId] or {}
end

function ClothingManager.setEquipped(characterId, components)
    equippedCache[characterId] = components or {}
end

function ClothingManager.clearCache(characterId)
    equippedCache[characterId] = nil
end

function ClothingManager.recalculateBonuses(characterId)
    local equipped = equippedCache[characterId] or {}
    local totalSlots  = 0
    local totalWeight = 0.0

    for _, comp in pairs(equipped) do
        totalSlots  = totalSlots  + (tonumber(comp.bonus_slots)  or 0)
        totalWeight = totalWeight + (tonumber(comp.bonus_weight) or 0.0)
    end

    exports.inventory:SetInventoryBonuses(characterId, totalSlots, totalWeight)
end

function ClothingManager.equipItem(source, characterId, storeItemId, texture)
    ClothingDB.getItemById(storeItemId, function(item)
        if not item then return end

        local invId       = 'char:' .. tostring(characterId)
        local componentKey = item.component_type .. '_' .. item.component_id

        local inv = exports.inventory:GetInventory(invId)
        if not inv then return end

        local owned = false
        for _, slot in pairs(inv.slots) do
            if slot and slot.name == item.item_name then
                local meta = slot.metadata or {}
                if tonumber(meta.clothing_item_id) == tonumber(storeItemId) then
                    owned = true
                    break
                end
            end
        end

        if not owned then
            TriggerClientEvent('switcore:notify', source, 'error', 'Nu deții acest articol.', 4000)
            return
        end

        local equipped = equippedCache[characterId] or {}

        local prev = equipped[componentKey]
        if prev then removeBonus(characterId, prev) end

        local finalTexture = tonumber(texture) or tonumber(item.default_texture) or 0

        equipped[componentKey] = {
            item_name      = item.item_name,
            clothing_item_id = tonumber(storeItemId),
            component_type = item.component_type,
            component_id   = tonumber(item.component_id),
            drawable       = tonumber(item.drawable),
            texture        = finalTexture,
            bonus_slots    = tonumber(item.bonus_slots)  or 0,
            bonus_weight   = tonumber(item.bonus_weight) or 0.0,
            label          = item.label
        }
        equippedCache[characterId] = equipped

        local bs = tonumber(item.bonus_slots)  or 0
        local bw = tonumber(item.bonus_weight) or 0.0
        if bs > 0 or bw > 0 then
            exports.inventory:AddInventoryBonus(characterId, bs, bw)
        end

        ClothingDB.saveEquippedClothing(characterId, equipped)
        TriggerClientEvent('clothing:applyComponents', source, equipped)
        TriggerClientEvent('switcore:notify', source, 'success', 'Ai echipat: ' .. item.label, 4000)
    end)
end

function ClothingManager.unequipItem(source, characterId, componentType, componentId)
    local equipped     = equippedCache[characterId] or {}
    local componentKey = componentType .. '_' .. tostring(componentId)
    local prev         = equipped[componentKey]

    if not prev then
        TriggerClientEvent('switcore:notify', source, 'error', 'Nu ai nimic echipat pe acel slot.', 4000)
        return
    end

    removeBonus(characterId, prev)

    equipped[componentKey] = nil
    equippedCache[characterId] = equipped

    ClothingDB.saveEquippedClothing(characterId, equipped)
    TriggerClientEvent('clothing:applyComponents', source, equipped)
    TriggerClientEvent('switcore:notify', source, 'info', 'Ai dezechipat: ' .. (prev.label or 'articolul'), 4000)
end
