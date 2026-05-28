
local isUIOpen          = false
local currentVehicle    = nil
local currentVehicleId  = nil
local currentShopCode   = nil
local originalMods      = {}

local MOD_NATIVE = {
    engine       = 11,
    brakes       = 12,
    transmission = 13,
    turbo        = 18,
    suspension   = 15,
    armor        = 16,
    xenon        = 22,
}

local function HexToRGB(hex)
    if not hex or #hex < 6 then return 255, 255, 255 end
    hex = hex:gsub('#', '')
    return tonumber(hex:sub(1, 2), 16) or 255,
           tonumber(hex:sub(3, 4), 16) or 255,
           tonumber(hex:sub(5, 6), 16) or 255
end

local function RGBToHex(r, g, b)
    return string.format('#%02X%02X%02X', r or 0, g or 0, b or 0)
end

local function ApplyModNative(vehicle, category, tier)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)

    local nativeType = MOD_NATIVE[category]

    if category == 'turbo' or category == 'xenon' then
        ToggleVehicleMod(vehicle, nativeType, tier == 1)

    elseif category == 'wheels' then
        if type(tier) == 'table' then
            SetVehicleWheelType(vehicle, tonumber(tier.type) or 0)
            local idx = tonumber(tier.index)
            if idx and idx >= 0 then
                SetVehicleMod(vehicle, 23, idx, false)
                SetVehicleMod(vehicle, 24, idx, false)
            end
        else
            SetVehicleWheelType(vehicle, tonumber(tier) or 0)
        end

    elseif category == 'color' then
        if type(tier) == 'table' then
            if tier.primary then
                local r, g, b = HexToRGB(tier.primary)
                SetVehicleCustomPrimaryColour(vehicle, r, g, b)
            end
            if tier.secondary then
                local r, g, b = HexToRGB(tier.secondary)
                SetVehicleCustomSecondaryColour(vehicle, r, g, b)
            end
            if tier.pearl ~= nil then
                local _, _, wheelCol = GetVehicleExtraColours(vehicle)
                SetVehicleExtraColours(vehicle, tonumber(tier.pearl) or 0, wheelCol or 0)
            end
        end

    elseif category == 'livery' then
        SetVehicleLivery(vehicle, tonumber(tier))

    elseif nativeType then
        -- tier 0 înseamnă stock: nativul așteaptă -1, nu 0
        if tonumber(tier) == 0 then
            SetVehicleMod(vehicle, nativeType, -1, false)
        else
            SetVehicleMod(vehicle, nativeType, tonumber(tier) - 1, false)
        end
    end
end

local function ApplyAllMods(vehicle, mods)
    if not mods or not DoesEntityExist(vehicle) then return end
    if type(mods) == 'string' then mods = json.decode(mods) or {} end

    SetVehicleModKit(vehicle, 0)

    for cat, val in pairs(mods) do
        if cat == 'color_primary' or cat == 'color_secondary' then
            -- aplicate la final, după kit
        elseif cat == 'livery' then
            SetVehicleLivery(vehicle, tonumber(val))
        elseif cat == 'turbo' or cat == 'xenon' then
            local nativeType = MOD_NATIVE[cat]
            if nativeType then ToggleVehicleMod(vehicle, nativeType, tonumber(val) == 1) end
        elseif cat == 'wheels' then
            SetVehicleWheelType(vehicle, tonumber(val) or 0)
        elseif cat == 'wheels_index' then
            local idx = tonumber(val)
            if idx and idx >= 0 then
                SetVehicleMod(vehicle, 23, idx, false)
                SetVehicleMod(vehicle, 24, idx, false)
            end
        elseif cat == 'color_pearl' then
            local _, _, wheelCol = GetVehicleExtraColours(vehicle)
            SetVehicleExtraColours(vehicle, tonumber(val) or 0, wheelCol or 0)
        elseif MOD_NATIVE[cat] then
            local t = tonumber(val) or 0
            if t == 0 then
                SetVehicleMod(vehicle, MOD_NATIVE[cat], -1, false)
            else
                SetVehicleMod(vehicle, MOD_NATIVE[cat], t - 1, false)
            end
        end
    end

    if mods['color_primary'] then
        local r, g, b = HexToRGB(tostring(mods['color_primary']))
        SetVehicleCustomPrimaryColour(vehicle, r, g, b)
    end
    if mods['color_secondary'] then
        local r, g, b = HexToRGB(tostring(mods['color_secondary']))
        SetVehicleCustomSecondaryColour(vehicle, r, g, b)
    end
