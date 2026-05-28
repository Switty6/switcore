GovManager = {}

local GOV_ORG_CODE = 'government'
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

    if #title < 3 or #description < 5 or #category < 2 then
        notify(source, 'error', 'Completeaza toate campurile obligatorii.')
        return
    end

    local proposal = GovDB.createProposal(title, description, category, penalty, fineAmount, characterId)
    if not proposal then
        notify(source, 'error', 'Eroare la crearea propunerii.')
        return
    end

    notifyGovMembers('info', 'Propunere noua: ' .. title .. ' - voteaza in panoul de guvern.')
    return proposal
end

function GovManager.voteLaw(source, characterId, proposalId, vote)
    proposalId = tonumber(proposalId)
    if not proposalId or (vote ~= 'yes' and vote ~= 'no') then
        notify(source, 'error', 'Date invalide.')
        return
    end

    local proposal = GovDB.getProposal(proposalId)
    if not proposal or proposal.status ~= 'pending' then
        notify(source, 'error', 'Propunerea nu mai este activa.')
        return
    end

    local existing = GovDB.getVote(proposalId, characterId)
    if existing then
        notify(source, 'error', 'Ai votat deja aceasta propunere.')
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
            notifyGovMembers('success', 'Legea "' .. proposal.title .. '" a fost adoptata! (' .. yesVotes .. '/' .. quorum .. ' voturi)')
            return 'passed'
        end
    end

    notify(source, 'success', 'Vot inregistrat.')
    return 'voted'
end

function GovManager.repealLaw(source, characterId, lawId)
    lawId = tonumber(lawId)
    if not lawId then
        notify(source, 'error', 'ID invalid.')
        return
    end
    GovDB.repealLaw(lawId, characterId)
    notify(source, 'success', 'Legea a fost abrogata.')
    return true
end

function GovManager.rejectProposal(source, characterId, proposalId)
    proposalId = tonumber(proposalId)
    if not proposalId then return end
    GovDB.setProposalStatus(proposalId, 'rejected')
    notify(source, 'success', 'Propunerea a fost respinsa.')
    return true
end

function GovManager.createParty(source, characterId, name, color)
    name  = tostring(name or ''):sub(1, 100)
    color = tostring(color or '#00b4ff'):sub(1, 7)

    if #name < 3 then
        notify(source, 'error', 'Numele partidului este prea scurt.')
        return
    end

    local existing = GovDB.getPartyByName(name)
    if existing then
        notify(source, 'error', 'Exista deja un partid cu acest nume.')
        return
    end

    local myParty = GovDB.getCharacterParty(characterId)
    if myParty then
        notify(source, 'error', 'Esti deja membru intr-un partid.')
        return
    end

    local party = GovDB.createParty(name, color, characterId)
    if not party then
        notify(source, 'error', 'Eroare la crearea partidului.')
        return
    end

    GovDB.joinParty(party.id, characterId, 'leader')
    notify(source, 'success', 'Partidul "' .. name .. '" a fost infiintat.')
    return party
end

function GovManager.joinParty(source, characterId, partyId)
    partyId = tonumber(partyId)
    if not partyId then return end

    local myParty = GovDB.getCharacterParty(characterId)
    if myParty then
        notify(source, 'error', 'Esti deja intr-un partid. Iesi mai intai.')
        return
    end

    local party = GovDB.getParty(partyId)
    if not party or not party.is_active then
        notify(source, 'error', 'Partidul nu exista.')
        return
    end

    GovDB.joinParty(partyId, characterId, 'member')
    notify(source, 'success', 'Te-ai alaturat partidului "' .. party.name .. '".')
    return true
end

function GovManager.leaveParty(source, characterId)
    local myParty = GovDB.getCharacterParty(characterId)
    if not myParty then
        notify(source, 'error', 'Nu esti in niciun partid.')
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
    notify(source, 'info', 'Ai parasit partidul.')
    return true
end

