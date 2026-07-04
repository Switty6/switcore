local stores           = {}
local currentStore     = nil
local isInStore        = false
local equippedComponents = {}
local tryOnCam         = nil
local isAutoRotating   = false
local isInTryOn        = false
local storeBlips       = {}
local registeredStores = {}

local BLIP_SPRITE = 73   -- t-shirt
local BLIP_COLOR  = 4    -- alb
local BLIP_SCALE  = 0.8

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

RegisterNetEvent('clothing:receiveStores', function(storesData)
    stores = storesData or {}
    SetupStoreInteractions()
    SetupStoreBlips()
end)

RegisterNetEvent('clothing:applyComponents', function(components)
    equippedComponents = components or {}
    ApplyAllComponents(equippedComponents)
end)

function ApplyAllComponents(components, targetPed)
    local ped = targetPed or PlayerPedId()
    if not components then return end

    for _, comp in pairs(components) do
        if comp.component_type == 'component' then
            SetPedComponentVariation(ped, tonumber(comp.component_id), tonumber(comp.drawable), tonumber(comp.texture) or 0, 2)
        elseif comp.component_type == 'prop' then
            SetPedPropIndex(ped, tonumber(comp.component_id), tonumber(comp.drawable), tonumber(comp.texture) or 0, true)
        end
    end
end

function SetupStoreInteractions()
    -- proximity nu permite stergerea interactiunilor statice; inregistram fiecare
    -- magazin o singura data (nu tot lotul), ca magazinele adaugate in DB dupa
    -- primul push (clothing:receiveStores) sa primeasca si ele interactiunea,
    -- nu doar blip-ul (SetupStoreBlips se reruleaza mereu de la zero).
    for _, store in ipairs(stores) do
        if store.name and not registeredStores[store.name] then
            local coords = store.shop_coords
            if type(coords) == 'string' then
                local ok, decoded = pcall(json.decode, coords)
                coords = ok and decoded or nil
                if not ok then
                    print(('[CLOTHING] Coordonate invalide pentru magazinul %s'):format(tostring(store.name)))
                end
            end
            if coords then
                exports.proximity:AddStaticInteraction(
                    vector3(coords.x, coords.y, coords.z),
                    store.label,
                    'clothing_store',
                    {storeName = store.name}
                )
                registeredStores[store.name] = true
            end
        end
    end
end

function SetupStoreBlips()
    for _, blip in ipairs(storeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    storeBlips = {}

    for _, store in ipairs(stores) do
        local coords = store.shop_coords
        if type(coords) == 'string' then
            local ok, decoded = pcall(json.decode, coords)
            coords = ok and decoded or nil
        end
        if coords then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, BLIP_SPRITE)
            SetBlipColour(blip, BLIP_COLOR)
            SetBlipScale(blip, BLIP_SCALE)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(store.label or Sw.T('clothing.blip_name'))
            EndTextCommandSetBlipName(blip)
            storeBlips[#storeBlips + 1] = blip
        end
    end
end

AddEventHandler('switcore:proximity:interact', function(interaction)
    if interaction.type == 'clothing_store' then
        OpenClothingStore(interaction.data.storeName)
    end
end)

function OpenClothingStore(storeName)
    for _, s in ipairs(stores) do
        if s.name == storeName then
            currentStore = s
            break
        end
    end
    if not currentStore then return end

    isInStore = true
    TriggerServerEvent('clothing:getStoreData', storeName)
end

RegisterNetEvent('clothing:receiveStoreData', function(items, storeName, ownedItemIds, equipped)
    SetNuiFocus(true, true)
    pushI18n()
    SendNUIMessage({
        action     = 'openStore',
        storeName  = storeName,
        storeLabel = (currentStore and currentStore.label) or storeName,
        storeType  = (currentStore and currentStore.type)  or 'casual',
        items      = items      or {},
        ownedItems = ownedItemIds or {},
        equipped   = equipped   or {}
    })
end)

function CloseClothingStore()
    if not isInStore then return end
    isInStore      = false
    isAutoRotating = false

    ExitTryOnMode()
    ApplyAllComponents(equippedComponents)
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeStore'})
end

local function applyComponentToSelf(data)
    local ped = PlayerPedId()
    if data.componentType == 'component' then
        SetPedComponentVariation(ped, tonumber(data.componentId), tonumber(data.drawable), tonumber(data.texture) or 0, 2)
    elseif data.componentType == 'prop' then
        SetPedPropIndex(ped, tonumber(data.componentId), tonumber(data.drawable), tonumber(data.texture) or 0, true)
    end
end

RegisterNUICallback('tryOn',         function(data, cb) applyComponentToSelf(data) cb({ok = true}) end)
RegisterNUICallback('changeTexture', function(data, cb) applyComponentToSelf(data) cb({ok = true}) end)

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('clothing:buyItem', data.itemId, data.texture)
    cb({ok = true})
end)

