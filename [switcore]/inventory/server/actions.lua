local drops = {}
local dropCounter = 0

CreateThread(function()
    while true do
        Wait(30000)
        local expirySec = exports.settings:GetSettingNumber('inventory.drop_expiry_seconds', 600)
        if expirySec and expirySec > 0 then
            local now = os.time()
            for dropId, dropData in pairs(drops) do
                local createdAt = dropData.createdAt or now
                if (now - createdAt) > expirySec then
                    drops[dropId] = nil
                    TriggerClientEvent('switcore:removePhysicalDrop', -1, dropId)
                end
            end
        end
    end
end)

RegisterNetEvent('switcore:inventoryMoveItem')
AddEventHandler('switcore:inventoryMoveItem', function(fromInvId, toInvId, fromSlot, toSlot, amount)
    local src = source
    local fromInv = GetInventory(fromInvId)
    local toInv = GetInventory(toInvId)

    if not fromInv or not toInv then return end
    local item = fromInv.slots[fromSlot]
    if not item then return end

    amount = tonumber(amount) or item.amount
    if amount > item.amount then amount = item.amount end

    local cfg = GetItemConfig(item.name)
    if not cfg then return end

    local toWeight = exports.inventory:GetInventoryTotalWeight(toInvId)
    if toInvId ~= fromInvId then
        if toWeight + (cfg.weight * amount) > toInv.maxWeight then
            TriggerClientEvent("switcore:showNotification", src, "Inventar prea plin!", "error")
            return
        end
    end

    local targetSlotData = toInv.slots[toSlot]

    if targetSlotData then
        if targetSlotData.name == item.name and cfg.stackable then
            targetSlotData.amount = targetSlotData.amount + amount
            if amount == item.amount then
                fromInv.slots[fromSlot] = nil
                InventoryDB.saveSlot(fromInvId, fromSlot, nil)
            else
                item.amount = item.amount - amount
                InventoryDB.saveSlot(fromInvId, fromSlot, item)
            end
            InventoryDB.saveSlot(toInvId, toSlot, targetSlotData)
        else
            if amount == item.amount then
                if toInvId ~= fromInvId then
                    local targetCfg = GetItemConfig(targetSlotData.name)
                    local targetW = (targetCfg and targetCfg.weight) or 0
                    local currentFromW = exports.inventory:GetInventoryTotalWeight(fromInvId)
                    if (currentFromW - (cfg.weight*amount) + (targetW*targetSlotData.amount)) > fromInv.maxWeight then
                        TriggerClientEvent("switcore:showNotification", src, "Inventarul sursă nu poate susține schimbul de greutate!", "error")
                        return
                    end
                end

                fromInv.slots[fromSlot] = targetSlotData
                toInv.slots[toSlot] = item

                InventoryDB.saveSlot(fromInvId, fromSlot, targetSlotData)
                InventoryDB.saveSlot(toInvId, toSlot, item)
            else
                TriggerClientEvent("switcore:showNotification", src, "Slot ocupat!", "error")
                return
            end
        end
    else
        toInv.slots[toSlot] = {
            id = nil,
            name = item.name,
            amount = amount,
            metadata = item.metadata
        }
        
        if amount == item.amount then
            fromInv.slots[fromSlot] = nil
            InventoryDB.saveSlot(fromInvId, fromSlot, nil)
        else
            fromInv.slots[fromSlot].amount = item.amount - amount
            InventoryDB.saveSlot(fromInvId, fromSlot, fromInv.slots[fromSlot])
        end
        InventoryDB.saveSlot(toInvId, toSlot, toInv.slots[toSlot])
    end

    TriggerClientEvent("switcore:inventoryUpdated", -1, fromInvId, fromInv)
    if fromInvId ~= toInvId then
        TriggerClientEvent("switcore:inventoryUpdated", -1, toInvId, toInv)
    end
end)

RegisterNetEvent('switcore:inventoryUseItem')
AddEventHandler('switcore:inventoryUseItem', function(invId, slot)
    local src = source
    local inv = GetInventory(invId)
    if not inv then return end

    local item = inv.slots[slot]
    if not item then return end

    local cfg = GetItemConfig(item.name)
    if not cfg or not cfg.usable then 
        TriggerClientEvent("switcore:showNotification", src, "Acest item nu se poate folosi.")
        return 
    end

    if exports.inventory:UseItem(src, item.name) then
        if cfg.type == "consumable" then
            exports.inventory:RemoveItem(invId, item.name, 1, slot)
        end
    end
end)

