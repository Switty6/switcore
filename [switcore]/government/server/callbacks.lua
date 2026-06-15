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

Sw.SecureEvent('government:server:getPublicLaws', {
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local laws = GovDB.getLaws(true) or {}
    TriggerClientEvent('government:client:openLaws', src, laws)
end)

Sw.SecureEvent('government:server:open', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src = ctx.source

    if not hasAnyGovPerm(src) then
        notify(src, 'error', Sw.TP(src, 'government.access_denied'))
        return
    end

    local data = GovManager.buildFullData(src)
    TriggerClientEvent('government:client:open', src, data)
end)

Sw.SecureEvent('government:server:proposeLaw', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local data = ctx.args[1]
    if not perm(src, 'government.laws') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_propose'))
        return
    end
    local proposal = GovManager.proposeLaw(src, char.id, data or {})
    if proposal then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:voteLaw', {
    character = true,
    rateLimit = { max = 20, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local proposalId, vote = ctx.args[1], ctx.args[2]
    if not perm(src, 'government.laws') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_vote'))
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

Sw.SecureEvent('government:server:repealLaw', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local lawId = ctx.args[1]
    if not perm(src, 'government.laws') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_repeal'))
        return
    end
    local ok = GovManager.repealLaw(src, char.id, lawId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:rejectProposal', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local proposalId = ctx.args[1]
    if not perm(src, 'government.laws') then return end
    local ok = GovManager.rejectProposal(src, char.id, proposalId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:addTransaction', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local data = ctx.args[1]
    if not perm(src, 'government.budget') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_budget'))
        return
    end

    data = data or {}
    local txType     = data.type == 'expense' and 'expense' or 'income'
    local amount     = math.max(1, tonumber(data.amount) or 0)
    local description = tostring(data.description or ''):sub(1, 500)
    local category   = tostring(data.category or 'Altele'):sub(1, 50)

    if #description < 3 then
        notify(src, 'error', Sw.TP(src, 'government.add_description'))
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

Sw.SecureEvent('government:server:createParty', {
    character = true,
    rateLimit = { max = 5, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local name, color = ctx.args[1], ctx.args[2]
    if not perm(src, 'government.parties') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_parties'))
        return
    end
    local party = GovManager.createParty(src, char.id, name, color)
    if party then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:joinParty', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local partyId = ctx.args[1]
    if not hasAnyGovPerm(src) then return end
    local ok = GovManager.joinParty(src, char.id, partyId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:leaveParty', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local ok = GovManager.leaveParty(src, char.id)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:kickPartyMember', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local targetCharId = ctx.args[1]
    local ok = GovManager.kickPartyMember(src, char.id, targetCharId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:updateManifesto', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local manifesto = ctx.args[1]
    local ok = GovManager.updateManifesto(src, char.id, manifesto)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:startElection', {
    character = true,
    rateLimit = { max = 5, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local position, description = ctx.args[1], ctx.args[2]
    if not perm(src, 'government.elections') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_open_elections'))
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

Sw.SecureEvent('government:server:candidateElection', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local electionId = ctx.args[1]
    if not hasAnyGovPerm(src) then return end
    local ok = GovManager.candidateElection(src, char.id, electionId)
    if ok then
        local updated = GovManager.buildFullData(src)
        TriggerClientEvent('government:client:update', src, updated)
    end
end)

Sw.SecureEvent('government:server:voteElection', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local electionId, candidateId = ctx.args[1], ctx.args[2]
    local fromVote = ctx.args[3] == true
    -- Votul la alegeri e public: orice cetatean poate vota.
    local ok = GovManager.voteElection(src, char.id, electionId, candidateId)
    if ok then
        -- Reimprospatam exact vederea din care s-a votat, nu in functie de permisiuni:
        -- vot din /vot -> overlay public; vot din panoul /guv -> panou complet.
        if fromVote then
            TriggerClientEvent('government:client:openVote', src, GovManager.buildPublicElections())
        elseif hasAnyGovPerm(src) then
            TriggerClientEvent('government:client:update', src, GovManager.buildFullData(src))
        end
    end
end)

-- Vot public: orice jucator poate cere lista alegerilor active si vota (candidatura ramane doar pentru membri).
Sw.SecureEvent('government:server:getPublicElections', {
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    TriggerClientEvent('government:client:openVote', ctx.source, GovManager.buildPublicElections())
end)

Sw.SecureEvent('government:server:closeElection', {
    character = true,
    rateLimit = { max = 5, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local electionId = ctx.args[1]
    if not perm(src, 'government.elections') then
        notify(src, 'error', Sw.TP(src, 'government.no_perm_close_elections'))
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

-- Verifica periodic propunerile al caror termen de vot a expirat si le finalizeaza
-- (adoptate la cvorum, altfel respinse). Reimprospateaza panourile membrilor online.
CreateThread(function()
    while true do
        Wait(30000)
        local changed = GovManager.finalizeExpiredProposals()
        if changed then
            for _, playerId in ipairs(GetPlayers()) do
                local s = tonumber(playerId)
                if hasAnyGovPerm(s) then
                    TriggerClientEvent('government:client:update', s, GovManager.buildFullData(s))
                end
            end
        end
    end
end)
