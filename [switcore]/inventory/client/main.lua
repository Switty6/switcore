local isInventoryOpen = false
local currentInventoryId = nil
local droppedProps = {}
local PlayerPedPreview = nil

local ClientConfig = {
    HotbarSlots = 5,
    DropInteractionRange = 2.0,
    DefaultDropProp = 'prop_paper_bag_01'
}

RegisterNetEvent('switcore:inventoryInit')
AddEventHandler('switcore:inventoryInit', function(invId, inv, itemsConfig, srvConfig)
    currentInventoryId = invId
    if srvConfig then ClientConfig = srvConfig end

    local uiCfg = {
        HotbarSlots          = ClientConfig.HotbarSlots or 5,
        MaxSlots             = (inv and inv.maxSlots) or 40,
        DropInteractionRange = ClientConfig.DropInteractionRange or 2.0,
        DefaultDropProp      = ClientConfig.DefaultDropProp or 'prop_paper_bag_01',
    }

    SendNUIMessage({
        action = "setupConfig",
        config = uiCfg,
        items  = itemsConfig
    })

    SendNUIMessage({
        action    = "updateInventory",
        inventory = inv,
        invId     = invId
    })
end)

RegisterNetEvent('switcore:inventoryUpdated')
AddEventHandler('switcore:inventoryUpdated', function(invId, inv)
    SendNUIMessage({
        action = "updateInventory",
        inventory = inv,
        invId = invId
    })
end)

RegisterNetEvent('switcore:inventoryCashUpdate')
AddEventHandler('switcore:inventoryCashUpdate', function(cashList)
    SendNUIMessage({
        action = "updateCash",
        cash = cashList or {}
    })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Citizen.CreateThread(function()
            Citizen.Wait(1000)
            TriggerEvent('switcore:requestCurrentCharacter')
        end)
    end
end)

function createPedScreen()
    Citizen.CreateThread(function()
        local heading = GetEntityHeading(PlayerPedId())
        SetFrontendActive(true)
        ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_EMPTY_NO_BACKGROUND"), true, -1)
        Citizen.Wait(100)
        N_0x98215325a695e78a(false)
        PlayerPedPreview = ClonePed(PlayerPedId(), heading, true, false)
        local x,y,z = table.unpack(GetEntityCoords(PlayerPedPreview))
        SetEntityCoords(PlayerPedPreview, x,y,z-10)
        FreezeEntityPosition(PlayerPedPreview, true)
        SetEntityVisible(PlayerPedPreview, false, false)
        NetworkSetEntityInvisibleToNetwork(PlayerPedPreview, false)
        Wait(200)
        SetPedAsNoLongerNeeded(PlayerPedPreview)
        GivePedToPauseMenu(PlayerPedPreview, 2)
        SetPauseMenuPedLighting(true)
        SetPauseMenuPedSleepState(true)
    end)
end

function destroyPedScreen()
    if PlayerPedPreview then
        DeleteEntity(PlayerPedPreview)
        PlayerPedPreview = nil
    end
    SetFrontendActive(false)
end

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

function ToggleInventory()
    isInventoryOpen = not isInventoryOpen
    SetNuiFocus(isInventoryOpen, isInventoryOpen)
    if isInventoryOpen then
        pushI18n()
    end
    SendNUIMessage({
        action = isInventoryOpen and "open" or "close"
    })

    if isInventoryOpen then
        createPedScreen()
        TriggerServerEvent('switcore:inventoryRequestCash')
    else
        destroyPedScreen()
    end
end

CreateThread(function()
    while true do
        Wait(3000)
        if isInventoryOpen then
            TriggerServerEvent('switcore:inventoryRequestCash')
        end
    end
end)

RegisterCommand('inventory', function()
    ToggleInventory()
end, false)
RegisterKeyMapping('inventory', Sw.T('inventory.keybind.open_inventory'), 'keyboard', 'TAB')

exports('OpenSecondaryInventory', function()
    if isInventoryOpen then return end
    isInventoryOpen = true
    SetNuiFocus(true, true)
    pushI18n()
    SendNUIMessage({ action = 'open' })
    createPedScreen()
    TriggerServerEvent('switcore:inventoryRequestCash')
end)

