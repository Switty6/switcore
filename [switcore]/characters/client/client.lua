local characterSelected = false
local currentCharacter  = nil

RegisterNetEvent('switcore:openCharacterSelection', function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    TriggerEvent('switcore:playIntroMenu')
end)

AddEventHandler('switcore:introFinished', function()
    CharacterSelection.open()
end)

RegisterNetEvent('switcore:charactersList', function(characters)
    CharacterSelection.setCharacters(characters)
    if not characters or #characters == 0 then
        SendNUIMessage({ action = 'showCreateForm' })
    else
        SendNUIMessage({ action = 'showCharacterList', characters = characters })
    end
end)

RegisterNetEvent('switcore:characterSelected', function(character)
    currentCharacter  = character
    characterSelected = true

    CharacterSelection.close()

    if not (character and character.position) then
        TriggerEvent('switcore:characterLoaded', character)
        TriggerServerEvent('switcore:characterLoaded', character)
        return
    end

    local pos = character.position
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)

    if character.appearance and character.appearance.gender ~= nil then
        local modelStr = (character.appearance.gender == 0) and 'mp_m_freemode_01' or 'mp_f_freemode_01'
        local hash     = GetHashKey(modelStr)
        if IsModelInCdimage(hash) and not HasModelLoaded(hash) then
            RequestModel(hash)
            while not HasModelLoaded(hash) do Wait(10) end
        end
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
    end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false, true)
    SetEntityHeading(ped, pos.heading or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.heading or 0.0, true, false)

    if character.appearance then ApplyCharacterAppearance(character.appearance) end

    if character.stats then
        local ped2 = PlayerPedId()
        if character.stats.health then SetEntityHealth(ped2, tonumber(character.stats.health)) end
        if character.stats.armor  then SetPedArmour(ped2, tonumber(character.stats.armor))    end
    end

    TriggerEvent('switcore:characterLoaded', character)
    TriggerServerEvent('switcore:characterLoaded', character)
end)

RegisterNetEvent('switcore:charactersConfig', function(cfg)
    if cfg.creatorRoom then Config.CREATOR_ROOM = cfg.creatorRoom end
end)

RegisterNetEvent('switcore:characterCreated', function()
    TriggerServerEvent('switcore:requestCharacters')
end)

RegisterNetEvent('switcore:characterDeleted', function()
    TriggerServerEvent('switcore:requestCharacters')
end)

RegisterNetEvent('switcore:characterError', function(error)
    SendNUIMessage({ action = 'showError', error = error })
end)

function ApplyCharacterAppearance(appearance, targetPed)
    if not appearance then return end
    local ped = targetPed or PlayerPedId()

    if appearance.faceFeatures then
        for feature, value in pairs(appearance.faceFeatures) do
            SetPedFaceFeature(ped, GetHashKey(feature), value)
        end
    end

    if appearance.headBlend then
        local hb = appearance.headBlend
        SetPedHeadBlendData(
            ped,
            hb.shapeFirst  or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
            hb.skinFirst   or 0, hb.skinSecond  or 0, hb.skinThird  or 0,
            hb.shapeMix    or 0.5, hb.skinMix   or 0.5, hb.thirdMix or 0.0
        )
    end

    if appearance.hair then
        SetPedComponentVariation(ped, 2, appearance.hair.style or 0, appearance.hair.color or 0, 0)
        if appearance.hair.highlight then
            SetPedHairColor(ped, appearance.hair.color or 0, appearance.hair.highlight)
        end
    end

    if appearance.eyes then SetPedEyeColor(ped, appearance.eyes.color or 0) end

    if appearance.overlays then
        for overlayId, overlay in pairs(appearance.overlays) do
            SetPedHeadOverlay(ped, tonumber(overlayId), overlay.style or 0, overlay.opacity or 1.0)
            if overlay.color then
                SetPedHeadOverlayColor(ped, tonumber(overlayId), overlay.color.type or 1, overlay.color.color or 0, overlay.color.secondaryColor or 0)
            end
        end
    end
end

RegisterNUICallback('setupCharacterCreation', function(data, cb)
    CharacterSelection.setupCreatorRoom(data.gender, data.appearance)
    cb('ok')
end)

RegisterNUICallback('previewAppearance', function(data, cb)
    if data.appearance then CharacterSelection.updateCreatorRoom(data.appearance) end
    cb('ok')
end)

RegisterNUICallback('cancelCharacterCreation', function(data, cb)
    CharacterSelection.cleanupCreatorRoom()
    cb('ok')
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    if data.characterId then CharacterSelection.selectCharacter(data.characterId) end
    cb('ok')
end)

RegisterNUICallback('createCharacter', function(data, cb)
    if data.firstName and data.lastName and data.age then
        CharacterSelection.createCharacter(data.firstName, data.lastName, data.age, data.appearance)
    end
    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    if data.characterId then CharacterSelection.deleteCharacter(data.characterId) end
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    cb(characterSelected and 'ok' or 'error')
end)

function IsCharacterSelected() return characterSelected end
function GetCurrentCharacter() return currentCharacter   end

exports('IsCharacterSelected', function() return characterSelected end)
exports('GetCurrentCharacter', function() return currentCharacter end)

RegisterNetEvent('switcore:requestCurrentCharacter')
AddEventHandler('switcore:requestCurrentCharacter', function()
    if currentCharacter then
        TriggerEvent('switcore:characterLoaded', currentCharacter)
        TriggerServerEvent('switcore:characterLoaded', currentCharacter)
    end
end)
