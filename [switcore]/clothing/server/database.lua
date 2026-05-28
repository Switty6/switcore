ClothingDB = {}

function ClothingDB.getStores(callback)
    exports.postgres:queryAll('SELECT * FROM clothing_stores WHERE active = TRUE', {}, callback)
end

function ClothingDB.getStoreItems(storeName, gender, callback)
    exports.postgres:queryAll(
        'SELECT * FROM clothing_items WHERE store_name = $1 AND (gender = -1 OR gender = $2) ORDER BY component_id, drawable',
        {storeName, gender},
        callback
    )
end

function ClothingDB.getEquippedClothing(characterId, callback)
    exports.postgres:queryOne(
        'SELECT components FROM character_equipped_clothing WHERE character_id = $1',
        {characterId},
        function(row)
            if row then
                local components = row.components
                if type(components) == 'string' then
                    components = json.decode(components) or {}
                end
                callback(components)
            else
                callback({})
            end
        end
    )
end

function ClothingDB.saveEquippedClothing(characterId, components, callback)
    exports.postgres:query([[
        INSERT INTO character_equipped_clothing (character_id, components)
        VALUES ($1, $2::jsonb)
        ON CONFLICT (character_id) DO UPDATE SET components = $2::jsonb
    ]], {characterId, json.encode(components)}, callback)
end

function ClothingDB.getOutfits(characterId, callback)
    exports.postgres:queryAll(
        'SELECT * FROM character_outfits WHERE character_id = $1 ORDER BY created_at DESC',
        {characterId},
        callback
    )
end

function ClothingDB.saveOutfit(characterId, name, components, callback)
    exports.postgres:query([[
        INSERT INTO character_outfits (character_id, name, components)
        VALUES ($1, $2, $3::jsonb)
        ON CONFLICT (character_id, name) DO UPDATE SET components = $3::jsonb
    ]], {characterId, name, json.encode(components)}, callback)
end

function ClothingDB.deleteOutfit(characterId, outfitId, callback)
    exports.postgres:query(
        'DELETE FROM character_outfits WHERE id = $1 AND character_id = $2',
        {outfitId, characterId},
        callback
    )
end

function ClothingDB.getItemById(itemId, callback)
    exports.postgres:queryOne('SELECT * FROM clothing_items WHERE id = $1', {itemId}, callback)
end

function ClothingDB.getOutfitById(outfitId, characterId, callback)
    exports.postgres:queryOne(
        'SELECT * FROM character_outfits WHERE id = $1 AND character_id = $2',
        {outfitId, characterId},
        callback
    )
end
