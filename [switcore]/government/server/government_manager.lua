GovManager = {}

local GOV_ORG_CODE = 'gov'  -- codul organizatiei seedate in banking (organizations.code)
local currencyCache = nil

local function getCurrencyId()
    if not currencyCache then
        local currencies = exports.banking:getActiveCurrencies()
        currencyCache = currencies and currencies[1] and currencies[1].id or 1
    end
    return currencyCache
end

local function getQuorum()
    return exports.settings:GetSettingNumber('government.vote_quorum', 3)
end

local function notify(source, t, msg)
    TriggerClientEvent('switcore:notify', source, t, msg)
end

local function notifyGovMembers(t, msg)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if exports.core:hasPermission(src, 'government.laws')
            or exports.core:hasPermission(src, 'government.all')
            or exports.core:hasPermission(src, 'admin.all') then
            notify(src, t, msg)
        end
    end
end

function GovManager.getTreasuryBalance()
    local ok, balance = pcall(function()
        return exports.banking:getOrgAccountBalance(GOV_ORG_CODE, getCurrencyId())
    end)
    return ok and (balance or 0) or 0
end

function GovManager.addIncome(amount, currencyCode, description, category, characterId)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    local currId = getCurrencyId()
    pcall(function()
        exports.banking:orgSystemCredit(GOV_ORG_CODE, amount, currId, description)
    end)
    GovDB.addBudgetEntry('income', amount, currencyCode or 'RON', description, category, characterId)
    return true
end

function GovManager.addExpense(amount, currencyCode, description, category, characterId)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    local currId = getCurrencyId()
    pcall(function()
        exports.banking:orgSystemDebit(GOV_ORG_CODE, amount, currId, description)
    end)
    GovDB.addBudgetEntry('expense', amount, currencyCode or 'RON', description, category, characterId)
    return true
end

function GovManager.proposeLaw(source, characterId, data)
    local title       = tostring(data.title or ''):sub(1, 200)
    local description = tostring(data.description or ''):sub(1, 2000)
    local category    = tostring(data.category or ''):sub(1, 50)
    local penalty     = tostring(data.penalty or ''):sub(1, 200)
    local fineAmount  = math.max(0, tonumber(data.fine_amount) or 0)

    -- Termen de vot in minute: din formular, cu fallback pe setarea globala. Limitat intre 5 min si 7 zile.
    local defaultMin = exports.settings:GetSettingNumber('government.vote_duration_minutes', 1440)
    local duration   = math.floor(tonumber(data.duration_minutes) or defaultMin)
    duration = math.max(5, math.min(duration, 10080))

    if #title < 3 or #description < 5 or #category < 2 then
        notify(source, 'error', Sw.TP(source, 'government.fill_required_fields'))
        return
    end

    local proposal = GovDB.createProposal(title, description, category, penalty, fineAmount, characterId, duration)
    if not proposal then
        notify(source, 'error', Sw.TP(source, 'government.proposal_create_failed'))
        return
    end

    notifyGovMembers('info', Sw.T('government.new_proposal_notify', title))
    return proposal
end

-- Finalizeaza propunerile al caror termen a expirat: adoptate daca au atins cvorumul, altfel respinse.
-- Intoarce true daca s-a schimbat ceva (ca apelantul sa reimprospateze panourile).
function GovManager.finalizeExpiredProposals()
    local expired = GovDB.getExpiredProposals() or {}
    if #expired == 0 then return false end

    local quorum = getQuorum()
    for _, p in ipairs(expired) do
        local yesVotes = GovDB.countYesVotes(p.id)
        if yesVotes >= quorum then
            GovDB.setProposalStatus(p.id, 'passed')
            GovDB.createLaw(p.id, p.title, p.description, p.category, p.penalty, p.fine_amount, p.proposed_by)
            notifyGovMembers('success', Sw.T('government.law_passed_on_expiry', p.title, yesVotes, quorum))
        else
            GovDB.setProposalStatus(p.id, 'rejected')
            notifyGovMembers('warning', Sw.T('government.proposal_rejected_insufficient', p.title, yesVotes, quorum))
        end
    end
    return true
