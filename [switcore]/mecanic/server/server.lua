exports.core:registerModuleLocales(GetCurrentResourceName())

local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function notify(src, notifType, title, message)
    TriggerClientEvent('notifications:client:send', src, {
        type = notifType, title = title, message = message, duration = 5000
    })
end

local function findSourceForChar(characterId)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local char = getActiveChar(src)
        if char and char.id == characterId then return src end
    end
    return nil
end

local function getCharJob(characterId)
    local ok, job = pcall(function()
        return exports.jobs:GetCharacterJob(characterId)
    end)
    return ok and job or nil
end

local function hasPermission(characterId, perm)
    local ok, result = pcall(function()
        return exports.jobs:HasJobPermission(characterId, perm)
    end)
    return ok and result == true
end

local function loadPrices()
    local s = exports.settings
    Config.Prices.inspect          = s:GetSettingNumber('mecanic.inspect_price',          200)
    Config.Prices.oil_change       = s:GetSettingNumber('mecanic.oil_change_price',       400)
    Config.Prices.brakes           = s:GetSettingNumber('mecanic.brakes_price',           500)
    Config.Prices.tire             = s:GetSettingNumber('mecanic.tire_price',             300)
    Config.Prices.suspension       = s:GetSettingNumber('mecanic.suspension_price',       800)
    Config.Prices.battery          = s:GetSettingNumber('mecanic.battery_price',          600)
    Config.Prices.engine           = s:GetSettingNumber('mecanic.engine_price',           1500)
    Config.Prices.bodywork         = s:GetSettingNumber('mecanic.bodywork_price',         800)
    Config.Prices.roadside_engine  = s:GetSettingNumber('mecanic.roadside_engine_price',  2000)
    Config.Prices.roadside_tire    = s:GetSettingNumber('mecanic.roadside_tire_price',    600)
    Config.Prices.roadside_battery = s:GetSettingNumber('mecanic.roadside_battery_price', 500)
    Config.Prices.roadside_tow     = s:GetSettingNumber('mecanic.roadside_tow_price',     1500)
    Config.Bonus[0] = s:GetSettingNumber('mecanic.bonus_grade_0', 8)
    Config.Bonus[1] = s:GetSettingNumber('mecanic.bonus_grade_1', 12)
    Config.Bonus[2] = s:GetSettingNumber('mecanic.bonus_grade_2', 18)
    Config.Bonus[3] = s:GetSettingNumber('mecanic.bonus_grade_3', 25)

    -- mecanic.workshop_locations (array) e noua sursa canonica, editabila din
    -- panoul de setari (JSON generic). Daca lipseste, incapsulam vechea setare
    -- unica mecanic.workshop_coords intr-o lista cu o singura intrare, fara migrare.
    local locationsRaw = s:GetSettingJSON('mecanic.workshop_locations', nil)
    if locationsRaw and #locationsRaw > 0 then
        Config.WorkshopLocations = locationsRaw
    else
        local coordsRaw = s:GetSettingJSON('mecanic.workshop_coords', { x=375.84, y=-1888.77, z=29.41 })
        if coordsRaw then
            Config.WorkshopLocations = { {
                x = coordsRaw.x, y = coordsRaw.y, z = coordsRaw.z,
                radius = s:GetSettingNumber('mecanic.workshop_radius', 25.0),
            } }
        end
    end

    TriggerClientEvent('mecanic:client:workshopLocations', -1, Config.WorkshopLocations)
end

-- Semanam si setarea noua (goala implicit -> foloseste fallback-ul de mai sus)
-- ca sa apara editabila in panoul de setari, la fel ca celelalte preturi.
local function seedWorkshopLocationsSetting()
    local ok = pcall(function()
        exports.postgres:query(
            'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
            {
                'mecanic.workshop_locations',
                '[]',
                'Lista atelierelor mecanic [JSON array cu x,y,z,radius]. Daca e goala, se foloseste mecanic.workshop_coords (o singura locatie).',
            }
        )
    end)
    if ok then
        pcall(function() exports.settings:ReloadSettings() end)
    end
end

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    seedWorkshopLocationsSetting()
    loadPrices()
    print('[MECANIC] Sistem mecanic initializat')
end)

-- Jucatorii care se conecteaza dupa pornirea serverului nu prind broadcast-ul
-- initial (-1) din loadPrices; le trimitem lista la incarcarea personajului.
RegisterNetEvent('switcore:characterLoaded', function(character)
    if not character then return end
    local src = source
    TriggerClientEvent('mecanic:client:workshopLocations', src, Config.WorkshopLocations)
end)

function CompleteService(mechanicSrc, clientSrc, vehicleId, serviceType, price, clientCharId, mechanicCharId)
    local currencyId = MecanicDB.getRonCurrencyId()
    if not currencyId then
        notify(mechanicSrc, 'error', Sw.TP(mechanicSrc, 'mecanic.err_generic'), Sw.TP(mechanicSrc, 'mecanic.ron_currency_missing'))
        return false
    end

    if not exports.banking:tryDeductCharacterCash(clientCharId, currencyId, price) then
        notify(mechanicSrc, 'error', Sw.TP(mechanicSrc, 'mecanic.payment_failed'), Sw.TP(mechanicSrc, 'mecanic.client_no_funds'))
        notify(clientSrc, 'error', Sw.TP(clientSrc, 'mecanic.insufficient_funds'), Sw.TP(clientSrc, 'mecanic.client_insufficient_funds'))
        return false
    end

    local orgOk = pcall(function()
        exports.banking:orgSystemCredit(
            Config.OrgCode, price, currencyId,
            Sw.T('mecanic.tx_service', serviceType)
        )
    end)
    if not orgOk then
        exports.banking:addCharacterCash(clientCharId, currencyId, price)
        notify(mechanicSrc, 'error', Sw.TP(mechanicSrc, 'mecanic.err_internal'), Sw.TP(mechanicSrc, 'mecanic.money_refunded'))
        return false
    end

    local grade = 0
    local job   = getCharJob(mechanicCharId)
    if job then grade = job.grade or 0 end
    local bonusPct = Config.Bonus[grade] or 8
    local bonus    = math.floor(price * bonusPct / 100)

    if bonus > 0 then
        pcall(function()
            exports.banking:orgSystemDebit(Config.OrgCode, bonus, currencyId, Sw.T('mecanic.tx_bonus'))
            exports.banking:addCharacterCash(mechanicCharId, currencyId, bonus)
        end)
    end

    MecanicDB.logService(mechanicCharId, clientCharId, vehicleId, serviceType, price, bonus)

    notify(clientSrc, 'error', Sw.TP(clientSrc, 'mecanic.service_paid_title'),
        Sw.TP(clientSrc, 'mecanic.service_paid_msg', price, serviceType))
    notify(mechanicSrc, 'success', Sw.TP(mechanicSrc, 'mecanic.service_done_title'),
        Sw.TP(mechanicSrc, 'mecanic.service_bonus_msg', bonus, bonusPct))

    return true
end

function BroadcastCallToMechanics(callData)
    local ok, roster = pcall(function() return exports.jobs:GetJobRoster(Config.JobName) end)
    if not ok or not roster then return end

    local onDutySet = {}
    for _, m in ipairs(roster) do
        if m.is_on_duty then onDutySet[m.id] = true end
    end

    for _, pid in ipairs(GetPlayers()) do
        local src  = tonumber(pid)
        local char = getActiveChar(src)
        if char and onDutySet[char.id] and hasPermission(char.id, 'roadside') then
            TriggerClientEvent('mecanic:client:newServiceCall', src, callData)
        end
    end
end
