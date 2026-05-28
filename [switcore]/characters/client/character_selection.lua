CharacterSelection = {}

local isSelectionOpen   = false
local currentCharacters = {}
local pedFather, pedMother, creatorCam

local function LoadModel(modelName)
    local hash = (type(modelName) == 'number') and modelName or GetHashKey(modelName)
    if IsModelInCdimage(hash) and not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end
    end
    return hash
end

function CharacterSelection.open()
    if isSelectionOpen then return end
    isSelectionOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    DisplayRadar(false)
    TriggerServerEvent('switcore:requestCharacters')
end

function CharacterSelection.close()
    if not isSelectionOpen then return end
    isSelectionOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    DisplayRadar(true)
    CharacterSelection.cleanupCreatorRoom()
end

function CharacterSelection.selectCharacter(characterId)
    if not characterId then return false end
    TriggerServerEvent('switcore:selectCharacter', characterId)
    return true
end

function CharacterSelection.createCharacter(firstName, lastName, age, appearance)
    if not firstName or not lastName or not age then return false end
    TriggerServerEvent('switcore:createCharacter', firstName, lastName, age, appearance or {})
    return true
end

function CharacterSelection.deleteCharacter(characterId)
    if not characterId then return false end
    TriggerServerEvent('switcore:deleteCharacter', characterId)
    return true
end

function CharacterSelection.getCharacters()
    return currentCharacters
end

function CharacterSelection.setCharacters(characters)
    currentCharacters = characters
    SendNUIMessage({ action = 'updateCharacters', characters = characters })
end

function CharacterSelection.isOpen()
    return isSelectionOpen
end

function CharacterSelection.setupCreatorRoom(gender, appearance)
    CharacterSelection.cleanupCreatorRoom()

    if not Config.CREATOR_ROOM then
        print('[CHARACTERS] Creator room config nu a fost primit de la server.')
        return
    end

    local childModel  = (gender == 0) and 'mp_m_freemode_01' or 'mp_f_freemode_01'
    local fatherModel = 'mp_m_freemode_01'
    local motherModel = 'mp_f_freemode_01'

    local childHash  = LoadModel(childModel)
    local fatherHash = LoadModel(fatherModel)
    local motherHash = LoadModel(motherModel)

    SetPlayerModel(PlayerId(), childHash)
    local playerPed = PlayerPedId()
    local cRoom     = Config.CREATOR_ROOM

    SetEntityCoordsNoOffset(playerPed, cRoom.child.x, cRoom.child.y, cRoom.child.z, false, false, false, true)
    SetEntityHeading(playerPed, cRoom.child.heading)
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, true, false)
    SetPedComponentVariation(playerPed, 3, 15, 0, 2)
    SetPedComponentVariation(playerPed, 8, 15, 0, 2)
    SetPedComponentVariation(playerPed, 11, 15, 0, 2)

    Wait(500)

    pedFather = CreatePed(4, fatherHash, cRoom.father.x, cRoom.father.y, cRoom.father.z, cRoom.father.heading, false, true)
    SetEntityInvincible(pedFather, true)
    FreezeEntityPosition(pedFather, true)
    SetBlockingOfNonTemporaryEvents(pedFather, true)
    SetPedComponentVariation(pedFather, 3, 15, 0, 2)
    SetPedComponentVariation(pedFather, 11, 15, 0, 2)

    pedMother = CreatePed(4, motherHash, cRoom.mother.x, cRoom.mother.y, cRoom.mother.z, cRoom.mother.heading, false, true)
    SetEntityInvincible(pedMother, true)
    FreezeEntityPosition(pedMother, true)
    SetBlockingOfNonTemporaryEvents(pedMother, true)
    SetPedComponentVariation(pedMother, 3, 15, 0, 2)
    SetPedComponentVariation(pedMother, 11, 15, 0, 2)

    local lookAt = cRoom.lookAt or { x = cRoom.child.x, y = cRoom.child.y, z = cRoom.child.z + 0.65 }
    creatorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(creatorCam, cRoom.camera.x, cRoom.camera.y, cRoom.camera.z)
    PointCamAtCoord(creatorCam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(creatorCam, cRoom.camera.fov or 50.0)
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, true, 1000, true, true)

    SetModelAsNoLongerNeeded(childHash)
    SetModelAsNoLongerNeeded(fatherHash)
    SetModelAsNoLongerNeeded(motherHash)

    if appearance then CharacterSelection.updateCreatorRoom(appearance) end
end

function CharacterSelection.updateCreatorRoom(appearance)
    if not appearance or not appearance.headBlend then return end

    ApplyCharacterAppearance(appearance, PlayerPedId())

    local fatherShape = appearance.headBlend.shapeFirst  or 0
    local motherShape = appearance.headBlend.shapeSecond or 0

    if pedFather and pedFather > 0 then
        SetPedHeadBlendData(pedFather, fatherShape, 0, 0, fatherShape, 0, 0, 0.0, 0.0, 0.0)
    end
    if pedMother and pedMother > 0 then
        SetPedHeadBlendData(pedMother, motherShape, 0, 0, motherShape, 0, 0, 0.0, 0.0, 0.0)
    end
end

function CharacterSelection.cleanupCreatorRoom()
    if pedFather and pedFather > 0 then DeleteEntity(pedFather); pedFather = nil end
    if pedMother and pedMother > 0 then DeleteEntity(pedMother); pedMother = nil end
    if creatorCam then
        SetCamActive(creatorCam, false)
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(creatorCam, false)
        creatorCam = nil
    end
end

return CharacterSelection
