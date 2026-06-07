ClothingDB = {}

function ClothingDB.getStores(callback)
    local stores = exports.postgres:queryAll('SELECT * FROM clothing_stores WHERE active = TRUE', {})
    if callback then callback(stores or {}) end
    return stores
end

function ClothingDB.getStoreItems(storeName, gender, callback)
    local items = exports.postgres:queryAll(
        'SELECT * FROM clothing_items WHERE store_name = $1 AND (gender = -1 OR gender = $2) ORDER BY component_id, drawable',
        {storeName, gender}
    )
    if callback then callback(items or {}) end
    return items
end

function ClothingDB.getEquippedClothing(characterId, callback)
    local row = exports.postgres:queryOne(
        'SELECT components FROM character_equipped_clothing WHERE character_id = $1',
        {characterId}
    )
    local components = {}
    if row then
        components = row.components
        if type(components) == 'string' then
            components = json.decode(components) or {}
        end
    end
    if callback then callback(components) end
    return components
end

function ClothingDB.saveEquippedClothing(characterId, components, callback)
    local result = exports.postgres:query([[
        INSERT INTO character_equipped_clothing (character_id, components)
        VALUES ($1, $2::jsonb)
        ON CONFLICT (character_id) DO UPDATE SET components = $2::jsonb
    ]], {characterId, json.encode(components)})
    if callback then callback(result) end
    return result
end

function ClothingDB.getOutfits(characterId, callback)
    local outfits = exports.postgres:queryAll(
        'SELECT * FROM character_outfits WHERE character_id = $1 ORDER BY created_at DESC',
        {characterId}
    )
    if callback then callback(outfits or {}) end
    return outfits
end

function ClothingDB.saveOutfit(characterId, name, components, callback)
    local result = exports.postgres:query([[
        INSERT INTO character_outfits (character_id, name, components)
        VALUES ($1, $2, $3::jsonb)
        ON CONFLICT (character_id, name) DO UPDATE SET components = $3::jsonb
    ]], {characterId, name, json.encode(components)})
    if callback then callback(result) end
    return result
end

function ClothingDB.deleteOutfit(characterId, outfitId, callback)
    local result = exports.postgres:query(
        'DELETE FROM character_outfits WHERE id = $1 AND character_id = $2',
        {outfitId, characterId}
    )
    if callback then callback(result) end
    return result
end

function ClothingDB.getItemById(itemId, callback)
    local item = exports.postgres:queryOne('SELECT * FROM clothing_items WHERE id = $1', {itemId})
    if callback then callback(item) end
    return item
end

function ClothingDB.getOutfitById(outfitId, characterId, callback)
    local outfit = exports.postgres:queryOne(
        'SELECT * FROM character_outfits WHERE id = $1 AND character_id = $2',
        {outfitId, characterId}
    )
    if callback then callback(outfit) end
    return outfit
end
