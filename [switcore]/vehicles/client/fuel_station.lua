local PUMP_MODELS = {
    'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c', 'prop_gas_pump_1d',
    'prop_gas_pump_old2', 'prop_gas_pump_old3', 'prop_vintage_pump',
}

local PUMP_HASHES = {}
for _, m in ipairs(PUMP_MODELS) do PUMP_HASHES[#PUMP_HASHES + 1] = GetHashKey(m) end

local NOZZLE_MODEL  = GetHashKey('prop_cs_fuel_nozle')
local ATTACH_BONE   = 0xDEAD          -- hash SKEL_R_Hand
local CABLE_MAX     = 6.0
local FILL_RATE_L_S = 2.4
local KEY_FILL      = 38              -- tasta E
local PUMP_PROX_DIST    = 2.0
local VEHICLE_PROX_DIST = 3.0
local VEHICLE_SEARCH    = 8.0

local HOLD_ANIM_DICT = 'mp_common'
local HOLD_ANIM_NAME = 'givetake2_b'
local FILL_ANIM_DICT = 'timetable@gardener@filling_can'
local FILL_ANIM_NAME = 'gar_ig_5_filling_can'

-- Offset Z al nozzle-ului pe tank bone, calibrat per clasă (poziția bone-ului diferă vizual între clase).
local nozzleClassZ = {
    [0]=0.65, [1]=0.65, [2]=0.85, [3]=0.6,  [4]=0.55, [5]=0.6,
    [6]=0.6,  [7]=0.55, [8]=0.12, [9]=0.8,  [10]=0.7, [11]=0.6,
    [12]=0.7, [17]=0.6, [18]=0.65,[19]=0.65,[20]=0.75,
}

-- Global: thread-ul de consum în client.lua îl verifică pentru a pauza consumul în timpul alimentării.
IsFueling = false

local nozzleProp, ropeHandle
local pumpEntityRef
local fillVehicle, fillVehicleId
local fillTankVol       = 65.0
local fillAdded         = 0.0
local fillPricePerLitre = 8
local playerBalance, playerCash, playerBank = 0, 0, 0
local currencySymbol    = '$'

local holdingNozzle         = false
local nozzleInVehicle       = false
local isHolding             = false
local vehicleInteractId     = nil
local vehicleInteractEntity = nil
local pumpInteractId        = nil
local pumpInteractEntity    = nil

local pendingPayment = nil

local function sendNUI(action, data)
    data = data or {}; data.action = action
    SendNUIMessage(data)
end

local function FindClosestPump()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, hash in ipairs(PUMP_HASHES) do
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, PUMP_PROX_DIST, hash, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            local d = #(pos - GetEntityCoords(obj))
            if not bestDist or d < bestDist then best, bestDist = obj, d end
        end
    end
    return best, bestDist
end

local function PlayAnim(ped, dict, name)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 30 do Wait(50); t = t + 1 end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, name, 2.0, 8.0, -1, 50, 0, false, false, false)
    end
end

local function SpawnNozzleInHand(ped)
    RequestModel(NOZZLE_MODEL)
    local t = 0
    while not HasModelLoaded(NOZZLE_MODEL) and t < 50 do Wait(50); t = t + 1 end
    if not HasModelLoaded(NOZZLE_MODEL) then return nil end

    PlayAnim(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME)
    Wait(1000)

    local prop = CreateObject(NOZZLE_MODEL, 0.0, 0.0, 0.0, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, ATTACH_BONE),
        0.1, -0.02, -0.02, -80.0, -90.0, -15.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(NOZZLE_MODEL)
    return prop
end

local function AttachRopeToPump()
    if not nozzleProp or not DoesEntityExist(nozzleProp) then return end
    if not pumpEntityRef or not DoesEntityExist(pumpEntityRef) then return end

    RopeLoadTextures()
    local t = 0
    while not RopeAreTexturesLoaded() and t < 30 do Wait(100); t = t + 1 end

    local pc = GetEntityCoords(pumpEntityRef)
    ropeHandle = AddRope(pc.x, pc.y, pc.z, 0.0, 0.0, 0.0,
        3.0, 1, 1000.0, 0.0, 1.0, false, false, false, 1.0, true)
    if not ropeHandle then return end

    ActivatePhysics(ropeHandle)
    StopRopeUnwindingFront(ropeHandle)
    StopRopeWinding(ropeHandle)
    Wait(50)

    local np = GetOffsetFromEntityInWorldCoords(nozzleProp, 0.0, -0.033, -0.195)
    AttachEntitiesToRope(ropeHandle, pumpEntityRef, nozzleProp,
        pc.x, pc.y, pc.z, np.x, np.y, np.z,
        5.0, false, false, nil, nil)