end

function GovManager.voteLaw(source, characterId, proposalId, vote)
    proposalId = tonumber(proposalId)
    if not proposalId or (vote ~= 'yes' and vote ~= 'no') then
        notify(source, 'error', Sw.TP(source, 'government.invalid_data'))
        return
    end

    local proposal = GovDB.getProposal(proposalId)
    if not proposal or proposal.status ~= 'pending' then
        notify(source, 'error', Sw.TP(source, 'government.proposal_not_active'))
        return
    end

    local existing = GovDB.getVote(proposalId, characterId)
    if existing then
        notify(source, 'error', Sw.TP(source, 'government.already_voted_proposal'))
        return
    end

    GovDB.addVote(proposalId, characterId, vote)

    if vote == 'yes' then
        local yesVotes = GovDB.countYesVotes(proposalId)
        local quorum   = getQuorum()
        if yesVotes >= quorum then
            GovDB.setProposalStatus(proposalId, 'passed')
            GovDB.createLaw(
                proposalId,
                proposal.title, proposal.description, proposal.category,
                proposal.penalty, proposal.fine_amount, characterId
            )
            notifyGovMembers('success', Sw.T('government.law_passed_notify', proposal.title, yesVotes, quorum))
            return 'passed'
        end
    end

    notify(source, 'success', Sw.TP(source, 'government.vote_registered'))
    return 'voted'
end

function GovManager.repealLaw(source, characterId, lawId)
    lawId = tonumber(lawId)
    if not lawId then
        notify(source, 'error', Sw.TP(source, 'government.invalid_id'))
        return
    end
    GovDB.repealLaw(lawId, characterId)
    notify(source, 'success', Sw.TP(source, 'government.law_repealed'))
    return true
end

function GovManager.rejectProposal(source, characterId, proposalId)
    proposalId = tonumber(proposalId)
    if not proposalId then return end
    GovDB.setProposalStatus(proposalId, 'rejected')
    notify(source, 'success', Sw.TP(source, 'government.proposal_rejected'))
    return true
end

function GovManager.createParty(source, characterId, name, color)
    name  = tostring(name or ''):sub(1, 100)
    color = tostring(color or '#00b4ff'):sub(1, 7)

    if #name < 3 then
        notify(source, 'error', Sw.TP(source, 'government.party_name_too_short'))
        return
    end

    local existing = GovDB.getPartyByName(name)
    if existing then
        notify(source, 'error', Sw.TP(source, 'government.party_name_exists'))
        return
    end

    local myParty = GovDB.getCharacterParty(characterId)
    if myParty then
        notify(source, 'error', Sw.TP(source, 'government.already_in_party'))
        return
    end

    local party = GovDB.createParty(name, color, characterId)
    if not party then
        notify(source, 'error', Sw.TP(source, 'government.party_create_failed'))
        return
    end

    GovDB.joinParty(party.id, characterId, 'leader')
    notify(source, 'success', Sw.TP(source, 'government.party_created', name))
    return party
end

function GovManager.joinParty(source, characterId, partyId)
    partyId = tonumber(partyId)
    if not partyId then return end

    local myParty = GovDB.getCharacterParty(characterId)
    if myParty then
        notify(source, 'error', Sw.TP(source, 'government.already_in_party_leave_first'))
        return
    end

    local party = GovDB.getParty(partyId)
    if not party or not party.is_active then
        notify(source, 'error', Sw.TP(source, 'government.party_not_found'))
        return
    end

    GovDB.joinParty(partyId, characterId, 'member')
    notify(source, 'success', Sw.TP(source, 'government.party_joined', party.name))
    return true
end

