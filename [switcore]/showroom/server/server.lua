local function SeedDefaultSettings()
    local defaults = {
        {
            key   = 'showroom.dealership_locations',
            value = json.encode({
                {
                    code           = 'pdm',
                    name           = 'Premium Deluxe Motorsport',
                    coords         = { x = -43.65, y = -1098.73, z = 26.42 },
                    testDriveSpawn = { x = -36.35, y = -1100.73, z = 26.42, heading = 90.0 },
                }
            }),
            desc  = 'Locatiile dealership-urilor [JSON array cu code,name,coords,testDriveSpawn]',
        },
        {
            key   = 'showroom.vehicle_catalog',
            value = json.encode({}),
            desc  = 'Catalogul de vehicule [JSON array cu model,label,category,price,dealership,...]',
        },
        { key = 'showroom.finance_min_price',           value = '50000',  desc = 'Pret minim pentru finantare' },
        { key = 'showroom.test_drive_duration_minutes', value = '5',      desc = 'Durata test drive (minute)' },
        { key = 'showroom.default_finance_bank_code',   value = 'MAZE',   desc = 'Banca default pentru credite auto' },
        { key = 'showroom.default_finance_term_months', value = '24',     desc = 'Termen default credit auto (luni)' },
        { key = 'showroom.finance_interest_rate',       value = '0.08',   desc = 'Rata dobanda credit auto (0.08 = 8%)' },
        { key = 'showroom.default_loan_type',           value = 'personal', desc = 'Tipul de credit default pentru showroom (personal/mortgage/business)' },
    }
    for _, s in ipairs(defaults) do
        exports.postgres:query(
            'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
            { s.key, s.value, s.desc }
        )
    end
end

local function SeedDealerships()
    local dealershipLocations = exports.settings:GetSettingList('showroom.dealership_locations', {})
    local vehicleCatalog      = exports.settings:GetSettingList('showroom.vehicle_catalog', {})

    for _, loc in ipairs(dealershipLocations) do
        local dealership = ShowroomDatabase.upsertDealership(loc.code, loc.name, loc.coords, loc.npcModel)
        if dealership then
            print(string.format('[SHOWROOM] Dealership upsert: %s', loc.code))

            for _, entry in ipairs(vehicleCatalog) do
                if entry.dealership == loc.code then
                    ShowroomDatabase.seedCatalogItem(
                        dealership.id,
                        entry.model,
                        entry.label,
                        entry.category,
                        entry.price,
                        entry.financeEligible,
                        entry.vipOnly,
                        entry.sortOrder
                    )
                end
            end
        end
    end
    print('[SHOWROOM] Catalog preincarcat')
end

local function StartCleanupTask()
    CreateThread(function()
        while true do
            Wait(60000)
            ShowroomManager.cleanupExpiredTestDrives()
        end
    end)
end

local function InitializeShowroomSystem()
    SeedDefaultSettings()
    exports.settings:ReloadSettings()
    SeedDealerships()
    StartCleanupTask()
    print('[SHOWROOM] Sistem showroom inițializat')
end

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    ShowroomDatabase.ensureCatalogUniqueIndex()
    InitializeShowroomSystem()
end)

Sw.SecureEvent('showroom:server:getLocationConfig', {
    silent = true,
    rateLimit = { max = 5, window = 3000 },
}, function(ctx)
    local locations = exports.settings:GetSettingList('showroom.dealership_locations', {})
    TriggerClientEvent('showroom:client:locationConfig', ctx.source, { locations = locations })
end)