end

local function FindTankBone(vehicle)
    for _, name in ipairs({'petrolcap', 'petroltank_l', 'petroltank_r', 'petroltank', 'hub_lr', 'engine'}) do
        local b = GetEntityBoneIndexByName(vehicle, name)
        if b and b ~= -1 then return b end
    end
    return -1
end

local function AttachNozzleToVehicle(vehicle)
    if not nozzleProp or not DoesEntityExist(nozzleProp) then return false end
    local bone = FindTankBone(vehicle)
    if bone == -1 then return false end

    local class  = GetVehicleClass(vehicle)
    local isBike = class == 8
    local zOff   = nozzleClassZ[class] or 0.5

    DetachEntity(nozzleProp, true, false)
    if isBike then
        AttachEntityToEntity(nozzleProp, vehicle, bone,
            0.0, -0.2, 0.2 + zOff, -80.0, 0.0, 0.0,
            true, true, false, false, 1, true)
    else
        AttachEntityToEntity(nozzleProp, vehicle, bone,
            -0.18, 0.0, zOff, -125.0, -90.0, -90.0,
            true, true, false, false, 1, true)
    end
    return true
end

local function CleanupVehicleInteraction()
    if vehicleInteractId then
        exports.proximity:RemoveInteraction(vehicleInteractId)
        vehicleInteractId = nil
    end
    vehicleInteractEntity = nil
end

local function CleanupPumpInteraction()
    if pumpInteractId then
        exports.proximity:RemoveInteraction(pumpInteractId)
        pumpInteractId = nil
    end
    pumpInteractEntity = nil
end

local function CleanupNozzle()
    if nozzleProp and DoesEntityExist(nozzleProp) then
        DetachEntity(nozzleProp, true, false)
        DeleteEntity(nozzleProp)
    end
    nozzleProp = nil
end

local function CleanupRope()
    if ropeHandle then
        DeleteRope(ropeHandle)
        ropeHandle = nil
    end
    RopeUnloadTextures()
end

local function ResetState()
    holdingNozzle    = false
    nozzleInVehicle  = false
    isHolding        = false
    IsFueling        = false
    fillAdded        = 0.0
    fillVehicle      = nil
    fillVehicleId    = nil
    pumpEntityRef    = nil
    pendingPayment   = nil
end

local function ReturnNozzleToPump()
    local ped = PlayerPedId()
    PlayAnim(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME)
    Wait(800)
    CleanupNozzle()
    CleanupRope()
    CleanupVehicleInteraction()
    ClearPedTasks(ped)
    ResetState()
    sendNUI('fuel:close', {})
    SetNuiFocus(false, false)
end

local function SnapNozzleInHand()
    TriggerEvent('switcore:notify:local', 'error', 'Furtunul s-a rupt!', 3500)
    CleanupNozzle()
    CleanupRope()
    CleanupVehicleInteraction()
    CleanupPumpInteraction()
    ClearPedTasks(PlayerPedId())
    ResetState()
    sendNUI('fuel:close', {})
    SetNuiFocus(false, false)
end

local function RegisterVehicleInteraction()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pos.x, pos.y, pos.z, VEHICLE_SEARCH, 0, 70)
    if veh == 0 or not DoesEntityExist(veh) then
        CleanupVehicleInteraction()
        return false
    end
    if vehicleInteractId and vehicleInteractEntity == veh then return true end

    CleanupVehicleInteraction()
    vehicleInteractId = exports.proximity:AddEntityInteraction(
        veh, 'Atașează furtunul la rezervor', 'fuel_vehicle_attach', {},
        nil, nil, nil, VEHICLE_PROX_DIST
    )
    vehicleInteractEntity = veh
    return true
end