end

exports('ApplyModsToEntity', ApplyAllMods)

local function SnapshotMods(vehicle)
    local snap = {}
    if not DoesEntityExist(vehicle) then return snap end

    SetVehicleModKit(vehicle, 0)

    for cat, nativeType in pairs(MOD_NATIVE) do
        if cat == 'turbo' or cat == 'xenon' then
            snap[cat] = IsToggleModOn(vehicle, nativeType) and 1 or 0
        else
            local idx = GetVehicleMod(vehicle, nativeType)
            snap[cat] = idx >= 0 and (idx + 1) or 0
        end
    end

    snap['wheels']       = GetVehicleWheelType(vehicle)
    snap['wheels_index'] = GetVehicleMod(vehicle, 23)
    snap['livery']       = GetVehicleLivery(vehicle)

    local pr, pg, pb = GetVehicleCustomPrimaryColour(vehicle)
    local sr, sg, sb = GetVehicleCustomSecondaryColour(vehicle)
    snap['color_primary']   = RGBToHex(pr, pg, pb)
    snap['color_secondary'] = RGBToHex(sr, sg, sb)

    local pearl = GetVehicleExtraColours(vehicle)
    snap['color_pearl'] = pearl or 0

    return snap
end

local function RestoreSnapshot(vehicle, snap)
    if not DoesEntityExist(vehicle) or not snap then return end

    SetVehicleModKit(vehicle, 0)

    -- wheel type trebuie setat înainte de index, altfel SetVehicleMod 23/24 e ignorat
    if snap['wheels'] ~= nil then
        SetVehicleWheelType(vehicle, tonumber(snap['wheels']) or 0)
    end

    for cat, tier in pairs(snap) do
        if cat ~= 'color_primary' and cat ~= 'color_secondary'
           and cat ~= 'color_pearl'  and cat ~= 'wheels'
           and cat ~= 'wheels_index' then
            ApplyModNative(vehicle, cat, tier)
        end
    end

    if snap['wheels_index'] ~= nil then
        local idx = tonumber(snap['wheels_index'])
        if idx and idx >= 0 then
            SetVehicleMod(vehicle, 23, idx, false)
            SetVehicleMod(vehicle, 24, idx, false)
        end
    end

    ApplyModNative(vehicle, 'color', {
        primary   = snap['color_primary'],
        secondary = snap['color_secondary'],
        pearl     = snap['color_pearl'],
    })
end

local function CloseUI()
    if not isUIOpen then return end

    RestoreSnapshot(currentVehicle, originalMods)

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })

    isUIOpen         = false
    currentVehicle   = nil
    currentVehicleId = nil
    currentShopCode  = nil
    originalMods     = {}
end

local shopsRegistered = false
local proximityIds = {}
local shopBlips = {}

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('tuning:server:requestShops')
end)

