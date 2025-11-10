local characterSelected = false
local currentCharacter = nil

-- Când serverul trimite evenimentul de deschidere selecție
RegisterNetEvent('switcore:openCharacterSelection', function()
    -- Previne spawn-ul pânâ când un caracter este selectat
    local ped = PlayerPedId()
    if ped and ped > 0 then
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
    end
    
    CharacterSelection.open()
end)

-- Când serverul trimite locale-urile pentru caractere
RegisterNetEvent('switcore:charactersLocale', function(locale)
    SendNUIMessage({
        action = 'setLocale',
        locale = locale
    })
end)

-- Când serverul trimite lista de personaje
RegisterNetEvent('switcore:charactersList', function(characters)
    CharacterSelection.setCharacters(characters)
    
    if not characters or #characters == 0 then
        SendNUIMessage({
            action = 'showCreateForm'
        })
    else
        SendNUIMessage({
            action = 'showCharacterList',
            characters = characters
        })
    end
end)

-- Când un caracter este selectat
RegisterNetEvent('switcore:characterSelected', function(character)
    currentCharacter = character
    characterSelected = true
    
    CharacterSelection.close()
    
    if character and character.position then
        local pos = character.position
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        
        local ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false, true)
        SetEntityHeading(ped, pos.heading or 0.0)
        
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.heading or 0.0, true, false)
        
        if character.appearance then
            ApplyCharacterAppearance(character.appearance)
        end
    end
    
    TriggerEvent('switcore:characterLoaded', character)
end)

-- Când un caracter este creat
RegisterNetEvent('switcore:characterCreated', function(character)
    TriggerServerEvent('switcore:requestCharacters')
end)

-- Când un personaj este șters
RegisterNetEvent('switcore:characterDeleted', function(characterId)
    TriggerServerEvent('switcore:requestCharacters')
end)

-- Când apare o eroare
RegisterNetEvent('switcore:characterError', function(error)
    SendNUIMessage({
        action = 'showError',
        error = error
    })
end)

-- Aplică aspectul caracterului (face/body/parents only, no clothing)
function ApplyCharacterAppearance(appearance)
    if not appearance then
        return
    end
    
    local ped = PlayerPedId()
    
    if appearance.faceFeatures then
        for feature, value in pairs(appearance.faceFeatures) do
            SetPedFaceFeature(ped, GetHashKey(feature), value)
        end
    end
    
    if appearance.headBlend then
        SetPedHeadBlendData(
            ped,
            appearance.headBlend.shapeFirst or 0,
            appearance.headBlend.shapeSecond or 0,
            appearance.headBlend.shapeThird or 0,
            appearance.headBlend.skinFirst or 0,
            appearance.headBlend.skinSecond or 0,
            appearance.headBlend.skinThird or 0,
            appearance.headBlend.shapeMix or 0.5,
            appearance.headBlend.skinMix or 0.5,
            appearance.headBlend.thirdMix or 0.0
        )
    end
    
    if appearance.hair then
        SetPedComponentVariation(ped, 2, appearance.hair.style or 0, appearance.hair.color or 0, 0)
        if appearance.hair.highlight then
            SetPedHairColor(ped, appearance.hair.color or 0, appearance.hair.highlight)
        end
    end
    
    if appearance.eyes then
        SetPedEyeColor(ped, appearance.eyes.color or 0)
    end
    
    if appearance.overlays then
        for overlayId, overlay in pairs(appearance.overlays) do
            SetPedHeadOverlay(ped, tonumber(overlayId), overlay.style or 0, overlay.opacity or 1.0)
            if overlay.color then
                SetPedHeadOverlayColor(ped, tonumber(overlayId), overlay.color.type or 1, overlay.color.color or 0, overlay.color.secondaryColor or 0)
            end
        end
    end
end

-- NUI Callbacks
RegisterNUICallback('selectCharacter', function(data, cb)
    if data.characterId then
        CharacterSelection.selectCharacter(data.characterId)
    end
    cb('ok')
end)

RegisterNUICallback('createCharacter', function(data, cb)
    if data.firstName and data.lastName and data.age then
        CharacterSelection.createCharacter(data.firstName, data.lastName, data.age, data.appearance)
    end
    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    if data.characterId then
        CharacterSelection.deleteCharacter(data.characterId)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    if not characterSelected then
        cb('error')
        return
    end
    cb('ok')
end)

-- Verifică dacă un personaj este selectat
function IsCharacterSelected()
    return characterSelected
end

-- Obține personajul curent
function GetCurrentCharacter()
    return currentCharacter
end

