local spawnedVehicles = {}
local ownedPlates     = {}
local tempKeys        = {}

local isInVehicle     = false
local inVehicleEntity = nil
local inVehicleId     = nil

function GetOwnedVehicleData(plate)
    return spawnedVehicles[plate:gsub('%s+', '')]
end

exports('GrantTempKey', function(plate)
    if type(plate) ~= 'string' then return false end
    tempKeys[plate:gsub('%s+', '')] = true
    return true
end)

exports('RevokeTempKey', function(plate)
    if type(plate) ~= 'string' then return false end
    tempKeys[plate:gsub('%s+', '')] = nil
    return true
end)

local function HasKeyForVehicle(entity)
    if not DoesEntityExist(entity) then return false end
    local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
    if ownedPlates[plate] == true or tempKeys[plate] == true then return true end
    for _, data in pairs(spawnedVehicles) do
        if data.entity == entity then return true end
    end
    return false
end

local function GetVehicleStateSnapshot(entity, vehicleId)
    local coords  = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)

    SetVehicleModKit(entity, 0)

    local mods = {}
    for i = 0, 48 do
        local v = GetVehicleMod(entity, i)
        if v >= 0 then mods[tostring(i)] = v end
    end

    local paintP, paintS = GetVehicleColours(entity)
    if GetIsVehiclePrimaryColourCustom(entity) then
        local r1, g1, b1 = GetVehicleCustomPrimaryColour(entity)
        mods['color_primary'] = string.format('#%02X%02X%02X', r1, g1, b1)
    else
        mods['paint_primary'] = paintP
    end
    if GetIsVehicleSecondaryColourCustom(entity) then
        local r2, g2, b2 = GetVehicleCustomSecondaryColour(entity)
        mods['color_secondary'] = string.format('#%02X%02X%02X', r2, g2, b2)
    else
        mods['paint_secondary'] = paintS
    end
    local livery = GetVehicleLivery(entity)
    if livery >= 0 then mods['livery'] = livery end

    local damage = { doors = {}, windows = {}, tires = {} }
    for i = 0, 7 do
        if IsVehicleDoorDamaged(entity, i) then damage.doors[tostring(i)] = true end
        if not IsVehicleWindowIntact(entity, i) then damage.windows[tostring(i)] = true end
        if IsVehicleTyreBurst(entity, i, false) then damage.tires[tostring(i)] = true end
    end
    mods['_damage'] = damage

    local _tankSnap = GetVehicleHandlingFloat(entity, 'CHandlingData', 'fPetrolTankVolume')
    if not _tankSnap or _tankSnap <= 0 then _tankSnap = 65.0 end
    return {
        fuel          = GetVehicleFuelLevel(entity) * 100.0 / _tankSnap,
        body_health   = GetVehicleBodyHealth(entity),
        engine_health = GetVehicleEngineHealth(entity),
        modifications = mods,
        last_position = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
    }
end

local function ApplyModsToVehicle(entity, mods)
    if not mods or type(mods) ~= 'table' then return end
    SetVehicleModKit(entity, 0)

    for key, value in pairs(mods) do
        local modIndex = tonumber(key)
        if modIndex then
            SetVehicleMod(entity, modIndex, tonumber(value) or -1, false)
        end
    end

    local paintP = tonumber(mods.paint_primary)
    local paintS = tonumber(mods.paint_secondary)
    if paintP or paintS then
        local curP, curS = GetVehicleColours(entity)
        SetVehicleColours(entity, paintP or curP, paintS or curS)
    end

    if mods.color_primary and type(mods.color_primary) == 'string' and mods.color_primary:sub(1,1) == '#' then
        local hex = mods.color_primary:sub(2)
        SetVehicleCustomPrimaryColour(entity,
            tonumber(hex:sub(1,2), 16) or 255,
            tonumber(hex:sub(3,4), 16) or 255,
            tonumber(hex:sub(5,6), 16) or 255)
    end
    if mods.color_secondary and type(mods.color_secondary) == 'string' and mods.color_secondary:sub(1,1) == '#' then
        local hex = mods.color_secondary:sub(2)
        SetVehicleCustomSecondaryColour(entity,
            tonumber(hex:sub(1,2), 16) or 0,
            tonumber(hex:sub(3,4), 16) or 0,
            tonumber(hex:sub(5,6), 16) or 0)
    end
    if mods.livery and tonumber(mods.livery) and tonumber(mods.livery) >= 0 then
        SetVehicleLivery(entity, tonumber(mods.livery))
    end

    local damage = mods._damage
    if damage and type(damage) == 'table' then
        for idxStr in pairs(damage.doors or {}) do
            SetVehicleDoorBroken(entity, tonumber(idxStr), true)
        end
        for idxStr in pairs(damage.windows or {}) do
            SmashVehicleWindow(entity, tonumber(idxStr))
        end
        for idxStr in pairs(damage.tires or {}) do
            SetVehicleTyreBurst(entity, tonumber(idxStr), true, 1000.0)
        end
    end