CreateThread(function()
    while true do
        Wait(250)
        local ped = PlayerPedId()
        local snapped = false

        if holdingNozzle and not nozzleInVehicle then
            if pumpEntityRef and DoesEntityExist(pumpEntityRef)
               and #(GetEntityCoords(ped) - GetEntityCoords(pumpEntityRef)) >= CABLE_MAX then
                SnapNozzleInHand()
                snapped = true
            else
                RegisterVehicleInteraction()
            end
        elseif not holdingNozzle then
            CleanupVehicleInteraction()
        end

        if not snapped then
            local showPump = not IsPedInAnyVehicle(ped, false) and not nozzleInVehicle
            if showPump and holdingNozzle then
                local pos = GetEntityCoords(ped)
                local veh = GetClosestVehicle(pos.x, pos.y, pos.z, VEHICLE_PROX_DIST, 0, 70)
                if veh ~= 0 and DoesEntityExist(veh) then showPump = false end
            end

            if showPump then
                local pump = FindClosestPump()
                if pump and pumpInteractEntity ~= pump then
                    CleanupPumpInteraction()
                    pumpInteractId = exports.proximity:AddEntityInteraction(
                        pump, 'Alimentează', 'fuel_pump', {}, nil, nil, nil, PUMP_PROX_DIST)
                    pumpInteractEntity = pump
                elseif not pump then
                    CleanupPumpInteraction()
                end
            else
                CleanupPumpInteraction()
            end
        end
    end
end)

RegisterNetEvent('switcore:proximity:interact', function(interaction)
    if not interaction then return end

    if interaction.type == 'fuel_pump' then
        if IsPedInAnyVehicle(PlayerPedId(), false) then return end
        if holdingNozzle or nozzleInVehicle then
            ReturnNozzleToPump()
            return
        end

        pumpEntityRef = interaction.entity
        if not pumpEntityRef or not DoesEntityExist(pumpEntityRef) then
            TriggerEvent('switcore:notify:local', 'error', 'Pompa nu mai există.', 3000)
            return
        end

        local ped = PlayerPedId()
        nozzleProp = SpawnNozzleInHand(ped)
        if not nozzleProp then
            TriggerEvent('switcore:notify:local', 'error', 'Nu am putut prelua furtunul.', 3000)
            return
        end
        AttachRopeToPump()

        holdingNozzle = true

        if RegisterVehicleInteraction() then
            TriggerEvent('switcore:notify:local', 'info',
                'Apasă ALT pe rezervorul vehiculului pentru a alimenta.', 4500)
        else
            TriggerEvent('switcore:notify:local', 'warning',
                'Apropie-te de un vehicul și apasă ALT pe el.', 4500)
        end

        TriggerServerEvent('vehicles:server:getBalanceForFuel')
        return
    end

    if interaction.type == 'fuel_vehicle_attach' then
        if not holdingNozzle then return end
        local vehicle = interaction.entity
        if not vehicle or not DoesEntityExist(vehicle) then return end

        if not AttachNozzleToVehicle(vehicle) then
            TriggerEvent('switcore:notify:local', 'error',
                'Nu pot ataşa furtunul la acest vehicul.', 3000)
            return
        end

        fillVehicle = vehicle
        local plate   = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
        local vehData = GetOwnedVehicleData and GetOwnedVehicleData(plate) or nil
        fillVehicleId = vehData and vehData.vehicleId or nil

        fillTankVol = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPetrolTankVolume')
        if not fillTankVol or fillTankVol <= 0 then fillTankVol = 65.0 end

        holdingNozzle   = false
        nozzleInVehicle = true
        ClearPedTasks(PlayerPedId())
        CleanupVehicleInteraction()

        local currentGTA = GetVehicleFuelLevel(vehicle)
        sendNUI('fuel:openFillHud', {
            pumpId         = (pumpEntityRef and (pumpEntityRef % 99 + 1)) or 1,
            pricePerLitre  = fillPricePerLitre,
            balance        = playerBalance,
            cash           = playerCash,
            bank           = playerBank,
            fuelPct        = (currentGTA / fillTankVol) * 100.0,
            currencySymbol = currencySymbol,
        })

        TriggerServerEvent('vehicles:server:getBalanceForFuel')
        return
    end
end)

RegisterNetEvent('vehicles:client:updateFuelBalance', function(balance, serverPricePerLitre, cash, bank, symbol)
    playerBalance = tonumber(balance) or 0
    playerCash    = tonumber(cash)    or 0
    playerBank    = tonumber(bank)    or 0
    if serverPricePerLitre then fillPricePerLitre = tonumber(serverPricePerLitre) or 8 end
    if symbol and symbol ~= '' then currencySymbol = symbol end

    if nozzleInVehicle then
        sendNUI('fuel:updateBalance', {
            pricePerLitre  = fillPricePerLitre,
            balance        = playerBalance,
            cash           = playerCash,
            bank           = playerBank,
            currencySymbol = currencySymbol,
        })
    end
end)

