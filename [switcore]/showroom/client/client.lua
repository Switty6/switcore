
local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

local currentDealershipCode = nil
local isUIOpen = false

local testDriveEntity = 0
local testDriveTimer  = nil
local testDriveActive = false
local testDriveReturnCoords = nil

local dealershipLocations = {}
local registeredInteractions = {}

local displayVehicle = 0
local showroomCam = 0
local spawnToken = 0

local function DespawnDisplayVehicle()
    if displayVehicle ~= 0 and DoesEntityExist(displayVehicle) then
        SetEntityAsMissionEntity(displayVehicle, false, true)
        DeleteVehicle(displayVehicle)
    end
    displayVehicle = 0
end

local function DestroyShowroomCam()
    if showroomCam ~= 0 then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(showroomCam, false)
        showroomCam = 0
    end
end

local function SpawnDisplayVehicle(modelName, colorIndex)
    spawnToken = spawnToken + 1
    local myToken = spawnToken

    DespawnDisplayVehicle()

    local model = GetHashKey(modelName)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
        if myToken ~= spawnToken then
            SetModelAsNoLongerNeeded(model)
            return
        end
    end
    if not HasModelLoaded(model) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    if myToken ~= spawnToken then
        SetModelAsNoLongerNeeded(model)
        return
    end

    DespawnDisplayVehicle()

    local spawnPoint = nil
    for _, loc in ipairs(dealershipLocations) do
        if loc.code == currentDealershipCode then
            spawnPoint = loc.testDriveSpawn
            break
        end
    end

    if spawnPoint then
        displayVehicle = CreateVehicle(model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.heading or 0.0, false, false)
        SetEntityAsMissionEntity(displayVehicle, true, true)
        SetVehicleColours(displayVehicle, colorIndex or 0, colorIndex or 0)
        FreezeEntityPosition(displayVehicle, true)
        SetEntityInvincible(displayVehicle, true)
        SetVehicleDoorsLocked(displayVehicle, 2)
        SetModelAsNoLongerNeeded(model)

        if showroomCam == 0 then
            showroomCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            RenderScriptCams(true, true, 1000, true, true)
        end
        
        local camPos = GetOffsetFromEntityInWorldCoords(displayVehicle, 3.5, 4.0, 1.5)
        SetCamCoord(showroomCam, camPos.x, camPos.y, camPos.z)
        PointCamAtEntity(showroomCam, displayVehicle, 0.0, 0.0, 0.0, true)
        SetCamActive(showroomCam, true)
    else
        SetModelAsNoLongerNeeded(model)
    end
end


CreateThread(function()
    Wait(1500)
    TriggerServerEvent('showroom:server:getLocationConfig')
end)

RegisterNetEvent('showroom:client:locationConfig', function(config)
    for _, id in ipairs(registeredInteractions) do
        exports.proximity:RemoveInteraction(id)
    end
    registeredInteractions = {}

    dealershipLocations = config.locations or {}

    for _, loc in ipairs(dealershipLocations) do
        local coords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)

        local id = exports.proximity:AddInteraction(
            coords,
            loc.name,
            'showroom_' .. loc.code,
            {},
            function()
                if not isUIOpen and not testDriveActive then
                    currentDealershipCode = loc.code
                    TriggerServerEvent('showroom:server:openDealership', loc.code)
                end
            end
        )
        table.insert(registeredInteractions, id)
    end
    print('[SHOWROOM-CLIENT] ' .. #dealershipLocations .. ' dealership-uri înregistrate proximity')
end)

RegisterNetEvent('showroom:client:openUI', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    pushI18n()
    SendNUIMessage({
        action          = 'open',
        dealership      = data.dealership,
        catalog         = data.catalog,
        activeDrive     = data.activeDrive,
        financeMinPrice = data.financeMinPrice,
        testDriveDuration = data.testDriveDuration,
    })
end)

RegisterNetEvent('showroom:client:purchaseResult', function(data)
    if data.success then
        isUIOpen = false
        currentDealershipCode = nil
        SetNuiFocus(false, false)
        DespawnDisplayVehicle()
        DestroyShowroomCam()
        SendNUIMessage({ action = 'close' })
    else
        SendNUIMessage({ action = 'purchaseError', error = data.error })
    end
end)