function GovManager.leaveParty(source, characterId)
    local myParty = GovDB.getCharacterParty(characterId)
    if not myParty then
        notify(source, 'error', Sw.TP(source, 'government.not_in_party'))
        return
    end

    if myParty.role == 'leader' then
        -- Transfera leadership-ul; daca nu mai e nimeni, dizolva partidul
        local members = GovDB.getPartyMembers(myParty.party_id)
        local nextLeader = nil
        for _, m in ipairs(members) do
            if m.character_id ~= characterId then
                nextLeader = m
                break
            end
        end
        if nextLeader then
            GovDB.setMemberRole(myParty.party_id, nextLeader.character_id, 'leader')
            exports.postgres:query(
                'UPDATE government_parties SET leader_id=$2 WHERE id=$1',
                { myParty.party_id, nextLeader.character_id }
            )
        else
            GovDB.dissolveParty(myParty.party_id)
        end
    end

    GovDB.leaveParty(myParty.party_id, characterId)
    notify(source, 'info', Sw.TP(source, 'government.party_left'))
    return true
end

function GovManager.kickPartyMember(source, characterId, targetCharId)
    targetCharId = tonumber(targetCharId)
    if not targetCharId or targetCharId == characterId then
        notify(source, 'error', Sw.TP(source, 'government.invalid_action'))
        return
    end

    local myParty  = GovDB.getCharacterParty(characterId)
    local tgtParty = GovDB.getCharacterParty(targetCharId)

    if not myParty or not tgtParty or myParty.party_id ~= tgtParty.party_id then
        notify(source, 'error', Sw.TP(source, 'government.not_same_party'))
        return
    end
    if myParty.role ~= 'leader' and myParty.role ~= 'vice' then
        notify(source, 'error', Sw.TP(source, 'government.no_perm_kick'))
        return
    end
    if tgtParty.role == 'leader' then
        notify(source, 'error', Sw.TP(source, 'government.cannot_kick_leader'))
        return
    end

    GovDB.leaveParty(myParty.party_id, targetCharId)
    notify(source, 'success', Sw.TP(source, 'government.member_kicked'))
    return true
end

function GovManager.updateManifesto(source, characterId, manifesto)
    local myParty = GovDB.getCharacterParty(characterId)
    if not myParty or (myParty.role ~= 'leader' and myParty.role ~= 'secretary') then
        notify(source, 'error', Sw.TP(source, 'government.only_leader_secretary_manifesto'))
        return
    end
    manifesto = tostring(manifesto or ''):sub(1, 5000)
    GovDB.updateManifesto(myParty.party_id, manifesto)
    notify(source, 'success', Sw.TP(source, 'government.manifesto_updated'))
    return true
end

function GovManager.startElection(source, characterId, position, description)
    position    = tostring(position or ''):sub(1, 100)
    description = tostring(description or ''):sub(1, 500)

    if #position < 3 then
        notify(source, 'error', Sw.TP(source, 'government.specify_position'))
        return
    end

    local election = GovDB.createElection(position, description, characterId)
    if not election then
        notify(source, 'error', Sw.TP(source, 'government.election_open_failed'))
        return
    end

    notifyGovMembers('info', Sw.T('government.election_opened_notify', position))
    return election
end

function GovManager.candidateElection(source, characterId, electionId)
    electionId = tonumber(electionId)
    if not electionId then return end

    local election = GovDB.getElection(electionId)
    if not election or election.status ~= 'active' then
        notify(source, 'error', Sw.TP(source, 'government.election_not_active'))
        return
    end

    local myParty = GovDB.getCharacterParty(characterId)
    local partyId = myParty and myParty.party_id or nil

    local ok, res = pcall(function()
        return GovDB.addCandidate(electionId, characterId, partyId)
    end)
    if not ok then
        notify(source, 'error', Sw.TP(source, 'government.candidate_register_failed'))
        return
    end
    if res and tonumber(res.rowCount) == 0 then
        notify(source, 'error', Sw.TP(source, 'government.already_candidate'))
        return
    end

    notify(source, 'success', Sw.TP(source, 'government.candidate_registered'))
    return true
end

