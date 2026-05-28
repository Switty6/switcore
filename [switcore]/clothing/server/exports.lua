exports('GetStoreItems', function(storeName, gender)
    local result = {}
    ClothingDB.getStoreItems(storeName, gender or -1, function(items)
        result = items or {}
    end)
    return result
end)

exports('GetEquippedClothing', function(characterId)
    return ClothingManager.getEquipped(characterId)
end)
