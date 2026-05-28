local proxSettings = {
    proximityDistance         = (Config and Config.ProximityDistance) or 2.0,
    showMarker                = not Config or Config.ShowMarker ~= false,
    showText                  = not Config or Config.ShowText   ~= false,
    debug                     = (Config and Config.Debug)       or false,
    entityOffset              = (Config and Config.EntityOffset)              or { x = 0.0, y = 0.0, z = 0.5 },
    textOffset                = (Config and Config.TextOffset)                or { x = 0.0, y = 0.0, z = 0.5 },
    markerColor               = (Config and Config.MarkerColor)               or { r = 0, g = 255, b = 0, a = 200 },
    mouseToggleKey            = (Config and Config.MouseToggleKey)            or 'LMENU',
    mouseToggleKeyDescription = (Config and Config.MouseToggleKeyDescription) or 'Toggle Mouse Navigation',
}

local PLAIN_SETTINGS = { 'proximityDistance', 'entityOffset', 'textOffset', 'markerColor' }
local BOOL_SETTINGS  = { 'showMarker', 'showText', 'debug' }

RegisterNetEvent('proximity:client:settings', function(data)
    if not data then return end
    for _, k in ipairs(PLAIN_SETTINGS) do if data[k]        then proxSettings[k] = data[k] end end
    for _, k in ipairs(BOOL_SETTINGS)  do if data[k] ~= nil then proxSettings[k] = data[k] end end
    SendNUIMessage({
        action = 'updateConfig',
        config = { showMarker = proxSettings.showMarker, showText = proxSettings.showText }
    })
end)

local SEARCH_RADIUS    = 10.0
local SEARCH_RADIUS_SQ = SEARCH_RADIUS * SEARCH_RADIUS

local isNearby               = false
local currentInteraction     = nil
local interactionDistance    = 0.0
local nuiEnabled             = false
local mouseEnabled           = false
local nearbyInteractions     = {}
local selectedInteractionIndex = 1
local playerCoords           = vector3(0.0, 0.0, 0.0)
local lastCoordsUpdate       = 0
local COORDS_UPDATE_INTERVAL = 100
local lastScreenX            = 0
local lastScreenY            = 0

local modelCenterOffsetCache = {}
local cachedEntityGroups     = nil
local cachedInteractionsList = nil
local cachedIndexMap         = nil
local nearbyVersion          = 0
local lastGroupedVersion     = -1
local lastSentScreenX        = -1e9
local lastSentScreenY        = -1e9
local lastSentVersion        = -1
local lastSentMouseEnabled   = nil
local lastSentSelectedIndex  = -1

local function Translate(key, ...)
    if exports.core and exports.core.translate then
        return exports.core:translate(key, ...)
    end
    return key
end

local function GetPlayerCoords()
    local now = GetGameTimer()
    if now - lastCoordsUpdate > COORDS_UPDATE_INTERVAL then
        local ped = PlayerPedId()
        if ped ~= 0 then
            playerCoords     = GetEntityCoords(ped)
            lastCoordsUpdate = now
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

local function FindClosestByModel(modelHash, maxDist, entityType)
    local radius = math.min(maxDist or proxSettings.proximityDistance, SEARCH_RADIUS)
    local pos    = GetPlayerCoords()

    if entityType ~= "vehicle" and entityType ~= "ped" then
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, radius, modelHash, false, false, false)
        if DoesEntityExist(obj) then
            local objPos = GetEntityCoords(obj)
            local dist   = #(pos - objPos)
            if dist <= radius then return obj, objPos, dist end
        end
    end

    if entityType ~= "object" and entityType ~= "ped" then
        local veh = GetClosestVehicle(pos.x, pos.y, pos.z, radius, modelHash, 70)
        if DoesEntityExist(veh) then
            local vehPos = GetEntityCoords(veh)
            local dist   = #(pos - vehPos)
            if dist <= radius then return veh, vehPos, dist end
        end
    end

    if entityType == "ped" then
        local peds     = GetGamePool('CPed')
        local bestDist = radius + 1
        local bestPed, bestPos
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and GetEntityModel(ped) == modelHash then
                local pedPos = GetEntityCoords(ped)
                local dx = pedPos.x - pos.x
                local dy = pedPos.y - pos.y
                -- pre-filtru 2D înainte de sqrt complet
                if dx * dx + dy * dy <= radius * radius then
                    local dist = #(pos - pedPos)
                    if dist < bestDist then
                        bestDist = dist
                        bestPed  = ped
                        bestPos  = pedPos
                    end
                end
            end
        end
        if bestPed then return bestPed, bestPos, bestDist end
    end

    return nil, nil, math.huge
