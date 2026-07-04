-- Portbagaj / torpedou (glovebox) per vehicul. Fiecare vehicul are propriile
-- inventare trunk:<plate>/glove:<plate>, persistate ca orice alt inventar
-- (inventory_items nu are schema fixa pe inventory_id). Accesul se acorda
-- doar dupa ce verificam ca jucatorul are cheia vehiculului.
local STORAGE_CAPACITY = {
    trunk = { weight = 40.0, slots = 20 },
    glove = { weight = 5.0,  slots = 5  },
}

Sw.SecureEvent('vehicles:server:openVehicleStorage', {
    character = true,
    rateLimit = { max = 15, window = 5000 },
    args = {
        { name = 'plate',       type = 'string', minLen = 1, maxLen = 16 },
        { name = 'storageType', type = 'string', minLen = 1, maxLen = 10 },
    },
}, function(ctx)
    local src         = ctx.source
    local characterId = ctx.character.id
    local plate       = ctx.args.plate:gsub('%s+', '')
    local storageType = ctx.args.storageType

    local cap = STORAGE_CAPACITY[storageType]
    if not cap then return end

    local vehicle = VehiclesDatabase.getOwnedVehicleByPlate(plate)
    if not vehicle then return end

    if not KeysManager.hasKey(vehicle.id, characterId) then
        TriggerClientEvent('switcore:notify', src, 'error', Sw.TP(src, 'vehicles.trunk_locked'), 3000)
        return
    end

    local invId = storageType .. ':' .. plate
    exports.inventory:GrantInventoryAccess(characterId, invId)
    exports.inventory:LoadInventoryWithCapacity(invId, cap.weight, cap.slots, function(inv)
        TriggerClientEvent('switcore:inventoryUpdated', src, invId, inv)
        TriggerClientEvent('vehicles:client:openVehicleStorage', src, invId)
    end)
end)
