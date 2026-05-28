local isUIOpen   = false
local isLawsOpen = false

local function OpenGov()
    if isUIOpen then return end
    TriggerServerEvent('government:server:open')
end

local function CloseGov()
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('government:client:open', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('government:client:update', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'update', data = data })
    end
end)

RegisterCommand('guv', function()
    OpenGov()
end, false)

RegisterKeyMapping('guv', 'Panou Guvern', 'keyboard', 'F6')

RegisterCommand('legi', function()
    if isLawsOpen then return end
    TriggerServerEvent('government:server:getPublicLaws')
end, false)

RegisterNetEvent('government:client:openLaws', function(laws)
    isLawsOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openLaws', laws = laws })
end)

RegisterNUICallback('closeLaws', function(_, cb)
    isLawsOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeLaws' })
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseGov()
    cb('ok')
end)

RegisterNUICallback('proposeLaw', function(data, cb)
    TriggerServerEvent('government:server:proposeLaw', data)
    cb('ok')
end)

RegisterNUICallback('voteLaw', function(data, cb)
    TriggerServerEvent('government:server:voteLaw', data.proposalId, data.vote)
    cb('ok')
end)

RegisterNUICallback('repealLaw', function(data, cb)
    TriggerServerEvent('government:server:repealLaw', data.lawId)
    cb('ok')
end)

RegisterNUICallback('rejectProposal', function(data, cb)
    TriggerServerEvent('government:server:rejectProposal', data.proposalId)
    cb('ok')
end)

RegisterNUICallback('addTransaction', function(data, cb)
    TriggerServerEvent('government:server:addTransaction', data)
    cb('ok')
end)

RegisterNUICallback('createParty', function(data, cb)
    TriggerServerEvent('government:server:createParty', data.name, data.color)
    cb('ok')
end)

RegisterNUICallback('joinParty', function(data, cb)
    TriggerServerEvent('government:server:joinParty', data.partyId)
    cb('ok')
end)

RegisterNUICallback('leaveParty', function(_, cb)
    TriggerServerEvent('government:server:leaveParty')
    cb('ok')
end)

RegisterNUICallback('kickPartyMember', function(data, cb)
    TriggerServerEvent('government:server:kickPartyMember', data.targetCharId)
    cb('ok')
end)

RegisterNUICallback('updateManifesto', function(data, cb)
    TriggerServerEvent('government:server:updateManifesto', data.manifesto)
    cb('ok')
end)

RegisterNUICallback('startElection', function(data, cb)
    TriggerServerEvent('government:server:startElection', data.position, data.description)
    cb('ok')
end)

RegisterNUICallback('candidateElection', function(data, cb)
    TriggerServerEvent('government:server:candidateElection', data.electionId)
    cb('ok')
end)

RegisterNUICallback('voteElection', function(data, cb)
    TriggerServerEvent('government:server:voteElection', data.electionId, data.candidateId)
    cb('ok')
end)

RegisterNUICallback('closeElection', function(data, cb)
    TriggerServerEvent('government:server:closeElection', data.electionId)
    cb('ok')
end)
