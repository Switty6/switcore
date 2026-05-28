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

    local coordsRaw = s:GetSettingJSON('mecanic.workshop_coords', { x=375.84, y=-1888.77, z=29.41 })
    if coordsRaw then
        Config.WorkshopCoords = vector3(coordsRaw.x, coordsRaw.y, coordsRaw.z)
    end
end

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    loadPrices()
    print('[MECANIC] Sistem mecanic initializat')
end)

function CompleteService(mechanicSrc, clientSrc, vehicleId, serviceType, price, clientCharId, mechanicCharId)
    local currencyId = MecanicDB.getRonCurrencyId()
    if not currencyId then
        notify(mechanicSrc, 'error', 'Eroare', 'Valuta RON nu a fost gasita.')
        return false
    end

    if not exports.banking:tryDeductCharacterCash(clientCharId, currencyId, price) then
        notify(mechanicSrc, 'error', 'Plata esecata', 'Clientul nu are fonduri suficiente.')
        notify(clientSrc, 'error', 'Fonduri insuficiente', 'Nu ai destui bani pentru acest serviciu.')
        return false
    end

    local orgOk = pcall(function()
        exports.banking:orgSystemCredit(
            Config.OrgCode, price, currencyId,
            'Serviciu: ' .. serviceType
        )
    end)
    if not orgOk then
        exports.banking:addCharacterCash(clientCharId, currencyId, price)
        notify(mechanicSrc, 'error', 'Eroare interna', 'Banii au fost restituiti clientului.')
        return false
    end

    local grade = 0
    local job   = getCharJob(mechanicCharId)
    if job then grade = job.grade or 0 end
    local bonusPct = Config.Bonus[grade] or 8
    local bonus    = math.floor(price * bonusPct / 100)

    if bonus > 0 then
        pcall(function()
            exports.banking:orgSystemDebit(Config.OrgCode, bonus, currencyId, 'Bonus mecanic')
            exports.banking:addCharacterCash(mechanicCharId, currencyId, bonus)
        end)
    end

    MecanicDB.logService(mechanicCharId, clientCharId, vehicleId, serviceType, price, bonus)

    notify(clientSrc, 'error', 'Plata serviciu',
        string.format('Ai platit %d RON pentru %s.', price, serviceType))
    notify(mechanicSrc, 'success', 'Serviciu finalizat',
        string.format('Ai primit bonus %d RON (%d%%).', bonus, bonusPct))

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