RegisterNetEvent('showroom:client:startTestDrive', function(data)
    isUIOpen = false
    SetNuiFocus(false, false)
    DespawnDisplayVehicle()
    DestroyShowroomCam()
    SendNUIMessage({ action = 'close' })

    local spawnPoint = nil
    for _, loc in ipairs(dealershipLocations) do
        if loc.code == currentDealershipCode then
            spawnPoint = loc.testDriveSpawn
            -- Retinem punctul de intoarcere (intrarea dealership-ului) pentru finalul testului.
            testDriveReturnCoords = loc.coords
            break
        end
    end

    if not spawnPoint then
        TriggerEvent('switcore:notify:local', 'error', Sw.T('showroom.notify_test_drive_spawn_missing'), 3000)
        return
    end

    local model = GetHashKey(data.model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        TriggerEvent('switcore:notify:local', 'error', Sw.T('showroom.notify_vehicle_model_unavailable'), 3000)
        return
    end

    testDriveEntity = CreateVehicle(
        model,
        spawnPoint.x, spawnPoint.y, spawnPoint.z,
        spawnPoint.heading or 0.0,
        true, false
    )

    SetVehicleNumberPlateText(testDriveEntity, data.plate)
    SetEntityAsMissionEntity(testDriveEntity, true, true)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, testDriveEntity, -1)

    testDriveActive = true
    currentDealershipCode = nil

    SendNUIMessage({
        action       = 'testDriveStarted',
        label        = data.label,
        durationSecs = data.durationSecs,
    })
    SetNuiFocus(false, false)

    CreateThread(function()
        Wait(data.durationSecs * 1000)
        if testDriveActive then
            TriggerServerEvent('showroom:server:endTestDrive')
        end
    end)
end)

RegisterNetEvent('showroom:client:endTestDrive', function()
    if not testDriveActive then return end
    testDriveActive = false

    local ped = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    if currentVehicle == testDriveEntity then
        TaskLeaveVehicle(ped, testDriveEntity, 0)
        Wait(1500)
    end

    if DoesEntityExist(testDriveEntity) then
        SetEntityAsMissionEntity(testDriveEntity, false, true)
        DeleteVehicle(testDriveEntity)
    end
    testDriveEntity = 0

    -- Punctul de iesire din test-drive: aducem jucatorul inapoi la dealership.
    if testDriveReturnCoords then
        SetEntityCoords(ped, testDriveReturnCoords.x, testDriveReturnCoords.y, testDriveReturnCoords.z, false, false, false, false)
        testDriveReturnCoords = nil
    end

    SendNUIMessage({ action = 'testDriveEnded' })
end)

RegisterNUICallback('close', function(_, cb)
    isUIOpen = false
    currentDealershipCode = nil
    SetNuiFocus(false, false)
    DespawnDisplayVehicle()
    DestroyShowroomCam()
    cb('ok')
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
    TriggerServerEvent('showroom:server:purchaseVehicle', data.catalogId, data.paymentMethod, data.customPlate, data.colorIndex)
    cb('ok')
end)

RegisterNUICallback('startTestDrive', function(data, cb)
    TriggerServerEvent('showroom:server:startTestDrive', data.catalogId)
    cb('ok')
end)

RegisterNUICallback('selectVehicle', function(data, cb)
    SpawnDisplayVehicle(data.model, data.colorIndex)
    cb('ok')
end)

RegisterNUICallback('previewColor', function(data, cb)
    if displayVehicle ~= 0 and DoesEntityExist(displayVehicle) then
        SetVehicleColours(displayVehicle, data.colorIndex or 0, data.colorIndex or 0)
    end
    cb('ok')
end)

RegisterNUICallback('endTestDrive', function(_, cb)
    TriggerServerEvent('showroom:server:endTestDrive')
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DespawnDisplayVehicle()
        DestroyShowroomCam()
        for _, id in ipairs(registeredInteractions) do
            exports.proximity:RemoveInteraction(id)
        end
    end
end)
