
TuningDatabase = {}

function TuningDatabase.getActiveShops()
    return exports.postgres:queryAll(
        'SELECT * FROM tuning_shops WHERE is_active = true ORDER BY name',
        {}
    )
end

function TuningDatabase.getShopByCode(code)
    return exports.postgres:queryOne(
        'SELECT * FROM tuning_shops WHERE code = $1 AND is_active = true',
        { code }
    )
end

function TuningDatabase.seedShops(shops)
    for _, shop in ipairs(shops) do
        exports.postgres:query(
            [[INSERT INTO tuning_shops (name, code, coords)
              VALUES ($1, $2, $3)
              ON CONFLICT (code) DO NOTHING]],
            {
                shop.name,
                shop.code,
                json.encode({ x = shop.coords.x, y = shop.coords.y, z = shop.coords.z }),
            }
        )
    end
end

function TuningDatabase.getAllPrices()
    return exports.postgres:queryAll(
        'SELECT * FROM tuning_prices ORDER BY category, tier',
        {}
    )
end

function TuningDatabase.getPrice(category, tier)
    return exports.postgres:queryOne(
        'SELECT * FROM tuning_prices WHERE category = $1 AND tier = $2',
        { category, tier }
    )
end

function TuningDatabase.seedPrices(prices)
    for _, row in ipairs(prices) do
        exports.postgres:query(
            [[INSERT INTO tuning_prices (category, tier, price, vip_only)
              VALUES ($1, $2, $3, $4)
              ON CONFLICT (category, tier) DO NOTHING]],
            { row.category, row.tier, row.price, not not row.vip_only }
        )
    end
end

function TuningDatabase.insertLog(characterId, vehicleId, shopId, category, tierBefore, tierAfter, pricePaid)
    return exports.postgres:insert('tuning_logs', {
        character_id = characterId,
        vehicle_id   = vehicleId,
        shop_id      = shopId,
        category     = category,
        tier_before  = tierBefore,
        tier_after   = tierAfter,
        price_paid   = pricePaid,
    })
end

function TuningDatabase.getVehicleLogs(vehicleId, limit)
    return exports.postgres:queryAll(
        [[SELECT tl.*, c.first_name, c.last_name
          FROM tuning_logs tl
          JOIN characters c ON c.id = tl.character_id
          WHERE tl.vehicle_id = $1
          ORDER BY tl.applied_at DESC
          LIMIT $2]],
        { vehicleId, limit or 50 }
    )
end

function TuningDatabase.getCharacterLogs(characterId, limit)
    return exports.postgres:queryAll(
        [[SELECT tl.*, ov.plate, ov.label
          FROM tuning_logs tl
          JOIN owned_vehicles ov ON ov.id = tl.vehicle_id
          WHERE tl.character_id = $1
          ORDER BY tl.applied_at DESC
          LIMIT $2]],
        { characterId, limit or 50 }
    )
end
