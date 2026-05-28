local isUIOpen = false

local function OpenNUI(data)
    if isUIOpen then return end
    isUIOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        shop   = data.shop,
        items  = data.items,
        cash   = data.cash,
        accounts = data.accounts
    })
end

local function CloseNUI()
    if not isUIOpen then return end
    isUIOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('shops:server:getShops')
end)

RegisterNetEvent('shops:client:shopsData', function(shops)
    for _, shop in ipairs(shops) do
        local coords = shop.coords
        if type(coords) == 'string' then
            coords = json.decode(coords)
        end
        if coords and coords.x then
            exports.proximity:AddStaticInteraction(
                vector3(coords.x, coords.y, coords.z),
                shop.label,
                'shop_interaction',
                { shopName = shop.name }
            )
        end
    end
    print('[SHOPS-CLIENT] ' .. #shops .. ' magazine înregistrate în proximity.')
end)

RegisterNetEvent('switcore:proximity:interact', function(interaction)
    if not interaction or interaction.type ~= 'shop_interaction' then return end
    local shopName = interaction.data and interaction.data.shopName
    if not shopName then return end
    TriggerServerEvent('shops:server:openShop', shopName)
end)

RegisterNetEvent('shops:client:openShop', function(data)
    OpenNUI(data)
end)

RegisterNetEvent('shops:client:buyResult', function(result)
    if result.success and result.result then
        SendNUIMessage({
            action      = 'buySuccess',
            totalCost   = result.result.totalCost,
            currencyCode = result.result.currencyCode
        })
    else
        SendNUIMessage({
            action = 'buyError',
            error  = result.error or 'Eroare necunoscută'
        })
    end
end)

RegisterNUICallback('closeShop', function(_, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('shops:server:buyItem', data)
    cb('ok')
end)