local TICK_MS       = 100
local litresPerTick = FILL_RATE_L_S * (TICK_MS / 1000.0)

local function OpenPaymentModal(litres, cost, reason)
    SetNuiFocus(true, true)
    sendNUI('fuel:openPayment', {
        litres         = litres,
        cost           = cost,
        cash           = playerCash,
        bank           = playerBank,
        reason         = reason,
        currencySymbol = currencySymbol,
    })
    pendingPayment = { litres = litres, cost = cost, vehicleId = fillVehicleId }
end

local function ChargeAndFinish(reason)
    IsFueling = false
    isHolding = false
    local litres = fillAdded
    local cost   = math.floor(litres * fillPricePerLitre)

    if reason == 'cable_snap' then
        sendNUI('fuel:cableSnap', {})
        TriggerEvent('switcore:notify:local', 'error', 'Furtunul s-a rupt!', 3500)
    end

    if litres <= 0.01 then
        ReturnNozzleToPump()
        return
    end

    if reason == 'tank_full' then
        TriggerEvent('switcore:notify:local', 'info', 'Rezervor plin! Alege metoda de plată.', 3500)
    elseif reason == 'no_funds' then
        TriggerEvent('switcore:notify:local', 'warning', 'Fonduri insuficiente, alege metoda de plată.', 4000)
    end

    OpenPaymentModal(litres, cost, reason)
end

CreateThread(function()
    while true do
        Wait(TICK_MS)
        if nozzleInVehicle and fillVehicle and DoesEntityExist(fillVehicle) then
            local eHeld = IsControlPressed(0, KEY_FILL)

            if eHeld and not isHolding then
                isHolding = true
                IsFueling = true
                sendNUI('fuel:holdState', { active = true })
            end

            if not eHeld and isHolding then
                isHolding = false
                IsFueling = false
                sendNUI('fuel:holdState', { active = false })
                ChargeAndFinish('release')
            elseif isHolding then
                local currentGTA = GetVehicleFuelLevel(fillVehicle)
                local playerPos  = GetEntityCoords(PlayerPedId())
                local cableDist  = pumpEntityRef and DoesEntityExist(pumpEntityRef)
                                       and #(playerPos - GetEntityCoords(pumpEntityRef)) or 0.0

                if currentGTA >= fillTankVol - 0.1 then
                    ChargeAndFinish('tank_full')
                elseif (fillAdded + litresPerTick) * fillPricePerLitre > playerBalance then
                    ChargeAndFinish('no_funds')
                elseif cableDist >= CABLE_MAX then
                    ChargeAndFinish('cable_snap')
                else
                    local addedGTA = litresPerTick * fillTankVol / 100.0
                    local newGTA   = math.min(fillTankVol, currentGTA + addedGTA)
                    SetVehicleFuelLevel(fillVehicle, newGTA)
                    fillAdded = fillAdded + litresPerTick
                    sendNUI('fuel:updateFill', {
                        filledLitres   = fillAdded,
                        totalCost      = math.floor(fillAdded * fillPricePerLitre),
                        fuelPct        = (newGTA / fillTankVol) * 100.0,
                        cableDistance  = cableDist,
                        maxCable       = CABLE_MAX,
                        currencySymbol = currencySymbol,
                    })
                end
            end
        end
    end
end)

RegisterNUICallback('fuel:pay', function(data, cb)
    cb({})
    if not pendingPayment then return end
    local method = data and data.method == 'card' and 'card' or 'cash'
    TriggerServerEvent('vehicles:server:refuel',
        pendingPayment.vehicleId, pendingPayment.litres, pendingPayment.cost, method)
end)

RegisterNUICallback('fuel:cancelPayment', function(data, cb)
    cb({})
    pendingPayment = nil
    ReturnNozzleToPump()
end)

RegisterNetEvent('vehicles:client:refuelResult', function(success, err, result)
    if success then
        pendingPayment = nil
        ReturnNozzleToPump()
    else
        if pendingPayment then
            TriggerServerEvent('vehicles:server:getBalanceForFuel')
            sendNUI('fuel:paymentError', { error = err or 'Plată eșuată' })
        end
    end
end)

RegisterNUICallback('fuel:complete', function(_, cb) cb({}) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CleanupPumpInteraction()
    if holdingNozzle or nozzleInVehicle then
        CleanupNozzle()
        CleanupRope()
        CleanupVehicleInteraction()
    end
end)

print('[FUEL-STATION] Client module loaded (pickup-then-attach workflow)')
