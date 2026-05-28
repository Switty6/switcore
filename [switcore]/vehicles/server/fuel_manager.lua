
FuelManager = {}

local fuelCache = {}
local lastAuthoritativeFuel = {}

function FuelManager.getFuel(vehicleId)
    if fuelCache[vehicleId] then
        return fuelCache[vehicleId]
    end
    local vehicle = VehiclesDatabase.getOwnedVehicleById(vehicleId)
    if vehicle then
        local fuel = tonumber(vehicle.fuel) or 100.0
        fuelCache[vehicleId] = fuel
        lastAuthoritativeFuel[vehicleId] = fuel
        return fuel
    end
    return 100.0
end

function FuelManager.setFuel(vehicleId, amount)
    if not vehicleId then return false end

    local fuel = math.max(0.0, math.min(100.0, tonumber(amount) or 0.0))
    fuelCache[vehicleId] = fuel
    lastAuthoritativeFuel[vehicleId] = fuel

    return VehiclesDatabase.updateVehicleState(vehicleId, { fuel = fuel })
end

function FuelManager.updateCache(vehicleId, amount)
    if not vehicleId then return end
    local fuel = math.max(0.0, math.min(100.0, tonumber(amount) or 0.0))
    fuelCache[vehicleId] = fuel
end

function FuelManager.clearCache(vehicleId)
    fuelCache[vehicleId] = nil
    lastAuthoritativeFuel[vehicleId] = nil
end

function FuelManager.validateClientTick(vehicleId, currentFuel)
    if not vehicleId or not currentFuel then return false end
    if currentFuel < 0 or currentFuel > 100 then return false end

    local last = lastAuthoritativeFuel[vehicleId]
    if last ~= nil and currentFuel > last + 2.0 then
        return false
    end

    lastAuthoritativeFuel[vehicleId] = currentFuel
    return true
end

function FuelManager.refuel(source, characterId, vehicleId, liters, method)
    if not characterId or not vehicleId or not liters or liters <= 0 then
        return false, 'Parametri invalizi'
    end

    method = method == 'card' and 'card' or 'cash'

    local vehicle = VehiclesDatabase.getOwnedVehicleById(vehicleId)
    if not vehicle then
        return false, 'Vehicul inexistent'
    end

    if not VehiclesDatabase.hasVehicleKey(vehicleId, characterId) then
        return false, 'Nu ai cheie pentru acest vehicul'
    end

    local currentFuel = tonumber(vehicle.fuel) or 0.0
    local maxFill = 100.0 - currentFuel
    if maxFill <= 0 then
        return false, 'Rezervorul este plin'
    end

    liters = math.min(liters, maxFill)

    local pricePerLiter = exports.settings:GetSettingNumber('vehicles.fuel_price_per_liter', 3.5)
    local cost = liters * pricePerLiter

    local currencies = exports.banking:getActiveCurrencies()
    if not currencies or #currencies == 0 then
        return false, 'Sistem banking indisponibil'
    end
    local currencyId = currencies[1].id

    local cash     = exports.banking:getCharacterCash(characterId, currencyId) or 0
    local accounts = exports.banking:getCharacterAccounts(characterId) or {}
    local bankBalance = 0
    if #accounts > 0 then
        bankBalance = exports.banking:getAccountBalance(accounts[1].id, currencyId) or 0
    end

    if method == 'cash' then
        if cash < cost then
            return false, string.format('Cash insuficient. Necesar: $%.2f, ai: $%.2f', cost, cash)
        end
        exports.banking:addCharacterCash(characterId, currencyId, -cost)
    else
        if #accounts == 0 then
            return false, 'Nu ai cont bancar'
        end
        if bankBalance < cost then
            return false, string.format('Sold bancar insuficient. Necesar: $%.2f, ai: $%.2f', cost, bankBalance)
        end
        exports.banking:removeAccountBalance(accounts[1].id, currencyId, cost)
    end

    local newFuel = currentFuel + liters
    FuelManager.setFuel(vehicleId, newFuel)

    TriggerClientEvent('vehicles:client:setFuel', source, vehicleId, newFuel)

    return true, nil, { newFuel = newFuel, cost = cost, liters = liters, method = method }
end

return FuelManager