function GovManager.voteElection(source, characterId, electionId, candidateId)
    electionId  = tonumber(electionId)
    candidateId = tonumber(candidateId)
    if not electionId or not candidateId then return end

    local election = GovDB.getElection(electionId)
    if not election or election.status ~= 'active' then
        notify(source, 'error', Sw.TP(source, 'government.election_not_active'))
        return
    end

    if GovDB.hasVotedElection(electionId, characterId) then
        notify(source, 'error', Sw.TP(source, 'government.already_voted_election'))
        return
    end

    GovDB.voteElection(electionId, characterId, candidateId)
    notify(source, 'success', Sw.TP(source, 'government.vote_cast'))
    return true
end

function GovManager.closeElection(source, characterId, electionId)
    electionId = tonumber(electionId)
    if not electionId then return end

    local election = GovDB.getElection(electionId)
    if not election or election.status ~= 'active' then
        notify(source, 'error', Sw.TP(source, 'government.election_not_found_or_closed'))
        return
    end

    local winnerId = GovDB.closeElection(electionId, characterId)
    if winnerId then
        local ok, wd = pcall(function()
            return exports.postgres:queryOne(
                'SELECT first_name, last_name FROM characters WHERE id=$1',
                { winnerId }
            )
        end)
        local winnerName = (ok and wd) and (wd.first_name .. ' ' .. wd.last_name) or Sw.T('government.winner_unknown')
        notifyGovMembers('success', Sw.T('government.election_closed_notify', election.position, winnerName))
    end

    notify(source, 'success', Sw.TP(source, 'government.election_closed'))
    return true
end

-- Payload restrans pentru votul public (cetateni): doar alegerile active + candidatii.
function GovManager.buildPublicElections()
    local elections = GovDB.getActiveElections() or {}
    for _, el in ipairs(elections) do
        el.candidates = GovDB.getElectionCandidates(el.id) or {}
    end
    return elections
end

function GovManager.buildFullData(source)
    local balance    = GovManager.getTreasuryBalance()
    local proposals  = GovDB.getProposals() or {}
    local laws       = GovDB.getLaws(true) or {}
    local budgetLog  = GovDB.getBudgetLog(50) or {}
    local parties    = GovDB.getParties() or {}
    local elections  = GovDB.getActiveElections() or {}
    local closedEl   = GovDB.getClosedElections() or {}
    local quorum     = getQuorum()

    for _, el in ipairs(elections) do
        el.candidates = GovDB.getElectionCandidates(el.id) or {}
    end

    local officials = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local pd  = exports.core:getPlayerData(src)
        if exports.core:hasPermission(src, 'government.access')
            or exports.core:hasPermission(src, 'government.all')
            or exports.core:hasPermission(src, 'admin.all') then
            local char = exports.characters:getActiveCharacter(src)
            local name = char and char.first_name and ((char.first_name or '') .. ' ' .. (char.last_name or ''))
            table.insert(officials, {
                id   = src,
                name = name or GetPlayerName(src) or 'Unknown',
                dbId = pd and pd.dbId,
            })
        end
    end

    local perms = {
        laws      = exports.core:hasPermission(source, 'government.laws')      or exports.core:hasPermission(source, 'government.all') or exports.core:hasPermission(source, 'admin.all'),
        budget    = exports.core:hasPermission(source, 'government.budget')    or exports.core:hasPermission(source, 'government.all') or exports.core:hasPermission(source, 'admin.all'),
        parties   = exports.core:hasPermission(source, 'government.parties')   or exports.core:hasPermission(source, 'government.all') or exports.core:hasPermission(source, 'admin.all'),
        elections = exports.core:hasPermission(source, 'government.elections') or exports.core:hasPermission(source, 'government.all') or exports.core:hasPermission(source, 'admin.all'),
    }

    return {
        balance   = balance,
        proposals = proposals,
        laws      = laws,
        budgetLog = budgetLog,
        parties   = parties,
        elections = elections,
        closedElections = closedEl,
        officials = officials,
        quorum    = quorum,
        perms     = perms,
    }
end