RegisterNUICallback('equipItem', function(data, cb)
    TriggerServerEvent('clothing:equipItem', data.itemId, data.texture)
    cb({ok = true})
end)

RegisterNUICallback('unequipItem', function(data, cb)
    TriggerServerEvent('clothing:unequipItem', data.componentType, data.componentId)
    cb({ok = true})
end)

RegisterNUICallback('closeStore', function(_, cb)
    CloseClothingStore()
    cb({ok = true})
end)

RegisterNUICallback('goToTryOn', function(_, cb)
    if not currentStore then cb({ok = false}) return end

    local tryonCoords = currentStore.tryon_coords
    if type(tryonCoords) == 'string' then tryonCoords = json.decode(tryonCoords) end
    if not tryonCoords then cb({ok = false}) return end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, tryonCoords.x, tryonCoords.y, tryonCoords.z, false, false, false, true)
    SetEntityHeading(ped, tryonCoords.heading or 0.0)

    Wait(200)
    SetupFittingRoomCamera(tryonCoords)
    isInTryOn = true

    cb({ok = true})
end)

function SetupFittingRoomCamera(coords)
    if tryOnCam then
        DestroyCam(tryOnCam, false)
        tryOnCam = nil
    end

    -- Camera in fata personajului. In GTA 5: forward = (-sin(h), cos(h), 0)
    local h    = math.rad(coords.heading or 0.0)
    local fwdX = -math.sin(h)
    local fwdY =  math.cos(h)

    local camX = coords.x + fwdX * 2.5
    local camY = coords.y + fwdY * 2.5
    local camZ = coords.z + 0.7

    tryOnCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(tryOnCam, camX, camY, camZ)
    PointCamAtCoord(tryOnCam, coords.x, coords.y, coords.z + 0.7)
    SetCamFov(tryOnCam, 40.0)
    RenderScriptCams(true, true, 500, true, true)
end

RegisterNUICallback('exitTryOn', function(_, cb)
    ExitTryOnMode()
    cb({ok = true})
end)

function ExitTryOnMode()
    isInTryOn      = false
    isAutoRotating = false

    if tryOnCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(tryOnCam, false)
        tryOnCam = nil
    end
end

RegisterNUICallback('rotateView', function(data, cb)
    if not isInTryOn then cb({ok = false}) return end
    local ped     = PlayerPedId()
    local current = GetEntityHeading(ped)
    local dir     = (data.direction == 'left') and -90.0 or 90.0
    SetEntityHeading(ped, (current + dir) % 360.0)
    cb({ok = true})
end)

-- 4 pasi de 90°, pauza 2s intre ei
RegisterNUICallback('autoRotate', function(_, cb)
    if isAutoRotating or not isInTryOn then
        cb({ok = false, reason = 'busy'})
        return
    end

    isAutoRotating = true
    cb({ok = true})

    CreateThread(function()
        local ped = PlayerPedId()
        for i = 1, 4 do
            if not isAutoRotating then break end
            local current = GetEntityHeading(ped)
            SetEntityHeading(ped, (current + 90.0) % 360.0)
            local waited = 0
            while waited < 2000 and isAutoRotating do
                Wait(50)
                waited = waited + 50
            end
        end
        isAutoRotating = false
        SendNUIMessage({action = 'autoRotateFinished'})
    end)
end)

RegisterNUICallback('stopAutoRotate', function(_, cb)
    isAutoRotating = false
    cb({ok = true})
end)

RegisterNUICallback('getOutfits', function(_, cb)
    TriggerServerEvent('clothing:getOutfits')
    cb({ok = true})
end)

RegisterNetEvent('clothing:receiveOutfits', function(outfits)
    SendNUIMessage({action = 'receiveOutfits', outfits = outfits or {}})
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    if not data.name or data.name == '' then cb({ok = false}) return end
    TriggerServerEvent('clothing:saveOutfit', data.name)
    cb({ok = true})
end)

RegisterNUICallback('loadOutfit', function(data, cb)
    TriggerServerEvent('clothing:loadOutfit', data.outfitId)
    cb({ok = true})
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    TriggerServerEvent('clothing:deleteOutfit', data.outfitId)
    cb({ok = true})
end)

RegisterNetEvent('clothing:itemPurchased', function(storeItemId)
    SendNUIMessage({action = 'itemPurchased', itemId = storeItemId})
end)

CreateThread(function()
    while true do
        Wait(0)
        if isInStore and IsControlJustPressed(0, 200) then
            CloseClothingStore()
        end
    end
end)

-- Fallback: daca am ratat switcore:characterLoaded (restart de resource
-- sau race la pornire), cerem singuri lista de magazine.
CreateThread(function()
    Wait(2000)
    if #stores == 0 then
        TriggerServerEvent('clothing:requestStores')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(storeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    storeBlips = {}
end)
