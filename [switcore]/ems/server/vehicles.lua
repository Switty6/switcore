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

RegisterNetEvent('ems:server:reportVehiclePos')
AddEventHandler('ems:server:reportVehiclePos', function(plate, coords, model)
    local src = source
    if not IsEMSOnDuty(src) then return end

    emsVehicles[src] = {
        plate = plate,
        x     = coords.x,
        y     = coords.y,
        z     = coords.z,
        model = model,
    }

    TriggerClientEvent('ems:client:updateEMSBlips', -1, BuildBlipsList())
end)

RegisterNetEvent('ems:server:getVehicleInventory')
AddEventHandler('ems:server:getVehicleInventory', function(plate)
    local src = source
    if not IsEMSOnDuty(src) then return end

    local items = EmsDB.getVehicleInventory(plate)
    TriggerClientEvent('ems:client:vehicleInventory', src, items, plate)
end)

RegisterNetEvent('ems:server:stockDefaultInventory')
AddEventHandler('ems:server:stockDefaultInventory', function(plate)
    local src = source
    if not IsEMSOnDuty(src) then return end

    local defaultStock = exports.settings:GetSettingJSON('ems.default_stock', {})

    for _, entry in ipairs(defaultStock) do
        local current = EmsDB.getVehicleItemAmount(plate, entry.item)
        if current < entry.amount then
            EmsDB.setVehicleItem(plate, entry.item, entry.amount)
        end
    end

    print(('[EMS] Ambulanta %s aprovizionata cu stoc implicit.'):format(plate))
end)

RegisterNetEvent('ems:server:takeFromAmbulance')
AddEventHandler('ems:server:takeFromAmbulance', function(plate, itemName, qty)
    local src    = source
    local charId = exports.characters:getCharacterId(src)
    if not charId then return end

    if not IsEMSOnDuty(src) then return end

    local amount = EmsDB.getVehicleItemAmount(plate, itemName)
    qty = math.max(1, math.min(qty or 1, amount))

    if amount <= 0 then
        TriggerClientEvent('switcore:notify', src, 'warning', 'Stoc insuficient in ambulanta.', 3000)
        return
    end

    EmsDB.removeVehicleItem(plate, itemName, qty)
    exports.inventory:AddItem(charId, itemName, qty)

    TriggerClientEvent('switcore:notify', src, 'success',
        qty .. 'x ' .. itemName .. ' luat din ambulanta.', 3000)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if emsVehicles[src] then
        emsVehicles[src] = nil
        TriggerClientEvent('ems:client:updateEMSBlips', -1, BuildBlipsList())
    end
end)
