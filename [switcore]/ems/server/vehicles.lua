local emsVehicles = {}

local function IsEMSOnDuty(source)
    local charId = exports.characters:getCharacterId(source)
    if not charId then return false end
    local job = exports.jobs:GetCharacterJob(charId)
    return job and job.name == 'ems' and job.isOnDuty
end

local function BuildBlipsList()
    local list = {}
    for _, v in pairs(emsVehicles) do
        list[#list + 1] = v
    end
    return list
end

Sw.SecureEvent('ems:server:reportVehiclePos', {
    character = true,
    rateLimit = { max = 30, window = 10000 },
    silent = true,
}, function(ctx)
    local src = ctx.source
    if not IsEMSOnDuty(src) then return end

    local plate, coords, model = ctx.args[1], ctx.args[2], ctx.args[3]
    if type(coords) ~= 'table' then return end

    emsVehicles[src] = {
        plate = plate,
        x     = coords.x,
        y     = coords.y,
        z     = coords.z,
        model = model,
    }

    TriggerClientEvent('ems:client:updateEMSBlips', -1, BuildBlipsList())
end)

Sw.SecureEvent('ems:server:getVehicleInventory', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src = ctx.source
    if not IsEMSOnDuty(src) then return end

    local plate = ctx.args[1]
    local items = EmsDB.getVehicleInventory(plate)
    TriggerClientEvent('ems:client:vehicleInventory', src, items, plate)
end)

Sw.SecureEvent('ems:server:stockDefaultInventory', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src = ctx.source
    if not IsEMSOnDuty(src) then return end

    local plate = ctx.args[1]
    local defaultStock = exports.settings:GetSettingJSON('ems.default_stock', {})

    for _, entry in ipairs(defaultStock) do
        local current = EmsDB.getVehicleItemAmount(plate, entry.item)
        if current < entry.amount then
            EmsDB.setVehicleItem(plate, entry.item, entry.amount)
        end
    end

    print(('[EMS] Ambulanta %s aprovizionata cu stoc implicit.'):format(plate))
end)

Sw.SecureEvent('ems:server:takeFromAmbulance', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src    = ctx.source
    local charId = ctx.character.id
    local plate, itemName, qty = ctx.args[1], ctx.args[2], ctx.args[3]

    if not IsEMSOnDuty(src) then return end

    local amount = EmsDB.getVehicleItemAmount(plate, itemName)
    qty = math.max(1, math.min(qty or 1, amount))

    if amount <= 0 then
        TriggerClientEvent('switcore:notify', src, 'warning', Sw.TP(src, 'ems.ambulance_stock_insufficient'), 3000)
        return
    end

    EmsDB.removeVehicleItem(plate, itemName, qty)
    exports.inventory:AddItem(charId, itemName, qty)

    TriggerClientEvent('switcore:notify', src, 'success',
        Sw.TP(src, 'ems.item_taken', qty, itemName), 3000)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if emsVehicles[src] then
        emsVehicles[src] = nil
        TriggerClientEvent('ems:client:updateEMSBlips', -1, BuildBlipsList())
    end
end)
