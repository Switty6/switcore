local function getChar(source)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(source)
    end)
    return ok and char or nil
end

local function perm(source, node)
    return exports.core:hasPermission(source, 'admin.all')
        or exports.core:hasPermission(source, 'government.all')
        or exports.core:hasPermission(source, node)
end

local function hasAnyGovPerm(source)
    return exports.core:hasPermission(source, 'admin.all')
        or exports.core:hasPermission(source, 'government.all')
        or exports.core:hasPermission(source, 'government.access')
        or exports.core:hasPermission(source, 'government.laws')
        or exports.core:hasPermission(source, 'government.budget')
        or exports.core:hasPermission(source, 'government.parties')
        or exports.core:hasPermission(source, 'government.elections')
end

local function notify(source, t, msg)
    TriggerClientEvent('switcore:notify', source, t, msg)
end

RegisterNetEvent('government:server:getPublicLaws', function()
    local src  = source
    local laws = GovDB.getLaws(true) or {}
    TriggerClientEvent('government:client:openLaws', src, laws)
end)

RegisterNetEvent('government:server:open', function()
    local src  = source
    local char = getChar(src)
    if not char then return end

    if not hasAnyGovPerm(src) then
        notify(src, 'error', 'Acces interzis.')
        return
    end

    local data = GovManager.buildFullData(src)
    TriggerClientEvent('government:client:open', src, data)
end)

RegisterNetEvent('government:server:proposeLaw', function(data)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.laws') then
        notify(src, 'error', 'Nu ai permisiunea de a propune legi.')
        return
    end
    local proposal = GovManager.proposeLaw(src, char.id, data or {})
    if proposal then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:voteLaw', function(proposalId, vote)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.laws') then
        notify(src, 'error', 'Nu ai permisiunea de a vota.')
        return
    end
    local result = GovManager.voteLaw(src, char.id, proposalId, vote)
    if result then
        if result == 'passed' then
            for _, playerId in ipairs(GetPlayers()) do
                local s = tonumber(playerId)
                if hasAnyGovPerm(s) then
                    local d = GovManager.buildFullData(s)
                    TriggerClientEvent('government:client:update', s, d)
                end
            end
        else
            local updated = GovManager.buildFullData(src)
            TriggerClientEvent('government:client:update', src, updated)
        end
    end
end)

RegisterNetEvent('government:server:repealLaw', function(lawId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.laws') then
        notify(src, 'error', 'Nu ai permisiunea de a abroga legi.')
        return
    end
    local ok = GovManager.repealLaw(src, char.id, lawId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:rejectProposal', function(proposalId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.laws') then return end
    local ok = GovManager.rejectProposal(src, char.id, proposalId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:addTransaction', function(data)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.budget') then
        notify(src, 'error', 'Nu ai permisiunea de a gestiona bugetul.')
        return
    end

    data = data or {}
    local txType     = data.type == 'expense' and 'expense' or 'income'
    local amount     = math.max(1, tonumber(data.amount) or 0)
    local description = tostring(data.description or ''):sub(1, 500)
    local category   = tostring(data.category or 'Altele'):sub(1, 50)

    if #description < 3 then
        notify(src, 'error', 'Adauga o descriere.')
        return
    end

    if txType == 'income' then
        GovManager.addIncome(amount, 'RON', description, category, char.id)
    else
        GovManager.addExpense(amount, 'RON', description, category, char.id)
    end

    local updated = GovManager.buildFullData(src)
    TriggerClientEvent('government:client:update', src, updated)
end)

RegisterNetEvent('government:server:createParty', function(name, color)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.parties') then
        notify(src, 'error', 'Nu ai permisiunea de a infiinta partide.')
        return
    end
    local party = GovManager.createParty(src, char.id, name, color)
    if party then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:joinParty', function(partyId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not hasAnyGovPerm(src) then return end
    local ok = GovManager.joinParty(src, char.id, partyId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:leaveParty', function()
    local src  = source
    local char = getChar(src)
    if not char then return end
    local ok = GovManager.leaveParty(src, char.id)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:kickPartyMember', function(targetCharId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    local ok = GovManager.kickPartyMember(src, char.id, targetCharId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:updateManifesto', function(manifesto)
    local src  = source
    local char = getChar(src)
    if not char then return end
    local ok = GovManager.updateManifesto(src, char.id, manifesto)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:startElection', function(position, description)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.elections') then
        notify(src, 'error', 'Nu ai permisiunea de a deschide alegeri.')
        return
    end
    local election = GovManager.startElection(src, char.id, position, description)
    if election then
        for _, playerId in ipairs(GetPlayers()) do
            local s = tonumber(playerId)
            if hasAnyGovPerm(s) then
                local d = GovManager.buildFullData(s)
                TriggerClientEvent('government:client:update', s, d)
            end
        end
    end
end)

RegisterNetEvent('government:server:candidateElection', function(electionId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not hasAnyGovPerm(src) then return end
    local ok = GovManager.candidateElection(src, char.id, electionId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:voteElection', function(electionId, candidateId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not hasAnyGovPerm(src) then return end
    local ok = GovManager.voteElection(src, char.id, electionId, candidateId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

RegisterNetEvent('government:server:closeElection', function(electionId)
    local src  = source
    local char = getChar(src)
    if not char then return end
    if not perm(src, 'government.elections') then
        notify(src, 'error', 'Nu ai permisiunea de a inchide alegerile.')
        return
    end
    local ok = GovManager.closeElection(src, char.id, electionId)
    if ok then
        for _, playerId in ipairs(GetPlayers()) do
            local s = tonumber(playerId)
            if hasAnyGovPerm(s) then
                local d = GovManager.buildFullData(s)
                TriggerClientEvent('government:client:update', s, d)
            end
        end
    end
end)
