
JobsDatabase = {}

local function pg()
    return exports.postgres
end

local function ensurePg()
    local p = pg()
    if not p or not p:isReady() then
        error('[JOBS] Postgres nu este disponibil!')
    end
    return true
end

function JobsDatabase.getJob(jobName)
    if not ensurePg() then return nil end
    return pg():queryOne('SELECT * FROM jobs WHERE name = $1', { jobName })
end

function JobsDatabase.getAllJobs()
    if not ensurePg() then return {} end
    return pg():queryAll('SELECT * FROM jobs WHERE is_active = TRUE ORDER BY name ASC', {})
end

function JobsDatabase.getJobGrades(jobName)
    if not ensurePg() then return {} end
    return pg():queryAll(
        'SELECT * FROM job_grades WHERE job_name = $1 ORDER BY grade ASC',
        { jobName }
    )
end

function JobsDatabase.getGrade(jobName, grade)
    if not ensurePg() then return nil end
    return pg():queryOne(
        'SELECT * FROM job_grades WHERE job_name = $1 AND grade = $2',
        { jobName, grade }
    )
end

function JobsDatabase.getCharacterJob(characterId)
    if not ensurePg() then return nil end
    return pg():queryOne([[
        SELECT cj.*,
               j.label      AS job_label,
               j.type       AS job_type,
               j.blip_sprite, j.blip_color, j.blip_coords,
               jg.label     AS grade_label,
               jg.salary,
               jg.can_manage,
               jg.permissions
        FROM character_jobs cj
        JOIN jobs       j  ON j.name      = cj.job_name
        JOIN job_grades jg ON jg.job_name = cj.job_name AND jg.grade = cj.grade
        WHERE cj.character_id = $1
    ]], { characterId })
end

function JobsDatabase.upsertCharacterJob(characterId, jobName, grade)
    if not ensurePg() then return end
    pg():query([[
        INSERT INTO character_jobs (character_id, job_name, grade, is_on_duty, hired_at)
        VALUES ($1, $2, $3, FALSE, NOW())
        ON CONFLICT (character_id) DO UPDATE
            SET job_name   = EXCLUDED.job_name,
                grade      = EXCLUDED.grade,
                is_on_duty = FALSE,
                hired_at   = NOW()
    ]], { characterId, jobName, grade })
end

function JobsDatabase.setGrade(characterId, grade)
    if not ensurePg() then return end
    pg():query(
        'UPDATE character_jobs SET grade = $1 WHERE character_id = $2',
        { grade, characterId }
    )
end

function JobsDatabase.setDuty(characterId, onDuty)
    if not ensurePg() then return end
    pg():query(
        'UPDATE character_jobs SET is_on_duty = $1 WHERE character_id = $2',
        { onDuty, characterId }
    )
end

function JobsDatabase.atomicClockIn(characterId, jobName)
    if not ensurePg() then return false end
    local row = pg():queryOne([[
        WITH duty AS (
            UPDATE character_jobs SET is_on_duty = TRUE
            WHERE character_id = $1 AND is_on_duty = FALSE
            RETURNING character_id
        )
        INSERT INTO job_duty_logs (character_id, job_name, clocked_in)
        SELECT $1, $2, NOW() FROM duty
        RETURNING id
    ]], { characterId, jobName })
    return row ~= nil
end

function JobsDatabase.atomicClockOut(characterId)
    if not ensurePg() then return false end
    local row = pg():queryOne([[
        WITH duty AS (
            UPDATE character_jobs SET is_on_duty = FALSE
            WHERE character_id = $1 AND is_on_duty = TRUE
            RETURNING character_id
        ),
        last_log AS (
            SELECT id FROM job_duty_logs
            WHERE character_id = $1 AND clocked_out IS NULL
            ORDER BY id DESC LIMIT 1
        )
        UPDATE job_duty_logs SET clocked_out = NOW()
        WHERE id IN (SELECT id FROM last_log) AND EXISTS (SELECT 1 FROM duty)
        RETURNING id
    ]], { characterId })
    return row ~= nil or pg():queryOne('SELECT character_id FROM character_jobs WHERE character_id = $1 AND is_on_duty = FALSE', { characterId }) ~= nil