end

local function SpawnVehicle(data)
    local model = GetHashKey(data.model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then
        print(string.format('[VEHICLES-CLIENT] Model %s nu a putut fi încărcat', data.model))
        return nil
    end
    local spawnCoords, spawnHeading
    if data.lastPosition and data.lastPosition.x then
        spawnCoords  = vector3(data.lastPosition.x, data.lastPosition.y, data.lastPosition.z)
        spawnHeading = data.lastPosition.heading or 0.0
    else
        local ped     = PlayerPedId()
        local forward = GetEntityForwardVector(ped)
        local pos     = GetEntityCoords(ped)
        spawnCoords  = vector3(pos.x + forward.x * 5.0, pos.y + forward.y * 5.0, pos.z)
        spawnHeading = GetEntityHeading(ped)
    end
    local entity = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, true, false)
    SetVehicleNumberPlateText(entity, data.plate)
    SetVehicleEngineHealth(entity, data.engineHealth or 1000.0)
    SetVehicleBodyHealth(entity, data.bodyHealth or 1000.0)
    do
        local _tank = GetVehicleHandlingFloat(entity, 'CHandlingData', 'fPetrolTankVolume')
        if not _tank or _tank <= 0 then _tank = 65.0 end
        SetVehicleFuelLevel(entity, (data.fuel or 100.0) * _tank / 100.0)
    end
    ApplyModsToVehicle(entity, data.modifications)
    SetModelAsNoLongerNeeded(model)
    spawnedVehicles[data.plate:gsub('%s+', '')] = { vehicleId = data.vehicleId, entity = entity }
    if data.vehicleId then
        TriggerServerEvent('vehicles:server:vehicleSpawned', data.vehicleId, NetworkGetNetworkIdFromEntity(entity))
    end
    return entity
end

local function DespawnVehicle(plate, saveState)
    local cleanPlate = plate:gsub('%s+', '')
    local data = spawnedVehicles[cleanPlate]
    if not data then return end
    if DoesEntityExist(data.entity) then
        if saveState then
            local state = GetVehicleStateSnapshot(data.entity, data.vehicleId)
            state.stored = true
            TriggerServerEvent('vehicles:server:despawnVehicle', data.vehicleId, state)
        end
        DeleteEntity(data.entity)
    end
    spawnedVehicles[cleanPlate] = nil
end

local wasInVehicle  = false
local lockedVehicle = nil
local lockpickBusy  = false

local function RunLockpickSkillCheck()
    local barX, barY, barW, barH = 0.5, 0.82, 0.18, 0.02
    local zoneStart = 0.35 + math.random() * 0.35
    local zoneWidth = 0.14
    local pos, dir  = 0.0, 1.0
    local speed     = 0.9
    local deadline  = GetGameTimer() + 6000
    local result    = nil

    while result == nil do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)

        pos = pos + dir * speed * (1.0 / 60.0)
        if pos >= 1.0 then pos = 1.0; dir = -1.0 end
        if pos <= 0.0 then pos = 0.0; dir = 1.0 end

        DrawRect(barX, barY, barW, barH, 20, 20, 20, 180)
        DrawRect(barX - barW/2 + zoneStart*barW + (zoneWidth*barW)/2, barY, zoneWidth*barW, barH, 40, 200, 40, 200)
        DrawRect(barX - barW/2 + pos*barW, barY, 0.004, barH*1.6, 255, 255, 255, 230)

        if IsControlJustPressed(0, 38) then
            result = (pos >= zoneStart and pos <= zoneStart + zoneWidth)
        elseif GetGameTimer() > deadline then
            result = false
        end
    end

    return result
