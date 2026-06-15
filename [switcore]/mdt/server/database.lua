exports.core:registerModuleLocales(GetCurrentResourceName())

MDTDatabase = {}

function MDTDatabase.createCitation(officerId, suspectId, offense, fineAmount, cb)
    exports.postgres:query(
        'INSERT INTO police_citations (officer_id, suspect_id, offense, fine_amount) VALUES ($1,$2,$3,$4) RETURNING *',
        { officerId, suspectId, offense, fineAmount },
        function(rows)
            cb(rows and rows[1] or nil)
        end
    )
end

function MDTDatabase.getCitations(cb)
    exports.postgres:queryAll(
        [[SELECT c.*, sus.first_name, sus.last_name
          FROM police_citations c
          JOIN characters sus ON sus.id = c.suspect_id
          ORDER BY c.issued_at DESC LIMIT 100]],
        {},
        function(rows) cb(rows or {}) end
    )
end

function MDTDatabase.markCitationPaid(citationId, cb)
    exports.postgres:query(
        'UPDATE police_citations SET is_paid=TRUE, paid_at=NOW() WHERE id=$1 AND is_paid=FALSE RETURNING id',
        { citationId },
        function(rows)
            cb(rows and rows[1] ~= nil)
        end
    )
end

function MDTDatabase.createBOLO(officerId, subjectName, description, vehicleInfo, cb)
    exports.postgres:query(
        'INSERT INTO police_bolos (officer_id, subject_name, description, vehicle_info) VALUES ($1,$2,$3,$4) RETURNING *',
        { officerId, subjectName, description, vehicleInfo ~= '' and vehicleInfo or nil },
        function(rows)
            cb(rows and rows[1] or nil)
        end
    )
end

function MDTDatabase.getActiveBOLOs(cb)
    exports.postgres:queryAll(
        'SELECT * FROM police_bolos WHERE is_active=TRUE ORDER BY created_at DESC',
        {},
        function(rows) cb(rows or {}) end
    )
end

function MDTDatabase.closeBOLO(boloId, officerId, cb)
    exports.postgres:query(
        'UPDATE police_bolos SET is_active=FALSE, closed_at=NOW(), closed_by=$2 WHERE id=$1',
        { boloId, officerId },
        function() cb() end
    )
end

function MDTDatabase.createIncident(officerId, title, description, involvedJson, cb)
    exports.postgres:query(
        'INSERT INTO police_incidents (officer_id, title, description, involved_characters) VALUES ($1,$2,$3,$4::jsonb) RETURNING *',
        { officerId, title, description, involvedJson },
        function(rows)
            cb(rows and rows[1] or nil)
        end
    )
end

function MDTDatabase.getIncidents(cb)
    exports.postgres:queryAll(
        'SELECT * FROM police_incidents ORDER BY created_at DESC LIMIT 50',
        {},
        function(rows) cb(rows or {}) end
    )
end

function MDTDatabase.createImpound(officerId, plate, model, reason, fee, cb)
    exports.postgres:query(
        'INSERT INTO police_impounds (officer_id, plate, model, reason, fee) VALUES ($1,$2,$3,$4,$5) RETURNING *',
        { officerId, plate, model ~= '' and model or nil, reason, fee },
        function(rows)
            cb(rows and rows[1] or nil)
        end
    )
end

function MDTDatabase.getImpounds(cb)
    exports.postgres:queryAll(
        'SELECT * FROM police_impounds ORDER BY impounded_at DESC LIMIT 100',
        {},
        function(rows) cb(rows or {}) end
    )
end

function MDTDatabase.retrieveImpound(impoundId, cb)
    exports.postgres:query(
        'UPDATE police_impounds SET is_retrieved=TRUE, retrieved_at=NOW() WHERE id=$1',
        { impoundId },
        function() cb() end
    )
end

function MDTDatabase.getCriminalHistory(characterId, cb)
    local result = { jails = {}, warrants = {}, citations = {} }
    local pending = 3

    local function done()
        pending = pending - 1
        if pending == 0 then cb(result) end
    end

    exports.postgres:queryAll(
        'SELECT * FROM police_jail_sentences WHERE character_id=$1 ORDER BY arrested_at DESC LIMIT 20',
        { characterId },
        function(rows) result.jails = rows or {}; done() end
    )

    exports.postgres:queryAll(
        'SELECT * FROM police_warrants WHERE character_id=$1 ORDER BY issued_at DESC LIMIT 20',
        { characterId },
        function(rows) result.warrants = rows or {}; done() end
    )

    exports.postgres:queryAll(
        'SELECT * FROM police_citations WHERE suspect_id=$1 ORDER BY issued_at DESC LIMIT 20',
        { characterId },
        function(rows) result.citations = rows or {}; done() end
    )
end
