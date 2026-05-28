
local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function getCharJob(characterId)
    local ok, job = pcall(function()
        return exports.jobs:GetCharacterJob(characterId)
    end)
    return ok and job or nil
end

local function notify(src, notifType, title, message)
    TriggerClientEvent('notifications:client:send', src, {
        type = notifType, title = title, message = message, duration = 5000
    })
end

RegisterNetEvent('taxi:server:hire', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if job and job.name == Config.JobName then
        notify(src, 'warning', 'Taxi', 'Esti deja angajat la Compania de Taxi.')
        return
    end

    exports.jobs:SetCharacterJob(char.id, Config.JobName, 0)
    TaxiDB.upsertStats(char.id, 0, 0)

    local updated = exports.jobs:GetCharacterJob(char.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, updated)
    notify(src, 'success', 'Angajat!', 'Bine ai venit la Compania de Taxi! Intra in tura pentru a primi curse.')
end)

RegisterNetEvent('taxi:server:quit', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then return end

    exports.jobs:SetCharacterJob(char.id, 'unemployed', 0)
    local updated = exports.jobs:GetCharacterJob(char.id)
    TriggerClientEvent('jobs:client:jobUpdated', src, updated)
    notify(src, 'info', 'Taxi', 'Ai parasit Compania de Taxi.')
end)

RegisterNetEvent('taxi:server:requestRide', function(pickupCoords)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    if not pickupCoords or not pickupCoords.x then
        notify(src, 'error', 'Taxi', 'Coordonate invalide.')
        return
    end

    local order = TaxiDB.createOrder(char.id, src, pickupCoords)
    if not order then
        notify(src, 'error', 'Taxi', 'Eroare la trimiterea cererii.')
        return
    end

    local orderData = {
        id            = order.id,
        pickup_coords = pickupCoords,
        passenger_src = src,
        passenger_name = char.first_name .. ' ' .. char.last_name,
    }

    BroadcastOrderToDrivers(orderData)
    notify(src, 'info', 'Taxi', 'Cererea a fost trimisa. Asteapta un sofer.')
end)