end

function JobsDatabase.ensureDefaultJob(characterId)
    local existing = JobsDatabase.getCharacterJob(characterId)
    if not existing then
        local defaultJob   = exports.settings:GetSetting('jobs.default_job', 'unemployed')
        local defaultGrade = exports.settings:GetSettingNumber('jobs.default_grade', 0)
        JobsDatabase.upsertCharacterJob(characterId, defaultJob, defaultGrade)
        return JobsDatabase.getCharacterJob(characterId)
    end
    return existing
end

function JobsDatabase.logClockIn(characterId, jobName)
    if not ensurePg() then return end
    pg():query(
        'INSERT INTO job_duty_logs (character_id, job_name, clocked_in) VALUES ($1, $2, NOW())',
        { characterId, jobName }
    )
end

function JobsDatabase.logClockOut(characterId)
    if not ensurePg() then return end
    pg():query([[
        UPDATE job_duty_logs SET clocked_out = NOW()
        WHERE id = (
            SELECT id FROM job_duty_logs
            WHERE character_id = $1 AND clocked_out IS NULL
            ORDER BY id DESC LIMIT 1
        )
    ]], { characterId })
end

function JobsDatabase.getRoster(jobName)
    if not ensurePg() then return {} end
    return pg():queryAll([[
        SELECT c.id, c.first_name, c.last_name,
               cj.grade, cj.is_on_duty, cj.hired_at,
               jg.label AS grade_label, jg.can_manage
        FROM character_jobs cj
        JOIN characters c  ON c.id        = cj.character_id
        JOIN job_grades jg ON jg.job_name = cj.job_name AND jg.grade = cj.grade
        WHERE cj.job_name = $1
        ORDER BY cj.grade DESC, c.last_name ASC
    ]], { jobName })
end

function JobsDatabase.getOnDutyRoster(jobName)
    if not ensurePg() then return {} end
    return pg():queryAll([[
        SELECT c.id, c.first_name, c.last_name,
               cj.grade, jg.label AS grade_label
        FROM character_jobs cj
        JOIN characters c  ON c.id        = cj.character_id
        JOIN job_grades jg ON jg.job_name = cj.job_name AND jg.grade = cj.grade
        WHERE cj.job_name = $1 AND cj.is_on_duty = TRUE
        ORDER BY cj.grade DESC
    ]], { jobName })
end

function JobsDatabase.ensureSalarySchema()
    if not ensurePg() then return end
    pg():query([[
        ALTER TABLE character_jobs
        ADD COLUMN IF NOT EXISTS last_salary_at TIMESTAMPTZ
    ]], {})
end

function JobsDatabase.claimSalaryBatch(intervalSecs)
    if not ensurePg() then return {} end
    return pg():queryAll([[
        UPDATE character_jobs cj
        SET last_salary_at = NOW()
        FROM jobs j, job_grades jg, characters c
        WHERE cj.character_id = c.id
          AND j.name      = cj.job_name
          AND jg.job_name = cj.job_name AND jg.grade = cj.grade
          AND cj.is_on_duty = TRUE
          AND j.type        = 'whitelisted'
          AND jg.salary     > 0
          AND (cj.last_salary_at IS NULL OR cj.last_salary_at < NOW() - ($1::int * INTERVAL '1 second'))
        RETURNING cj.character_id   AS character_id,
                  cj.job_name       AS job_name,
                  jg.salary         AS salary,
                  jg.label          AS grade_label,
                  j.label           AS job_label,
                  c.first_name      AS first_name,
                  c.last_name       AS last_name
    ]], { intervalSecs })
end
