
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

Sw.SecureEvent('tuning:server:openShop', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'plate',    type = 'string', minLen = 1, maxLen = 12 },
        { name = 'shopCode', type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local source  = ctx.source
    local plate   = ctx.args.plate
    local character = ctx.character

    local vehicle = exports.vehicles:getOwnedVehicleByPlate(plate)
    if not vehicle then
        return TriggerClientEvent('tuning:client:openFailed', source, Sw.TP(source, 'tuning.open_not_registered'))
    end

    if not exports.vehicles:hasVehicleKey(vehicle.id, character.id) then
        return TriggerClientEvent('tuning:client:openFailed', source, Sw.TP(source, 'tuning.open_no_key'))
    end

    if vehicle.impounded then
        return TriggerClientEvent('tuning:client:openFailed', source, Sw.TP(source, 'tuning.open_impounded'))
    end

    local config = buildTuningConfig(source, ctx.args.shopCode)
    TriggerClientEvent('tuning:client:openUI', source, vehicle, config)
end)

Sw.SecureEvent('tuning:server:applyMod', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'vehicleId',     type = 'int', min = 1 },
        { name = 'category',      type = 'string', minLen = 1, maxLen = 64 },
        { name = 'tier',          type = 'int', min = 0 },
        { name = 'paymentMethod', type = 'string', minLen = 1, maxLen = 32 },
        { name = 'shopCode',      type = 'string', minLen = 1, maxLen = 64 },
        { name = 'extra',         type = 'table', optional = true },
    },
}, function(ctx)
    local source = ctx.source
    local a = ctx.args

    local success, err, newMods = TuningManager.applyMod(
        source, a.vehicleId, a.category, a.tier, a.paymentMethod, a.shopCode, a.extra
    )

    if success then
        ctx.success(Sw.TP(ctx.source, 'tuning.mod_applied'), 4000)
        TriggerClientEvent('tuning:client:modApplied', source, a.category, a.tier, newMods)
    else
        ctx.error(err or Sw.TP(ctx.source, 'tuning.error_apply_mod'), 5000)
        TriggerClientEvent('tuning:client:modFailed', source, a.category, a.tier)
    end
end)

Sw.SecureEvent('tuning:server:applyColor', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'vehicleId',      type = 'int', min = 1 },
        { name = 'colorPrimary',   type = 'int', min = 0 },
        { name = 'colorSecondary', type = 'int', min = 0 },
        { name = 'paymentMethod',  type = 'string', minLen = 1, maxLen = 32 },
        { name = 'shopCode',       type = 'string', minLen = 1, maxLen = 64 },
        { name = 'colorPearl',     type = 'int', min = 0, optional = true },
    },
}, function(ctx)
    local source = ctx.source
    local a = ctx.args

    local success, err, newMods = TuningManager.applyColor(
        source, a.vehicleId, a.colorPrimary, a.colorSecondary, a.paymentMethod, a.shopCode, a.colorPearl
    )

    if success then
        ctx.success(Sw.TP(ctx.source, 'tuning.color_applied'), 4000)
        TriggerClientEvent('tuning:client:colorApplied', source, a.colorPrimary, a.colorSecondary, newMods)
    else
        ctx.error(err or Sw.TP(ctx.source, 'tuning.error_apply_color'), 5000)
        TriggerClientEvent('tuning:client:modFailed', source, 'color', 0)
    end
end)

Sw.SecureEvent('tuning:server:applyLivery', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
    args = {
        { name = 'vehicleId',     type = 'int', min = 1 },
        { name = 'liveryIndex',   type = 'int', min = 0 },
        { name = 'paymentMethod', type = 'string', minLen = 1, maxLen = 32 },
        { name = 'shopCode',      type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local source = ctx.source
    local a = ctx.args

    local success, err, newMods = TuningManager.applyLivery(
        source, a.vehicleId, a.liveryIndex, a.paymentMethod, a.shopCode
    )

    if success then
        ctx.success(Sw.TP(ctx.source, 'tuning.livery_applied'), 4000)
        TriggerClientEvent('tuning:client:liveryApplied', source, a.liveryIndex, newMods)
    else
        ctx.error(err or Sw.TP(ctx.source, 'tuning.error_apply_livery'), 5000)
        TriggerClientEvent('tuning:client:modFailed', source, 'livery', a.liveryIndex)
    end
end)

-- Procesează coșul secvențial; la prima eroare oprește (modificările deja aplicate rămân persistate).
Sw.SecureEvent('tuning:server:applyCart', {
    character = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'vehicleId',     type = 'int', min = 1 },
        { name = 'cartItems',     type = 'table' },
        { name = 'paymentMethod', type = 'string', minLen = 1, maxLen = 32 },
        { name = 'shopCode',      type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local source    = ctx.source
    local vehicleId = ctx.args.vehicleId
    local cartItems = ctx.args.cartItems
    local paymentMethod = ctx.args.paymentMethod
    local shopCode  = ctx.args.shopCode

    if not cartItems or #cartItems == 0 then
        return ctx.error(Sw.TP(ctx.source, 'tuning.error_cart_empty'), 4000)
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
            ctx.error(Sw.TP(ctx.source, 'tuning.error_cart_item', tostring(item.category), err or Sw.TP(ctx.source, 'tuning.error_cart_unknown')), 5000)
            return
        end
    end

    TriggerClientEvent('tuning:client:cartApplied', source, applied, finalMods)
    ctx.success(Sw.TP(ctx.source, 'tuning.cart_applied', #applied), 4000)
end)

Sw.SecureEvent('tuning:server:resetMods', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'vehicleId',     type = 'int', min = 1 },
        { name = 'paymentMethod', type = 'string', minLen = 1, maxLen = 32 },
        { name = 'shopCode',      type = 'string', minLen = 1, maxLen = 64 },
    },
}, function(ctx)
    local source = ctx.source
    local a = ctx.args

    local success, err = TuningManager.resetMods(source, a.vehicleId, a.paymentMethod, a.shopCode)

    if success then
        ctx.success(Sw.TP(ctx.source, 'tuning.mods_reset'), 4000)
        TriggerClientEvent('tuning:client:modsReset', source)
    else
        ctx.error(err or Sw.TP(ctx.source, 'tuning.error_reset'), 5000)
    end
end)
