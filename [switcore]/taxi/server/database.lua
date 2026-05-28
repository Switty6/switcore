
TaxiDB = {}

local function pg() return exports.postgres end

local cachedCurrencyId = nil

function TaxiDB.getCurrencyId()
    if cachedCurrencyId then return cachedCurrencyId end
    local ok, currency = pcall(function()
        return exports.banking:getCurrencyByCode('RON')
    end)
    if ok and currency then
        cachedCurrencyId = currency.id
    end
    return cachedCurrencyId
end

function TaxiDB.createOrder(passengerCharId, passengerSrc, pickupCoords)
    local ok, result = pcall(function()
        return pg():queryOne(
            [[INSERT INTO taxi_orders (character_id, passenger_src, pickup_coords)
              VALUES ($1, $2, $3) RETURNING *]],
            { passengerCharId, passengerSrc, json.encode(pickupCoords) }
        )
    end)
    return ok and result or nil
end

function TaxiDB.getOrder(orderId)
    local ok, result = pcall(function()
        return pg():queryOne('SELECT * FROM taxi_orders WHERE id = $1', { orderId })
    end)
    return ok and result or nil
end

-- Accepta o comanda atomic (returneaza false daca deja acceptata)
function TaxiDB.acceptOrder(orderId, driverCharId)
    local ok, result = pcall(function()
        return pg():queryOne(
            [[UPDATE taxi_orders SET status = 'accepted', driver_char_id = $2
              WHERE id = $1 AND status = 'waiting' RETURNING id]],
            { orderId, driverCharId }
        )
    end)
    return ok and result ~= nil
end

function TaxiDB.startOrder(orderId, dropoffCoords)
    local ok = pcall(function()
        pg():execute(
            [[UPDATE taxi_orders SET status = 'in_progress', dropoff_coords = $2
              WHERE id = $1]],
            { orderId, dropoffCoords and json.encode(dropoffCoords) or nil }
        )
    end)
    return ok
end

function TaxiDB.completeOrder(orderId, payAmount, distanceKm)
    local ok = pcall(function()
        pg():execute(
            [[UPDATE taxi_orders
              SET status = 'completed', pay_amount = $2, distance_km = $3, completed_at = NOW()
              WHERE id = $1]],
            { orderId, payAmount, distanceKm }
        )
    end)
    return ok
end

function TaxiDB.cancelOrder(orderId)
    local ok = pcall(function()
        pg():execute(
            [[UPDATE taxi_orders SET status = 'cancelled'
              WHERE id = $1 AND status IN ('waiting','accepted','in_progress')]],
            { orderId }
        )
    end)
    return ok
end

function TaxiDB.getPendingOrders()
    local ok, rows = pcall(function()
        return pg():queryAll(
            [[SELECT o.id, o.pickup_coords, o.created_at,
                     c.first_name || ' ' || c.last_name AS passenger_name
              FROM taxi_orders o
              JOIN characters c ON c.id = o.character_id
              WHERE o.status = 'waiting'
              ORDER BY o.created_at ASC
              LIMIT 20]],
            {}
        )
    end)
    return ok and rows or {}
end

function TaxiDB.upsertStats(charId, tripsAdd, earnedAdd)
    local ok = pcall(function()
        pg():execute(
            [[INSERT INTO taxi_stats (character_id, total_trips, total_earned)
              VALUES ($1, $2, $3)
              ON CONFLICT (character_id) DO UPDATE SET
                  total_trips  = taxi_stats.total_trips  + EXCLUDED.total_trips,
                  total_earned = taxi_stats.total_earned + EXCLUDED.total_earned,
                  updated_at   = NOW()]],
            { charId, tripsAdd, earnedAdd }
        )
    end)
    return ok
end

function TaxiDB.getStats(charId)
    local ok, result = pcall(function()
        return pg():queryOne(
            'SELECT * FROM taxi_stats WHERE character_id = $1',
            { charId }
        )
    end)
    return ok and result or nil
end

function TaxiDB.getRecentTrips(charId, limit)
    local ok, rows = pcall(function()
        return pg():queryAll(
            [[SELECT id, distance_km, pay_amount, completed_at
              FROM taxi_orders
              WHERE driver_char_id = $1 AND status = 'completed'
              ORDER BY completed_at DESC
              LIMIT $2]],
            { charId, limit or 15 }
        )
    end)
    return ok and rows or {}
end
