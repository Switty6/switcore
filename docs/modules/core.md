# Modul: core

**Locație:** `[switcore]/core/`
**Dependențe:** `postgres`, `settings`
**Game:** `common` (rulează și server-side fără client GTA)

## Fișiere server

| Fișier | Rol |
|--------|-----|
| `server/player_cache.lua` | Cache în memorie pentru toți jucătorii online |
| `server/database.lua` | CRUD PostgreSQL (players, identifiers, groups, bans, warns) |
| `server/playtime.lua` | Tracking timp online per jucător |
| `server/groups.lua` | CRUD grupuri + inițializare defaults |
| `server/permissions.lua` | Verificare + reload permissions din cache |
| `server/moderation.lua` | Ban, warn, kick logic |
| `server/commands.lua` | Comenzi admin (`/ban`, `/warn`, `/kick`, etc.) |
| `server/localization.lua` | Sistem i18n server-side |
| `server/server.lua` | Init, player lifecycle events, exports |

## Fișiere client

| Fișier | Rol |
|--------|-----|
| `client/localization.lua` | Cache locale pe client |
| `client/language.lua` | Setare limbă + event handlers |
| `client/npc_management.lua` | Șterge/ascunde NPC-uri default GTA |

---

## Exports (server-side)

### Player Data
```lua
exports.core:getPlayerId(source)                  → dbId (number)
exports.core:getPlayerById(dbId)                  → playerData
exports.core:getPlayerIdFromIdentifier(identifier) → dbId
exports.core:getPlayerIdentifiers(dbId)            → string[]
exports.core:getPlayerData(source)                 → playerData
exports.core:logPlayerActivity(source, eventType, metadata) → bool
exports.core:updatePlayerPlaytime(source, seconds) → bool
exports.core:setPlayerLanguage(source, language)   → bool, err
exports.core:getPlayerLanguage(source)             → string
```

### Permissions & Groups
```lua
exports.core:hasPermission(source, 'perm.name')   → bool
exports.core:hasGroup(source, 'groupName')         → bool
exports.core:getPlayerPermissions(source)          → string[]
exports.core:getPlayerGroups(source)               → table[]
exports.core:reloadPlayerPermissions(source)       → bool
exports.core:addPlayerGroup(source, name, expiresAt, assignedBy) → bool
exports.core:removePlayerGroup(source, name)       → bool
exports.core:createGroup(name, displayName, priority, desc) → group
exports.core:deleteGroup(name)                     → bool
exports.core:updateGroup(name, displayName, priority, desc) → bool
exports.core:getAllGroups()                        → table[]
exports.core:getAllPermissions()                   → table[]
exports.core:deletePermission(name)               → bool
exports.core:removePermissionFromGroup(groupName, permName) → bool
```

### Moderation
```lua
exports.core:banPlayerBySource(source, by, reason, duration)  → bool
exports.core:banPlayerByDbId(dbId, by, reason, duration)      → bool
exports.core:unbanPlayer(target, by, reason)                  → bool
exports.core:unbanPlayerByDbId(dbId, by, reason)              → bool
exports.core:warnPlayer(target, by, reason)                   → bool
exports.core:warnPlayerBySource(source, by, reason)           → bool
exports.core:warnPlayerByDbId(dbId, by, reason)               → bool
exports.core:removeWarn(warnId, by, reason)                   → bool
exports.core:kickPlayer(target, by, reason)                   → bool
exports.core:kickPlayerBySource(source, by, reason)           → bool
exports.core:isPlayerBanned(target)                           → bool
exports.core:isPlayerBannedByDbId(dbId)                       → bool
exports.core:getPlayerBans(target, includeInactive)           → bans[]
exports.core:getPlayerBansByDbId(dbId, includeInactive)       → bans[]
exports.core:getPlayerWarns(target, includeInactive)          → warns[]
exports.core:getPlayerWarnsByDbId(dbId, includeInactive)      → warns[]
```

---

## Events