end

local function ClearLockedVehicle(vehicle)
    if lockedVehicle == vehicle then
        lockedVehicle = nil
    end
end

RegisterNetEvent('vehicles:client:lockpickResult', function(plate, success)
    local cleanPlate = plate:gsub('%s+', '')
    if success then
        tempKeys[cleanPlate] = true
        TriggerEvent('switcore:notify:local', 'success', Sw.T('vehicles.lockpick_success'), 4000)
        if lockedVehicle and DoesEntityExist(lockedVehicle)
           and GetVehicleNumberPlateText(lockedVehicle):gsub('%s+', '') == cleanPlate then
            SetVehicleUndriveable(lockedVehicle, false)
            ClearLockedVehicle(lockedVehicle)
        end
    end
end)

RegisterCommand('lockpick', function()
    if lockpickBusy or not lockedVehicle or not DoesEntityExist(lockedVehicle) then return end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= lockedVehicle then return end

    lockpickBusy = true
    local vehicle = lockedVehicle
    local plate   = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')

    CreateThread(function()
        local success = RunLockpickSkillCheck()
        lockpickBusy = false
        TriggerServerEvent('vehicles:server:lockpickAttempt', plate, success)
        if not success then
            TriggerEvent('switcore:notify:local', 'warning', Sw.T('vehicles.lockpick_failed'), 3500)
        end
    end)
end, false)
RegisterKeyMapping('lockpick', Sw.T('vehicles.keymap_lockpick'), 'keyboard', 'g')

CreateThread(function()
    while true do
        Wait(100)
        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                if not wasInVehicle then
                    wasInVehicle = true
                    local hasKey = HasKeyForVehicle(vehicle)
                    if hasKey then
                        SetVehicleEngineOn(vehicle, GetIsVehicleEngineRunning(vehicle), true, true)
                    else
                        SetVehicleEngineOn(vehicle, false, true, true)
                        SetVehicleUndriveable(vehicle, true)
                        lockedVehicle = vehicle
                        TriggerEvent('switcore:notify:local', 'error', Sw.T('vehicles.vehicle_locked_no_key_lockpick'), 5000)
                    end
                end
            else
                wasInVehicle = true
            end
        else
            wasInVehicle = false
            if lockedVehicle then
                if DoesEntityExist(lockedVehicle) then
                    SetVehicleUndriveable(lockedVehicle, false)
                end
                lockedVehicle = nil
            end
        end
    end
end)

RegisterCommand('toggleengine', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        if HasKeyForVehicle(vehicle) then
            local isEngineOn = GetIsVehicleEngineRunning(vehicle)
            if isEngineOn then
                SetVehicleEngineOn(vehicle, false, false, true)
                TriggerEvent('switcore:notify:local', 'info', Sw.T('vehicles.engine_off'), 3000)
            else
                SetVehicleEngineOn(vehicle, true, false, true)
                TriggerEvent('switcore:notify:local', 'success', Sw.T('vehicles.engine_on'), 3000)
            end
        else
            TriggerEvent('switcore:notify:local', 'error', Sw.T('vehicles.no_vehicle_access'), 3000)
        end
    end
end, false)
RegisterKeyMapping('toggleengine', Sw.T('vehicles.keymap_toggle_engine'), 'keyboard', 'y')

CreateThread(function()
    while true do
        Wait(500)

        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 then
            if not isInVehicle then
                isInVehicle     = true
                inVehicleEntity = vehicle

                local data = GetOwnedVehicleData(GetVehicleNumberPlateText(vehicle))
                inVehicleId      = data and data.vehicleId or nil
                currentVehicleKm = 0.0
                accumulatedKm    = 0.0

                if inVehicleId then
                    TriggerServerEvent('vehicles:server:requestMileage', inVehicleId)
                end
            end
        else
            if isInVehicle then
                if inVehicleId and inVehicleEntity and DoesEntityExist(inVehicleEntity) then
                    local state = GetVehicleStateSnapshot(inVehicleEntity, inVehicleId)
                    TriggerServerEvent('vehicles:server:saveVehicleState', inVehicleId, state)
                end
                isInVehicle      = false
                inVehicleEntity  = nil
                inVehicleId      = nil
                currentVehicleKm = 0.0
                accumulatedKm    = 0.0
            end
        end

    end
end)

