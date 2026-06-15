local drops = {}
local dropCounter = 0

-- Sistemul foloseste doar inventare char:<id> si keys:<id>, iar un jucator
-- poate accesa prin aceste net events DOAR inventarele propriului personaj activ.
-- (Containerele secundare gen portbagaj/stash nu trec prin aceste evenimente.)
-- Previne ca un client modificat sa trimita un invId arbitrar (ex. char:<alt_id>)
-- pentru a manipula inventarul altui jucator.
local function ownsInventory(characterId, invId)
    if type(invId) ~= 'string' then return false end
    local invCharId = tonumber(invId:match('^char:(%d+)$')) or tonumber(invId:match('^keys:(%d+)$'))
    return invCharId ~= nil and invCharId == characterId
end

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

Sw.SecureEvent('switcore:inventoryMoveItem', {
    character = true,
    rateLimit = { max = 40, window = 3000 },
    args = {
        { name = 'fromInvId', type = 'string', minLen = 1, maxLen = 64 },
        { name = 'toInvId',   type = 'string', minLen = 1, maxLen = 64 },
        { name = 'fromSlot',  type = 'int', min = 1 },
        { name = 'toSlot',    type = 'int', min = 1 },
        { name = 'amount',    type = 'int', min = 1, optional = true },
    },
}, function(ctx)
    local src = ctx.source
    local fromInvId, toInvId = ctx.args.fromInvId, ctx.args.toInvId
    local fromSlot, toSlot   = ctx.args.fromSlot, ctx.args.toSlot
    if not ownsInventory(ctx.character.id, fromInvId) or not ownsInventory(ctx.character.id, toInvId) then return end
    local fromInv = GetInventory(fromInvId)
    local toInv = GetInventory(toInvId)

    if not fromInv or not toInv then return end
    local item = fromInv.slots[fromSlot]
    if not item then return end

    local amount = ctx.args.amount or item.amount
    if amount > item.amount then amount = item.amount end

    local cfg = GetItemConfig(item.name)
    if not cfg then return end

    local toWeight = exports.inventory:GetInventoryTotalWeight(toInvId)
    if toInvId ~= fromInvId then
        if toWeight + (cfg.weight * amount) > toInv.maxWeight then
            TriggerClientEvent("switcore:showNotification", src, Sw.TP(src, 'inventory.notify.inventory_too_full'), "error")
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
                        TriggerClientEvent("switcore:showNotification", src, Sw.TP(src, 'inventory.notify.source_weight_cannot_support'), "error")
                        return
                    end
                end

                fromInv.slots[fromSlot] = targetSlotData
                toInv.slots[toSlot] = item

                InventoryDB.saveSlot(fromInvId, fromSlot, targetSlotData)
                InventoryDB.saveSlot(toInvId, toSlot, item)
            else
                TriggerClientEvent("switcore:showNotification", src, Sw.TP(src, 'inventory.notify.slot_occupied'), "error")
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

Sw.SecureEvent('switcore:inventoryUseItem', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'invId', type = 'string', minLen = 1, maxLen = 64 },
        { name = 'slot',  type = 'int', min = 1 },
    },
}, function(ctx)
    local src = ctx.source
    local invId, slot = ctx.args.invId, ctx.args.slot
    if not ownsInventory(ctx.character.id, invId) then return end
    local inv = GetInventory(invId)
    if not inv then return end

    local item = inv.slots[slot]
    if not item then return end

    local cfg = GetItemConfig(item.name)
    if not cfg or not cfg.usable then
        TriggerClientEvent("switcore:showNotification", src, Sw.TP(src, 'inventory.notify.item_not_usable'))
        return
    end

    if exports.inventory:UseItem(src, item.name) then
        if cfg.type == "consumable" then
            exports.inventory:RemoveItem(invId, item.name, 1, slot)
        end
    end
end)

Sw.SecureEvent('switcore:inventoryDropItem', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'invId',  type = 'string', minLen = 1, maxLen = 64 },
        { name = 'slot',   type = 'int', min = 1 },
        { name = 'amount', type = 'int', min = 1, optional = true },
    },
}, function(ctx)
    local src = ctx.source
    local invId, slot = ctx.args.invId, ctx.args.slot
    if not ownsInventory(ctx.character.id, invId) then return end
    local inv = GetInventory(invId)
    if not inv then return end

    local item = inv.slots[slot]
    if not item then return end

    local amount = ctx.args.amount or item.amount
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

Sw.SecureEvent('switcore:inventoryPickupDrop', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'dropId',      type = 'string', minLen = 1, maxLen = 64 },
        { name = 'targetInvId', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local src = ctx.source
    local drop = drops[ctx.args.dropId]
    if not drop then return end
    if not ownsInventory(ctx.character.id, ctx.args.targetInvId) then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    if #(coords - drop.coords) > 5.0 then return end

    local success, msg = exports.inventory:AddItem(ctx.args.targetInvId, drop.itemData.name, drop.itemData.amount, drop.itemData.metadata)

    if success then
        drops[ctx.args.dropId] = nil
        TriggerClientEvent('switcore:removePhysicalDrop', -1, ctx.args.dropId)
    else
        TriggerClientEvent("switcore:showNotification", src, msg, "error")
    end
end)

Sw.SecureEvent('switcore:inventoryGiveItem', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'targetSrc', type = 'int', min = 1 },
        { name = 'invId',     type = 'string', minLen = 1, maxLen = 64 },
        { name = 'slot',      type = 'int', min = 1 },
        { name = 'amount',    type = 'int', min = 1, optional = true, default = 1 },
    },
}, function(ctx)
    local src = ctx.source
    local targetSrc = ctx.args.targetSrc
    local invId     = ctx.args.invId
    local slot      = ctx.args.slot
    local amount    = ctx.args.amount
    if targetSrc == src then return end
    if not ownsInventory(ctx.character.id, invId) then return end

    local srcPed    = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)
    if srcPed == 0 or targetPed == 0 then return end
    if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.5 then
        TriggerClientEvent('switcore:showNotification', src, Sw.TP(src, 'inventory.notify.player_too_far'), 'error')
        return
    end

    local inv = GetInventory(invId)
    if not inv or not inv.slots[slot] then return end
    local item = inv.slots[slot]
    if item.amount < amount then amount = item.amount end

    local targetCharacter = exports.characters:getActiveCharacter(targetSrc)
    if not targetCharacter or not targetCharacter.id then
        TriggerClientEvent('switcore:showNotification', src, Sw.TP(src, 'inventory.notify.invalid_target'), 'error')
        return
    end

    local targetInvId = 'char:' .. tostring(targetCharacter.id)

    local okAdd, errAdd = exports.inventory:AddItem(targetInvId, item.name, amount, item.metadata)
    if not okAdd then
        TriggerClientEvent('switcore:showNotification', src, Sw.TP(src, 'inventory.notify.give_error', tostring(errAdd)), 'error')
        return
    end

    exports.inventory:RemoveItem(invId, item.name, amount, slot)

    local cfg = GetItemConfig(item.name)
    local label = (cfg and cfg.label) or item.name
    TriggerClientEvent('switcore:notify', src,       'success', Sw.TP(src, 'inventory.notify.gave_item', amount, label), 3000)
    TriggerClientEvent('switcore:notify', targetSrc, 'success', Sw.TP(targetSrc, 'inventory.notify.received_item', amount, label), 3000)
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
