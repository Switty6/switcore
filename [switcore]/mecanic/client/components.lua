local currentVehicleId  = nil
local currentComponents = nil
local lastMileage       = 0.0
local notifiedThresholds = {}

local wheelIndexMap = { fl=0, fr=1, rl=4, rr=5 }

local function applyComponentEffects(vehicle, components)
    if not DoesEntityExist(vehicle) then return end

    local battery = components.battery or 100
    if battery <= 0 then
        SetVehicleEngineOn(vehicle, false, true, false)
    end

    local tires = components.tires or {}
    for pos, val in pairs(tires) do
        local idx = wheelIndexMap[pos]
        if idx and val <= 0 then
            SetVehicleTyreBurst(vehicle, idx, false, 0.0)
        end
    end

    local suspension = components.suspension or {}
    for pos, val in pairs(suspension) do
        local idx = wheelIndexMap[pos]
        if idx and val <= 20 then
            SetVehicleWheelHealth(vehicle, idx, 200.0)
        end
    end

    local exhaust = components.exhaust or 100
    if exhaust <= 20 then
        SetVehicleEngineDamagescale(vehicle, 1.3)
    end
end

CreateThread(function()
    while true do
        Wait(5000)

        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then goto continue end

        local vehicle = GetVehiclePedIsIn(ped, false)
        if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            goto continue
        end

        local plate   = GetVehicleNumberPlateText(vehicle)
        local vehicleData = nil

        if plate and plate ~= '' then
            local ok, vd = pcall(function()
                return exports.vehicles:getOwnedVehicleByPlate(plate)
            end)
            if ok and vd then vehicleData = vd end
        end

        if not vehicleData then goto continue end

        local vehicleId = vehicleData.id
        local components = vehicleData.components
        if type(components) == 'string' then
            components = json.decode(components) or {}
        end
        if not components or type(components) ~= 'table' then
            components = { oil=100, battery=100, brakes=100, exhaust=100,
                           tires={fl=100,fr=100,rl=100,rr=100},
                           suspension={fl=100,fr=100,rl=100,rr=100} }
        end

        applyComponentEffects(vehicle, components)

        local oil = components.oil or 100
        if oil <= 0 then
            local engineHealth = GetVehicleEngineHealth(vehicle)
            if engineHealth > 200.0 then
                SetVehicleEngineHealth(vehicle, engineHealth - (2.0 * (5000 / 1000)))
            end
        elseif oil <= Config.Thresholds.oil_crit then
            local engineHealth = GetVehicleEngineHealth(vehicle)
            if engineHealth > 300.0 then
                SetVehicleEngineHealth(vehicle, engineHealth - (0.5 * (5000 / 1000)))
            end
        end

        local key = vehicleId .. '_oil_warn'
        if oil <= Config.Thresholds.oil_warn and oil > Config.Thresholds.oil_crit
           and not notifiedThresholds[key] then
            notifiedThresholds[key] = true
            TriggerEvent('notifications:client:send', {
                type='warning', title=Sw.T('mecanic.warn.oil_low_title'),
                message=Sw.T('mecanic.warn.oil_low_msg'), duration=8000
            })
        end

        local keyOilCrit = vehicleId .. '_oil_crit'
        if oil <= Config.Thresholds.oil_crit and oil > 0
           and not notifiedThresholds[keyOilCrit] then
            notifiedThresholds[keyOilCrit] = true
            TriggerEvent('notifications:client:send', {
                type='error', title=Sw.T('mecanic.warn.oil_crit_title'),
                message=Sw.T('mecanic.warn.oil_crit_msg'), duration=10000
            })
        end

        local keyBattery = vehicleId .. '_battery'
        local battery = components.battery or 100
        if battery <= Config.Thresholds.battery_low and battery > 0
           and not notifiedThresholds[keyBattery] then
            notifiedThresholds[keyBattery] = true
            TriggerEvent('notifications:client:send', {
                type='warning', title=Sw.T('mecanic.warn.battery_low_title'),
                message=Sw.T('mecanic.warn.battery_low_msg'), duration=8000
            })
        end

        local keyBrakes = vehicleId .. '_brakes'
        local brakes = components.brakes or 100
        if brakes <= Config.Thresholds.brakes_warn
           and not notifiedThresholds[keyBrakes] then
            notifiedThresholds[keyBrakes] = true
            TriggerEvent('notifications:client:send', {
                type='warning', title=Sw.T('mecanic.warn.brakes_title'),
                message=Sw.T('mecanic.warn.brakes_msg'), duration=8000
            })
        end

        local tires = components.tires or {}
        for pos, val in pairs(tires) do
            local keyTire = vehicleId .. '_tire_' .. pos
            if val <= 0 and not notifiedThresholds[keyTire] then
                notifiedThresholds[keyTire] = true
                TriggerEvent('notifications:client:send', {
                    type='error', title=Sw.T('mecanic.warn.tire_flat_title'),
                    message=Sw.T('mecanic.warn.tire_flat_msg', pos:upper()), duration=8000
                })
            end
        end

        ::continue::
    end
end)

local function FindVehicleByPlateNearby(plate, radius)
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local vPlate = GetVehicleNumberPlateText(veh):gsub('%s+$', '')
            if vPlate == plate and #(coords - GetEntityCoords(veh)) <= (radius or 30.0) then
                return veh
            end
        end
    end
    return nil
end

RegisterNetEvent('mecanic:client:vehicleRepaired', function(data)
    local plate = data.plate and data.plate:gsub('%s+$', '')
    local vehicle = plate and FindVehicleByPlateNearby(plate)

    if not vehicle then
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local occupied = GetVehiclePedIsIn(ped, false)
            if not plate or GetVehicleNumberPlateText(occupied):gsub('%s+$', '') == plate then
                vehicle = occupied
            end
        end
    end

    if not vehicle or not DoesEntityExist(vehicle) then return end

    local state = data.state or {}

    if state.engine_health then
        SetVehicleEngineHealth(vehicle, state.engine_health)
    end
    if state.body_health then
        SetVehicleBodyHealth(vehicle, state.body_health)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleDirtLevel(vehicle, 0.0)
    end

    if state.components then
        local comps = state.components

        local tires = comps.tires or {}
        for pos, val in pairs(tires) do
            if val >= 100 then
                local idx = wheelIndexMap[pos]
                if idx then
                    SetVehicleTyreFixed(vehicle, idx)
                end
            end
        end

        local suspension = comps.suspension or {}
        for pos, val in pairs(suspension) do
            if val >= 100 then
                local idx = wheelIndexMap[pos]
                if idx then
                    SetVehicleWheelHealth(vehicle, idx, 1000.0)
                end
            end
        end

        if comps.exhaust and comps.exhaust >= 100 then
            SetVehicleEngineDamagescale(vehicle, 1.0)
        end

        local plate2 = GetVehicleNumberPlateText(vehicle)
        local vId    = data.vehicleId
        if vId then
            notifiedThresholds[vId .. '_oil_warn']  = nil
            notifiedThresholds[vId .. '_oil_crit']  = nil
            notifiedThresholds[vId .. '_battery']   = nil
            notifiedThresholds[vId .. '_brakes']    = nil
            for pos, _ in pairs(tires) do
                notifiedThresholds[vId .. '_tire_' .. pos] = nil
            end
        end
    end

    TriggerEvent('notifications:client:send', {
        type='success', title=Sw.T('mecanic.warn.vehicle_repaired_title'),
        message=Sw.T('mecanic.warn.vehicle_repaired_msg'), duration=6000
    })
end)
