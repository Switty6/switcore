local isNearby = false
local currentInteraction = nil
local currentInteractionId = nil
local interactionDistance = 0.0
local nuiEnabled = false
local mouseEnabled = false
local nearbyInteractions = {}
local selectedInteractionIndex = 1
local PlayerPed = nil
local playerCoords = vector3(0.0, 0.0, 0.0)
local lastCoordsUpdate = 0
local COORDS_UPDATE_INTERVAL = 100
local lastScreenX = 0
local lastScreenY = 0

-- Helper pentru traducere (folosește client-side localization)
local function Translate(key, ...)
    if exports.core and exports.core.translate then
        return exports.core:translate(key, ...)
    end
    return key
end

local function GetPlayerPed()
    local ped = PlayerPedId()
    if ped ~= PlayerPed then
        PlayerPed = ped
    end
    return PlayerPed
end

local function GetDistance(coords1, coords2)
    local dx = coords1.x - coords2.x
    local dy = coords1.y - coords2.y
    local dz = coords1.z - coords2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function GetPlayerCoords()
    local currentTime = GetGameTimer()
    if currentTime - lastCoordsUpdate > COORDS_UPDATE_INTERVAL then
        local ped = GetPlayerPed()
        if ped and ped ~= 0 then
            playerCoords = GetEntityCoords(ped)
            lastCoordsUpdate = currentTime
        end
    end
    return playerCoords
end

local function IsPointInTriangle(point, v1, v2, v3)
    local d1 = (point.x - v3.x) * (v1.y - v3.y) - (v1.x - v3.x) * (point.y - v3.y)
    local d2 = (point.x - v3.x) * (v2.y - v3.y) - (v2.x - v3.x) * (point.y - v3.y)
    local d3 = (v1.x - v3.x) * (v2.y - v3.y) - (v2.x - v3.x) * (v1.y - v3.y)
    local has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    local has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)
end

local function IsPointInRectangle(point, corner1, corner2, minZ, maxZ)
    local minX = math.min(corner1.x, corner2.x)
    local maxX = math.max(corner1.x, corner2.x)
    local minY = math.min(corner1.y, corner2.y)
    local maxY = math.max(corner1.y, corner2.y)
    if minZ and maxZ then
        return point.x >= minX and point.x <= maxX and point.y >= minY and point.y <= maxY and point.z >= minZ and point.z <= maxZ
    else
        return point.x >= minX and point.x <= maxX and point.y >= minY and point.y <= maxY
    end
end

local function IsPointInZone(point, zone)
    if zone.type == "rectangle" or zone.type == "square" then
        return IsPointInRectangle(point, zone.corner1, zone.corner2, zone.minZ, zone.maxZ)
    elseif zone.type == "triangle" then
        return IsPointInTriangle(point, zone.v1, zone.v2, zone.v3)
    end
    return false
end

local function FindEntitiesByModel(modelHash, maxDistance)
    local playerPos = GetPlayerCoords()
    local entities = {}
    local maxDist = maxDistance or Config.ProximityDistance * 2
    local function CheckPool(pool, getModel)
        for i, entity in ipairs(pool) do
            if DoesEntityExist(entity) and getModel(entity) == modelHash then
                local pos = GetEntityCoords(entity)
                local dist = GetDistance(playerPos, pos)
                if dist <= maxDist then
                    table.insert(entities, { entity = entity, coords = pos, distance = dist })
                end
            end
            if i % 5 == 0 then Wait(4) end
        end
    end
    CheckPool(GetGamePool('CVehicle'), GetEntityModel)
    CheckPool(GetGamePool('CPed'), GetEntityModel)
    CheckPool(GetGamePool('CObject'), GetEntityModel)
    table.sort(entities, function(a, b) return a.distance < b.distance end)
    return entities
end

