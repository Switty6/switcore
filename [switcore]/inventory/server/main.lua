local inventories = {}
local usableItems = {}
local invLocks = {}

local function getOwnerSource(invId)
    if type(invId) ~= 'string' then return nil end
    local characterId = tonumber(invId:match('^char:(%d+)$')) or tonumber(invId:match('^keys:(%d+)$'))
    if not characterId then return nil end
    local ok, src = pcall(function()
        return exports.characters:getSourceByCharacterId(characterId)
    end)
    if ok then return src end
    return nil
end

local function notifyInventoryUpdate(invId, inv)
    local src = getOwnerSource(invId)
    if src then
        TriggerClientEvent("switcore:inventoryUpdated", src, invId, inv)
    else
        TriggerClientEvent("switcore:inventoryUpdated", -1, invId, inv)
    end
end

local function withInventoryLock(invId, fn)
    while invLocks[invId] do
        Citizen.Wait(5)
    end
    invLocks[invId] = true
    local results = { pcall(fn) }
    invLocks[invId] = nil
    if not results[1] then
        return false, results[2]
    end
    return table.unpack(results, 2)
end

function GetInventory(invId)
    if not inventories[invId] then return nil end
    return inventories[invId]
end
exports("GetInventory", GetInventory)

exports("LoadInventory", function(invId, cb)
    LoadInventoryData(invId, nil, nil, cb)
end)

exports("ReloadItems", function()
    InventoryDB.loadItems()
end)

local KEYS_MAX_SLOTS  = 100
local KEYS_MAX_WEIGHT = 9999.0

local function isKeyItem(itemName)
    local cfg = InventoryDB.getItemConfig(itemName)
    return cfg and cfg.type == 'key'
end

local function routeInvId(invId, itemName)
    if type(invId) == 'string' and invId:sub(1, 5) == 'char:' and isKeyItem(itemName) then
        return 'keys:' .. invId:sub(6)
    end
    return invId
end

function GetItemConfig(name)
    return InventoryDB.getItemConfig(name)
end
exports("GetItemConfig", GetItemConfig)

function LoadInventoryData(invId, maxWeight, maxSlots, cb)
    if inventories[invId] then
        if cb then cb(inventories[invId]) end
        return
    end

    local isKeysInv = type(invId) == 'string' and invId:sub(1, 5) == 'keys:'
    local characterId = tonumber(string.match(invId, "^char:(%d+)$"))

    local baseWeight, baseSlots
    if isKeysInv then
        baseWeight = maxWeight or KEYS_MAX_WEIGHT
        baseSlots  = maxSlots  or KEYS_MAX_SLOTS
    else
        baseWeight = maxWeight or exports.settings:GetSettingNumber('inventory.max_weight', 30.0)
        baseSlots  = maxSlots  or exports.settings:GetSettingNumber('inventory.max_slots', 40)
    end

    InventoryDB.loadInventory(invId, function(slots)
        if characterId then
            InventoryDB.getBonuses(characterId, function(bonuses)
                inventories[invId] = {
                    id = invId,
                    slots = slots,
                    maxWeight = baseWeight + (tonumber(bonuses.bonus_weight) or 0.0),
                    maxSlots  = baseSlots  + (tonumber(bonuses.bonus_slots)  or 0)
                }
                if cb then cb(inventories[invId]) end
            end)
        else
            inventories[invId] = {
                id = invId,
                slots = slots,
                maxWeight = baseWeight,
                maxSlots  = baseSlots
            }
            if cb then cb(inventories[invId]) end
        end
    end)
end

function GetInventoryTotalWeight(invId)
    local inv = inventories[invId]
    if not inv then return 0.0 end

    local weight = 0.0
    for i=1, inv.maxSlots do
        local slotData = inv.slots[i]
        if slotData then
            local cfg = GetItemConfig(slotData.name)
            if cfg then
                weight = weight + (cfg.weight * slotData.amount)
            end
        end
    end
    return weight
end
exports('GetInventoryTotalWeight', GetInventoryTotalWeight)

