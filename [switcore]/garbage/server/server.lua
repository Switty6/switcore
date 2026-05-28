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
    TriggerClientEvent('switcore:notify', src, notifType, title .. ': ' .. message, 5000)
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
    Config.GradePay[0].perPoint = s:GetSettingNumber('garbage.pay_per_point_0', 50)
    Config.GradePay[1].perPoint = s:GetSettingNumber('garbage.pay_per_point_1', 65)
    Config.GradePay[2].perPoint = s:GetSettingNumber('garbage.pay_per_point_2', 80)
    Config.GradePay[0].bonus    = s:GetSettingNumber('garbage.route_bonus_0', 200)
    Config.GradePay[1].bonus    = Config.GradePay[0].bonus
    Config.GradePay[2].bonus    = s:GetSettingNumber('garbage.route_bonus_2', 350)
    Config.VehicleModel         = s:GetSetting('garbage.vehicle_model', 'trash')
    Config.PromotionThresholds[1] = s:GetSettingNumber('garbage.promo_grade_1', 10)
    Config.PromotionThresholds[2] = s:GetSettingNumber('garbage.promo_grade_2', 40)
    local coordsRaw = s:GetSettingJSON('garbage.hiring_coords', { x = 1175.0, y = -1562.0, z = 35.0 })
    if coordsRaw then
        Config.HiringCoords = vector3(coordsRaw.x, coordsRaw.y, coordsRaw.z)
    end
end

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    loadConfig()
    GarbageDB.abandonStaleSessions()
    print('[GARBAGE] Sistem salubritate initializat')
end)

function CalculateSessionPay(charId, collectedCount, isComplete)
    local job   = getCharJob(charId)
    local grade = job and job.grade or 0
    local cfg   = Config.GradePay[grade] or Config.GradePay[0]
    local pay   = collectedCount * cfg.perPoint
    if isComplete then pay = pay + cfg.bonus end
    return pay
end

function CheckGarbagePromotion(charId, src)
    local stats = GarbageDB.getStats(charId)
    if not stats then return end
    local job = getCharJob(charId)
    if not job or job.name ~= Config.JobName then return end
    local cur = job.grade or 0
    for grade = 2, 1, -1 do
        local threshold = Config.PromotionThresholds[grade]
        if threshold and cur < grade and stats.total_sessions >= threshold then
            exports.jobs:SetCharacterGrade(charId, grade)
            local updated = exports.jobs:GetCharacterJob(charId)
            TriggerClientEvent('jobs:client:jobUpdated', src, updated)
            notify(src, 'success', 'Promovare!',
                'Ai avansat la ' .. (updated and updated.gradeLabel or 'grad nou') .. '!')
            return
        end
    end
end