RegisterNUICallback('close', function(data, cb)
    isInventoryOpen = false
    SetNuiFocus(false, false)
    destroyPedScreen()
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('switcore:inventoryMoveItem', data.fromInv, data.toInv, data.fromSlot, data.toSlot, data.amount)
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('switcore:inventoryUseItem', data.invId, data.slot)
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('switcore:inventoryDropItem', data.invId, data.slot, data.amount)
    cb('ok')
end)

local function getClosestPlayerServerId()
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestId, closestDist = nil, 3.0
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= PlayerId() then
            local ped = GetPlayerPed(p)
            if DoesEntityExist(ped) then
                local d = #(myCoords - GetEntityCoords(ped))
                if d < closestDist then
                    closestDist = d
                    closestId = GetPlayerServerId(p)
                end
            end
        end
    end
    return closestId
end

RegisterNUICallback('giveItem', function(data, cb)
    local target = getClosestPlayerServerId()
    if not target then
        exports.notifications:Notify('error', Sw.T('inventory.notify.no_player_nearby'), 3500)
        cb('ok')
        return
    end
    TriggerServerEvent('switcore:inventoryGiveItem', target, data.invId, data.slot, data.amount)
    cb('ok')
end)

for i=1, 5 do
    RegisterCommand('hotbar_'..i, function()
        if not isInventoryOpen and currentInventoryId then
            TriggerServerEvent('switcore:inventoryUseItem', currentInventoryId, i)
        end
    end, false)
    RegisterKeyMapping('hotbar_'..i, Sw.T('inventory.keybind.use_slot', i), 'keyboard', tostring(i))
end

local savedClothes = {}

RegisterNUICallback('ToggleClothing', function(data, cb)
    local ped = PlayerPedId()
    local type = data.type
    
    if type == "hat" then
        if savedClothes.hat then
            SetPedPropIndex(ped, 0, savedClothes.hat.drawable, savedClothes.hat.texture, true)
            savedClothes.hat = nil
        else
            savedClothes.hat = { drawable = GetPedPropIndex(ped, 0), texture = GetPedPropTextureIndex(ped, 0) }
            ClearPedProp(ped, 0)
        end
    elseif type == "mask" then
        if savedClothes.mask then
            SetPedComponentVariation(ped, 1, savedClothes.mask.drawable, savedClothes.mask.texture, 2)
            savedClothes.mask = nil
        else
            savedClothes.mask = { drawable = GetPedDrawableVariation(ped, 1), texture = GetPedTextureVariation(ped, 1) }
            SetPedComponentVariation(ped, 1, 0, 0, 2)
        end
    elseif type == "glasses" then
        if savedClothes.glasses then
            SetPedPropIndex(ped, 1, savedClothes.glasses.drawable, savedClothes.glasses.texture, true)
            savedClothes.glasses = nil
        else
            savedClothes.glasses = { drawable = GetPedPropIndex(ped, 1), texture = GetPedPropTextureIndex(ped, 1) }
            ClearPedProp(ped, 1)
        end
    elseif type == "torso" then
        if savedClothes.torso then
            SetPedComponentVariation(ped, 11, savedClothes.torso.drawable, savedClothes.torso.texture, 2)
            SetPedComponentVariation(ped, 8, savedClothes.tshirt.drawable, savedClothes.tshirt.texture, 2)
            SetPedComponentVariation(ped, 3, savedClothes.arms.drawable, savedClothes.arms.texture, 2)
            savedClothes.torso = nil
            savedClothes.tshirt = nil
            savedClothes.arms = nil
        else
            savedClothes.torso = { drawable = GetPedDrawableVariation(ped, 11), texture = GetPedTextureVariation(ped, 11) }
            savedClothes.tshirt = { drawable = GetPedDrawableVariation(ped, 8), texture = GetPedTextureVariation(ped, 8) }
            savedClothes.arms = { drawable = GetPedDrawableVariation(ped, 3), texture = GetPedTextureVariation(ped, 3) }
            SetPedComponentVariation(ped, 11, 15, 0, 2)
            SetPedComponentVariation(ped, 8, 15, 0, 2)
            SetPedComponentVariation(ped, 3, 15, 0, 2)
        end
    elseif type == "armor" then
        if savedClothes.armor then
            SetPedComponentVariation(ped, 9, savedClothes.armor.drawable, savedClothes.armor.texture, 2)
            savedClothes.armor = nil
        else
            savedClothes.armor = { drawable = GetPedDrawableVariation(ped, 9), texture = GetPedTextureVariation(ped, 9) }
            SetPedComponentVariation(ped, 9, 0, 0, 2)
        end
    elseif type == "pants" then
        if savedClothes.pants then
            SetPedComponentVariation(ped, 4, savedClothes.pants.drawable, savedClothes.pants.texture, 2)
            savedClothes.pants = nil
        else
            savedClothes.pants = { drawable = GetPedDrawableVariation(ped, 4), texture = GetPedTextureVariation(ped, 4) }
            local model = GetEntityModel(ped)
            if model == GetHashKey("mp_m_freemode_01") then
                SetPedComponentVariation(ped, 4, 14, 0, 2) 
            elseif model == GetHashKey("mp_f_freemode_01") then
                SetPedComponentVariation(ped, 4, 15, 0, 2)
            else
                SetPedComponentVariation(ped, 4, 14, 0, 2)
            end
        end
    elseif type == "shoes" then
        if savedClothes.shoes then
            SetPedComponentVariation(ped, 6, savedClothes.shoes.drawable, savedClothes.shoes.texture, 2)
            savedClothes.shoes = nil
        else
            savedClothes.shoes = { drawable = GetPedDrawableVariation(ped, 6), texture = GetPedTextureVariation(ped, 6) }
            local model = GetEntityModel(ped)
            if model == GetHashKey("mp_m_freemode_01") then
                SetPedComponentVariation(ped, 6, 34, 0, 2) 
            elseif model == GetHashKey("mp_f_freemode_01") then
                SetPedComponentVariation(ped, 6, 35, 0, 2)
            else
                SetPedComponentVariation(ped, 6, 34, 0, 2)
            end
        end
    end
    
    if PlayerPedPreview then
        ClonePedToTarget(ped, PlayerPedPreview)
    end
    
    cb('ok')
end)

