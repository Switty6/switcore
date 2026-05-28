GovDB = {}

local function pg() return exports.postgres end

function GovDB.getProposals()
    return pg():queryAll([[
        SELECT p.*,
               c.first_name || ' ' || c.last_name AS proposed_by_name,
               COUNT(CASE WHEN v.vote='yes' THEN 1 END)::INT AS yes_votes,
               COUNT(CASE WHEN v.vote='no'  THEN 1 END)::INT AS no_votes
        FROM government_law_proposals p
        LEFT JOIN characters c ON c.id = p.proposed_by
        LEFT JOIN government_law_votes v ON v.proposal_id = p.id
        WHERE p.status = 'pending'
        GROUP BY p.id, c.first_name, c.last_name
        ORDER BY p.created_at DESC
    ]])
end

function GovDB.createProposal(title, description, category, penalty, fineAmount, characterId)
    return pg():queryOne(
        'INSERT INTO government_law_proposals (title,description,category,penalty,fine_amount,proposed_by) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
        { title, description, category, penalty, fineAmount, characterId }
    )
end

function GovDB.getProposal(id)
    return pg():queryOne('SELECT * FROM government_law_proposals WHERE id=$1', { id })
end

function GovDB.getVote(proposalId, characterId)
    return pg():queryOne(
        'SELECT * FROM government_law_votes WHERE proposal_id=$1 AND character_id=$2',
        { proposalId, characterId }
    )
end

function GovDB.countYesVotes(proposalId)
    local row = pg():queryOne(
        "SELECT COUNT(*)::INT AS cnt FROM government_law_votes WHERE proposal_id=$1 AND vote='yes'",
        { proposalId }
    )
    return row and row.cnt or 0
end

function GovDB.addVote(proposalId, characterId, vote)
    return pg():execute(
        'INSERT INTO government_law_votes (proposal_id,character_id,vote) VALUES ($1,$2,$3) ON CONFLICT (proposal_id,character_id) DO UPDATE SET vote=$3, voted_at=NOW()',
        { proposalId, characterId, vote }
    )
end

function GovDB.setProposalStatus(proposalId, status)
    return pg():execute(
        'UPDATE government_law_proposals SET status=$2 WHERE id=$1',
        { proposalId, status }
    )
end

function GovDB.getLaws(activeOnly)
    local where = activeOnly and 'WHERE l.is_active = TRUE' or ''
    return pg():queryAll(string.format([[
        SELECT l.*,
               c.first_name || ' ' || c.last_name AS created_by_name,
               r.first_name || ' ' || r.last_name AS repealed_by_name
        FROM government_laws l
        LEFT JOIN characters c ON c.id = l.created_by
        LEFT JOIN characters r ON r.id = l.repealed_by
        %s
        ORDER BY l.created_at DESC
    ]], where))
end

function GovDB.createLaw(proposalId, title, description, category, penalty, fineAmount, characterId)
    return pg():queryOne(
        'INSERT INTO government_laws (proposal_id,title,description,category,penalty,fine_amount,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',
        { proposalId, title, description, category, penalty, fineAmount, characterId }
    )
end

function GovDB.repealLaw(lawId, characterId)
    return pg():execute(
        'UPDATE government_laws SET is_active=FALSE, repealed_at=NOW(), repealed_by=$2 WHERE id=$1',
        { lawId, characterId }
    )
end

function GovDB.getBudgetLog(limit)
    return pg():queryAll([[
        SELECT bl.*, c.first_name || ' ' || c.last_name AS created_by_name
        FROM government_budget_log bl
        LEFT JOIN characters c ON c.id = bl.created_by
        ORDER BY bl.created_at DESC
        LIMIT $1
    ]], { limit or 50 })
end

function GovDB.addBudgetEntry(type, amount, currencyCode, description, category, characterId)
    return pg():execute(
        'INSERT INTO government_budget_log (type,amount,currency_code,description,category,created_by) VALUES ($1,$2,$3,$4,$5,$6)',
        { type, amount, currencyCode, description, category, characterId }
    )
end

function GovDB.getParties()
    return pg():queryAll([[
        SELECT p.*,
               c.first_name || ' ' || c.last_name AS leader_name,
               COUNT(pm.id)::INT AS member_count
        FROM government_parties p
        LEFT JOIN characters c ON c.id = p.leader_id
        LEFT JOIN government_party_members pm ON pm.party_id = p.id
        WHERE p.is_active = TRUE
        GROUP BY p.id, c.first_name, c.last_name
        ORDER BY p.name
    ]])
end

function GovDB.getParty(id)
    return pg():queryOne('SELECT * FROM government_parties WHERE id=$1', { id })
end

function GovDB.getPartyByName(name)
    return pg():queryOne('SELECT * FROM government_parties WHERE name=$1', { name })
end

function GovDB.createParty(name, color, characterId)
    return pg():queryOne(
        'INSERT INTO government_parties (name,color,leader_id,founded_by) VALUES ($1,$2,$3,$3) RETURNING *',
        { name, color, characterId }
    )
