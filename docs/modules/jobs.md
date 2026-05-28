# Modul: jobs

**Locație:** `[switcore]/jobs/`
**Dependențe:** `core`, `postgres`, `characters`, `banking`, `notifications`, `proximity`, `settings`, `blips`

## Fișiere server

| Fișier | Rol |
|--------|-----|
| `server/database.lua` | CRUD jobs, grades, character_jobs |
| `server/server.lua` | Init, salary loop, exports, event handlers |
| `server/callbacks.lua` | RegisterNetEvent pentru clock-in/out, assign |

---

## Exports (server-side)

```lua
exports.jobs:GetCharacterJob(characterId)             → job{name, label, grade, grade_label, salary, on_duty}
exports.jobs:SetCharacterJob(characterId, jobName, grade) → bool
exports.jobs:SetCharacterGrade(characterId, grade)    → bool
exports.jobs:HasJobPermission(characterId, permission) → bool
exports.jobs:GetJobRoster(jobName)                    → roster[]
exports.jobs:IsJobManager(characterId, jobName)       → bool
```

---

## Events (NetEvents)

```lua
RegisterNetEvent('jobs:server:getMyJob')          -- client cere jobul său
RegisterNetEvent('jobs:server:clockIn')           -- intră în serviciu
RegisterNetEvent('jobs:server:clockOut')          -- iese din serviciu
RegisterNetEvent('jobs:server:adminAssign', targetSrc, jobName, grade)  -- admin assign
RegisterNetEvent('jobs:server:manageGrade', targetCharId, newGrade)      -- manager schimbă grad
RegisterNetEvent('jobs:server:getRoster', jobName)                        -- get roster
```

---

## Salary System

```lua
-- Background loop care rulează la fiecare `jobs.salary_interval` ms (default 30 min)
-- Plătește în cash toți jucătorii on_duty din toate joburile
PaySalaries()
-- Folosește: exports.banking:addCharacterCash(characterId, salary, currencyCode)
```

---

## Tipuri de joburi

| Tip | Descriere |
|-----|-----------|
| `whitelisted` | Require assign manual de admin/manager |
| `self-serve` | Jucătorul se poate angaja singur |
| `faction` | Bazat pe grupuri/organizații (police, ems) |

---

## Schema DB

```sql
jobs (
    id      SERIAL PRIMARY KEY,
    name    VARCHAR(50) UNIQUE,
    label   VARCHAR(100),
    type    VARCHAR(20)  -- 'whitelisted', 'self-serve', 'faction'
)

job_grades (
    id          SERIAL PRIMARY KEY,
    job_id      INTEGER REFERENCES jobs(id) ON DELETE CASCADE,
    grade       INTEGER,
    label       VARCHAR(100),
    salary      NUMERIC(12,2),
    permissions JSONB DEFAULT '[]'  -- array de permisiuni specifice jobului
)

character_jobs (
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    job_id       INTEGER REFERENCES jobs(id),
    grade_id     INTEGER REFERENCES job_grades(id),
    on_duty      BOOLEAN DEFAULT false,
    clocked_in_at TIMESTAMP,
    PRIMARY KEY (character_id)
)
```

---

## Integrare în alte resurse

```lua
-- Verificare job în police/ems/mecanic
local job = exports.jobs:GetCharacterJob(characterId)
if not job or job.name ~= 'police' then return end

-- Verificare on_duty
if not job.on_duty then
    TriggerClientEvent('switcore:notify', source, 'error', 'Nu ești în serviciu', 5000)
    return
end

-- Verificare permisiune specifică jobului
if not exports.jobs:HasJobPermission(characterId, 'management') then return end
```

---

## Settings folosite

| Cheie | Implicit | Descriere |
|-------|---------|-----------|
| `jobs.salary_interval` | `1800000` | ms între plăți salarii (30 min) |
| `jobs.default_currency` | `'USD'` | Valuta pentru salarii |
