exports.core:registerModuleLocales(GetCurrentResourceName())

MDTDatabase = {}

function MDTDatabase.createCitation(officerId, suspectId, offense, fineAmount, cb)
    local row = exports.postgres:queryOne(
        'INSERT INTO police_citations (officer_id, suspect_id, offense, fine_amount) VALUES ($1,$2,$3,$4) RETURNING *',
        { officerId, suspectId, offense, fineAmount }
    )
    cb(row)
end

function MDTDatabase.getCitations(cb)
    local rows = exports.postgres:queryAll(
        [[SELECT c.*, sus.first_name, sus.last_name
          FROM police_citations c
          JOIN characters sus ON sus.id = c.suspect_id
          ORDER BY c.issued_at DESC LIMIT 100]],
        {}
    )
    cb(rows or {})
end

function MDTDatabase.markCitationPaid(citationId, cb)
    local row = exports.postgres:queryOne(
        'UPDATE police_citations SET is_paid=TRUE, paid_at=NOW() WHERE id=$1 AND is_paid=FALSE RETURNING id',
        { citationId }
    )
    cb(row ~= nil)
end

function MDTDatabase.createBOLO(officerId, subjectName, description, vehicleInfo, cb)
    local row = exports.postgres:queryOne(
        'INSERT INTO police_bolos (officer_id, subject_name, description, vehicle_info) VALUES ($1,$2,$3,$4) RETURNING *',
        { officerId, subjectName, description, vehicleInfo ~= '' and vehicleInfo or nil }
    )
    cb(row)
end

function MDTDatabase.getActiveBOLOs(cb)
    local rows = exports.postgres:queryAll(
        'SELECT * FROM police_bolos WHERE is_active=TRUE ORDER BY created_at DESC',
        {}
    )
    cb(rows or {})
end

function MDTDatabase.closeBOLO(boloId, officerId, cb)
    exports.postgres:query(
        'UPDATE police_bolos SET is_active=FALSE, closed_at=NOW(), closed_by=$2 WHERE id=$1',
        { boloId, officerId }
    )
    cb()
end

function MDTDatabase.createIncident(officerId, title, description, involvedJson, cb)
    local row = exports.postgres:queryOne(
        'INSERT INTO police_incidents (officer_id, title, description, involved_characters) VALUES ($1,$2,$3,$4::jsonb) RETURNING *',
        { officerId, title, description, involvedJson }
    )
    cb(row)
end

function MDTDatabase.getIncidents(cb)
    local rows = exports.postgres:queryAll(
        'SELECT * FROM police_incidents ORDER BY created_at DESC LIMIT 50',
        {}
    )
    cb(rows or {})
end

function MDTDatabase.createImpound(officerId, plate, model, reason, fee, cb)
    local row = exports.postgres:queryOne(
        'INSERT INTO police_impounds (officer_id, plate, model, reason, fee) VALUES ($1,$2,$3,$4,$5) RETURNING *',
        { officerId, plate, model ~= '' and model or nil, reason, fee }
    )
    cb(row)
end

function MDTDatabase.getImpounds(cb)
    local rows = exports.postgres:queryAll(
        'SELECT * FROM police_impounds ORDER BY impounded_at DESC LIMIT 100',
        {}
    )
    cb(rows or {})
end

function MDTDatabase.retrieveImpound(impoundId, cb)
    exports.postgres:query(
        'UPDATE police_impounds SET is_retrieved=TRUE, retrieved_at=NOW() WHERE id=$1',
        { impoundId }
    )
    cb()
end

function MDTDatabase.getCriminalHistory(characterId, cb)
    local result = {
        jails = exports.postgres:queryAll(
            'SELECT * FROM police_jail_sentences WHERE character_id=$1 ORDER BY arrested_at DESC LIMIT 20',
            { characterId }
        ) or {},
        warrants = exports.postgres:queryAll(
            'SELECT * FROM police_warrants WHERE character_id=$1 ORDER BY issued_at DESC LIMIT 20',
            { characterId }
        ) or {},
        citations = exports.postgres:queryAll(
            'SELECT * FROM police_citations WHERE suspect_id=$1 ORDER BY issued_at DESC LIMIT 20',
            { characterId }
        ) or {},
    }
    cb(result)
end
