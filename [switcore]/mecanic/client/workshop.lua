local vehicleInteractions = {}
local activeClientSrc     = nil
local activeVehicleId     = nil
local activeVehicleEntity = nil

local function isInWorkshop()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, c in ipairs(Config.WorkshopLocations) do
        if #(coords - vector3(c.x, c.y, c.z)) <= (c.radius or 25.0) then
            return true
        end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(3000)
        if not isMechanic or not myJob or not myJob.isOnDuty then
            for _, intId in pairs(vehicleInteractions) do
                exports.proximity:RemoveInteraction(intId)
            end
            vehicleInteractions = {}
            Wait(5000)
            goto continue
        end

        if not isInWorkshop() then goto continue end

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local vehicles = {}

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and not IsEntityDead(veh) then
                local vCoords = GetEntityCoords(veh)
                if #(coords - vCoords) <= Config.NearVehicleRadius then
                    local plate = GetVehicleNumberPlateText(veh)
                    if plate and plate ~= '' then
                        vehicles[plate] = { entity = veh, coords = vCoords }
                    end
                end
            end
        end

        for plate, info in pairs(vehicles) do
            if not vehicleInteractions[plate] then
                local intId          = 'mecanic_veh_' .. plate
                local capturedPlate  = plate
                local capturedEntity = info.entity
                exports.proximity:AddInteraction(
                    info.coords,
                    Sw.T('mecanic.prox_vehicle_services', plate),
                    intId, {},
                    function() OpenWorkshopMenu(capturedPlate, capturedEntity) end
                )
                vehicleInteractions[plate] = intId
            end
        end

        for plate, intId in pairs(vehicleInteractions) do
            if not vehicles[plate] then
                exports.proximity:RemoveInteraction(intId)
                vehicleInteractions[plate] = nil
            end
        end

        ::continue::
    end
end)

function OpenWorkshopMenu(plate, vehicleEntity)
    activeVehicleEntity = vehicleEntity
    TriggerServerEvent('mecanic:server:getVehicleByPlate', plate)
end

RegisterNetEvent('mecanic:client:vehicleByPlate', function(data)
    if not data then return end
    activeVehicleId = data.vehicleId
    activeClientSrc = data.ownerSrc

    PushMecanicI18n()
    SendNUIMessage({
        action       = 'openWorkshop',
        vehicleId    = data.vehicleId,
        plate        = data.plate,
        model        = data.model,
        engineHealth = data.engineHealth,
        bodyHealth   = data.bodyHealth,
        mileage      = data.mileage,
        components   = data.components,
        clientSrc    = data.ownerSrc,
    })

    SetNuiFocus(true, true)
end)

local WheelOffsets = {
    fl = {x=-1.25, y=0.85,  z=0},
    fr = {x=1.25,  y=0.85,  z=0},
    rl = {x=-1.25, y=-0.85, z=0},
    rr = {x=1.25,  y=-0.85, z=0},
}
local function wheelLabel(pos)
    return Sw.T('mecanic.wheel.' .. pos)
end

local ServiceColors = {
    inspect    = {r=0,   g=180, b=255},
    oil_change = {r=249, g=115, b=22 },
    brakes     = {r=239, g=68,  b=68 },
    tire       = {r=234, g=179, b=8  },
    suspension = {r=168, g=85,  b=247},
    battery    = {r=234, g=179, b=8  },
    engine     = {r=239, g=68,  b=68 },
    bodywork   = {r=249, g=115, b=22 },
}

local function svcColor(st)
    return ServiceColors[st] or {r=249, g=115, b=22}
end

local function buildTargets(data)
    local st = data.serviceType
    if st == 'inspect' then
        return {{ offset={x=0, y=2.2, z=0}, label=Sw.T('mecanic.target.inspect') }}

    elseif st == 'oil_change' then
        return {{ offset={x=0.5, y=0.4, z=0}, label=Sw.T('mecanic.target.oil_change') }}

    elseif st == 'brakes' then
        return {{ offset={x=1.4, y=0.6, z=0}, label=Sw.T('mecanic.target.brakes') }}

    elseif st == 'tire' then
        local targets = {}
        for _, pos in ipairs(data.damagedTires or {}) do
            if WheelOffsets[pos] then
                table.insert(targets, {
                    offset   = WheelOffsets[pos],
                    label    = Sw.T('mecanic.target.tire_pos', wheelLabel(pos)),
                    wheelPos = pos,
                })
            end
        end
        if #targets == 0 then
            targets = {{ offset={x=1.25, y=0.85, z=0}, label=Sw.T('mecanic.target.tire_generic') }}
        end
        return targets

    elseif st == 'suspension' then
        return {
            { offset={x=1.4,  y=0.2, z=0}, label=Sw.T('mecanic.target.suspension_right'), suspSide='r' },
            { offset={x=-1.4, y=0.2, z=0}, label=Sw.T('mecanic.target.suspension_left'),  suspSide='l' },
        }

    elseif st == 'battery' then
        return {{ offset={x=0, y=2.2, z=0}, label=Sw.T('mecanic.target.battery') }}

    elseif st == 'engine' then
        return {{ offset={x=0, y=2.2, z=0}, label=Sw.T('mecanic.target.engine') }}

    elseif st == 'bodywork' then
        return {{ offset={x=1.8, y=0.0, z=0.2}, label=Sw.T('mecanic.target.bodywork') }}

    else
        return {{ offset={x=0, y=1.5, z=0}, label=st }}
    end
end

local svcActive  = false
local svcType    = nil
local svcVehicle = nil
local svcPending = nil
local svcTargets = {}
local svcCol     = {r=249, g=115, b=22}

