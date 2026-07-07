
KeysManager = {}

local function removeKeyFromInventory(inventoryId, vehicleId)
    local inv = exports.inventory:GetInventory(inventoryId)
    if not inv or not inv.slots then return end
    for slotIdx, slotData in pairs(inv.slots) do
        if slotData.name == 'vehicle_key' and slotData.metadata and
           tonumber(slotData.metadata.vehicleId) == tonumber(vehicleId) then
            exports.inventory:RemoveItem(inventoryId, 'vehicle_key', 1, slotIdx)
            break
        end
    end
end

function KeysManager.giveKey(vehicleId, characterId, keyType)
    if not vehicleId or not characterId then
        return false, Sw.T('vehicles.invalid_parameters')
    end

    local success = VehiclesDatabase.addVehicleKey(vehicleId, characterId, keyType or 'standard')
    if not success then
        return false, Sw.T('vehicles.key_add_db_error')
    end

    local vehicle = VehiclesDatabase.getOwnedVehicleById(vehicleId)
    if vehicle then
        local inventoryId = 'char:' .. tostring(characterId)
        local metadata = {
            vehicleId = vehicleId,
            plate     = vehicle.plate,
            label     = vehicle.label or vehicle.model,
            keyType   = keyType or 'standard'
        }
        exports.inventory:AddItem(inventoryId, 'vehicle_key', 1, metadata)
    end

    return true, nil
end

function KeysManager.removeKey(vehicleId, characterId)
    if not vehicleId or not characterId then
        return false, Sw.T('vehicles.invalid_parameters')
    end

    local success = VehiclesDatabase.removeVehicleKey(vehicleId, characterId)
    if not success then
        return false, Sw.T('vehicles.key_remove_failed')
    end

    removeKeyFromInventory('keys:' .. tostring(characterId), vehicleId)

    return true, nil
end

function KeysManager.hasKey(vehicleId, characterId)
    if not vehicleId or not characterId then return false end
    return VehiclesDatabase.hasVehicleKey(vehicleId, characterId)
end

function KeysManager.getVehicleKeys(vehicleId)
    return VehiclesDatabase.getVehicleKeys(vehicleId)
end

function KeysManager.getCharacterKeys(characterId)
    return VehiclesDatabase.getCharacterVehicleKeys(characterId)
end

function KeysManager.transferOwnership(vehicleId, fromCharacterId, toCharacterId)
    if not vehicleId or not fromCharacterId or not toCharacterId then
        return false, Sw.T('vehicles.invalid_parameters')
    end

    local keys = VehiclesDatabase.getVehicleKeys(vehicleId)
    local isOwner = false
    for _, key in ipairs(keys) do
        if tonumber(key.character_id) == tonumber(fromCharacterId) and key.key_type == 'owner' then
            isOwner = true
            break
        end
    end

    if not isOwner then
        return false, Sw.T('vehicles.not_owner')
    end

    VehiclesDatabase.removeVehicleKey(vehicleId, fromCharacterId)
    removeKeyFromInventory('keys:' .. tostring(fromCharacterId), vehicleId)

    local success, err = KeysManager.giveKey(vehicleId, toCharacterId, 'owner')
    if not success then
        KeysManager.giveKey(vehicleId, fromCharacterId, 'owner')
        return false, Sw.T('vehicles.ownership_transfer_failed', err or '')
    end

    print(string.format('[VEHICLES] Transfer proprietate vehicul %d: %d → %d',
        vehicleId, fromCharacterId, toCharacterId))

    return true, nil
end

function KeysManager.syncKeysToInventory(characterId)
    if not characterId then return end

    local keys        = VehiclesDatabase.getCharacterVehicleKeys(characterId)
    local charInvId    = 'char:' .. tostring(characterId)
    local keysInvId    = 'keys:' .. tostring(characterId)

    -- Cheile fizic locuiesc in keys:<id> (routeInvId le muta acolo la AddItem).
    -- Scanam inventarul GRESIT (char:) aici era cauza duplicarii: nu gasea
    -- niciodata nimic de sters, deci fiecare reconectare readauga toate
    -- cheile din DB peste cele deja existente. Acum facem diff (nu rebuild
    -- complet): stergem doar cheile orfane, adaugam doar cele lipsa.
    local owned = {}
    for _, key in ipairs(keys) do
        owned[tonumber(key.vehicle_id)] = key
    end

    local inv = exports.inventory:GetInventory(keysInvId)
    local present = {}
    if inv and inv.slots then
        for slotIdx, slotData in pairs(inv.slots) do
            if slotData.name == 'vehicle_key' and slotData.metadata then
                local vId = tonumber(slotData.metadata.vehicleId)
                if vId and owned[vId] then
                    present[vId] = true
                else
                    exports.inventory:RemoveItem(keysInvId, 'vehicle_key', slotData.amount or 1, slotIdx)
                end
            end
        end
    end

    for vehicleId, key in pairs(owned) do
        if not present[vehicleId] then
            local metadata = {
                vehicleId = key.vehicle_id,
                plate     = key.plate,
                label     = key.label or key.model,
                keyType   = key.key_type
            }
            exports.inventory:AddItem(charInvId, 'vehicle_key', 1, metadata)
        end
    end
end

return KeysManager