local function ProcessInteraction(interaction, playerPos, i, isStatic)
    if not interaction then return end
    if isStatic and i % 10 == 0 then Wait(4) end
    local distance = 999999.0
    local coords = nil
    local isValid = false
    if interaction.coords then
        distance = GetDistance(playerPos, interaction.coords)
        coords = interaction.coords
        isValid = true
    elseif interaction.entity and DoesEntityExist(interaction.entity) then
        coords = GetEntityCoords(interaction.entity)
        distance = GetDistance(playerPos, coords)
        isValid = true
    elseif interaction.modelHash then
        if not interaction._lastModelCheck then interaction._lastModelCheck = 0 end
        local currentTime = GetGameTimer()
        if currentTime - interaction._lastModelCheck > 200 then
            interaction._lastModelCheck = currentTime
            local entities = FindEntitiesByModel(interaction.modelHash, interaction.maxDistance or Config.ProximityDistance * 2)
            if #entities > 0 then
                local closest = entities[1]
                distance = closest.distance
                coords = closest.coords
                isValid = true
                if not interaction.entity then interaction.entity = closest.entity end
            end
        else
            if interaction.entity and DoesEntityExist(interaction.entity) then
                coords = GetEntityCoords(interaction.entity)
                distance = GetDistance(playerPos, coords)
                isValid = true
            end
        end
    elseif interaction.zone then
        if IsPointInZone(playerPos, interaction.zone) then
            coords = interaction.zone.center or interaction.zone.corner1 or interaction.zone.v1
            if coords then
                distance = GetDistance(playerPos, coords)
                isValid = true
            else
                distance = 0.0
                coords = playerPos
                isValid = true
            end
        end
    end
    if isValid and distance <= Config.ProximityDistance then
        return {
            interaction = interaction,
            id = isStatic and ("static_" .. i) or ("dynamic_" .. (type(i) == "string" and i or tostring(i))),
            distance = distance,
            coords = coords,
            entity = interaction.entity
        }
    end
    return nil
end