### Server → Client
```lua
TriggerClientEvent('switcore:localeData', source, language, locale)
TriggerClientEvent('switcore:languageChanged', source, language)
TriggerClientEvent('switcore:localizedMessage', source, message)
TriggerClientEvent('switcore:languageError', source, error)
```

### Client → Server (NetEvents)
```lua
RegisterNetEvent('switcore:setLanguage', language)
RegisterNetEvent('switcore:getLocalizedMessage', key, ...)
RegisterNetEvent('switcore:requestLocale', language)
```

### Server → Server (internal heartbeat)
```lua
-- Emis la fiecare 1000ms pentru fiecare jucător online
TriggerEvent('switcore:playerLoaded', source, dbId, playerData)
```

---

## Structura playerData (din cache)

```lua
{
    dbId        = 42,
    name        = "Mihai",
    identifiers = { "steam:110000...", "discord:123...", "license:abc..." },
    last_seen   = 1714123456,  -- os.time()
    playtime    = 3600,        -- secunde totale
    join_time   = 1714120000,
    groups      = { { id=1, name="admin", priority=100, expires_at=nil }, ... },
    permissions = { "admin.kick", "admin.ban", "core.moderation" },
    language    = "ro"
}
```

---

## Schema DB

```sql
players (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(100),
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP,
    last_seen   TIMESTAMP,
    playtime    INTEGER DEFAULT 0,
    language    VARCHAR(10) DEFAULT 'ro'
)

player_identifiers (
    id          BIGSERIAL PRIMARY KEY,
    player_id   BIGINT REFERENCES players(id),
    type        VARCHAR(30),   -- 'steam', 'discord', 'license', etc.
    value       VARCHAR(200)
)

player_activity_log (
    id          BIGSERIAL PRIMARY KEY,
    player_id   BIGINT REFERENCES players(id),
    event_type  VARCHAR(50),   -- 'join', 'quit', 'ban', 'warn', 'kick'
    command     VARCHAR(200),
    metadata    JSONB,
    created_at  TIMESTAMP DEFAULT NOW()
)

groups (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(50) UNIQUE,
    display_name VARCHAR(100),
    priority     INTEGER DEFAULT 0,
    description  TEXT
)

permissions (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) UNIQUE,
    description TEXT
)

group_permissions (
    group_id      INTEGER REFERENCES groups(id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, permission_id)
)

player_groups (
    player_id   BIGINT REFERENCES players(id) ON DELETE CASCADE,
    group_id    INTEGER REFERENCES groups(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT NOW(),
    assigned_by BIGINT REFERENCES players(id),
    expires_at  TIMESTAMP  -- NULL = permanent
)

bans (
    id              BIGSERIAL PRIMARY KEY,
    player_id       BIGINT REFERENCES players(id),
    banned_by       BIGINT REFERENCES players(id),
    reason          TEXT,
    expires_at      TIMESTAMP,  -- NULL = permanent
    is_active       BOOLEAN DEFAULT true,
    unbanned_by     BIGINT REFERENCES players(id),
    unbanned_reason TEXT
)

warns (
    id              BIGSERIAL PRIMARY KEY,
    player_id       BIGINT REFERENCES players(id),
    warned_by       BIGINT REFERENCES players(id),
    reason          TEXT,
    is_active       BOOLEAN DEFAULT true,
    removed_by      BIGINT REFERENCES players(id),
    removed_reason  TEXT
)

kick_logs (
    id          BIGSERIAL PRIMARY KEY,
    player_id   BIGINT REFERENCES players(id),
    kicked_by   BIGINT REFERENCES players(id),
    reason      TEXT,
    metadata    JSONB,
    created_at  TIMESTAMP DEFAULT NOW()
)
```

---

## Background tasks

```lua
-- La fiecare 1s: heartbeat playerLoaded per player online
-- La fiecare 60s: dezactivare ban-uri expirate automat
```

---

## Localizare

Locale sunt în `[switcore]/core/locales/`.
- Server trimite locale la connect: `TriggerClientEvent('switcore:localeData', ...)`
- Client cachează locale și le accesează via `Localize(key, ...)`
- Schimbare limbă: `RegisterNetEvent('switcore:setLanguage', language)`
