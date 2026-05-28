local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function getCharJob(characterId)
    local ok, job = pcall(function()
        return exports.jobs:GetCharacterJob(characterId)
    end)
    return ok and job or nil
end

local function notify(src, notifType, title, message)
    TriggerClientEvent('notifications:client:send', src, {
        type = notifType, title = title, message = message, duration = 5000
    })
end

function FindSourceForChar(characterId)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local char = getActiveChar(src)
        if char and char.id == characterId then return src end
    end
    return nil
end

local function loadConfig()
    local s = exports.settings
    Config.GradeRate[0] = s:GetSettingNumber('taxi.rate_per_km_0', 80)
    Config.GradeRate[1] = s:GetSettingNumber('taxi.rate_per_km_1', 100)
    Config.GradeRate[2] = s:GetSettingNumber('taxi.rate_per_km_2', 130)
    Config.GradeRate[3] = Config.GradeRate[2]
    Config.DispatchRadius = s:GetSettingNumber('taxi.dispatch_radius', 5000)
    Config.VehicleModel   = s:GetSettingNumber('taxi.vehicle_model', 'taxi')
    Config.PromotionThresholds[1] = s:GetSettingNumber('taxi.promo_grade_1', 20)
    Config.PromotionThresholds[2] = s:GetSettingNumber('taxi.promo_grade_2', 75)
    local coordsRaw = s:GetSettingJSON('taxi.hiring_coords', { x = -69.0, y = -1763.0, z = 29.0 })
    if coordsRaw then
        Config.HiringCoords = vector3(coordsRaw.x, coordsRaw.y, coordsRaw.z)
    end
end

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    loadConfig()
    print('[TAXI] Sistem taxi initializat')
end)

-- GTA world units * 0.001 ≈ km
local function calcDistanceKm(p1, p2)
    local dx = (p2.x - p1.x) * 0.001
    local dy = (p2.y - p1.y) * 0.001
    return math.sqrt(dx * dx + dy * dy)
end

function CalculatePay(driverCharId, distanceKm)
    local job  = getCharJob(driverCharId)
    local grade = job and job.grade or 0
    local rate  = Config.GradeRate[grade] or Config.GradeRate[0]
    return math.max(1, math.floor(distanceKm * rate))
end

function BroadcastOrderToDrivers(orderData)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local char = getActiveChar(src)
        if char then
            local job = getCharJob(char.id)
            if job and job.name == Config.JobName and job.isOnDuty then
                TriggerClientEvent('taxi:client:newOrder', src, orderData)
            end
        end
    end
end

function CheckPromotion(driverCharId, driverSrc)
    local stats = TaxiDB.getStats(driverCharId)
    if not stats then return end
    local job = getCharJob(driverCharId)
    if not job or job.name ~= Config.JobName then return end
    local cur = job.grade or 0
    for grade = 2, 1, -1 do
        local threshold = Config.PromotionThresholds[grade]
        if threshold and cur < grade and (stats.total_trips + 0) >= threshold then
            exports.jobs:SetCharacterGrade(driverCharId, grade)
            local updated = exports.jobs:GetCharacterJob(driverCharId)
            TriggerClientEvent('jobs:client:jobUpdated', driverSrc, updated)
            notify(driverSrc, 'success', 'Promovare!',
                'Ai avansat la ' .. (updated and updated.gradeLabel or 'grad nou') .. '!')
            return
        end
    end
end