function FindFirstEmptySlot(invId)
    local inv = inventories[invId]
    if not inv then return nil end
    
    for i=1, inv.maxSlots do
        if not inv.slots[i] then return i end
    end
    return nil
end

function FindStackableSlot(invId, itemName)
    local inv = inventories[invId]
    if not inv then return nil end

    local cfg = GetItemConfig(itemName)
    if not cfg or not cfg.stackable then return nil end

    for i=1, inv.maxSlots do
        if inv.slots[i] and inv.slots[i].name == itemName then
            return i
        end
    end
    return nil
end

function AddItem(invId, itemName, amount, metadata, targetSlot)
    invId = routeInvId(invId, itemName)
    return withInventoryLock(invId, function()
        local inv = inventories[invId]
        if not inv then return false, "Inventory not loaded" end

        local cfg = GetItemConfig(itemName)
        if not cfg then return false, "Invalid item" end

        amount = tonumber(amount) or 1
        if amount <= 0 then return false, "Invalid amount" end

        local currentWeight = GetInventoryTotalWeight(invId)
        if currentWeight + (cfg.weight * amount) > inv.maxWeight then
            return false, "Inventory too heavy"
        end

        local finalSlot = targetSlot
        if not finalSlot then
            if cfg.stackable then
                finalSlot = FindStackableSlot(invId, itemName)
            end
            if not finalSlot then
                finalSlot = FindFirstEmptySlot(invId)
            end
        end

        if not finalSlot or finalSlot > inv.maxSlots then
            return false, "No inventory space"
        end

        if inv.slots[finalSlot] then
            if inv.slots[finalSlot].name == itemName and cfg.stackable then
                inv.slots[finalSlot].amount = inv.slots[finalSlot].amount + amount
                InventoryDB.saveSlot(invId, finalSlot, inv.slots[finalSlot])
                notifyInventoryUpdate(invId, inv)
                return true, "Added to stack"
            end
            return false, "Slot is occupied"
        end

        inv.slots[finalSlot] = {
            id = nil,
            name = itemName,
            amount = amount,
            metadata = metadata or {}
        }
        InventoryDB.saveSlot(invId, finalSlot, inv.slots[finalSlot])
        notifyInventoryUpdate(invId, inv)
        return true, "Added to slot " .. finalSlot
    end)
end
exports('AddItem', AddItem)

function RemoveItem(invId, itemName, amount, fromSlot)
    invId = routeInvId(invId, itemName)
    return withInventoryLock(invId, function()
        local inv = inventories[invId]
        if not inv then return false, "Inventory not loaded" end

        amount = tonumber(amount) or 1
        if amount <= 0 then return false, "Invalid amount" end

        local function remove(slotIdx, num)
            if inv.slots[slotIdx].amount <= num then
                inv.slots[slotIdx] = nil
            else
                inv.slots[slotIdx].amount = inv.slots[slotIdx].amount - num
            end
            InventoryDB.saveSlot(invId, slotIdx, inv.slots[slotIdx])
        end

        if fromSlot then
            if not inv.slots[fromSlot] or inv.slots[fromSlot].name ~= itemName then return false, "Item not found in slot" end
            if inv.slots[fromSlot].amount < amount then return false, "Not enough items" end
            remove(fromSlot, amount)
            notifyInventoryUpdate(invId, inv)
            return true
        end

        local totalFound = 0
        local slotsFound = {}
        for i=1, inv.maxSlots do
            if inv.slots[i] and inv.slots[i].name == itemName then
                totalFound = totalFound + inv.slots[i].amount
                table.insert(slotsFound, {slot=i, amt=inv.slots[i].amount})
            end
        end

        if totalFound < amount then return false, "Not enough items" end

        local remainingToRemove = amount
        for _, s in ipairs(slotsFound) do
            if remainingToRemove <= 0 then break end
            local toRemove = math.min(s.amt, remainingToRemove)
            remove(s.slot, toRemove)
            remainingToRemove = remainingToRemove - toRemove
        end
        notifyInventoryUpdate(invId, inv)
        return true
    end)
end
exports('RemoveItem', RemoveItem)