local function CheckProximity()
    local playerPos = GetPlayerCoords()
    nearbyInteractions = {}
    for i = 1, #Config.Interactions do
        local result = ProcessInteraction(Config.Interactions[i], playerPos, i, true)
        if result then table.insert(nearbyInteractions, result) end
    end
    local dynamicCount = 0
    for id, interaction in pairs(Config.DynamicInteractions) do
        if interaction then
            dynamicCount = dynamicCount + 1
            if dynamicCount % 10 == 0 then Wait(4) end
            local result = ProcessInteraction(interaction, playerPos, id, false)
            if result then table.insert(nearbyInteractions, result) end
        end
    end
    table.sort(nearbyInteractions, function(a, b) return a.distance < b.distance end)
    if selectedInteractionIndex > #nearbyInteractions then
        selectedInteractionIndex = math.max(1, #nearbyInteractions)
    end
    local wasNearby = isNearby
    local shouldBeNearby = #nearbyInteractions > 0
    if shouldBeNearby ~= wasNearby or (shouldBeNearby and #nearbyInteractions > 0) then
        isNearby = shouldBeNearby
        if shouldBeNearby and #nearbyInteractions > 0 then
            local selectedData = nearbyInteractions[selectedInteractionIndex]
            if selectedData then
                currentInteraction = selectedData.interaction
                currentInteractionId = selectedData.id
                interactionDistance = selectedData.distance
                if selectedData.coords then currentInteraction.currentCoords = selectedData.coords end
                if selectedData.entity then currentInteraction.entity = selectedData.entity end
                if Config.Debug then
                    print(string.format("[PROXIMITY] %d interacțiuni disponibile. Selectat: %s (%.2fm)", #nearbyInteractions, currentInteraction.label or "Unknown", interactionDistance))
                end
            end
        else
            currentInteraction = nil
            currentInteractionId = nil
            interactionDistance = 0.0
            selectedInteractionIndex = 1
        end
    end
end

local function GetEntityCenter(entity)
    if not DoesEntityExist(entity) then return nil end
    local min, max = GetModelDimensions(GetEntityModel(entity))
    if min and max then
        local coords = GetEntityCoords(entity)
        local centerZ = coords.z + (min.z + max.z) / 2
        return vector3(coords.x, coords.y, centerZ)
    end
    return GetEntityCoords(entity)
end

local function UpdateNUI()
    if not nuiEnabled then return end
    if isNearby and currentInteraction then
        local interactionCoords = currentInteraction.currentCoords or currentInteraction.coords or GetPlayerCoords()
        local targetCoords = interactionCoords
        
        if currentInteraction.entity and DoesEntityExist(currentInteraction.entity) then
            local entityCenter = GetEntityCenter(currentInteraction.entity)
            if entityCenter then
                targetCoords = vector3(
                    entityCenter.x + Config.EntityOffset.x,
                    entityCenter.y + Config.EntityOffset.y,
                    entityCenter.z + Config.EntityOffset.z
                )
            else
                local entityCoords = GetEntityCoords(currentInteraction.entity)
                targetCoords = vector3(
                    entityCoords.x + Config.EntityOffset.x,
                    entityCoords.y + Config.EntityOffset.y,
                    entityCoords.z + Config.EntityOffset.z
                )
            end
        else
            targetCoords = vector3(
                interactionCoords.x,
                interactionCoords.y,
                interactionCoords.z + Config.TextOffset.z
            )
        end
        
        if targetCoords then
            local onScreen, screenX, screenY = World3dToScreen2d(
                targetCoords.x,
                targetCoords.y,
                targetCoords.z
            )
            if onScreen then
                local w, h = GetActiveScreenResolution()
                screenX = screenX * w
                screenY = screenY * h
                if lastScreenX and lastScreenY and lastScreenX > 0 and lastScreenY > 0 then
                    local diffX = math.abs(screenX - lastScreenX)
                    local diffY = math.abs(screenY - lastScreenY)
                    if diffX < 150 and diffY < 150 then
                        screenX = lastScreenX + (screenX - lastScreenX) * 0.25
                        screenY = lastScreenY + (screenY - lastScreenY) * 0.25
                    end
                end
                lastScreenX = screenX
                lastScreenY = screenY
                local selectedData = nearbyInteractions[selectedInteractionIndex]
                local firstInteraction = nearbyInteractions[1]
                local markerColor = firstInteraction and (firstInteraction.interaction.color or Config.MarkerColor) or Config.MarkerColor
                
                local entityGroups = {}
                
                for i, data in ipairs(nearbyInteractions) do
                    local entityKey = "none"
                    if data.entity and DoesEntityExist(data.entity) then
                        entityKey = "entity_" .. tostring(data.entity)
                    elseif data.coords then
                        local foundGroup = false
                        for key, groupData in pairs(entityGroups) do
                            if not groupData.entity then
                                local dist = GetDistance(data.coords, groupData.coords)
                                if dist < 0.5 then
                                    entityKey = key
                                    foundGroup = true
                                    break
                                end
                            end
                        end
                        if not foundGroup then
                            entityKey = "coords_" .. tostring(i)
                        end
                    end
                    
                    if not entityGroups[entityKey] then
                        entityGroups[entityKey] = {
                            interactions = {},
                            entity = data.entity,
                            coords = data.coords
                        }
                    end
                    
                    table.insert(entityGroups[entityKey].interactions, {
                        index = i,
                        data = data,
                        selected = (i == selectedInteractionIndex)
                    })
                end
                
                local interactionsList = {}
                for entityKey, groupData in pairs(entityGroups) do
                    local groupInteractions = groupData.interactions
                    table.sort(groupInteractions, function(a, b) return a.data.distance < b.data.distance end)
                    
                    local limit = math.min(3, #groupInteractions)
                    for j = 1, limit do
                        local item = groupInteractions[j]
                        table.insert(interactionsList, {
                            label = item.data.interaction.label or Translate('proximity.interaction'),
                            distance = item.data.distance,
                            selected = item.selected,
                            originalIndex = item.index
                        })
                    end
                end
                
                table.sort(interactionsList, function(a, b) 
                    return (a.originalIndex or 0) < (b.originalIndex or 0)
                end)
                
                local filteredSelectedIndex = 1
                local indexMap = {}
                for listIdx, listItem in ipairs(interactionsList) do
                    indexMap[listIdx] = listItem.originalIndex
                    if listItem.originalIndex == selectedInteractionIndex then
                        filteredSelectedIndex = listIdx
                    end
                    listItem.originalIndex = nil
                end
                
                local currentDistance = interactionDistance
                if selectedInteractionIndex > 0 and nearbyInteractions[selectedInteractionIndex] then
                    currentDistance = nearbyInteractions[selectedInteractionIndex].distance
                end
                SendNUIMessage({
                    action = 'showInteraction',
                    screenX = screenX,
                    screenY = screenY,
                    label = mouseEnabled and (currentInteraction.label or Translate('proximity.interaction')) or Translate('proximity.interact'),
                    keyName = mouseEnabled and "Click" or "ALT",
                    color = markerColor,
                    markerColor = markerColor,
                    distance = currentDistance,
                    interaction = { type = currentInteraction.type, data = currentInteraction.data },
                    multipleInteractions = #interactionsList > 1,
                    currentIndex = filteredSelectedIndex,
                    totalCount = #interactionsList,
                    interactionsList = mouseEnabled and interactionsList or nil,
                    indexMap = mouseEnabled and indexMap or nil,
                    mouseEnabled = mouseEnabled,
                    showList = mouseEnabled,
                    showText = not mouseEnabled
                })
            else
                SendNUIMessage({ action = 'hideInteraction' })
            end
        else
            SendNUIMessage({ action = 'hideInteraction' })
        end
    else
        SendNUIMessage({ action = 'hideInteraction' })
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        if GetPlayerPed() then
            CheckProximity()
            if isNearby and currentInteraction then
                sleep = 100
                UpdateNUI()
            else
                if nuiEnabled then
                    SendNUIMessage({ action = 'hideInteraction' })
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterKeyMapping('proximity:toggleMouse', Config.MouseToggleKeyDescription, 'keyboard', Config.MouseToggleKey)
RegisterCommand('proximity:toggleMouse', function()
    if not isNearby or #nearbyInteractions == 0 then return end
    mouseEnabled = not mouseEnabled
    SetNuiFocus(mouseEnabled, mouseEnabled)
    SendNUIMessage({ action = 'setMouseEnabled', enabled = mouseEnabled })
    if Config.Debug then
        print(string.format("[PROXIMITY] Mouse navigation: %s", mouseEnabled and "ENABLED" or "DISABLED"))
    end
end, false)

RegisterKeyMapping('proximity:closeMouse', 'Close Mouse Navigation', 'keyboard', 'ESCAPE')
RegisterCommand('proximity:closeMouse', function()
    if mouseEnabled then
        mouseEnabled = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'setMouseEnabled', enabled = false })
        if Config.Debug then
            print("[PROXIMITY] Mouse navigation disabled (ESC)")
        end
    end
end, false)

CreateThread(function()
    while true do
        Wait(500)
        if not isNearby or #nearbyInteractions == 0 then
            if mouseEnabled then
                mouseEnabled = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'setMouseEnabled', enabled = false })
            end
        end
    end
end)

CreateThread(function()
    Wait(1000)
    SendNUIMessage({
        action = 'updateConfig',
        config = { showMarker = Config.ShowMarker, showText = Config.ShowText }
    })
    nuiEnabled = true
end)

RegisterNUICallback('selectInteraction', function(data, cb)
    if data.index and nearbyInteractions and #nearbyInteractions > 0 then
        local newIndex = tonumber(data.index)
        if newIndex and newIndex >= 1 and newIndex <= #nearbyInteractions then
            selectedInteractionIndex = newIndex
            local selectedData = nearbyInteractions[selectedInteractionIndex]
            if selectedData then
                currentInteraction = selectedData.interaction
                currentInteractionId = selectedData.id
                interactionDistance = selectedData.distance
                if selectedData.coords then currentInteraction.currentCoords = selectedData.coords end
                if selectedData.entity then currentInteraction.entity = selectedData.entity end
                UpdateNUI()
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('interact', function(data, cb)
    if nearbyInteractions and #nearbyInteractions > 0 then
        local targetIndex = selectedInteractionIndex
        if data and data.index then
            local idx = tonumber(data.index)
            if idx and idx >= 1 and idx <= #nearbyInteractions then
                targetIndex = idx
            end
        end
        if targetIndex and targetIndex >= 1 and targetIndex <= #nearbyInteractions then
            local selectedData = nearbyInteractions[targetIndex]
            if selectedData and selectedData.interaction then
                local interaction = selectedData.interaction
                TriggerEvent('switcore:proximity:interact', interaction)
                if interaction.onInteract then
                    interaction.onInteract(interaction)
                end
                if mouseEnabled then
                    mouseEnabled = false
                    SetNuiFocus(false, false)
                end
                if nuiEnabled then
                    SendNUIMessage({ action = 'hideInteraction' })
                    SendNUIMessage({ action = 'setMouseEnabled', enabled = false })
                end
                isNearby = false
                currentInteraction = nil
                currentInteractionId = nil
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeMouse', function(data, cb)
    if mouseEnabled then
        mouseEnabled = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'setMouseEnabled', enabled = false })
        if Config.Debug then
            print("[PROXIMITY] Mouse navigation disabled (ESC)")
        end
    end
    cb('ok')
end)