function GovManager.kickPartyMember(source, characterId, targetCharId)
    targetCharId = tonumber(targetCharId)
    if not targetCharId or targetCharId == characterId then
        notify(source, 'error', 'Actiune invalida.')
        return
    end

    local myParty  = GovDB.getCharacterParty(characterId)
    local tgtParty = GovDB.getCharacterParty(targetCharId)

    if not myParty or not tgtParty or myParty.party_id ~= tgtParty.party_id then
        notify(source, 'error', 'Nu sunteti in acelasi partid.')
        return
    end
    if myParty.role ~= 'leader' and myParty.role ~= 'vice' then
        notify(source, 'error', 'Nu ai permisiunea de a exclude membri.')
        return
    end
    if tgtParty.role == 'leader' then
        notify(source, 'error', 'Nu poti exclude liderul.')
        return
    end

    GovDB.leaveParty(myParty.party_id, targetCharId)
    notify(source, 'success', 'Membrul a fost exclus din partid.')
    return true
end

function GovManager.updateManifesto(source, characterId, manifesto)
    local myParty = GovDB.getCharacterParty(characterId)
    if not myParty or (myParty.role ~= 'leader' and myParty.role ~= 'secretary') then
        notify(source, 'error', 'Doar liderul sau secretarul poate edita manifestul.')
        return
    end
    manifesto = tostring(manifesto or ''):sub(1, 5000)
    GovDB.updateManifesto(myParty.party_id, manifesto)
    notify(source, 'success', 'Manifest actualizat.')
    return true
end

function GovManager.startElection(source, characterId, position, description)
    position    = tostring(position or ''):sub(1, 100)
    description = tostring(description or ''):sub(1, 500)

    if #position < 3 then
        notify(source, 'error', 'Specificati pozitia pentru alegere.')
        return
    end

    local election = GovDB.createElection(position, description, characterId)
    if not election then
        notify(source, 'error', 'Eroare la deschiderea alegerilor.')
        return
    end

    notifyGovMembers('info', 'Alegeri deschise pentru: ' .. position .. ' - inscrie-te in panoul de guvern.')
    return election
end

function GovManager.candidateElection(source, characterId, electionId)
    electionId = tonumber(electionId)
    if not electionId then return end

    local election = GovDB.getElection(electionId)
    if not election or election.status ~= 'active' then
        notify(source, 'error', 'Alegerile nu sunt active.')
        return
    end

    local myParty = GovDB.getCharacterParty(characterId)
    local partyId = myParty and myParty.party_id or nil

    local ok, err = pcall(function()
        GovDB.addCandidate(electionId, characterId, partyId)
    end)
    if not ok then
        notify(source, 'error', 'Esti deja inscris ca si candidat.')
        return
    end

    notify(source, 'success', 'Te-ai inscris ca si candidat.')
    return true
end

function GovManager.voteElection(source, characterId, electionId, candidateId)
    electionId  = tonumber(electionId)
    candidateId = tonumber(candidateId)
    if not electionId or not candidateId then return end

    local election = GovDB.getElection(electionId)
    if not election or election.status ~= 'active' then
        notify(source, 'error', 'Alegerile nu sunt active.')
        return
    end

    if GovDB.hasVotedElection(electionId, characterId) then
        notify(source, 'error', 'Ai votat deja la aceste alegeri.')
        return
    end

    GovDB.voteElection(electionId, characterId, candidateId)
    notify(source, 'success', 'Vot exprimat.')
    return true
end

function GovManager.closeElection(source, characterId, electionId)
    electionId = tonumber(electionId)
    if not electionId then return end

    local election = GovDB.getElection(electionId)
    if not election or election.status ~= 'active' then
        notify(source, 'error', 'Alegerile nu exista sau sunt deja inchise.')
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
        local winnerName = (ok and wd) and (wd.first_name .. ' ' .. wd.last_name) or 'necunoscut'
        notifyGovMembers('success', 'Alegerile pentru "' .. election.position .. '" s-au incheiat. Castigator: ' .. winnerName)
    end

    notify(source, 'success', 'Alegerile au fost inchise.')
    return true
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
            table.insert(officials, {
                id   = src,
                name = GetPlayerName(src) or 'Unknown',
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