end

-- Returneaza TOATE entitatile de un model (vs. doar cea mai apropiata) - necesar
-- cand mai multe instante ale aceluiasi model coexista in aceeasi locatie (pompe, ATM-uri).
local function FindAllByModel(modelHash, maxDist, entityType)
    local radius = math.min(maxDist or proxSettings.proximityDistance, SEARCH_RADIUS)
    local pos    = GetPlayerCoords()
    local r2     = radius * radius
    local results = {}

    if entityType ~= "vehicle" and entityType ~= "ped" then
        for _, obj in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(obj) == modelHash then
                local op = GetEntityCoords(obj)
                local dx, dy = op.x - pos.x, op.y - pos.y
                if dx * dx + dy * dy <= r2 then
                    local d = #(pos - op)
                    if d <= radius then
                        results[#results+1] = { entity = obj, coords = op, distance = d }
                    end
                end
            end
        end
    end
    if entityType ~= "object" and entityType ~= "ped" then
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(veh) == modelHash then
                local vp = GetEntityCoords(veh)
                local dx, dy = vp.x - pos.x, vp.y - pos.y
                if dx * dx + dy * dy <= r2 then
                    local d = #(pos - vp)
                    if d <= radius then
                        results[#results+1] = { entity = veh, coords = vp, distance = d }
                    end
                end
            end
        end
    end
    if entityType == "ped" then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if GetEntityModel(ped) == modelHash then
                local pp = GetEntityCoords(ped)
                local dx, dy = pp.x - pos.x, pp.y - pos.y
                if dx * dx + dy * dy <= r2 then
                    local d = #(pos - pp)
                    if d <= radius then
                        results[#results+1] = { entity = ped, coords = pp, distance = d }
                    end
                end
            end
        end
    end
    return results
end

local function ProcessModelInteractionMulti(interaction, playerPos, i, isStatic)
    if not interaction._lastModelCheck then interaction._lastModelCheck = 0 end
    local now = GetGameTimer()
    if now - interaction._lastModelCheck > 200 then
        interaction._lastModelCheck = now
        interaction._cachedEntities = FindAllByModel(
            interaction.modelHash, interaction.maxDistance, interaction.entityType
        )
    end

    local triggerDist = interaction.maxDistance or proxSettings.proximityDistance
    local out = {}
    for _, e in ipairs(interaction._cachedEntities or {}) do
        if DoesEntityExist(e.entity) then
            local coords = GetEntityCoords(e.entity)
            local dist   = #(playerPos - coords)
            if dist <= triggerDist then
                out[#out+1] = {
                    interaction = interaction,
                    id          = isStatic
                        and ("static_" .. i .. "_" .. e.entity)
                        or  ("dynamic_" .. tostring(i) .. "_" .. e.entity),
                    distance    = dist,
                    coords      = coords,
                    entity      = e.entity,
                }
            end
        end
    end
    return out
end

local function ProcessInteraction(interaction, playerPos, i, isStatic)
    if not interaction then return end
    local distance = math.huge
    local coords   = nil
    local isValid  = false

    if interaction.coords then
        distance = #(playerPos - interaction.coords)
        coords   = interaction.coords
        isValid  = true
    elseif interaction.entity and DoesEntityExist(interaction.entity) then
        coords   = GetEntityCoords(interaction.entity)
        distance = #(playerPos - coords)
        isValid  = true
    elseif interaction.modelHash then
        if not interaction._lastModelCheck then interaction._lastModelCheck = 0 end
        local now = GetGameTimer()
        if now - interaction._lastModelCheck > 200 then
            interaction._lastModelCheck = now
            local ent, entPos, dist = FindClosestByModel(
                interaction.modelHash, interaction.maxDistance, interaction.entityType
            )
            if ent then
                distance           = dist
                coords             = entPos
                isValid            = true
                interaction.entity = ent
            else
                interaction.entity = nil
            end
        elseif interaction.entity and DoesEntityExist(interaction.entity) then
            coords   = GetEntityCoords(interaction.entity)
            distance = #(playerPos - coords)
            isValid  = true
        end
    elseif interaction.zone then
        if IsPointInZone(playerPos, interaction.zone) then
            coords = interaction.zone.center or interaction.zone.corner1 or interaction.zone.v1
            if coords then
                distance = #(playerPos - coords)
                isValid  = true
            else
                distance = 0.0
                coords   = playerPos
                isValid  = true
            end
        end
    end

    local triggerDist = interaction.maxDistance or proxSettings.proximityDistance
    if isValid and distance <= triggerDist then
        return {
            interaction = interaction,
            id          = isStatic and ("static_" .. i) or ("dynamic_" .. (type(i) == "string" and i or tostring(i))),
            distance    = distance,
            coords      = coords,
            entity      = interaction.entity
        }
    end
    return nil
end

local function BuildEntityGroups()
    local groups = {}
    for i, data in ipairs(nearbyInteractions) do
        local entityKey = "none"
        if data.entity and DoesEntityExist(data.entity) then
            entityKey = "entity_" .. tostring(data.entity)
        elseif data.coords then
            local foundGroup = false
            for key, groupData in pairs(groups) do
                if not groupData.entity and #(data.coords - groupData.coords) < 0.5 then
                    entityKey  = key
                    foundGroup = true
                    break
                end
            end
            if not foundGroup then entityKey = "coords_" .. tostring(i) end
        end
        if not groups[entityKey] then
            groups[entityKey] = { interactions = {}, entity = data.entity, coords = data.coords }
        end
        table.insert(groups[entityKey].interactions, {
            index    = i,
            data     = data,
            selected = (i == selectedInteractionIndex)
        })
    end

    local list = {}
    for _, groupData in pairs(groups) do
        local gi = groupData.interactions
        table.sort(gi, function(a, b) return a.data.distance < b.data.distance end)
        for j = 1, math.min(3, #gi) do
            local item = gi[j]
            table.insert(list, {
                label         = item.data.interaction.label or Translate('proximity.interaction'),
                distance      = item.data.distance,
                selected      = item.selected,
                originalIndex = item.index
            })
        end
    end

    table.sort(list, function(a, b) return (a.originalIndex or 0) < (b.originalIndex or 0) end)

    local indexMap, filteredSelected = {}, 1
    for listIdx, listItem in ipairs(list) do
        indexMap[listIdx] = listItem.originalIndex
        if listItem.originalIndex == selectedInteractionIndex then
            filteredSelected = listIdx
        end
        listItem.originalIndex = nil
    end

    return groups, list, indexMap, filteredSelected
end

local function DisableMouse()
    mouseEnabled = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'setMouseEnabled', enabled = false })
end

local function CheckProximity()
    local playerPos = GetPlayerCoords()
    nearbyInteractions = {}

    for i = 1, #Config.Interactions do
        local inter     = Config.Interactions[i]
        local refCoords = inter.coords or (inter.zone and inter.zone.center)
        if refCoords then
            local dx = refCoords.x - playerPos.x
            local dy = refCoords.y - playerPos.y
            if dx * dx + dy * dy > SEARCH_RADIUS_SQ then goto staticContinue end
        end
        do
            if inter.modelHash then
                local results = ProcessModelInteractionMulti(inter, playerPos, i, true)
                for _, r in ipairs(results) do table.insert(nearbyInteractions, r) end
            else
                local result = ProcessInteraction(inter, playerPos, i, true)
                if result then table.insert(nearbyInteractions, result) end
            end
        end
        ::staticContinue::
    end

    for id, interaction in pairs(Config.DynamicInteractions) do
        if interaction then
            local refCoords = interaction.coords or (interaction.zone and interaction.zone.center)
            if refCoords then
                local dx = refCoords.x - playerPos.x
                local dy = refCoords.y - playerPos.y
                if dx * dx + dy * dy > SEARCH_RADIUS_SQ then goto dynContinue end
            end
            if interaction.modelHash then
                local results = ProcessModelInteractionMulti(interaction, playerPos, id, false)
                for _, r in ipairs(results) do table.insert(nearbyInteractions, r) end
            else
                local result = ProcessInteraction(interaction, playerPos, id, false)
                if result then table.insert(nearbyInteractions, result) end
            end
            ::dynContinue::
        end
    end

    table.sort(nearbyInteractions, function(a, b) return a.distance < b.distance end)

    if selectedInteractionIndex > #nearbyInteractions then
        selectedInteractionIndex = math.max(1, #nearbyInteractions)
    end

    local shouldBeNearby = #nearbyInteractions > 0

    if shouldBeNearby ~= isNearby or shouldBeNearby then
        isNearby = shouldBeNearby
        if shouldBeNearby then
            local sel = nearbyInteractions[selectedInteractionIndex]
            if sel then
                currentInteraction  = sel.interaction
                interactionDistance = sel.distance
                if sel.coords  then currentInteraction.currentCoords = sel.coords  end
                if sel.entity  then currentInteraction.entity        = sel.entity  end
                if proxSettings.debug then
                    print(string.format("[PROXIMITY] %d interacțiuni. Selectat: %s (%.2fm)",
                        #nearbyInteractions, currentInteraction.label or "Unknown", interactionDistance))
                end
            end
        else
            currentInteraction       = nil
            interactionDistance      = 0.0
            selectedInteractionIndex = 1
            if mouseEnabled then DisableMouse() end
        end
    end

    nearbyVersion = nearbyVersion + 1
end

local function GetEntityCenter(entity)
    if not DoesEntityExist(entity) then return nil end
    local modelHash = GetEntityModel(entity)
    local zOffset   = modelCenterOffsetCache[modelHash]
    if zOffset == nil then
        local min, max = GetModelDimensions(modelHash)
        zOffset = (min and max) and ((min.z + max.z) / 2) or 0.0
        modelCenterOffsetCache[modelHash] = zOffset
    end
    local coords = GetEntityCoords(entity)
    return vector3(coords.x, coords.y, coords.z + zOffset)
end

local function UpdateNUI()
    if not nuiEnabled then return end
    if not (isNearby and currentInteraction) then
        SendNUIMessage({ action = 'hideInteraction' })
        return
    end

    local interactionCoords = currentInteraction.currentCoords or currentInteraction.coords or GetPlayerCoords()
    local targetCoords

    if currentInteraction.entity and DoesEntityExist(currentInteraction.entity) then
        local entityCenter = GetEntityCenter(currentInteraction.entity)
        if entityCenter then
            targetCoords = vector3(
                entityCenter.x + proxSettings.entityOffset.x,
                entityCenter.y + proxSettings.entityOffset.y,
                entityCenter.z + proxSettings.entityOffset.z
            )
        else
            local ec = GetEntityCoords(currentInteraction.entity)
            targetCoords = vector3(
                ec.x + proxSettings.entityOffset.x,
                ec.y + proxSettings.entityOffset.y,
                ec.z + proxSettings.entityOffset.z
            )
        end
    else
        targetCoords = vector3(
            interactionCoords.x,
            interactionCoords.y,
            interactionCoords.z + proxSettings.textOffset.z
        )
    end

    if not targetCoords then
        SendNUIMessage({ action = 'hideInteraction' })
        return
    end

    local onScreen, screenX, screenY = World3dToScreen2d(targetCoords.x, targetCoords.y, targetCoords.z)
    if not onScreen then
        SendNUIMessage({ action = 'hideInteraction' })
        return
    end

    local w, h = GetActiveScreenResolution()
    screenX = screenX * w
    screenY = screenY * h
    if lastScreenX > 0 and lastScreenY > 0 then
        local diffX = math.abs(screenX - lastScreenX)
        local diffY = math.abs(screenY - lastScreenY)
        if diffX < 150 and diffY < 150 then
            screenX = lastScreenX + (screenX - lastScreenX) * 0.7
            screenY = lastScreenY + (screenY - lastScreenY) * 0.7
        end
    end
    lastScreenX = screenX
    lastScreenY = screenY

    local filteredSelectedIndex
    if lastGroupedVersion ~= nearbyVersion then
        lastGroupedVersion = nearbyVersion
        cachedEntityGroups, cachedInteractionsList, cachedIndexMap, filteredSelectedIndex = BuildEntityGroups()
    else
        filteredSelectedIndex = 1
        if cachedIndexMap then
            for listIdx, origIdx in ipairs(cachedIndexMap) do
                if origIdx == selectedInteractionIndex then
                    filteredSelectedIndex = listIdx
                    break
                end
            end
        end
    end

    local interactionsList = cachedInteractionsList or {}
    local indexMap         = cachedIndexMap or {}

    if cachedIndexMap then
        for listIdx, listItem in ipairs(interactionsList) do
            listItem.selected = (cachedIndexMap[listIdx] == selectedInteractionIndex)
        end
    end

    local firstInteraction = nearbyInteractions[1]
    local markerColor = firstInteraction and (firstInteraction.interaction.color or proxSettings.markerColor) or proxSettings.markerColor

    local currentDistance = interactionDistance
    if selectedInteractionIndex > 0 and nearbyInteractions[selectedInteractionIndex] then
        currentDistance = nearbyInteractions[selectedInteractionIndex].distance
    end

    local dx = math.abs(screenX - lastSentScreenX)
    local dy = math.abs(screenY - lastSentScreenY)
    local structureChanged = (lastSentVersion ~= nearbyVersion)
        or (lastSentMouseEnabled ~= mouseEnabled)
        or (lastSentSelectedIndex ~= filteredSelectedIndex)
    if not structureChanged and dx < 8 and dy < 8 then
        return
    end
    lastSentScreenX, lastSentScreenY = screenX, screenY
    lastSentVersion = nearbyVersion
    lastSentMouseEnabled = mouseEnabled
    lastSentSelectedIndex = filteredSelectedIndex

    SendNUIMessage({
        action               = 'showInteraction',
        screenX              = screenX,
        screenY              = screenY,
        label                = mouseEnabled and (currentInteraction.label or Translate('proximity.interaction')) or Translate('proximity.interact'),
        keyName              = mouseEnabled and "Click" or "ALT",
        color                = markerColor,
        markerColor          = markerColor,
        distance             = currentDistance,
        interaction          = { type = currentInteraction.type, data = currentInteraction.data },
        multipleInteractions = #interactionsList > 1,
        currentIndex         = filteredSelectedIndex,
        totalCount           = #interactionsList,
        interactionsList     = mouseEnabled and interactionsList or nil,
        indexMap             = mouseEnabled and indexMap or nil,
        mouseEnabled         = mouseEnabled,
        showList             = mouseEnabled,
        showText             = not mouseEnabled
    })
end

CreateThread(function()
    while true do
        local sleep = 500
        if PlayerPedId() ~= 0 then
            CheckProximity()
            if isNearby and currentInteraction then
                sleep = 250
                UpdateNUI()
            elseif nuiEnabled then
                SendNUIMessage({ action = 'hideInteraction' })
                lastSentVersion = -1
            end
        end
        Wait(sleep)
    end
end)

RegisterKeyMapping('proximity:toggleMouse', proxSettings.mouseToggleKeyDescription, 'keyboard', proxSettings.mouseToggleKey)
RegisterCommand('proximity:toggleMouse', function()
    if not isNearby or #nearbyInteractions == 0 then return end

    if #nearbyInteractions == 1 then
        local sel = nearbyInteractions[1]
        if sel and sel.interaction then
            local interaction = sel.interaction
            TriggerEvent('switcore:proximity:interact', interaction)
            if interaction.onInteract then interaction.onInteract(interaction) end
            SendNUIMessage({ action = 'hideInteraction' })
            isNearby           = false
            currentInteraction = nil
            if proxSettings.debug then
                print(string.format("[PROXIMITY] Direct interact: %s", interaction.label or "Unknown"))
            end
        end
        return
    end

    mouseEnabled = not mouseEnabled
    SetNuiFocus(mouseEnabled, mouseEnabled)
    SendNUIMessage({ action = 'setMouseEnabled', enabled = mouseEnabled })
    if proxSettings.debug then
        print(string.format("[PROXIMITY] Mouse navigation: %s", mouseEnabled and "ENABLED" or "DISABLED"))
    end
end, false)

RegisterKeyMapping('proximity:closeMouse', 'Close Mouse Navigation', 'keyboard', 'ESCAPE')
RegisterCommand('proximity:closeMouse', function()
    if mouseEnabled then
        DisableMouse()
        if proxSettings.debug then print("[PROXIMITY] Mouse navigation disabled (ESC)") end
    end
end, false)

CreateThread(function()
    Wait(1000)
    SendNUIMessage({
        action = 'updateConfig',
        config = { showMarker = proxSettings.showMarker, showText = proxSettings.showText }
    })
    nuiEnabled = true
end)

RegisterNUICallback('selectInteraction', function(data, cb)
    if data.index and #nearbyInteractions > 0 then
        local newIndex = tonumber(data.index)
        if newIndex and newIndex >= 1 and newIndex <= #nearbyInteractions then
            selectedInteractionIndex = newIndex
            local sel = nearbyInteractions[newIndex]
            if sel then
                currentInteraction  = sel.interaction
                interactionDistance = sel.distance
                if sel.coords  then currentInteraction.currentCoords = sel.coords  end
                if sel.entity  then currentInteraction.entity        = sel.entity  end
                UpdateNUI()
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('interact', function(data, cb)
    if #nearbyInteractions > 0 then
        local targetIndex = selectedInteractionIndex
        if data and data.index then
            local idx = tonumber(data.index)
            if idx and idx >= 1 and idx <= #nearbyInteractions then targetIndex = idx end
        end
        local sel = nearbyInteractions[targetIndex]
        if sel and sel.interaction then
            local interaction = sel.interaction
            TriggerEvent('switcore:proximity:interact', interaction)
            if interaction.onInteract then interaction.onInteract(interaction) end
            if mouseEnabled then
                mouseEnabled = false
                SetNuiFocus(false, false)
            end
            if nuiEnabled then
                SendNUIMessage({ action = 'hideInteraction' })
                SendNUIMessage({ action = 'setMouseEnabled', enabled = false })
            end
            isNearby           = false
            currentInteraction = nil
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeMouse', function(data, cb)
    if mouseEnabled then
        DisableMouse()
        if proxSettings.debug then print("[PROXIMITY] Mouse navigation disabled (ESC)") end
    end
    cb('ok')
end)

RegisterNUICallback('toggleMouse', function(data, cb)
    if not isNearby or #nearbyInteractions == 0 then cb('ok'); return end
    mouseEnabled = not mouseEnabled
    SetNuiFocus(mouseEnabled, mouseEnabled)
    SendNUIMessage({ action = 'setMouseEnabled', enabled = mouseEnabled })
    if proxSettings.debug then
        print(string.format("[PROXIMITY] Mouse navigation: %s (NUI)", mouseEnabled and "ENABLED" or "DISABLED"))
    end
    cb('ok')
end)

local function GetModelHash(modelName)
    return type(modelName) == "string" and GetHashKey(modelName) or modelName
end

local function CreateInteraction(id, data)
    Config.DynamicInteractions[id] = {
        id         = id,
        label      = data.label or Translate('proximity.interaction'),
        type       = data.type or "default",
        data       = data.data or {},
        onInteract = data.onInteract,
        color      = data.markerColor or Config.MarkerColor
    }
    local di = Config.DynamicInteractions[id]
    if data.coords then
        di.coords = type(data.coords) == "vector3" and data.coords or vector3(data.coords.x, data.coords.y, data.coords.z)
    end
    if data.entity then
        if DoesEntityExist(data.entity) then
            di.entity = data.entity
            di.coords = GetEntityCoords(data.entity)
        else
            Config.DynamicInteractions[id] = nil
            return nil
        end
    end
    if data.modelHash then
        di.modelHash   = data.modelHash
        di.modelName   = type(data.modelName) == "string" and data.modelName or nil
        di.entityType  = data.entityType
    end
    if data.zone then di.zone = data.zone end
    if data.maxDistance then di.maxDistance = data.maxDistance end
    return id
end

exports('AddInteraction', function(coords, label, interactionType, data, onInteract, entity, glowColor, markerColor, maxDistance)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        coords = coords, label = label, type = interactionType,
        data = data, onInteract = onInteract, entity = entity,
        markerColor = markerColor, maxDistance = maxDistance
    })
end)

exports('AddEntityInteraction', function(entity, label, interactionType, data, onInteract, glowColor, markerColor, maxDistance)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        entity = entity, label = label, type = interactionType,
        data = data, onInteract = onInteract,
        markerColor = markerColor, maxDistance = maxDistance
    })
end)

exports('AddModelInteraction', function(modelName, label, interactionType, data, onInteract, maxDistance, glowColor, markerColor, entityType)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        modelHash = GetModelHash(modelName),
        modelName = type(modelName) == "string" and modelName or nil,
        label = label, type = interactionType, data = data, onInteract = onInteract,
        maxDistance = maxDistance, markerColor = markerColor, entityType = entityType
    })
end)

