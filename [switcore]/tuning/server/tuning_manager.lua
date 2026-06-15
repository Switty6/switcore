
TuningManager = {}

-- { [category] = { [tier] = { price = number, vipOnly = bool } } }
local priceCache = {}

function TuningManager.reloadPriceCache()
    local rows = TuningDatabase.getAllPrices()
    priceCache = {}

    if rows then
        for _, row in ipairs(rows) do
            local cat  = row.category
            local tier = tonumber(row.tier)
            if not priceCache[cat] then priceCache[cat] = {} end
            priceCache[cat][tier] = {
                price   = tonumber(row.price),
                vipOnly = row.vip_only,
            }
        end
    end

    local count = 0
    for _ in pairs(priceCache) do count = count + 1 end
    print(string.format('[TUNING] Price cache reîncărcat - %d categorii.', count))
end

function TuningManager.getPriceTable()
    return priceCache
end

local function decodeMods(raw)
    if not raw then return {} end
    if type(raw) == 'string' then return json.decode(raw) or {} end
    return raw
end

local function isVipMod(category, tier)
    local list = TuningData.VipOnlyMods[category]
    if not list then return false end
    for _, v in ipairs(list) do
        if v == tier then return true end
    end
    return false
end

local function resolveCurrencyId(_currencyCode)
    local currencies = exports.banking:getActiveCurrencies()
    if not currencies or #currencies == 0 then return nil end
    return currencies[1].id
end

local function chargePlayer(source, characterId, amount, paymentMethod, currencyId)
    if amount <= 0 then return true, nil, function() end end

    if paymentMethod == 'cash' then
        if not exports.banking:tryDeductCharacterCash(characterId, currencyId, amount) then
            return false, Sw.TP(source, 'tuning.error_insufficient_cash')
        end
        return true, nil, function()
            exports.banking:addCharacterCash(characterId, currencyId, amount)
        end
    end

    local accounts = exports.banking:getCharacterAccounts(characterId)
    if not accounts or #accounts == 0 then return false, Sw.TP(source, 'tuning.error_no_bank_account') end
    local accountId = accounts[1].id

    if not exports.banking:removeAccountBalance(accountId, currencyId, amount) then
        return false, Sw.TP(source, 'tuning.error_insufficient_bank')
    end
    return true, nil, function()
        exports.banking:addAccountBalance(accountId, currencyId, amount)
    end
end

local function validateRequest(source, vehicleId)
    local character = exports.characters:getActiveCharacter(source)
    if not character then return nil, nil, Sw.TP(source, 'tuning.error_no_character') end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return nil, nil, Sw.TP(source, 'tuning.error_no_vehicle') end

    if not exports.vehicles:hasVehicleKey(vehicleId, character.id) then
        return nil, nil, Sw.TP(source, 'tuning.error_no_key')
    end

    if vehicle.impounded then
        return nil, nil, Sw.TP(source, 'tuning.error_impounded')
    end

    return character, vehicle, nil
end

function TuningManager.calculateUpgradeCost(vehicleId, category, targetTier)
    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return nil, Sw.T('tuning.error_no_vehicle') end

    local catPrices = priceCache[category]
    if not catPrices then return nil, Sw.T('tuning.error_invalid_category') end

    local targetEntry = catPrices[targetTier]
    if not targetEntry then return nil, Sw.T('tuning.error_invalid_tier') end

    local mods        = decodeMods(vehicle.modifications)
    local currentTier = tonumber(mods[category]) or 0

    if currentTier == targetTier then return 0, nil end

    -- Plătești doar diferența față de tier-ul curent; downgrade nu rambursează (cost = 0).
    local currentPrice = 0
    if currentTier > 0 and catPrices[currentTier] then
        currentPrice = catPrices[currentTier].price
    end

    local cost = math.max(0, targetEntry.price - currentPrice)
    return cost, nil
end

function TuningManager.applyMod(source, vehicleId, category, tier, paymentMethod, shopCode, extra)
    local character, vehicle, err = validateRequest(source, vehicleId)
    if err then return false, err end
    extra = extra or {}

    if isVipMod(category, tier) then
        if not exports.core:hasPermission(source, 'vip') then
            return false, Sw.TP(source, 'tuning.error_vip_required')
        end
    end

    local cost, costErr = TuningManager.calculateUpgradeCost(vehicleId, category, tier)
    if cost == nil then return false, costErr end

    if cost > 0 and exports.core:hasPermission(source, 'vip') then
        local disc = tonumber(exports.settings:GetSettingNumber('tuning.vip_discount', 0.15))
        cost = math.floor(cost * (1.0 - disc))
    end

    local refund = function() end
    if cost > 0 then
        local currCode = exports.settings:GetSetting('vehicles.default_currency_code', 'USD')
        local currId   = resolveCurrencyId(currCode)
        if not currId then return false, Sw.TP(source, 'tuning.error_currency_unavailable') end

        local paid, payErr, refundFn = chargePlayer(source, character.id, cost, paymentMethod, currId)
        if not paid then return false, payErr end
        refund = refundFn
    end

    local mods        = decodeMods(vehicle.modifications)
    local tierBefore  = tonumber(mods[category]) or 0
    mods[category]    = tier
    if category == 'wheels' and extra.subIndex ~= nil then
        mods['wheels_index'] = tonumber(extra.subIndex)
    end

    local saved = exports.vehicles:saveVehicleState(vehicleId, { modifications = mods })
    if not saved then
        refund()
        print(string.format('[TUNING] WARN: saveVehicleState eșuat pentru vehicul %d - refund aplicat', vehicleId))
        return false, Sw.TP(source, 'tuning.error_save_mod')
    end

    local shopId = nil
    if shopCode then
        local shop = TuningDatabase.getShopByCode(shopCode)
        if shop then shopId = shop.id end
    end
    TuningDatabase.insertLog(character.id, vehicleId, shopId, category, tierBefore, tier, cost)

    print(string.format('[TUNING] %s %s (char %d) - vehicul %d - %s: %d → %d (cost: $%s)',
        character.first_name, character.last_name, character.id,
        vehicleId, category, tierBefore, tier, tostring(cost)))

    return true, nil, mods
