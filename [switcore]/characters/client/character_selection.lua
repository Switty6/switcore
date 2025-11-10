CharacterSelection = {}

local isSelectionOpen = false
local currentCharacters = {}
local selectedCharacterId = nil

-- Deschide UI-ul de selecție personaj
function CharacterSelection.open()
    if isSelectionOpen then
        return
    end
    
    isSelectionOpen = true
    SetNuiFocus(true, true)
    
    TriggerServerEvent('switcore:requestCharacters')
end

-- Inchide UI-ul de selecție caracter
function CharacterSelection.close()
    if not isSelectionOpen then
        return
    end
    
    isSelectionOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

-- Gestioneaza selectia unui caracter
function CharacterSelection.selectCharacter(characterId)
    if not characterId then
        return false
    end
    
    TriggerServerEvent('switcore:selectCharacter', characterId)
    return true
end

-- Gestioneaza crearea unui caracter nou
function CharacterSelection.createCharacter(firstName, lastName, age, appearance)
    if not firstName or not lastName or not age then
        return false
    end
    
    TriggerServerEvent('switcore:createCharacter', firstName, lastName, age, appearance or {})
    return true
end

-- Gestioneaza stergerea unui caracter
function CharacterSelection.deleteCharacter(characterId)
    if not characterId then
        return false
    end
    
    TriggerServerEvent('switcore:deleteCharacter', characterId)
    return true
end

-- Obține caracterele curente
function CharacterSelection.getCharacters()
    return currentCharacters
end

-- Seteaza caracterele
function CharacterSelection.setCharacters(characters)
    currentCharacters = characters
    SendNUIMessage({
        action = 'updateCharacters',
        characters = characters
    })
end

-- Verifică dacă UI-ul este deschis
function CharacterSelection.isOpen()
    return isSelectionOpen
end

return CharacterSelection