local CLASS_BASE = {
    [0]  = 0.080,
    [1]  = 0.100,
    [2]  = 0.095,
    [3]  = 0.110,
    [4]  = 0.150,
    [5]  = 0.135,
    [6]  = 0.180,
    [7]  = 0.220,
    [8]  = 0.300,
    [9]  = 0.070,
    [10] = 0.055,
    [11] = 0.120,
    [12] = 0.065,
    [13] = 0.030,
    [14] = 0.450,
    [15] = 0.750,
    [16] = 0.680,
    [17] = 0.045,
    [18] = 0.040,
    [19] = 0.095,
    [20] = 0.085,
    [21] = 0.600,
    [22] = 0.045,
}

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function GetTankVolume(entity)
    local v = GetVehicleHandlingFloat(entity, 'CHandlingData', 'fPetrolTankVolume')
    if v and v > 0 then return v end
    return 65.0
end

local fuelConsumptionMult = 1.0
local mileageEnabled      = true
local currentVehicleKm    = 0.0
local accumulatedKm       = 0.0

RegisterNetEvent('vehicles:client:setFuelMultiplier', function(mult)
    fuelConsumptionMult = tonumber(mult) or 1.0
end)

RegisterNetEvent('vehicles:client:setMileageEnabled', function(enabled)
    mileageEnabled = enabled == true or enabled == 'true'
end)

RegisterNetEvent('vehicles:client:setCurrentMileage', function(vehicleId, km)
    if inVehicleId == tonumber(vehicleId) then
        currentVehicleKm = tonumber(km) or 0.0
        accumulatedKm = 0.0
    end
end)

exports('GetCurrentVehicleKm', function()
    if not isInVehicle then return nil end
    return currentVehicleKm + accumulatedKm
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('vehicles:server:requestFuelMultiplier')
end)

local function CalculateFuelConsumption(entity)
    local class = GetVehicleClass(entity)
    local base  = CLASS_BASE[class] or 0.100

    local mass = GetVehicleHandlingFloat(entity, 'CHandlingData', 'fMass')
    mass = mass and mass > 0 and mass or 1500.0
    local massFactor = Clamp(math.sqrt(mass / 1500.0), 0.4, 4.0)

    local occupants = GetVehicleNumberOfPassengers(entity) +
                      (GetPedInVehicleSeat(entity, -1) ~= 0 and 1 or 0)
    local occupantFactor = 1.0 + math.max(0, occupants - 1) * 0.035

    local rpm = GetVehicleCurrentRpm(entity)
    local rpmFactor = 0.18 + (rpm ^ 1.8) * 0.82

    local speedMs = GetEntitySpeed(entity)
    local speedKmh = speedMs * 3.6
    local speedFactor
    if speedKmh <= 80.0 then
        speedFactor = 0.12 + (speedKmh / 80.0) * 0.48
    else
        speedFactor = 0.60 + ((speedKmh - 80.0) / 80.0) ^ 1.4 * 0.40
    end
    speedFactor = Clamp(speedFactor, 0.12, 2.0)

    local throttle = GetControlNormal(0, 71)
    local throttleFactor = 0.08 + (throttle ^ 0.7) * 0.92

    local engHealth = GetVehicleEngineHealth(entity)
    local engRatio  = Clamp(engHealth / 1000.0, 0.0, 1.0)
    local engHealthFactor = 1.0 + (1.0 - engRatio) * 1.8

    local engModLevel = GetVehicleMod(entity, 11)
    engModLevel = math.max(0, engModLevel)
    local engModFactor = 1.0 - engModLevel * 0.04

    local turboFactor = 1.0
    if IsToggleModOn(entity, 18) and rpm > 0.70 then
        turboFactor = 1.0 + (rpm - 0.70) * 0.8
    end

    local gear = GetVehicleCurrentGear(entity)
    local maxGear = GetVehicleHighGear(entity)
    local gearFactor
    if gear == 0 then
        gearFactor = 1.60
    elseif gear == 1 then
        gearFactor = 1.35
    elseif gear == 2 then
        gearFactor = 1.15
    elseif maxGear > 0 and gear >= maxGear then
        gearFactor = 0.92
    else
        gearFactor = 1.0
    end

    if not GetIsVehicleEngineRunning(entity) then return 0.0 end

    local totalRate = base * massFactor * occupantFactor * rpmFactor *
                      speedFactor * throttleFactor * engHealthFactor *
                      engModFactor * turboFactor * gearFactor

    totalRate = totalRate * fuelConsumptionMult

    return Clamp(totalRate, 0.0, 5.0)