exports('AddTriangleZone', function(v1, v2, v3, label, interactionType, data, onInteract, glowColor, markerColor, maxDistance)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        zone = {
            type   = "triangle",
            v1     = type(v1) == "vector3" and v1 or vector3(v1.x, v1.y, v1.z),
            v2     = type(v2) == "vector3" and v2 or vector3(v2.x, v2.y, v2.z),
            v3     = type(v3) == "vector3" and v3 or vector3(v3.x, v3.y, v3.z),
            center = vector3((v1.x + v2.x + v3.x) / 3, (v1.y + v2.y + v3.y) / 3, (v1.z + v2.z + v3.z) / 3)
        },
        label = label, type = interactionType, data = data, onInteract = onInteract,
        markerColor = markerColor, maxDistance = maxDistance
    })
end)

exports('AddRectangleZone', function(corner1, corner2, label, interactionType, data, onInteract, minZ, maxZ, glowColor, markerColor, maxDistance)
    return CreateInteraction(#Config.DynamicInteractions + 1, {
        zone = {
            type    = "rectangle",
            corner1 = type(corner1) == "vector3" and corner1 or vector3(corner1.x, corner1.y, corner1.z),
            corner2 = type(corner2) == "vector3" and corner2 or vector3(corner2.x, corner2.y, corner2.z),
            minZ    = minZ, maxZ = maxZ,
            center  = vector3((corner1.x + corner2.x) / 2, (corner1.y + corner2.y) / 2,
                minZ and maxZ and ((minZ + maxZ) / 2) or (corner1.z + corner2.z) / 2)
        },
        label = label, type = interactionType, data = data, onInteract = onInteract,
        markerColor = markerColor, maxDistance = maxDistance
    })
