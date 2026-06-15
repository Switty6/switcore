local pendingOrders  = {}
local activeOrderId  = nil
local pickupProxId   = nil
local dropoffProxId  = nil

local function notify(notifType, title, message)
    TriggerEvent('notifications:client:send', {
        type = notifType, title = title, message = message, duration = 5000
    })
end

RegisterNetEvent('taxi:client:newOrder', function(orderData)
    for i, o in ipairs(pendingOrders) do
        if o.id == orderData.id then
            table.remove(pendingOrders, i)
            break
        end
    end
    table.insert(pendingOrders, 1, orderData)

    notify('info', Sw.T('taxi.new_order_title'),
        Sw.T('taxi.new_order_message', orderData.passenger_name or '?'))

    SendNUIMessage({ action = 'newOrder', order = orderData })
end)

AddEventHandler('taxi:dispatch:orderTaken', function(orderId)
    for i, o in ipairs(pendingOrders) do
        if o.id == orderId then
            table.remove(pendingOrders, i)
            break
        end
    end
    SendNUIMessage({ action = 'orderRemoved', orderId = orderId })
end)

AddEventHandler('taxi:dispatch:orderAccepted', function(orderData)
    activeOrderId = orderData.id

    for i, o in ipairs(pendingOrders) do
        if o.id == orderData.id then
            table.remove(pendingOrders, i)
            break
        end
    end

    if pickupProxId then
        exports.proximity:RemoveInteraction(pickupProxId)
        pickupProxId = nil
    end

    local c = orderData.pickup_coords
    pickupProxId = 'taxi_pickup_' .. orderData.id

    exports.proximity:AddInteraction(
        vector3(c.x, c.y, c.z),
        Sw.T('taxi.prox_confirm_pickup'),
        pickupProxId,
        {},
        function()
            exports.proximity:RemoveInteraction(pickupProxId)
            pickupProxId = nil
            TriggerServerEvent('taxi:server:confirmPickup', activeOrderId)
        end
    )
end)

-- Pickup proximity already removed on confirmation; no-op while waiting
-- for the passenger to call /taxidest.
AddEventHandler('taxi:dispatch:rideStarted', function(data)
end)

AddEventHandler('taxi:dispatch:setDropoff', function(dropoffCoords)
    if dropoffProxId then
        exports.proximity:RemoveInteraction(dropoffProxId)
        dropoffProxId = nil
    end

    if not activeOrderId then return end

    local capturedOrderId = activeOrderId
    dropoffProxId = 'taxi_dropoff_' .. capturedOrderId

    exports.proximity:AddInteraction(
        vector3(dropoffCoords.x, dropoffCoords.y, dropoffCoords.z),
        Sw.T('taxi.prox_complete_ride'),
        dropoffProxId,
        {},
        function()
            exports.proximity:RemoveInteraction(dropoffProxId)
            dropoffProxId = nil
            TriggerServerEvent('taxi:server:completeRide', capturedOrderId)
        end
    )
end)

AddEventHandler('taxi:dispatch:cleanup', function()
    activeOrderId = nil

    if pickupProxId then
        exports.proximity:RemoveInteraction(pickupProxId)
        pickupProxId = nil
    end
    if dropoffProxId then
        exports.proximity:RemoveInteraction(dropoffProxId)
        dropoffProxId = nil
    end
end)

AddEventHandler('taxi:dispatch:orderCancelled', function(orderId)
    if activeOrderId == orderId then
        TriggerEvent('taxi:dispatch:cleanup')
        ClearGpsPlayerWaypoint()
        notify('warning', Sw.T('taxi.notify_title'), Sw.T('taxi.ride_cancelled'))
    end
    for i, o in ipairs(pendingOrders) do
        if o.id == orderId then table.remove(pendingOrders, i) break end
    end
    SendNUIMessage({ action = 'orderRemoved', orderId = orderId })
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    if pickupProxId then exports.proximity:RemoveInteraction(pickupProxId) end
    if dropoffProxId then exports.proximity:RemoveInteraction(dropoffProxId) end
end)