end

CreateThread(function()
    local syncCounter   = 0
    local TICK_MS       = 500
    local TICKS_TO_SYNC = 10

    while true do
        Wait(TICK_MS)

        if not IsFueling and isInVehicle and inVehicleEntity and DoesEntityExist(inVehicleEntity) then
            local isDriver = GetPedInVehicleSeat(inVehicleEntity, -1) == PlayerPedId()
            if isDriver then
                local pctRate = CalculateFuelConsumption(inVehicleEntity)
                local elapsed = TICK_MS / 1000.0
                local tankVol = GetTankVolume(inVehicleEntity)

                local currentPct = GetVehicleFuelLevel(inVehicleEntity) * 100.0 / tankVol
                local newPct     = math.max(0.0, currentPct - pctRate * elapsed)

                SetVehicleFuelLevel(inVehicleEntity, newPct * tankVol / 100.0)

                if mileageEnabled and GetIsVehicleEngineRunning(inVehicleEntity) then
                    local speedMs = GetEntitySpeed(inVehicleEntity)
                    if speedMs > 0.5 then
                        accumulatedKm = accumulatedKm + (speedMs * elapsed / 1000.0)
                    end
                end

                syncCounter = syncCounter + 1
                if syncCounter >= TICKS_TO_SYNC then
                    syncCounter = 0
                    if inVehicleId then
                        TriggerServerEvent('vehicles:server:fuelTick', inVehicleId, newPct)
                        if accumulatedKm > 0.001 then
                            TriggerServerEvent('vehicles:server:mileageTick', inVehicleId, accumulatedKm)
                            currentVehicleKm = currentVehicleKm + accumulatedKm
                            accumulatedKm    = 0.0
                        end
                    else
                        if accumulatedKm > 0.001 then
                            currentVehicleKm = currentVehicleKm + accumulatedKm
                            accumulatedKm    = 0.0
                        end
                    end
                end

                if newPct < 3.0 and newPct > 0.5 then
                    TriggerEvent('switcore:notify:local', 'warning', Sw.T('vehicles.fuel_critical'), 5000)
                elseif newPct <= 0.5 then
                    SetVehicleEngineOn(inVehicleEntity, false, true, false)
                end
            end
        end
    end
end)

RegisterNetEvent('vehicles:client:spawnVehicle', function(data)
    if not data or not data.model then return end
    SpawnVehicle(data)
end)

RegisterNetEvent('vehicles:client:despawnVehicle', function(plate)
    DespawnVehicle(plate, true)
end)

RegisterNetEvent('vehicles:client:setFuel', function(vehicleId, amount)
    for _, data in pairs(spawnedVehicles) do
        if data.vehicleId == vehicleId and DoesEntityExist(data.entity) then
            local tankVol = GetVehicleHandlingFloat(data.entity, 'CHandlingData', 'fPetrolTankVolume')
            if not tankVol or tankVol <= 0 then tankVol = 65.0 end
            SetVehicleFuelLevel(data.entity, (tonumber(amount) or 0) * tankVol / 100.0)
            break
        end
    end
end)

RegisterNetEvent('vehicles:client:syncKeys', function(plates)
    ownedPlates = {}
    for _, plate in ipairs(plates) do
        ownedPlates[plate:gsub('%s+', '')] = true
    end
    print(string.format('[VEHICLES-CLIENT] %d chei sincronizate', #plates))
end)

RegisterNetEvent('vehicles:client:addOwnedPlate', function(plate)
    if not plate then return end
    ownedPlates[plate:gsub('%s+', '')] = true
end)

RegisterNetEvent('vehicles:client:removeOwnedPlate', function(plate)
    if not plate then return end
    ownedPlates[plate:gsub('%s+', '')] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, data in pairs(spawnedVehicles) do
        if DoesEntityExist(data.entity) then
            local state = GetVehicleStateSnapshot(data.entity, data.vehicleId)
            TriggerServerEvent('vehicles:server:saveVehicleState', data.vehicleId, state)
        end
    end
end)

print('[VEHICLES-CLIENT] Client vehicles loaded')