end)

exports('RemoveInteraction', function(id)
    if Config.DynamicInteractions[id] then
        Config.DynamicInteractions[id] = nil
        return true
    end
    return false
end)

exports('GetCurrentInteraction', function() return currentInteraction end)
exports('IsNearInteraction',     function() return isNearby          end)

local function AddStaticInteraction(data)
    table.insert(Config.Interactions, {
        label      = data.label or Translate('proximity.interaction'),
        type       = data.type or "default",
        data       = data.data or {},
        entity     = data.entity,
        color      = data.markerColor or Config.MarkerColor,
        entityType = data.entityType
    })
    local idx = #Config.Interactions
    local si  = Config.Interactions[idx]
    if data.coords then
        si.coords = type(data.coords) == "vector3" and data.coords or vector3(data.coords.x, data.coords.y, data.coords.z)
    end
    if data.entity and DoesEntityExist(data.entity) then
        si.coords = GetEntityCoords(data.entity)
    end
    if data.modelHash then
        si.modelHash   = data.modelHash
        si.modelName   = type(data.modelName) == "string" and data.modelName or nil
        si.entityType  = data.entityType
    end
    if data.zone then si.zone = data.zone end
    if data.maxDistance then si.maxDistance = data.maxDistance end
end

exports('AddStaticInteraction', function(coords, label, interactionType, data, entity, glowColor, markerColor, maxDistance)
    AddStaticInteraction({
        coords = coords, label = label, type = interactionType, data = data,
        entity = entity, markerColor = markerColor, maxDistance = maxDistance
    })
end)