RegisterNUICallback('toggleMouse', function(data, cb)
    if not isNearby or #nearbyInteractions == 0 then
        cb('ok')
        return
    end
    mouseEnabled = not mouseEnabled
    SetNuiFocus(mouseEnabled, mouseEnabled)
    SendNUIMessage({ action = 'setMouseEnabled', enabled = mouseEnabled })
    if Config.Debug then
        print(string.format("[PROXIMITY] Mouse navigation: %s (from NUI)", mouseEnabled and "ENABLED" or "DISABLED"))
    end
    cb('ok')
end)

local function GetModelHash(modelName)
    if type(modelName) == "string" then
        return GetHashKey(modelName)
    end
    return modelName
end

local function CreateInteraction(id, data)
    Config.DynamicInteractions[id] = {
        id = id,
        label = data.label or Translate('proximity.interaction'),
        type = data.type or "default",
        data = data.data or {},
        onInteract = data.onInteract,
        color = data.markerColor or Config.MarkerColor
    }
    if data.coords then
        Config.DynamicInteractions[id].coords = type(data.coords) == "vector3" and data.coords or vector3(data.coords.x, data.coords.y, data.coords.z)
    end
    if data.entity then
        if DoesEntityExist(data.entity) then
            Config.DynamicInteractions[id].entity = data.entity
            Config.DynamicInteractions[id].coords = GetEntityCoords(data.entity)
        else
            return nil
        end
    end
    if data.modelHash then
        Config.DynamicInteractions[id].modelHash = data.modelHash
        Config.DynamicInteractions[id].modelName = type(data.modelName) == "string" and data.modelName or nil
        Config.DynamicInteractions[id].maxDistance = data.maxDistance
    end
    if data.zone then
        Config.DynamicInteractions[id].zone = data.zone
    end
    return id