RegisterNetEvent('switcore:inventoryDropItem')
AddEventHandler('switcore:inventoryDropItem', function(invId, slot, amount)
    local src = source
    local inv = GetInventory(invId)
    if not inv then return end

    local item = inv.slots[slot]
    if not item then return end

    amount = tonumber(amount) or item.amount
    if amount > item.amount then amount = item.amount end

    local dropItem = {
        name = item.name,
        amount = amount,
        metadata = item.metadata
    }

    local cfg = GetItemConfig(dropItem.name)
    local dropProp     = cfg and cfg.drop_prop or nil
    local dropAnimDict = cfg and cfg.drop_anim_dict or nil
    local dropAnimName = cfg and cfg.drop_anim_name or nil

    if dropAnimDict and dropAnimName and dropAnimDict ~= '' and dropAnimName ~= '' then
        TriggerClientEvent('switcore:inventoryPlayDropAnim', src, dropAnimDict, dropAnimName)
    end

    local success, res = exports.inventory:RemoveItem(invId, item.name, amount, slot)
    if not success then return end

    dropCounter = dropCounter + 1
    local dropId = "drop_" .. dropCounter

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local dropCoords = vector3(
        coords.x - math.sin(rad) * 0.8,
        coords.y + math.cos(rad) * 0.8,
        coords.z
    )

    drops[dropId] = {
        itemData  = dropItem,
        coords    = dropCoords,
        createdAt = os.time(),
        dropProp  = dropProp,
    }

    local label = ((cfg and cfg.label) or dropItem.name) .. " (x" .. amount .. ")"
    TriggerClientEvent('switcore:createPhysicalDrop', -1, dropId, dropItem.name, label, dropCoords, dropProp)
end)

RegisterNetEvent('switcore:inventoryPickupDrop')
AddEventHandler('switcore:inventoryPickupDrop', function(dropId, targetInvId)
    local src = source
    local drop = drops[dropId]
    if not drop then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    if #(coords - drop.coords) > 5.0 then return end

    local success, msg = exports.inventory:AddItem(targetInvId, drop.itemData.name, drop.itemData.amount, drop.itemData.metadata)
    
    if success then
        drops[dropId] = nil
        TriggerClientEvent('switcore:removePhysicalDrop', -1, dropId)
    else
        TriggerClientEvent("switcore:showNotification", src, msg, "error")
    end
end)

RegisterNetEvent('switcore:inventoryGiveItem')
AddEventHandler('switcore:inventoryGiveItem', function(targetSrc, invId, slot, amount)
    local src = source
    targetSrc = tonumber(targetSrc)
    slot      = tonumber(slot)
    amount    = tonumber(amount) or 1
    if not targetSrc or not invId or not slot or amount <= 0 then return end
    if targetSrc == src then return end

    local srcPed    = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)
    if srcPed == 0 or targetPed == 0 then return end
    if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.5 then
        TriggerClientEvent('switcore:showNotification', src, 'Jucătorul este prea departe.', 'error')
        return
    end

    local inv = GetInventory(invId)
    if not inv or not inv.slots[slot] then return end
    local item = inv.slots[slot]
    if item.amount < amount then amount = item.amount end

    local targetCharacter = exports.characters:getActiveCharacter(targetSrc)
    if not targetCharacter or not targetCharacter.id then
        TriggerClientEvent('switcore:showNotification', src, 'Țintă invalidă.', 'error')
        return
    end

    local targetInvId = 'char:' .. tostring(targetCharacter.id)

    local okAdd, errAdd = exports.inventory:AddItem(targetInvId, item.name, amount, item.metadata)
    if not okAdd then
        TriggerClientEvent('switcore:showNotification', src, 'Eroare: ' .. tostring(errAdd), 'error')
        return
    end

    exports.inventory:RemoveItem(invId, item.name, amount, slot)

    local cfg = GetItemConfig(item.name)
    local label = (cfg and cfg.label) or item.name
    TriggerClientEvent('switcore:notify', src,       'success', ('Ai oferit %dx %s.'):format(amount, label), 3000)
    TriggerClientEvent('switcore:notify', targetSrc, 'success', ('Ai primit %dx %s.'):format(amount, label), 3000)
end)

RegisterNetEvent('switcore:characterLoaded')
AddEventHandler('switcore:characterLoaded', function(character)
    local src = source
    if not character then return end

    for dropId, dropData in pairs(drops) do
        local cfg = GetItemConfig(dropData.itemData.name)
        local label = ((cfg and cfg.label) or dropData.itemData.name) .. " (x" .. dropData.itemData.amount .. ")"
        TriggerClientEvent('switcore:createPhysicalDrop', src, dropId, dropData.itemData.name, label, dropData.coords, dropData.dropProp)
    end
end)