end

function GovDB.updateManifesto(partyId, manifesto)
    return pg():execute(
        'UPDATE government_parties SET manifesto=$2 WHERE id=$1',
        { partyId, manifesto }
    )
end

function GovDB.dissolveParty(partyId)
    return pg():execute(
        'UPDATE government_parties SET is_active=FALSE WHERE id=$1',
        { partyId }
    )
end

function GovDB.getPartyMembers(partyId)
    return pg():queryAll([[
        SELECT pm.*, c.first_name || ' ' || c.last_name AS char_name
        FROM government_party_members pm
        JOIN characters c ON c.id = pm.character_id
        WHERE pm.party_id = $1
        ORDER BY
            CASE pm.role WHEN 'leader' THEN 1 WHEN 'vice' THEN 2 WHEN 'secretary' THEN 3 ELSE 4 END,
            c.first_name
    ]], { partyId })
end

function GovDB.getCharacterParty(characterId)
    return pg():queryOne(
        'SELECT pm.*, p.name, p.color FROM government_party_members pm JOIN government_parties p ON p.id=pm.party_id WHERE pm.character_id=$1',
        { characterId }
    )
end

function GovDB.joinParty(partyId, characterId, role)
    return pg():execute(
        'INSERT INTO government_party_members (party_id,character_id,role) VALUES ($1,$2,$3) ON CONFLICT (party_id,character_id) DO NOTHING',
        { partyId, characterId, role or 'member' }
    )
end

function GovDB.leaveParty(partyId, characterId)
    return pg():execute(
        'DELETE FROM government_party_members WHERE party_id=$1 AND character_id=$2',
        { partyId, characterId }
    )
end

function GovDB.setMemberRole(partyId, characterId, role)
    return pg():execute(
        'UPDATE government_party_members SET role=$3 WHERE party_id=$1 AND character_id=$2',
        { partyId, characterId, role }
    )
end

function GovDB.getActiveElections()
    return pg():queryAll([[
        SELECT e.*,
               c.first_name || ' ' || c.last_name AS started_by_name,
               w.first_name || ' ' || w.last_name AS winner_name
        FROM government_elections e
        LEFT JOIN characters c ON c.id = e.started_by
        LEFT JOIN characters w ON w.id = e.winner_character_id
        WHERE e.status = 'active'
        ORDER BY e.started_at DESC
    ]])
end

function GovDB.getElection(id)
    return pg():queryOne('SELECT * FROM government_elections WHERE id=$1', { id })
end

function GovDB.createElection(position, description, characterId)
    return pg():queryOne(
        'INSERT INTO government_elections (position,description,started_by) VALUES ($1,$2,$3) RETURNING *',
        { position, description, characterId }
    )
end

function GovDB.getElectionCandidates(electionId)
    return pg():queryAll([[
        SELECT ec.*, c.first_name || ' ' || c.last_name AS char_name, p.name AS party_name, p.color AS party_color
        FROM government_election_candidates ec
        JOIN characters c ON c.id = ec.character_id
        LEFT JOIN government_parties p ON p.id = ec.party_id
        WHERE ec.election_id = $1
        ORDER BY ec.votes DESC
    ]], { electionId })
end

function GovDB.addCandidate(electionId, characterId, partyId)
    return pg():execute(
        'INSERT INTO government_election_candidates (election_id,character_id,party_id) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
        { electionId, characterId, partyId }
    )
end

function GovDB.hasVotedElection(electionId, voterId)
    local row = pg():queryOne(
        'SELECT id FROM government_election_votes WHERE election_id=$1 AND voter_id=$2',
        { electionId, voterId }
    )
    return row ~= nil
end

function GovDB.voteElection(electionId, voterId, candidateId)
    pg():execute(
        'INSERT INTO government_election_votes (election_id,voter_id,candidate_id) VALUES ($1,$2,$3)',
        { electionId, voterId, candidateId }
    )
    pg():execute(
        'UPDATE government_election_candidates SET votes=votes+1 WHERE id=$1',
        { candidateId }
    )
end

function GovDB.closeElection(electionId, characterId)
    local winner = pg():queryOne([[
        SELECT character_id FROM government_election_candidates
        WHERE election_id=$1 ORDER BY votes DESC LIMIT 1
    ]], { electionId })
    local winnerId = winner and winner.character_id or nil
    pg():execute(
        'UPDATE government_elections SET status=$2, ended_at=NOW(), winner_character_id=$3 WHERE id=$1',
        { electionId, 'closed', winnerId }
    )
    return winnerId
end

function GovDB.getClosedElections()
    return pg():queryAll([[
        SELECT e.*,
               w.first_name || ' ' || w.last_name AS winner_name
        FROM government_elections e
        LEFT JOIN characters w ON w.id = e.winner_character_id
        WHERE e.status = 'closed'
        ORDER BY e.ended_at DESC
        LIMIT 20
    ]])
end
