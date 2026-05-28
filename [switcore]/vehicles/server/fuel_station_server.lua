local function GetCharacterId(source)
    local char = exports.characters:getActiveCharacter(source)
    return char and char.id
end

local function getFirstCurrency()
    local currencies = exports.banking:getActiveCurrencies()
    return (currencies and #currencies > 0) and currencies[1] or nil
end

local function getFirstCurrencyId()
    local c = getFirstCurrency()
    return c and c.id or nil
end

RegisterNetEvent('vehicles:server:getBalanceForFuel', function()
    local source = source
    local characterId = GetCharacterId(source)
    local currency    = getFirstCurrency()
    local symbol      = currency and currency.symbol or '$'

    if not characterId or not currency then
        TriggerClientEvent('vehicles:client:updateFuelBalance', source, 0, nil, 0, 0, symbol)
        return
    end

    local cash     = exports.banking:getCharacterCash(characterId, currency.id) or 0
    local accounts = exports.banking:getCharacterAccounts(characterId, currency.id) or {}
    local bank     = 0
    for _, acc in ipairs(accounts) do
        bank = bank + (tonumber(acc.balance) or 0)
    end

    local pricePerLitre = exports.settings:GetSettingNumber('vehicles.fuel_price_per_liter', 8)
    TriggerClientEvent('vehicles:client:updateFuelBalance',
        source, cash + bank, pricePerLitre, cash, bank, symbol)
end)

RegisterNetEvent('vehicles:server:refuel', function(vehicleId, litres, totalCost, method)
    local source = source
    vehicleId = tonumber(vehicleId)
    litres    = tonumber(litres) or 0
    method    = method == 'card' and 'card' or 'cash'

    if litres <= 0 then return end

    local methodLabel = method == 'card' and 'card' or 'cash'

    if vehicleId then
        local characterId = GetCharacterId(source)
        if not characterId then
            TriggerClientEvent('switcore:notify', source, 'error', 'Eroare autentificare.', 3000)
            return
        end

        local ok, err, result = FuelManager.refuel(source, characterId, vehicleId, litres, method)
        if not ok then
            TriggerClientEvent('switcore:notify', source, 'error', err or 'Alimentare eșuată.', 4000)
            TriggerClientEvent('vehicles:client:refuelResult', source, false, err)
        else
            local sym = (getFirstCurrency() or {}).symbol or '$'
            TriggerClientEvent('vehicles:client:refuelResult', source, true, nil, result)
            TriggerClientEvent('switcore:notify', source, 'success',
                string.format('Alimentat %.1fL  -  %s%.2f plătit cu %s',
                    result.liters, sym, result.cost,
                    result.method == 'card' and 'cardul' or 'cash'),
                5000)
            print(string.format('[FUEL-STATION] Jucătorul %d a alimentat vehiculul %d cu %.2fL (%s%.2f) - %s',
                source, vehicleId, result.liters, sym, result.cost, result.method))
        end
        return
    end

    -- vehicleId absent = vehicul non-owned (NPC, admin spawn): debităm jucătorul dar nu persistăm fuel-ul în DB.
    local characterId = GetCharacterId(source)
    if not characterId then return end

    local sym = (getFirstCurrency() or {}).symbol or '$'
    if totalCost and totalCost > 0 then
        local currencyId = getFirstCurrencyId()
        if currencyId then
            if method == 'cash' then
                local cash = exports.banking:getCharacterCash(characterId, currencyId) or 0
                if cash < totalCost then
                    TriggerClientEvent('switcore:notify', source, 'error',
                        string.format('Cash insuficient: %s%d necesar.', sym, totalCost), 4000)
                    return
                end
                exports.banking:addCharacterCash(characterId, currencyId, -totalCost)
            else
                local accounts = exports.banking:getCharacterAccounts(characterId) or {}
                if #accounts == 0 then
                    TriggerClientEvent('switcore:notify', source, 'error', 'Nu ai cont bancar.', 4000)
                    return
                end
                local bal = exports.banking:getAccountBalance(accounts[1].id, currencyId) or 0
                if bal < totalCost then
                    TriggerClientEvent('switcore:notify', source, 'error',
                        string.format('Sold bancar insuficient: %s%d necesar.', sym, totalCost), 4000)
                    return
                end
                exports.banking:removeAccountBalance(accounts[1].id, currencyId, totalCost)
            end
        end
    end

    TriggerClientEvent('vehicles:client:refuelResult', source, true, nil, { cost = totalCost, liters = litres, method = method })
    TriggerClientEvent('switcore:notify', source, 'success',
        string.format('Alimentat %.1fL  -  %s%.2f plătit cu %s',
            litres, sym, totalCost or 0,
            method == 'card' and 'cardul' or 'cash'),
        5000)
end)

RegisterNetEvent('vehicles:server:fuelFailed', function(vehicleId, litresActuallyAdded)
    local source = source
    vehicleId           = tonumber(vehicleId)
    litresActuallyAdded = tonumber(litresActuallyAdded) or 0

    if litresActuallyAdded <= 0 then return end

    local pricePerLitre = exports.settings:GetSettingNumber('vehicles.fuel_price_per_liter', 3.5)
    local partialCost   = math.floor(litresActuallyAdded * pricePerLitre)

    local characterId = GetCharacterId(source)
    if characterId and partialCost > 0 then
        local currencyId = getFirstCurrencyId()
        if currencyId then
            exports.banking:addCharacterCash(characterId, currencyId, -partialCost)
        end
    end

    if vehicleId then
        local vehicle = VehiclesDatabase.getOwnedVehicleById(vehicleId)
        if vehicle then
            local current = tonumber(vehicle.fuel) or 0
            FuelManager.setFuel(vehicleId, math.min(100, current + litresActuallyAdded))
        end
    end

    print(string.format('[FUEL-STATION] Furtun rupt - player %d: %.2fL parțial ($%d)',
        source, litresActuallyAdded, partialCost))
end)

print('[FUEL-STATION] Server module loaded')