function HasItem(invId, itemName, amount)
    invId = routeInvId(invId, itemName)
    local inv = inventories[invId]
    if not inv then return false end
    amount = tonumber(amount) or 1
    local total = 0
    for i = 1, inv.maxSlots do
        if inv.slots[i] and inv.slots[i].name == itemName then
            total = total + inv.slots[i].amount
            if total >= amount then return true end
        end
    end
    return false
end
exports('HasItem', HasItem)

function RegisterUsableItem(name, cb)
    usableItems[name] = cb
end
exports('RegisterUsableItem', RegisterUsableItem)

function UseItem(source, itemName)
    if usableItems[itemName] then
        usableItems[itemName](source, itemName)
        return true
    end
    return false
end

function AddInventoryBonus(characterId, bonusSlots, bonusWeight)
    local invId = 'char:' .. tostring(characterId)
    InventoryDB.getBonuses(characterId, function(current)
        local newSlots  = (tonumber(current.bonus_slots)  or 0)   + (tonumber(bonusSlots)  or 0)
        local newWeight = (tonumber(current.bonus_weight) or 0.0)  + (tonumber(bonusWeight) or 0.0)
        InventoryDB.setBonuses(characterId, newSlots, newWeight, function()
            local inv = inventories[invId]
            if inv then
                inv.maxSlots  = inv.maxSlots  + (tonumber(bonusSlots)  or 0)
                inv.maxWeight = inv.maxWeight + (tonumber(bonusWeight) or 0.0)
            end
        end)
    end)
end
exports('AddInventoryBonus', AddInventoryBonus)

function RemoveInventoryBonus(characterId, bonusSlots, bonusWeight)
    local invId = 'char:' .. tostring(characterId)
    InventoryDB.getBonuses(characterId, function(current)
        local newSlots  = math.max(0,   (tonumber(current.bonus_slots)  or 0)   - (tonumber(bonusSlots)  or 0))
        local newWeight = math.max(0.0, (tonumber(current.bonus_weight) or 0.0)  - (tonumber(bonusWeight) or 0.0))
        InventoryDB.setBonuses(characterId, newSlots, newWeight, function()
            local inv = inventories[invId]
            if inv then
                local base = exports.settings:GetSettingNumber('inventory.max_slots',  40)
                local baseW = exports.settings:GetSettingNumber('inventory.max_weight', 30.0)
                inv.maxSlots  = base  + newSlots
                inv.maxWeight = baseW + newWeight
            end
        end)
    end)
end
exports('RemoveInventoryBonus', RemoveInventoryBonus)

function SetInventoryBonuses(characterId, bonusSlots, bonusWeight)
    local invId = 'char:' .. tostring(characterId)
    local s = tonumber(bonusSlots)  or 0
    local w = tonumber(bonusWeight) or 0.0
    InventoryDB.setBonuses(characterId, s, w, function()
        local inv = inventories[invId]
        if inv then
            local base  = exports.settings:GetSettingNumber('inventory.max_slots',  40)
            local baseW = exports.settings:GetSettingNumber('inventory.max_weight', 30.0)
            inv.maxSlots  = base  + s
            inv.maxWeight = baseW + w
        end
    end)
end
exports('SetInventoryBonuses', SetInventoryBonuses)

local function SendCashUpdate(src, characterId)
    if not src or not characterId then return end
    local ok, cashMap = pcall(function()
        return exports.banking:getCharacterAllCash(characterId)
    end)
    local list = {}
    if ok and type(cashMap) == 'table' then
        for _, entry in pairs(cashMap) do
            table.insert(list, {
                code   = entry.currency_code,
                symbol = entry.currency_symbol,
                amount = tonumber(entry.amount) or 0.0,
            })
        end
    end
    TriggerClientEvent('switcore:inventoryCashUpdate', src, list)
end

RegisterNetEvent('switcore:inventoryRequestCash', function()
    local src = source
    local character = exports.characters:getActiveCharacter(src)
    if not character or not character.id then return end
    SendCashUpdate(src, character.id)
end)