RegisterNetEvent('taxi:server:acceptOrder', function(orderId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName or not job.isOnDuty then
        notify(src, 'error', 'Taxi', 'Trebuie sa fii in tura pentru a accepta o cursa.')
        return
    end

    local accepted = TaxiDB.acceptOrder(orderId, char.id)
    if not accepted then
        notify(src, 'warning', 'Taxi', 'Cursa nu mai este disponibila.')
        return
    end

    local order = TaxiDB.getOrder(orderId)
    if not order then return end

    local pickup = type(order.pickup_coords) == 'string'
        and json.decode(order.pickup_coords)
        or order.pickup_coords

    local orderData = {
        id            = order.id,
        pickup_coords = pickup,
        passenger_src = order.passenger_src,
    }

    TriggerClientEvent('taxi:client:orderAccepted', src, orderData)

    local passengerSrc = tonumber(order.passenger_src)
    if passengerSrc and GetPlayerName(passengerSrc) then
        notify(passengerSrc, 'success', 'Taxi', 'Un sofer vine catre tine!')
    end

    for _, pid in ipairs(GetPlayers()) do
        local s = tonumber(pid)
        if s ~= src then
            local c = getActiveChar(s)
            if c then
                local j = getCharJob(c.id)
                if j and j.name == Config.JobName and j.isOnDuty then
                    TriggerClientEvent('taxi:client:orderTaken', s, orderId)
                end
            end
        end
    end
end)

RegisterNetEvent('taxi:server:confirmPickup', function(orderId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local order = TaxiDB.getOrder(orderId)
    if not order or order.driver_char_id ~= char.id then return end

    TaxiDB.startOrder(orderId, nil)
    TriggerClientEvent('taxi:client:rideStarted', src, { orderId = orderId })

    local passengerSrc = tonumber(order.passenger_src)
    if passengerSrc and GetPlayerName(passengerSrc) then
        notify(passengerSrc, 'info', 'Taxi', 'Soferul te-a preluat! Indica destinatia cu /taxidest.')
        TriggerClientEvent('taxi:client:setDestination', passengerSrc, { orderId = orderId })
    end
end)

RegisterNetEvent('taxi:server:setDestination', function(orderId, dropoffCoords)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    if not dropoffCoords or not dropoffCoords.x then
        notify(src, 'error', 'Taxi', 'Coordonate invalide.')
        return
    end

    local order = TaxiDB.getOrder(orderId)
    if not order or order.character_id ~= char.id then return end

    TaxiDB.startOrder(orderId, dropoffCoords)

    local driverSrc = FindSourceForChar(order.driver_char_id)
    if driverSrc then
        TriggerClientEvent('taxi:client:gpsDropoff', driverSrc, dropoffCoords)
        notify(driverSrc, 'info', 'Taxi', 'Destinatia a fost setata. Urmeaza GPS-ul.')
    end
    notify(src, 'success', 'Taxi', 'Destinatia a fost trimisa soferului.')
end)

RegisterNetEvent('taxi:server:completeRide', function(orderId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local order = TaxiDB.getOrder(orderId)
    if not order or order.driver_char_id ~= char.id then
        notify(src, 'error', 'Taxi', 'Cursa invalida.')
        return
    end
    if order.status ~= 'in_progress' then
        notify(src, 'warning', 'Taxi', 'Cursa nu este activa.')
        return
    end

    local pickup  = type(order.pickup_coords)  == 'string' and json.decode(order.pickup_coords)  or order.pickup_coords
    local dropoff = type(order.dropoff_coords) == 'string' and json.decode(order.dropoff_coords) or order.dropoff_coords

    if not dropoff then
        notify(src, 'error', 'Taxi', 'Destinatia nu a fost setata inca.')
        return
    end

    local distKm = math.max(0.1, (function()
        local dx = (dropoff.x - pickup.x) * 0.001
        local dy = (dropoff.y - pickup.y) * 0.001
        return math.sqrt(dx * dx + dy * dy)
    end)())

    local pay        = CalculatePay(char.id, distKm)
    local currencyId = TaxiDB.getCurrencyId()

    if currencyId then
        pcall(function()
            exports.banking:addCharacterCash(char.id, currencyId, pay)
        end)
    end

    TaxiDB.completeOrder(orderId, pay, distKm)
    TaxiDB.upsertStats(char.id, 1, pay)

    TriggerClientEvent('taxi:client:rideCompleted', src, {
        pay         = pay,
        distanceKm  = distKm,
    })

    local passengerSrc = tonumber(order.passenger_src)
    if passengerSrc and GetPlayerName(passengerSrc) then
        notify(passengerSrc, 'success', 'Taxi', string.format('Cursa finalizata! (%.1f km)', distKm))
        TriggerClientEvent('taxi:client:passengerDone', passengerSrc)
    end

    CheckPromotion(char.id, src)
end)

RegisterNetEvent('taxi:server:cancelOrder', function(orderId)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local order = TaxiDB.getOrder(orderId)
    if not order then return end

    local isPassenger = order.character_id == char.id
    local isDriver    = order.driver_char_id == char.id
    if not isPassenger and not isDriver then return end

    TaxiDB.cancelOrder(orderId)
    notify(src, 'warning', 'Taxi', 'Cursa a fost anulata.')

    if isPassenger and order.driver_char_id then
        local driverSrc = FindSourceForChar(order.driver_char_id)
        if driverSrc then
            notify(driverSrc, 'warning', 'Taxi', 'Pasagerul a anulat cursa.')
            TriggerClientEvent('taxi:client:orderCancelled', driverSrc, orderId)
        end
    elseif isDriver then
        local passengerSrc = tonumber(order.passenger_src)
        if passengerSrc and GetPlayerName(passengerSrc) then
            notify(passengerSrc, 'warning', 'Taxi', 'Soferul a anulat cursa.')
        end
    end
end)

RegisterNetEvent('taxi:server:openTablet', function()
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName then return end

    local stats   = TaxiDB.getStats(char.id) or { total_trips = 0, total_earned = 0 }
    local recent  = TaxiDB.getRecentTrips(char.id, 15)
    local pending = TaxiDB.getPendingOrders()

    TriggerClientEvent('taxi:client:tabletData', src, {
        stats   = stats,
        recent  = recent,
        pending = pending,
        job     = job,
    })
end)

RegisterNetEvent('taxi:server:npcRideComplete', function(distKm, multiplier)
    local src  = source
    local char = getActiveChar(src)
    if not char then return end

    local job = getCharJob(char.id)
    if not job or job.name ~= Config.JobName or not job.isOnDuty then return end

    -- Anti-cheat: clamp distanta si multiplicator
    distKm     = math.max(0.1, math.min(distKm, 50.0))
    multiplier = math.max(1.0, math.min(tonumber(multiplier) or 1.0, 2.0))

    local pay        = math.floor(CalculatePay(char.id, distKm) * multiplier)
    local currencyId = TaxiDB.getCurrencyId()

    if currencyId and pay > 0 then
        pcall(function() exports.banking:addCharacterCash(char.id, currencyId, pay) end)
    end

    TaxiDB.upsertStats(char.id, 1, pay)

    local bonusText = multiplier > 1.01 and string.format(' (×%.2f)', multiplier) or ''
    notify(src, 'success', 'Cursa NPC finalizata!',
        string.format('Ai castigat %d lei (%.1f km)%s.', pay, distKm, bonusText))

    CheckPromotion(char.id, src)
end)
