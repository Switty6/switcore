
local function buildTuningConfig(source, shopCode)
    return {
        shopCode     = shopCode,
        priceTable   = TuningManager.getPriceTable(),
        isVip        = exports.core:hasPermission(source, 'vip'),
        currencyCode = exports.settings:GetSetting('vehicles.default_currency_code', 'USD'),
        resetCost    = tonumber(exports.settings:GetSettingNumber('tuning.reset_mods_cost',     1500)),
        colorCost    = tonumber(exports.settings:GetSettingNumber('tuning.color_change_cost',    500)),
        liveryCost   = tonumber(exports.settings:GetSettingNumber('tuning.livery_change_cost',  1000)),
        vipDiscount  = tonumber(exports.settings:GetSettingNumber('tuning.vip_discount',        0.15)),
        categories   = TuningData.ModCategories,
        tierLabels   = TuningData.TierLabels,
        vipOnlyMods  = TuningData.VipOnlyMods,
    }
end

RegisterNetEvent('tuning:server:openShop', function(plate, shopCode)
    local source = source

    local character = exports.characters:getActiveCharacter(source)
    if not character then return end

    local vehicle = exports.vehicles:getOwnedVehicleByPlate(plate)
    if not vehicle then
        TriggerClientEvent('tuning:client:openFailed', source, 'Vehiculul nu este înregistrat în sistem.')
        return
    end

    if not exports.vehicles:hasVehicleKey(vehicle.id, character.id) then
        TriggerClientEvent('tuning:client:openFailed', source, 'Nu ai cheie pentru acest vehicul.')
        return
    end

    if vehicle.impounded then
        TriggerClientEvent('tuning:client:openFailed', source, 'Vehiculul este sechestrat.')
        return
    end

    local config = buildTuningConfig(source, shopCode)
    TriggerClientEvent('tuning:client:openUI', source, vehicle, config)
end)

RegisterNetEvent('tuning:server:applyMod', function(vehicleId, category, tier, paymentMethod, shopCode, extra)
    local source = source

    local success, err, newMods = TuningManager.applyMod(
        source, vehicleId, category, tier, paymentMethod, shopCode, extra
    )

    if success then
        TriggerClientEvent('switcore:notify', source, 'success', 'Mod aplicat cu succes!', 4000)
        TriggerClientEvent('tuning:client:modApplied', source, category, tier, newMods)
    else
        TriggerClientEvent('switcore:notify', source, 'error', err or 'Eroare la aplicare mod.', 5000)
        TriggerClientEvent('tuning:client:modFailed', source, category, tier)
    end
end)

RegisterNetEvent('tuning:server:applyColor', function(vehicleId, colorPrimary, colorSecondary, paymentMethod, shopCode, colorPearl)
    local source = source

    local success, err, newMods = TuningManager.applyColor(
        source, vehicleId, colorPrimary, colorSecondary, paymentMethod, shopCode, colorPearl
    )

    if success then
        TriggerClientEvent('switcore:notify', source, 'success', 'Culoare aplicată!', 4000)
        TriggerClientEvent('tuning:client:colorApplied', source, colorPrimary, colorSecondary, newMods)
    else
        TriggerClientEvent('switcore:notify', source, 'error', err or 'Eroare la vopsire.', 5000)
        TriggerClientEvent('tuning:client:modFailed', source, 'color', 0)
    end
end)

RegisterNetEvent('tuning:server:applyLivery', function(vehicleId, liveryIndex, paymentMethod, shopCode)
    local source = source

    local success, err, newMods = TuningManager.applyLivery(
        source, vehicleId, liveryIndex, paymentMethod, shopCode
    )

    if success then
        TriggerClientEvent('switcore:notify', source, 'success', 'Liverie aplicată!', 4000)
        TriggerClientEvent('tuning:client:liveryApplied', source, liveryIndex, newMods)
    else
        TriggerClientEvent('switcore:notify', source, 'error', err or 'Eroare la liverie.', 5000)
        TriggerClientEvent('tuning:client:modFailed', source, 'livery', liveryIndex)
    end
end)

-- Procesează coșul secvențial; la prima eroare oprește (modificările deja aplicate rămân persistate).
RegisterNetEvent('tuning:server:applyCart', function(vehicleId, cartItems, paymentMethod, shopCode)
    local source = source

    if not cartItems or #cartItems == 0 then
        TriggerClientEvent('switcore:notify', source, 'error', 'Coșul este gol.', 4000)
        return
    end

    local applied   = {}
    local finalMods = nil

    for _, item in ipairs(cartItems) do
        local success, err, newMods

        if item.category == 'color' then
            success, err, newMods = TuningManager.applyColor(
                source, vehicleId, item.colorPrimary, item.colorSecondary, paymentMethod, shopCode, item.colorPearl)
        elseif item.category == 'livery' then
            success, err, newMods = TuningManager.applyLivery(
                source, vehicleId, item.tier, paymentMethod, shopCode)
        else
            success, err, newMods = TuningManager.applyMod(
                source, vehicleId, item.category, item.tier, paymentMethod, shopCode,
                { subIndex = item.subIndex })
        end

        if success then
            finalMods = newMods
            table.insert(applied, { category = item.category, tier = item.tier, success = true })
        else
            table.insert(applied, { category = item.category, tier = item.tier, success = false, err = err })
            TriggerClientEvent('tuning:client:cartApplied', source, applied, finalMods)
            TriggerClientEvent('switcore:notify', source, 'error',
                'Coș: eroare la ' .. tostring(item.category) .. ' - ' .. (err or 'eroare necunoscută'), 5000)
            return
        end
    end

    TriggerClientEvent('tuning:client:cartApplied', source, applied, finalMods)
    TriggerClientEvent('switcore:notify', source, 'success',
        string.format('Coș: %d upgrade(uri) aplicate!', #applied), 4000)
end)

RegisterNetEvent('tuning:server:resetMods', function(vehicleId, paymentMethod, shopCode)
    local source = source

    local success, err = TuningManager.resetMods(source, vehicleId, paymentMethod, shopCode)

    if success then
        TriggerClientEvent('switcore:notify', source, 'success', 'Mods resetate la stock!', 4000)
        TriggerClientEvent('tuning:client:modsReset', source)
    else
        TriggerClientEvent('switcore:notify', source, 'error', err or 'Eroare la resetare.', 5000)
    end
end)