end

exports('AddInteraction', function(coords, label, interactionType, data, onInteract, entity, glowColor, markerColor)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        coords = coords,
        label = label,
        type = interactionType,
        data = data,
        onInteract = onInteract,
        entity = entity,
        markerColor = markerColor
    })
end)

exports('AddEntityInteraction', function(entity, label, interactionType, data, onInteract, glowColor, markerColor)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        entity = entity,
        label = label,
        type = interactionType,
        data = data,
        onInteract = onInteract,
        markerColor = markerColor
    })
end)

exports('AddModelInteraction', function(modelName, label, interactionType, data, onInteract, maxDistance, glowColor, markerColor)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        modelHash = GetModelHash(modelName),
        modelName = type(modelName) == "string" and modelName or nil,
        label = label,
        type = interactionType,
        data = data,
        onInteract = onInteract,
        maxDistance = maxDistance,
        markerColor = markerColor
    })
end)

exports('AddTriangleZone', function(v1, v2, v3, label, interactionType, data, onInteract, glowColor, markerColor)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        zone = {
            type = "triangle",
            v1 = type(v1) == "vector3" and v1 or vector3(v1.x, v1.y, v1.z),
            v2 = type(v2) == "vector3" and v2 or vector3(v2.x, v2.y, v2.z),
            v3 = type(v3) == "vector3" and v3 or vector3(v3.x, v3.y, v3.z),
            center = vector3((v1.x + v2.x + v3.x) / 3, (v1.y + v2.y + v3.y) / 3, (v1.z + v2.z + v3.z) / 3)
        },
        label = label,
        type = interactionType,
        data = data,
        onInteract = onInteract,
        markerColor = markerColor
    })
end)

exports('AddRectangleZone', function(corner1, corner2, label, interactionType, data, onInteract, minZ, maxZ, glowColor, markerColor)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        zone = {
            type = "rectangle",
            corner1 = type(corner1) == "vector3" and corner1 or vector3(corner1.x, corner1.y, corner1.z),
            corner2 = type(corner2) == "vector3" and corner2 or vector3(corner2.x, corner2.y, corner2.z),
            minZ = minZ,
            maxZ = maxZ,
            center = vector3((corner1.x + corner2.x) / 2, (corner1.y + corner2.y) / 2, minZ and maxZ and ((minZ + maxZ) / 2) or (corner1.z + corner2.z) / 2)
        },
        label = label,
        type = interactionType,
        data = data,
        onInteract = onInteract,
        markerColor = markerColor
    })
