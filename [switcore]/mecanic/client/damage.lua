local POLL_MS        = 300
local SYNC_COOLDOWN  = 4000
local MIN_DELTA      = 40.0   -- delta minima body_health pentru a considera coliziune
local ENGINE_RATIO   = 0.20   -- cat din body damage se transfera la motor

local lastBodyHealth    = 1000.0
local lastSyncTime      = 0
local pendingDamage     = nil

local cachedVehicleData = nil
local cachedPlate       = nil
local wasInVehicle      = false

local wheelIndexMap = { fl=0, fr=1, rl=4, rr=5 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function computeCompDegradation(severity, components)
    local delta = {}

    local suspDeg = math.floor(severity * 35)
    if suspDeg > 0 then
        if not delta.suspension then delta.suspension = {} end
        local positions = {'fl','fr','rl','rr'}
        local count = severity > 0.5 and 2 or 1
        for i = 1, count do
            local pos = positions[math.random(1, #positions)]
            local current = (components.suspension and components.suspension[pos]) or 100
            delta.suspension[pos] = math.max(0, current - math.floor(suspDeg * math.random(60, 100) / 100))
        end
    end

    if severity > 0.55 then
        local tireDeg = math.floor((severity - 0.55) * 65)
        if tireDeg > 0 then
            if not delta.tires then delta.tires = {} end
            local positions = {'fl','fr','rl','rr'}
            local pos = positions[math.random(1, #positions)]
            local current = (components.tires and components.tires[pos]) or 100
            delta.tires[pos] = math.max(0, current - tireDeg)
        end
    end

    if severity > 0.70 then
        local exhaustDeg = math.floor((severity - 0.70) * 55)
        local current = components.exhaust or 100
        delta.exhaust = math.max(0, current - exhaustDeg)
    end

    return delta
end

-- Merge acumuland cel mai rau scenariu (damage nu poate imbunatati componenta)
local function mergePending(existing, vehicleId, bodyHealth, engineHealth, compDelta)
    if not existing then
        return {
            vehicleId    = vehicleId,
            bodyHealth   = bodyHealth,
            engineHealth = engineHealth,
            components   = compDelta,
        }
    end
    existing.bodyHealth   = math.min(existing.bodyHealth,   bodyHealth)
    existing.engineHealth = math.min(existing.engineHealth, engineHealth)
    for k, v in pairs(compDelta) do
        if type(v) == 'table' then
            if not existing.components[k] then existing.components[k] = {} end
            for pos, val in pairs(v) do
                if not existing.components[k][pos] or val < existing.components[k][pos] then
                    existing.components[k][pos] = val
                end
            end
        else
            if not existing.components[k] or v < existing.components[k] then
                existing.components[k] = v
            end
        end
    end
    return existing
end

local function flushDamage()
    if pendingDamage then
        TriggerServerEvent('mecanic:server:vehicleDamaged', pendingDamage)
        pendingDamage = nil
        lastSyncTime  = GetGameTimer()
    end
end

CreateThread(function()
    while true do
        Wait(POLL_MS)

        local ped = PlayerPedId()

        if not IsPedInAnyVehicle(ped, false) then
            if wasInVehicle then
                flushDamage()
                wasInVehicle      = false
                cachedVehicleData = nil
                cachedPlate       = nil
            end
            lastBodyHealth = 1000.0
            goto continue
        end

        local vehicle = GetVehiclePedIsIn(ped, false)
        if not DoesEntityExist(vehicle) then goto continue end
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then goto continue end

        wasInVehicle = true

        local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
        if plate ~= cachedPlate then
            cachedPlate = plate
            local ok, vd = pcall(function()
                return exports.vehicles:getOwnedVehicleByPlate(plate)
            end)
            cachedVehicleData = (ok and vd) or nil
            lastBodyHealth    = GetVehicleBodyHealth(vehicle)
            goto continue
        end

        -- Fara cachedVehicleData = vehicul NPC, nu trimitem damage
        if not cachedVehicleData then goto continue end

        local currentBody = GetVehicleBodyHealth(vehicle)
        local delta       = lastBodyHealth - currentBody

        if delta >= MIN_DELTA then
            local severity     = clamp(delta / 700.0, 0.0, 1.0)
            local currentEng   = GetVehicleEngineHealth(vehicle)
            local engineDmg    = delta * ENGINE_RATIO * (1.0 + severity * 0.6)
            local newEngine    = math.max(0.0, currentEng - engineDmg)

            SetVehicleEngineHealth(vehicle, newEngine)

            local components = cachedVehicleData.components
            if type(components) == 'string' then
                components = json.decode(components) or {}
            end
            if type(components) ~= 'table' then
                components = {
                    oil=100, battery=100, brakes=100, exhaust=100,
                    tires={fl=100,fr=100,rl=100,rr=100},
                    suspension={fl=100,fr=100,rl=100,rr=100}
                }
            end

            local compDelta = computeCompDegradation(severity, components)

            if compDelta.tires then
                for pos, val in pairs(compDelta.tires) do
                    if val <= 0 then
                        local idx = wheelIndexMap[pos]
                        if idx then SetVehicleTyreBurst(vehicle, idx, false, 0.0) end
                    end
                end
            end

            pendingDamage = mergePending(
                pendingDamage,
                cachedVehicleData.id,
                currentBody,
                newEngine,
                compDelta
            )
        end

        lastBodyHealth = currentBody

        local now = GetGameTimer()
        if pendingDamage and (now - lastSyncTime) >= SYNC_COOLDOWN then
            flushDamage()
        end

        ::continue::
    end
end)