exports('AddStaticEntityInteraction', function(entity, label, interactionType, data, glowColor, markerColor, maxDistance)
    if not DoesEntityExist(entity) then
        print("[PROXIMITY] " .. Translate('proximity.error_entity_not_exists'))
        return
    end
    AddStaticInteraction({
        entity = entity, label = label, type = interactionType, data = data,
        markerColor = markerColor, maxDistance = maxDistance
    })
end)

exports('AddStaticModelInteraction', function(modelName, label, interactionType, data, maxDistance, glowColor, markerColor, entityType)
    AddStaticInteraction({
        modelHash = GetModelHash(modelName),
        modelName = type(modelName) == "string" and modelName or nil,
        label = label, type = interactionType, data = data,
        maxDistance = maxDistance, markerColor = markerColor, entityType = entityType
    })
end)

exports('AddStaticTriangleZone', function(v1, v2, v3, label, interactionType, data, glowColor, markerColor)
    AddStaticInteraction({
        zone = {
            type   = "triangle",
            v1     = type(v1) == "vector3" and v1 or vector3(v1.x, v1.y, v1.z),
            v2     = type(v2) == "vector3" and v2 or vector3(v2.x, v2.y, v2.z),
            v3     = type(v3) == "vector3" and v3 or vector3(v3.x, v3.y, v3.z),
            center = vector3((v1.x + v2.x + v3.x) / 3, (v1.y + v2.y + v3.y) / 3, (v1.z + v2.z + v3.z) / 3)
        },
        label = label, type = interactionType, data = data, markerColor = markerColor
    })
end)

exports('AddStaticRectangleZone', function(corner1, corner2, label, interactionType, data, minZ, maxZ, glowColor, markerColor)
    AddStaticInteraction({
        zone = {
            type    = "rectangle",
            corner1 = type(corner1) == "vector3" and corner1 or vector3(corner1.x, corner1.y, corner1.z),
            corner2 = type(corner2) == "vector3" and corner2 or vector3(corner2.x, corner2.y, corner2.z),
            minZ    = minZ, maxZ = maxZ,
            center  = vector3((corner1.x + corner2.x) / 2, (corner1.y + corner2.y) / 2,
                minZ and maxZ and ((minZ + maxZ) / 2) or (corner1.z + corner2.z) / 2)
        },
        label = label, type = interactionType, data = data, markerColor = markerColor
    })
end)

RegisterNetEvent('switcore:proximity:interact', function(interaction) end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and nuiEnabled then
        SendNUIMessage({ action = 'hideInteraction' })
    end
end)

print('[PROXIMITY] ' .. Translate('proximity.system_loaded'))