end)

exports('RemoveInteraction', function(id)
    if Config.DynamicInteractions[id] then
        Config.DynamicInteractions[id] = nil
        return true
    end
    return false
end)

exports('GetCurrentInteraction', function()
    return currentInteraction
end)

exports('IsNearInteraction', function()
    return isNearby
end)

local function AddStaticInteraction(data)
    table.insert(Config.Interactions, {
        label = data.label or Translate('proximity.interaction'),
        type = data.type or "default",
        data = data.data or {},
        entity = data.entity,
        color = data.markerColor or Config.MarkerColor
    })
    if data.coords then
        Config.Interactions[#Config.Interactions].coords = type(data.coords) == "vector3" and data.coords or vector3(data.coords.x, data.coords.y, data.coords.z)
    end
    if data.entity then
        if DoesEntityExist(data.entity) then
            Config.Interactions[#Config.Interactions].coords = GetEntityCoords(data.entity)
        end
    end
    if data.modelHash then
        Config.Interactions[#Config.Interactions].modelHash = data.modelHash
        Config.Interactions[#Config.Interactions].modelName = type(data.modelName) == "string" and data.modelName or nil
        Config.Interactions[#Config.Interactions].maxDistance = data.maxDistance
    end
    if data.zone then
        Config.Interactions[#Config.Interactions].zone = data.zone
    end
end

exports('AddStaticInteraction', function(coords, label, interactionType, data, entity, glowColor, markerColor)
    AddStaticInteraction({ coords = coords, label = label, type = interactionType, data = data, entity = entity, markerColor = markerColor })
end)

exports('AddStaticEntityInteraction', function(entity, label, interactionType, data, glowColor, markerColor)
    if not DoesEntityExist(entity) then
        print("[PROXIMITY] " .. Translate('proximity.error_entity_not_exists'))
        return
    end
    AddStaticInteraction({ entity = entity, label = label, type = interactionType, data = data, markerColor = markerColor })
end)

exports('AddStaticModelInteraction', function(modelName, label, interactionType, data, maxDistance, glowColor, markerColor)
    AddStaticInteraction({
        modelHash = GetModelHash(modelName),
        modelName = type(modelName) == "string" and modelName or nil,
        label = label,
        type = interactionType,
        data = data,
        maxDistance = maxDistance,
        markerColor = markerColor
    })
end)

exports('AddStaticTriangleZone', function(v1, v2, v3, label, interactionType, data, glowColor, markerColor)
    AddStaticInteraction({
        zone = {
            type = "triangle",
            v1 = type(v1) == "vector3" and v1 or vector3(v1.x, v1.y, v1.z),
            v2 = type(v2) == "vector3" and v2 or vector3(v2.x, v2.y, v2.z),
            v3 = type(v3) == "vector3" and v3 or vector3(v3.x, v3.y, v3.z),
            center = vector3((v1.x + v2.x + v3.x) / 3, (v1.y + v2.y + v3.y) / 3, (v1.z + v2.z + v3.z) / 3)
        },
        label = label,
        type = interactionType,
        data = data,
        markerColor = markerColor
    })
end)

exports('AddStaticRectangleZone', function(corner1, corner2, label, interactionType, data, minZ, maxZ, glowColor, markerColor)
    AddStaticInteraction({
        zone = {
            type = "rectangle",
            corner1 = type(corner1) == "vector3" and corner1 or vector3(corner1.x, corner1.y, corner1.z),
            corner2 = type(corner2) == "vector3" and corner2 or vector3(corner2.x, corner2.y, corner2.z),
            minZ = minZ,
            maxZ = maxZ,
            center = vector3((corner1.x + corner2.x) / 2, (corner1.y + corner2.y) / 2, minZ and maxZ and ((minZ + maxZ) / 2) or (corner1.z + corner2.z) / 2)
        },
        label = label,
        type = interactionType,
        data = data,
        markerColor = markerColor
    })
end)

RegisterNetEvent('switcore:proximity:interact', function(interaction)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if nuiEnabled then
            SendNUIMessage({ action = 'hideInteraction' })
        end
    end
end)

print('[PROXIMITY] ' .. Translate('proximity.system_loaded'))
