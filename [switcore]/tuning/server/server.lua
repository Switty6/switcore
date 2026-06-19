exports.core:registerModuleLocales(GetCurrentResourceName())

local function SeedSettings()
    local defaults = {
        { 'tuning.reset_mods_cost',     '1500', 'Cost resetare mods la stock ($)' },
        { 'tuning.color_change_cost',   '500',  'Cost schimbare culoare/vopsea vehicul ($)' },
        { 'tuning.livery_change_cost',  '1000', 'Cost aplicare liverie vehicul ($)' },
        { 'tuning.vip_discount',        '0.15', 'Reducere pentru jucători VIP (0.15 = 15%)' },
        { 'tuning.interaction_distance','3.0',  'Raza de interacțiune la shop-urile de tuning (m)' },
    }
    for _, row in ipairs(defaults) do
        exports.postgres:query(
            'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
            row
        )
    end
    print('[TUNING] Settings preincarcat.')
end

local function CreateSchema()
    local path = GetResourcePath(GetCurrentResourceName()) .. '/schema.sql'
    local file = io.open(path, 'r')
    if not file then
        print('[TUNING] EROARE: schema.sql lipsește!')
        return
    end
    local sql = file:read('*a')
    file:close()
    exports.postgres:query(sql, {})
    print('[TUNING] Schema DB creată/verificată.')
end

local function Initialize()
    CreateSchema()
    SeedSettings()
    TuningDatabase.seedShops(TuningData.Shops)
    TuningDatabase.seedPrices(TuningData.PriceSeed)
    TuningManager.reloadPriceCache()

    local shops = TuningDatabase.getActiveShops()
    if shops then
        TriggerClientEvent('tuning:client:initShops', -1, shops)
    end

    print(string.format('[TUNING] Inițializat - %d shop-uri, %d prețuri.',
        #TuningData.Shops, #TuningData.PriceSeed))
end

CreateThread(function()
    while not exports.postgres:isReady() do Wait(500) end
    while not exports.settings:IsReady() do Wait(500) end
    Initialize()
end)

AddEventHandler('playerSpawned', function()
    local source = source
    local shops  = TuningDatabase.getActiveShops()
    if shops then
        TriggerClientEvent('tuning:client:initShops', source, shops)
    end
end)

Sw.SecureEvent('tuning:server:requestShops', {
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local shops = TuningDatabase.getActiveShops()
    if shops then
        TriggerClientEvent('tuning:client:initShops', ctx.source, shops)
    end
end)