RegisterNetEvent('tuning:client:initShops', function(shops)
    if shopsRegistered then return end
    shopsRegistered = true

    for _, shop in ipairs(shops) do
        local id = exports.proximity:AddInteraction(
            vector3(shop.coords.x, shop.coords.y, shop.coords.z),
            shop.name .. '\nDeschide LS Customs',
            'tuning_open',
            { shopCode = shop.code, shopName = shop.name }
        )
        table.insert(proximityIds, id)

        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 72)
        SetBlipColour(blip, 47)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(shop.name or 'LS Customs')
        EndTextCommandSetBlipName(blip)

        table.insert(shopBlips, blip)
    end

    print(string.format('[TUNING] %d shop-uri proximity înregistrate.', #shops))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, id in ipairs(proximityIds) do
        exports.proximity:RemoveInteraction(id)
    end
    for _, blip in ipairs(shopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)

AddEventHandler('switcore:proximity:interact', function(interaction)
    if interaction.type ~= 'tuning_open' then return end
    if isUIOpen then return end

    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not DoesEntityExist(vehicle) or vehicle == 0 then
        TriggerEvent('switcore:notify', 'error', 'Trebuie să fii în vehicul pentru a folosi LS Customs.', 4000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    TriggerServerEvent('tuning:server:openShop', plate, interaction.data.shopCode)
end)

RegisterNetEvent('tuning:client:openUI', function(vehicleData, tuningConfig)
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not DoesEntityExist(vehicle) or vehicle == 0 then return end

    currentVehicle   = vehicle
    currentVehicleId = vehicleData.id
    currentShopCode  = tuningConfig.shopCode
    originalMods     = SnapshotMods(vehicle)

    local liveryCount = GetVehicleLiveryCount(vehicle)

    SendNUIMessage({
        action  = 'openUI',
        vehicle = vehicleData,
        config  = tuningConfig,
    })

    SetNuiFocus(true, true)
    isUIOpen = true
end)

RegisterNetEvent('tuning:client:openFailed', function(reason)
    TriggerEvent('switcore:notify', 'error', reason or 'Nu s-a putut deschide LS Customs.', 5000)
end)

RegisterNUICallback('previewMod', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        cb({ ok = false, err = 'Niciun vehicul' })
        return
    end

    local category = data.category
    local tier     = data.tier

    if category == 'color' then
        ApplyModNative(currentVehicle, 'color', {
            primary   = data.colorPrimary,
            secondary = data.colorSecondary,
            pearl     = data.colorPearl,
        })
    elseif category == 'livery' then
        ApplyModNative(currentVehicle, 'livery', tonumber(tier))
    elseif category == 'wheels' then
        ApplyModNative(currentVehicle, 'wheels', {
            type  = tonumber(tier),
            index = tonumber(data.subIndex),
        })
    else
        ApplyModNative(currentVehicle, category, tonumber(tier))
    end

    cb({ ok = true })
end)

RegisterNUICallback('restorePreview', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local category = data.category
        if category == 'color' then
            ApplyModNative(currentVehicle, 'color', {
                primary   = originalMods['color_primary'],
                secondary = originalMods['color_secondary'],
                pearl     = originalMods['color_pearl'],
            })
        elseif category == 'wheels' then
            ApplyModNative(currentVehicle, 'wheels', {
                type  = originalMods['wheels']       or 0,
                index = originalMods['wheels_index'] or -1,
            })
        else
            local origTier = originalMods[category] or 0
            ApplyModNative(currentVehicle, category, origTier)
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('getWheelDesignCount', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        cb({ count = 0 }); return
    end
    SetVehicleModKit(currentVehicle, 0)
    local wheelType = tonumber(data.wheelType) or 0
    local prevType  = GetVehicleWheelType(currentVehicle)
    -- GetNumVehicleMods(23) depinde de wheelType-ul curent setat pe entitate
    SetVehicleWheelType(currentVehicle, wheelType)
    local count = GetNumVehicleMods(currentVehicle, 23)
    SetVehicleWheelType(currentVehicle, prevType)
    cb({ count = count })
end)

RegisterNUICallback('applyMod', function(data, cb)
    if not currentVehicleId then
        cb({ ok = false, err = 'Niciun vehicul selectat' })
        return
    end

    local category      = data.category
    local tier          = data.tier
    local paymentMethod = data.paymentMethod or 'cash'

    if category == 'color' then
        TriggerServerEvent('tuning:server:applyColor',
            currentVehicleId, data.colorPrimary, data.colorSecondary,
            paymentMethod, currentShopCode, data.colorPearl)
    elseif category == 'livery' then
        TriggerServerEvent('tuning:server:applyLivery',
            currentVehicleId, tonumber(tier), paymentMethod, currentShopCode)
    elseif category == 'wheels' then
        TriggerServerEvent('tuning:server:applyMod',
            currentVehicleId, category, tonumber(tier), paymentMethod, currentShopCode,
            { subIndex = tonumber(data.subIndex) })
    else
        TriggerServerEvent('tuning:server:applyMod',
            currentVehicleId, category, tonumber(tier), paymentMethod, currentShopCode)
    end

    cb({ ok = true })
end)

RegisterNUICallback('resetMods', function(data, cb)
    if not currentVehicleId then cb({ ok = false }) return end
    TriggerServerEvent('tuning:server:resetMods',
        currentVehicleId, data.paymentMethod or 'cash', currentShopCode)
    cb({ ok = true })
end)

RegisterNUICallback('closeUI', function(_data, cb)
    CloseUI()
    cb({ ok = true })
end)

RegisterNUICallback('restoreAll', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        RestoreSnapshot(currentVehicle, originalMods)
    end
    cb({ ok = true })
end)

RegisterNUICallback('applyCart', function(data, cb)
    if not currentVehicleId then cb({ ok = false, err = 'Niciun vehicul' }) return end
    TriggerServerEvent('tuning:server:applyCart',
        currentVehicleId, data.items, data.paymentMethod or 'cash', currentShopCode)
    cb({ ok = true })
end)

RegisterNUICallback('previewColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        ApplyModNative(currentVehicle, 'color', {
            primary   = data.colorPrimary,
            secondary = data.colorSecondary,
        })
    end
    cb({ ok = true })
end)

RegisterNetEvent('tuning:client:modApplied', function(category, tier, newMods)
    if category ~= 'color' then
        originalMods[category] = tier
    end
    SendNUIMessage({ action = 'modConfirmed', category = category, tier = tier, newMods = newMods })
end)

RegisterNetEvent('tuning:client:modFailed', function(category, tier)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        if category == 'color' then
            ApplyModNative(currentVehicle, 'color', {
                primary   = originalMods['color_primary'],
                secondary = originalMods['color_secondary'],
            })
        else
            ApplyModNative(currentVehicle, category, originalMods[category] or 0)
        end
    end
    SendNUIMessage({ action = 'modFailed', category = category, tier = tier })
end)

RegisterNetEvent('tuning:client:colorApplied', function(colorPrimary, colorSecondary, newMods)
    if colorPrimary   then originalMods['color_primary']   = colorPrimary   end
    if colorSecondary then originalMods['color_secondary'] = colorSecondary end
    if newMods and newMods['color_pearl'] ~= nil then
        originalMods['color_pearl'] = newMods['color_pearl']
    end
    SendNUIMessage({
        action        = 'colorConfirmed',
        colorPrimary  = colorPrimary,
        colorSecondary = colorSecondary,
        newMods        = newMods,
    })
end)

RegisterNetEvent('tuning:client:liveryApplied', function(liveryIndex, newMods)
    originalMods['livery'] = liveryIndex
    SendNUIMessage({ action = 'liveryConfirmed', liveryIndex = liveryIndex, newMods = newMods })
end)

RegisterNetEvent('tuning:client:modsReset', function()
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleModKit(currentVehicle, 0)
        for _, nativeType in pairs(MOD_NATIVE) do
            ToggleVehicleMod(currentVehicle, nativeType, false)
            SetVehicleMod(currentVehicle, nativeType, -1, false)
        end
    end
    originalMods = SnapshotMods(currentVehicle)
    SendNUIMessage({ action = 'modsReset', finalMods = originalMods })
end)

RegisterNetEvent('tuning:client:cartApplied', function(results, finalMods)
    if finalMods and currentVehicle and DoesEntityExist(currentVehicle) then
        ApplyAllMods(currentVehicle, finalMods)
    end

    if finalMods then
        for cat, val in pairs(finalMods) do
            originalMods[cat] = val
        end
    end

    SendNUIMessage({ action = 'cartApplied', results = results, finalMods = finalMods })
end)
