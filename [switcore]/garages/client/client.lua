
local currentGarageCode = nil
local isUIOpen = false

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('garages:server:getLocationConfig')
end)

RegisterNetEvent('garages:client:locationConfig', function(config)
    local interactionDistance = config.distance or 2.5

    for _, loc in ipairs(config.locations or {}) do
        local coords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)

        exports.proximity:AddInteraction(
            coords,
            loc.name,
            'garage_' .. loc.code,
            {},
            function()
                if not isUIOpen then
                    currentGarageCode = loc.code
                    TriggerServerEvent('garages:server:openGarage', loc.code)
                end
            end
        )
    end
    print('[GARAGES-CLIENT] ' .. #(config.locations or {}) .. ' garaje înregistrate proximity')
end)

RegisterNetEvent('garages:client:openUI', function(data)
    isUIOpen = true
    pushI18n()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action    = 'open',
        garage    = data.garage,
        vehicles  = data.vehicles,
        impounded = data.impounded,
        tickets   = data.tickets,
    })
end)

RegisterNetEvent('garages:client:updateData', function(data)
    SendNUIMessage({
        action    = 'updateData',
        vehicles  = data.vehicles,
        impounded = data.impounded,
        tickets   = data.tickets,
    })
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    currentGarageCode = nil
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    if not currentGarageCode then cb('no_garage'); return end
    TriggerServerEvent('garages:server:retrieveVehicle', data.vehicleId, currentGarageCode)
    isUIOpen = false
    currentGarageCode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('parkVehicle', function(data, cb)
    if not currentGarageCode then cb('no_garage'); return end

    -- Starea vehiculului e salvata periodic in alta parte; aici nu o trimitem
    TriggerServerEvent('garages:server:parkVehicle', data.vehicleId, currentGarageCode, nil)
    SetTimeout(400, function()
        if currentGarageCode then
            TriggerServerEvent('garages:server:refreshData', currentGarageCode)
        end
    end)
    cb('ok')
end)

RegisterNUICallback('releaseImpound', function(data, cb)
    TriggerServerEvent('garages:server:releaseImpound', data.vehicleId)
    isUIOpen = false
    currentGarageCode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('payTicket', function(data, cb)
    TriggerServerEvent('garages:server:payTicket', data.ticketId)
    Wait(300)
    if currentGarageCode then
        TriggerServerEvent('garages:server:refreshData', currentGarageCode)
    end
    cb('ok')
end)

RegisterNUICallback('refreshData', function(_, cb)
    if currentGarageCode then
        TriggerServerEvent('garages:server:refreshData', currentGarageCode)
    end
    cb('ok')
end)