local function clearSvcInteractions()
    for _, t in ipairs(svcTargets) do
        if t.intId then
            exports.proximity:RemoveInteraction(t.intId)
            t.intId = nil
        end
    end
    svcActive  = false
    svcTargets = {}
end

local function registerTargetInteraction(target, idx)
    if not DoesEntityExist(svcVehicle) then return end
    local wp = GetOffsetFromEntityInWorldCoords(svcVehicle, target.offset.x, target.offset.y, target.offset.z)
    target.worldPos = vector3(wp.x, wp.y, wp.z)

    local intId = 'mecanic_tgt_' .. idx .. '_' .. GetGameTimer()
    exports.proximity:AddInteraction(
        target.worldPos, target.label, intId, {},
        function()
            exports.proximity:RemoveInteraction(intId)
            target.intId = nil
            onTargetReached(target, idx)
        end
    )
    target.intId = intId
end

function onTargetReached(target, idx)
    StartServiceMinigame(svcType, svcVehicle, function(success)
        if not success then
            target.completed = false
            registerTargetInteraction(target, idx)
            TriggerEvent('notifications:client:send', {
                type='warning', title=Sw.T('mecanic.notify.service_failed_title'),
                message=Sw.T('mecanic.notify.minigame_failed'), duration=3000
            })
            return
        end

        target.completed = true

        -- Tire/suspension: server event per target (nu la final)
        if svcType == 'tire' and target.wheelPos then
            TriggerServerEvent('mecanic:server:performService', {
                serviceType   = 'tire',
                vehicleId     = svcPending.vehicleId,
                clientSrc     = svcPending.clientSrc,
                tirePositions = {target.wheelPos},
            })
        elseif svcType == 'suspension' and target.suspSide then
            TriggerServerEvent('mecanic:server:performService', {
                serviceType          = 'suspension',
                vehicleId            = svcPending.vehicleId,
                clientSrc            = svcPending.clientSrc,
                suspensionPositions  = {'f'..target.suspSide, 'r'..target.suspSide},
            })
        end

        local allDone = true
        for _, t in ipairs(svcTargets) do
            if not t.completed then allDone = false; break end
        end

        if allDone then
            if svcType ~= 'tire' and svcType ~= 'suspension' then
                TriggerServerEvent('mecanic:server:performService', svcPending)
            end

            if (svcType == 'battery' or svcType == 'engine') and DoesEntityExist(svcVehicle) then
                Wait(1000)
                SetVehicleDoorShut(svcVehicle, 4, false)
            end

            clearSvcInteractions()

            TriggerEvent('notifications:client:send', {
                type='success', title=Sw.T('mecanic.notify.service_done_title'),
                message=Sw.T('mecanic.notify.service_done_msg'), duration=4000
            })
        end
    end)
end

CreateThread(function()
    while true do
        if svcActive then
            Wait(0)
            for _, t in ipairs(svcTargets) do
                if not t.completed and t.worldPos then
                    local c = svcCol
                    if DoesEntityExist(svcVehicle) then
                        local wp = GetOffsetFromEntityInWorldCoords(
                            svcVehicle, t.offset.x, t.offset.y, t.offset.z
                        )
                        t.worldPos = vector3(wp.x, wp.y, wp.z)
                    end

                    DrawMarker(
                        1,
                        t.worldPos.x, t.worldPos.y, t.worldPos.z + 0.8,
                        0, 0, 0,
                        0, 0, 0,
                        0.5, 0.5, 0.5,
                        c.r, c.g, c.b, 180,
                        false, false, 2, false, nil, nil, false
                    )

                    local onScreen, sX, sY = World3dToScreen2d(
                        t.worldPos.x, t.worldPos.y, t.worldPos.z + 1.5
                    )
                    if onScreen then
                        SetTextFont(4)
                        SetTextScale(0.35, 0.35)
                        SetTextColour(255, 255, 255, 255)
                        SetTextOutline()
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName(t.label)
                        EndTextCommandDisplayText(sX, sY)
                    end
                end
            end
        else
            Wait(200)
        end
    end
end)

local function startServiceInteraction(data, vehicle)
    if svcActive or IsServiceInProgress() then return end

    svcActive  = true
    svcType    = data.serviceType
    svcVehicle = vehicle
    svcPending = data
    svcCol     = svcColor(data.serviceType)
    svcTargets = buildTargets(data)

    if (data.serviceType == 'battery' or data.serviceType == 'engine') and DoesEntityExist(vehicle) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    end

    for i, target in ipairs(svcTargets) do
        target.completed = false
        registerTargetInteraction(target, i)
    end

    TriggerEvent('notifications:client:send', {
        type='info', title=Sw.T('mecanic.notify.service_active_title'),
        message=Sw.T('mecanic.notify.service_active_msg'), duration=5000
    })
end

RegisterNUICallback('performService', function(data, cb)
    if not data or not activeVehicleId then cb('error') return end
    if svcActive or IsServiceInProgress() then cb('busy') return end

    local pending = {
        serviceType         = data.serviceType,
        vehicleId           = activeVehicleId,
        clientSrc           = activeClientSrc,
        damagedTires        = data.damagedTires,
        tirePositions       = data.tirePositions,
        suspensionPositions = data.suspensionPositions,
    }

    SendNUIMessage({ action = 'hidePanel' })
    SetNuiFocus(false, false)
    cb('ok')

    CreateThread(function()
        Wait(150)
        startServiceInteraction(pending, activeVehicleEntity)
    end)
end)

function CancelActiveService()
    clearSvcInteractions()
    if (svcType == 'battery' or svcType == 'engine') and DoesEntityExist(svcVehicle) then
        SetVehicleDoorShut(svcVehicle, 4, false)
    end
end