end

function TuningManager.applyColor(source, vehicleId, colorPrimary, colorSecondary, paymentMethod, shopCode, colorPearl)
    local character, vehicle, err = validateRequest(source, vehicleId)
    if err then return false, err end

    local cost    = tonumber(exports.settings:GetSettingNumber('tuning.color_change_cost', 500))
    local currCode = exports.settings:GetSetting('vehicles.default_currency_code', 'USD')
    local currId   = resolveCurrencyId(currCode)
    if not currId then return false, Sw.TP(source, 'tuning.error_currency_unavailable') end

    local refund = function() end
    if cost > 0 then
        local paid, payErr, refundFn = chargePlayer(source, character.id, cost, paymentMethod, currId)
        if not paid then return false, payErr end
        refund = refundFn
    end

    local mods = decodeMods(vehicle.modifications)
    if colorPrimary   then mods['color_primary']   = colorPrimary   end
    if colorSecondary then mods['color_secondary'] = colorSecondary end
    if colorPearl ~= nil then mods['color_pearl'] = tonumber(colorPearl) or 0 end

    if not exports.vehicles:saveVehicleState(vehicleId, { modifications = mods }) then
        refund()
        return false, Sw.TP(source, 'tuning.error_save_color')
    end

    local shopId = nil
    if shopCode then
        local shop = TuningDatabase.getShopByCode(shopCode)
        if shop then shopId = shop.id end
    end
    TuningDatabase.insertLog(character.id, vehicleId, shopId, 'color', nil, 0, cost)

    return true, nil, mods
end

function TuningManager.applyLivery(source, vehicleId, liveryIndex, paymentMethod, shopCode)
    local character, vehicle, err = validateRequest(source, vehicleId)
    if err then return false, err end

    local cost     = tonumber(exports.settings:GetSettingNumber('tuning.livery_change_cost', 1000))
    local currCode = exports.settings:GetSetting('vehicles.default_currency_code', 'USD')
    local currId   = resolveCurrencyId(currCode)
    if not currId then return false, Sw.TP(source, 'tuning.error_currency_unavailable') end

    local refund = function() end
    if cost > 0 then
        local paid, payErr, refundFn = chargePlayer(source, character.id, cost, paymentMethod, currId)
        if not paid then return false, payErr end
        refund = refundFn
    end

    local mods        = decodeMods(vehicle.modifications)
    local tierBefore  = tonumber(mods['livery'])
    mods['livery']    = liveryIndex

    if not exports.vehicles:saveVehicleState(vehicleId, { modifications = mods }) then
        refund()
        return false, Sw.TP(source, 'tuning.error_save_livery')
    end

    local shopId = nil
    if shopCode then
        local shop = TuningDatabase.getShopByCode(shopCode)
        if shop then shopId = shop.id end
    end
    TuningDatabase.insertLog(character.id, vehicleId, shopId, 'livery', tierBefore, liveryIndex, cost)

    return true, nil, mods
end

function TuningManager.resetMods(source, vehicleId, paymentMethod, shopCode)
    local character, vehicle, err = validateRequest(source, vehicleId)
    if err then return false, err end

    local cost     = tonumber(exports.settings:GetSettingNumber('tuning.reset_mods_cost', 1500))
    local currCode = exports.settings:GetSetting('vehicles.default_currency_code', 'USD')
    local currId   = resolveCurrencyId(currCode)
    if not currId then return false, Sw.TP(source, 'tuning.error_currency_unavailable') end

    local refund = function() end
    if cost > 0 then
        local paid, payErr, refundFn = chargePlayer(source, character.id, cost, paymentMethod, currId)
        if not paid then return false, payErr end
        refund = refundFn
    end

    if not exports.vehicles:saveVehicleState(vehicleId, { modifications = {}, replace_modifications = true }) then
        refund()
        return false, Sw.TP(source, 'tuning.error_save_reset')
    end

    local shopId = nil
    if shopCode then
        local shop = TuningDatabase.getShopByCode(shopCode)
        if shop then shopId = shop.id end
    end
    TuningDatabase.insertLog(character.id, vehicleId, shopId, 'reset', nil, 0, cost)

    print(string.format('[TUNING] %s %s (char %d) - vehicul %d - RESET stock (cost: $%d)',
        character.first_name, character.last_name, character.id, vehicleId, cost))

    return true, nil
end

function TuningManager.getVehicleMods(vehicleId)
    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then return nil, Sw.T('tuning.error_no_vehicle') end
    return decodeMods(vehicle.modifications), nil
end