local function buildClientConfig()
    return {
        HotbarSlots          = exports.settings:GetSettingNumber('inventory.hotbar_slots',           5),
        DropInteractionRange = exports.settings:GetSettingNumber('inventory.drop_interaction_range', 2.0),
        DefaultDropProp      = exports.settings:GetSetting('inventory.default_drop_prop', 'prop_paper_bag_01'),
    }
end

local function migrateKeysFor(characterId)
    local charInvId = 'char:' .. tostring(characterId)
    local keysInvId = 'keys:' .. tostring(characterId)

    local ok, keyRows = pcall(function()
        return exports.postgres:queryAll([[
            SELECT ii.id, ii.slot, ii.item_name, ii.amount
            FROM inventory_items ii
            JOIN items i ON i.name = ii.item_name
            WHERE ii.inventory_id = $1 AND i.type = 'key'
            ORDER BY ii.slot
        ]], { charInvId })
    end)
    if not ok or not keyRows or #keyRows == 0 then return end

    local occupied = exports.postgres:queryAll(
        'SELECT slot FROM inventory_items WHERE inventory_id = $1',
        { keysInvId }
    ) or {}
    local taken = {}
    for _, r in ipairs(occupied) do taken[tonumber(r.slot)] = true end

    local moved = 0
    local nextSlot = 1
    for _, row in ipairs(keyRows) do
        while taken[nextSlot] do nextSlot = nextSlot + 1 end
        local okUpd = pcall(function()
            exports.postgres:query(
                'UPDATE inventory_items SET inventory_id = $1, slot = $2 WHERE id = $3',
                { keysInvId, nextSlot, row.id }
            )
        end)
        if okUpd then
            moved = moved + 1
            taken[nextSlot] = true
            nextSlot = nextSlot + 1
        end
    end

    print(('[INVENTORY] Mutate %d/%d chei pentru characterId=%d în %s'):format(moved, #keyRows, characterId, keysInvId))
end

local function sendInventoryInit(src, character)
    if not character or not character.id then return end
    local charInvId = "char:" .. tostring(character.id)
    local keysInvId = "keys:" .. tostring(character.id)

    migrateKeysFor(character.id)

    inventories[charInvId] = nil
    inventories[keysInvId] = nil

    LoadInventoryData(charInvId, nil, nil, function(inv)
        TriggerClientEvent('switcore:inventoryInit', src, charInvId, inv, InventoryDB.getAllItems(), buildClientConfig())
        SendCashUpdate(src, character.id)
    end)
    LoadInventoryData(keysInvId, nil, nil, function(keysInv)
        TriggerClientEvent('switcore:inventoryUpdated', src, keysInvId, keysInv)
    end)
end

RegisterNetEvent('switcore:characterLoaded', function(character)
    if not character or not character.id then return end
    sendInventoryInit(source, character)
end)

local function seedInventorySettings()
    local defaults = {
        { 'inventory.max_weight',           '30.0',                  'Greutate maximă inventar player (kg)' },
        { 'inventory.max_slots',            '40',                    'Slot-uri maxime inventar player' },
        { 'inventory.hotbar_slots',         '5',                     'Numărul de slot-uri din hotbar' },
        { 'inventory.drop_interaction_range','2.0',                  'Distanța de interacțiune pentru pickup drop (metri)' },
        { 'inventory.default_drop_prop',    'prop_paper_bag_01',     'Prop default folosit la drop' },
        { 'inventory.drop_expiry_seconds',  '600',                   'Secunde după care drop-urile dispar automat (0 = dezactivat)' },
    }
    for _, s in ipairs(defaults) do
        pcall(function()
            exports.postgres:query(
                'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
                { s[1], s[2], s[3] }
            )
        end)
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Citizen.CreateThread(function()
        while not exports.postgres:isReady() do Citizen.Wait(200) end
        while not exports.settings:IsReady() do Citizen.Wait(200) end
        Citizen.Wait(1500)

        seedInventorySettings()
        pcall(function() exports.settings:ReloadSettings() end)

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local ok, character = pcall(function()
                return exports.characters:getActiveCharacter(src)
            end)
            if ok and character and character.id then
                sendInventoryInit(src, character)
            end
        end
    end)
end)