local function playAnimOnce(dict, name, durationMs)
    if not dict or not name or dict == '' or name == '' then return end
    RequestAnimDict(dict)
    local waited = 0
    while not HasAnimDictLoaded(dict) and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end
    if not HasAnimDictLoaded(dict) then return end
    local ped = PlayerPedId()
    TaskPlayAnim(ped, dict, name, 4.0, -4.0, durationMs or 1500, 49, 0, false, false, false)
end

RegisterNetEvent('switcore:inventoryPlayDropAnim')
AddEventHandler('switcore:inventoryPlayDropAnim', function(dict, name)
    playAnimOnce(dict, name, 1500)
end)

RegisterNetEvent('switcore:createPhysicalDrop')
AddEventHandler('switcore:createPhysicalDrop', function(dropId, itemName, label, coords, propOverride)
    local propModel = propOverride
    if not propModel or propModel == '' then propModel = ClientConfig.DefaultDropProp end

    local model = GetHashKey(propModel)
    RequestModel(model)
    local waited = 0
    while not HasModelLoaded(model) and waited < 3000 do
        Wait(20)
        waited = waited + 20
    end
    if not HasModelLoaded(model) then
        model = GetHashKey(ClientConfig.DefaultDropProp)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
    end

    local z = coords.z
    local retval, groundZ = GetGroundZFor_3dCoord_2(coords.x, coords.y, coords.z, false)
    if retval then z = groundZ end

    local prop = CreateObject(model, coords.x, coords.y, z, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)

    droppedProps[dropId] = prop

    exports.proximity:AddInteraction(dropId, {
        label = Sw.T('inventory.interaction.pickup', label),
        icon = "fas fa-hand-holding",
        distance = ClientConfig.DropInteractionRange,
        coords = vector3(coords.x, coords.y, z),
        action = function()
            playAnimOnce('pickup_object', 'pickup_low', 1500)
            Wait(900)
            TriggerServerEvent('switcore:inventoryPickupDrop', dropId, currentInventoryId)
        end
    })
end)

RegisterNetEvent('switcore:removePhysicalDrop')
AddEventHandler('switcore:removePhysicalDrop', function(dropId)
    if droppedProps[dropId] then
        DeleteEntity(droppedProps[dropId])
        droppedProps[dropId] = nil
    end
    exports.proximity:RemoveInteraction(dropId)
end)
