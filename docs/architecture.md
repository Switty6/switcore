# Arhitectura SwitCore

## Diagrama dependențelor

```
postgres ──────────────────────────────────────────────────────────────┐
    │                                                                    │
settings ────────────────────────────────────────────────────────────┐  │
    │                                                                 │  │
core ◄──────────────────────────────────────────────────────────────┘  │
    │                                                                    │
characters ◄────────────────────────────────────────────────────────┐  │
    │                                                                │  │
    ├──► banking ◄───────────────────────────────────────────────┐  │  │
    │        │                                                    │  │  │
    ├──► inventory ◄──────────────────────────────────────────┐  │  │  │
    │        │                                                │  │  │  │
    └──► jobs ────────────────────────────────────────────┐   │  │  │  │
              │                                           │   │  │  │  │
              ├──► police                                 │   │  │  │  │
              ├──► ems       (deps: medical)              │   │  │  │  │
              ├──► mecanic                                │   │  │  │  │
              ├──► taxi                                   │   │  │  │  │
              └──► garbage                                │   │  │  │  │
                                                          │   │  │  │  │
vehicles ◄────────────────────────────────────────────────┘   │  │  │  │
    │        (deps și: inventory, banking, notifications)      │  │  │  │
    ├──► garages                                               │  │  │  │
    ├──► showroom ◄────────────────────────────────────────────┘  │  │  │
    │        (deps și: interiors)                                  │  │  │
    └──► tuning                                                     │  │  │
                                                                    │  │  │
clothing  ◄─── deps: characters, inventory, banking, proximity      │  │  │
shops     ◄─── deps: characters, inventory, banking, proximity      │  │  │
government ◄── deps: characters, banking, notifications             │  │  │
medical   ◄─── deps: characters, inventory, notifications           │  │  │
admin     ◄─── deps: core, banking, characters, notifications       │  │  │
mdt       ◄─── deps: jobs, police, ems, banking                     │  │  │
                                                                    │  │  │
proximity ─────────────────────────────────────────────────────────┘  │  │
notifications ────────────────────────────────────────────────────────┘  │
blips     ◄─── deps: settings, banking                                   │
interiors ← independent (client-only)                                     │
hud       ◄─── deps: core, characters, banking, settings                  │
needs     ◄─── deps: characters, inventory, notifications                 │
welcome   ◄─── deps: core, notifications                                  │
loadscreen ← independent                                                  │
intro     ◄─── deps: core                                                 │
settings-panel ← independent (Node.js)                                    │
```

> **Auto-discovery la pornire:** FXServer rezolvă automat ordinea de pornire pe baza câmpului `dependencies` din `fxmanifest.lua`. Comanda `ensure [switcore]` din `server.cfg` pornește toate modulele în ordinea corectă fără să fie nevoie să le enumeri individual.

---

## Layer shared (`Sw`) & Secure Events

`core` expune o bibliotecă shared și un framework de net events sigure, folosite de orice modul prin includere `@core/...` în manifest. Detalii complete în [`docs/modules/lib.md`](modules/lib.md).

- **`Sw`** (`core/shared/lib.lua`) - utilitare pure (string, numeric, table, format bani) plus motorul de validare `Sw.ValidateArgs`. Shared client + server, zero stare.
- **`Sw.SecureEvent`** (`core/server/secure.lua`) - înlocuiește boilerplate-ul repetat din handlerele de server (rate-limit, permisiune, fetch personaj, validare argumente, notificare la eroare) cu o singură declarație și un `ctx` curat.
- **Rate limiter** (`core/server/ratelimit.lua`) - fereastră glisantă per `(source, cheie)`, expus ca `exports.core:checkRateLimit`, curățat la `playerDropped`.

Un modul adoptă layerul adăugând în manifest:
```lua
shared_scripts { '@core/shared/lib.lua', 'config.lua' }
server_scripts { '@core/server/secure.lua', ... }
```
Adopția e incrementală - modulele care nu includ aceste fișiere funcționează neschimbat.

---

## Player Lifecycle

### 1. Connect (`playerConnecting`)
```
GetPlayerIdentifiers(source)
    → filtrează blocklist (IP ignorat)
    → verifică ban activ → kick dacă ban
    → findOrCreatePlayer():
        - caută în PlayerCache după identifier
        - caută în DB (postgres) după identifier
        - merge identifiers dacă player găsit
        - crează player nou dacă nu există
    → loadGroups + loadPermissions din DB
    → loadLanguage (DB sau settings default)
    → TriggerClientEvent('switcore:localeData', ...)
    → TriggerClientEvent('switcore:languageChanged', ...)
    → PlaytimeTracker.startTracking(source)
    → logActivity('join')
```

### 2. Reconnect (`playerJoining` cu oldId)
```
PlayerCache.getFromCache(source) - dacă există deja, skip
PlayerCache.getFromCache(oldId)  - transfer de la old source
    → PlaytimeTracker.stopTracking(oldId) → savePartialPlaytime
    → PlayerCache.setInCache(source, oldPlayerData)
    → PlayerCache.removeFromCache(oldId)
    → PlaytimeTracker.startTracking(source)
```

### 3. Heartbeat (la fiecare secundă)
```lua
-- Emite evenimentul pentru toți jucătorii online
TriggerEvent('switcore:playerLoaded', source, dbId, playerData)
-- Folosit de alte resurse pentru a verifica dacă playerul e "gata"
```

### 4. Disconnect (`playerDropped`)
```
PlaytimeTracker.stopTracking(source) → savePlaytime în DB
updatePlayerLastSeen(dbId)
logActivity('quit', {reason})
PlayerCache.removeFromCache(source)
```

---

## Player Cache

Fișier: `[switcore]/core/server/player_cache.lua`

```lua
-- Structura în memorie
players[source] = {
    dbId        = number,
    name        = string,
    identifiers = string[],   -- ["steam:xxx", "discord:xxx", ...]
    last_seen   = timestamp,
    playtime    = seconds,
    join_time   = timestamp,
    groups      = table[],    -- grupuri active cu expiry
    permissions = string[],   -- permissions aplatizate din grupuri
    language    = string      -- 'ro', 'en', ...
}

playerById[dbId]              = source    -- lookup rapid după DB ID
identifierCache[identifier]   = dbId      -- lookup rapid după identifier
```

**Funcții cheie:**
```lua
PlayerCache.getFromCache(source)          → playerData
PlayerCache.setInCache(source, data)
PlayerCache.updateInCache(source, patch)  -- merge parțial
PlayerCache.removeFromCache(source)
PlayerCache.getSourceById(dbId)           → source
PlayerCache.getDbIdByIdentifier(id)       → dbId
PlayerCache.hasIdentifier(identifier)     → bool
```

---

## Permission & Groups System

### Ierarhie
```
Player → are grupuri (cu expiry opțional)
Grup   → are permissions
```

### Tabele DB (`core/schema.sql`)
```sql
groups            (id, name, display_name, priority, description)
permissions       (id, name, description)
group_permissions (group_id, permission_id)         -- many-to-many
player_groups     (player_id, group_id, assigned_at, assigned_by, expires_at)
```

### Verificare permisiuni
```lua
-- Permisiunile sunt caching-uite în player cache (string array aplatizat)
exports.core:hasPermission(source, 'admin.kick')  → bool
exports.core:hasGroup(source, 'admin')            → bool
exports.core:getPlayerPermissions(source)         → string[]
exports.core:getPlayerGroups(source)              → table[]

-- Reload după modificare grup
exports.core:reloadPlayerPermissions(source)
```

### Exemple permisiuni folosite
- `admin.kick`, `admin.ban`, `admin.warn`
- `job.police.management`, `job.police.roster`
- `vip` - verificat de showroom și tuning pentru acces VIP

---

## Settings System (Key-Value DB)

Toate setările serverului sunt în tabela `settings`:
```sql
settings (key VARCHAR UNIQUE, value TEXT, description TEXT)
```

**Pattern seed la init modul:**
```lua
exports.postgres:query(
    'INSERT INTO settings (key, value, description) VALUES ($1, $2, $3) ON CONFLICT (key) DO NOTHING',
    { 'modul.cheie', 'valoare_implicita', 'Descriere' }
)
```

**Setări globale cunoscute:**
| Cheie | Implicit | Descriere |
|-------|---------|-----------|
| `core.playtime_update_interval` | `60` | Secunde între update-uri playtime |
| `core.default_language` | `'ro'` | Limbă implicită server |
| `jobs.salary_interval` | `1800000` | ms între plăți salarii (30 min) |
| `vehicles.default_fuel` | `100` | Combustibil implicit vehicul nou |
| `vehicles.fuel_consumption_rate` | `0.02` | % combustibil/secundă |
| `vehicles.fuel_tick_interval` | `5000` | ms tick consum combustibil |
| `vehicles.save_interval` | `30000` | ms auto-save stare vehicule |
| `vehicles.impound_fee_per_day` | `500` | Taxă sechestru/zi |
| `vehicles.enable_fuel_system` | `true` | Activează sistemul de combustibil |
| `vehicles.enable_mileage` | `true` | Activează mileage tracking |
| `garages.impound_release_fee` | `2500` | Taxă eliberare sechestru |
| `garages.parking_ticket_base_fine` | `500` | Amendă de bază parcare |
| `garages.max_tickets_before_impound` | `3` | Amenzi maxime înainte de sechestru |
| `showroom.test_drive_duration_minutes` | `5` | Durată test drive (minute) |
| `tuning.reset_mods_cost` | `1500` | Cost resetare modificări |
| `tuning.vip_discount` | `0.15` | Reducere VIP la tuning |

---

## Schema DB principală

### Core (`[switcore]/core/schema.sql`)
```sql
players (id, name, created_at, updated_at, last_seen, playtime, language)
player_identifiers (id, player_id, type, value)
player_activity_log (id, player_id, event_type, command, metadata, created_at)
groups (id, name, display_name, priority, description)
permissions (id, name, description)
group_permissions (group_id, permission_id)
player_groups (player_id, group_id, assigned_at, assigned_by, expires_at)
bans (id, player_id, banned_by, reason, expires_at, is_active, unbanned_by, unbanned_reason)
warns (id, player_id, warned_by, reason, is_active, removed_by, removed_reason)
kick_logs (id, player_id, kicked_by, reason, metadata)
```

### Characters (`[switcore]/characters/schema.sql`)
```sql
characters (id, player_id, firstname, lastname, birthdate, gender, ...)
character_stats (character_id, stat_name, stat_value)
```

### Banking (`[switcore]/banking/schema.sql`)
```sql
currencies (id, code, name, symbol, exchange_rate)
banks (id, code, name, type)
bank_accounts (id, character_id, bank_id, currency_id, account_number, balance, type)
transactions (id, from_account_id, to_account_id, amount, currency_id, description, created_at)
loans (id, character_id, bank_id, amount, remaining, term_months, monthly_payment, type, status)
org_accounts (id, org_id, bank_id, currency_id, balance)
```

### Inventory (`[switcore]/inventory/schema.sql`)
```sql
items (id, name, label, description, weight, stackable, usable, image)
character_inventory (id, character_id, item_id, quantity, metadata)
```

### Jobs (`[switcore]/jobs/schema.sql`)
```sql
jobs (id, name, label, type)    -- type: 'whitelisted', 'self-serve', 'faction'
job_grades (id, job_id, grade, label, salary, permissions)
character_jobs (character_id, job_id, grade_id, on_duty, clocked_in_at)
```

### Vehicles (`[switcore]/vehicles/schema.sql`)
```sql
owned_vehicles (id, character_id, plate, model, label, category,
                fuel, mileage, body_health, engine_health,
                modifications JSONB, stored, impounded, last_position JSONB,
                purchased_at, updated_at)
vehicle_keys (id, vehicle_id, character_id, key_type, given_at)
--   key_type: 'owner' | 'standard' | 'valet'
```

### Garages (`[switcore]/garages/schema.sql`)
```sql
garages (id, name, code, type, coords JSONB, spawn_point JSONB, is_active)
--  type: 'public' | 'private' | 'impound' | 'vip'
garage_logs (id, vehicle_id, character_id, garage_id, action, fuel_at_action, created_at)
--  action: 'parked' | 'retrieved'
parking_tickets (id, character_id, vehicle_id, plate, fine_amount, reason, paid, issued_by, issued_at, paid_at)
```

### Showroom (`[switcore]/showroom/schema.sql`)
```sql
dealerships (id, name, code, coords JSONB, npc_model, is_active)
vehicle_catalog (id, dealership_id, model, label, category, price,
                 finance_eligible, vip_only, sort_order, is_active)
vehicle_purchases (id, character_id, catalog_id, vehicle_id, price_paid,
                   payment_method, loan_id, purchased_at)
--  payment_method: 'cash' | 'bank' | 'finance'
test_drives (id, character_id, catalog_id, plate, started_at, expires_at, returned)
```

### Tuning (`[switcore]/tuning/schema.sql`)
```sql
tuning_shops (id, name, code, coords JSONB, is_active)
tuning_prices (id, category, tier, price, vip_only)
tuning_logs (id, character_id, vehicle_id, shop_id, category, tier_before, tier_after, price_paid, applied_at)
```

---

## Ordinea `ensure` în server.cfg

### Varianta simplă (recomandat)

```
# Sistem
ensure baseevents
ensure sessionmanager
ensure hardcap

# Build tools (pentru resurse Node.js)
ensure yarn
ensure webpack

# Managers
ensure mapmanager
ensure spawnmanager

# Tot framework-ul intr-un singur ensure - FXServer rezolva ordinea
ensure [switcore]

# Gameplay general
ensure chat
ensure playernames
ensure basic-gamemode
```

### Varianta cu ensure-uri individuale (debug)

Folosește această variantă doar când vrei să pornești module selective sau să debugezi probleme de încărcare:

```
ensure postgres        # MUST BE FIRST
ensure player-data
ensure settings
ensure core
ensure characters
ensure loadscreen
ensure intro
ensure proximity
ensure notifications
ensure inventory
ensure banking
ensure needs
ensure hud
ensure welcome
ensure interiors
ensure vehicles
ensure garages
ensure showroom
ensure tuning
ensure blips
ensure jobs
ensure police
ensure ems
ensure mecanic
ensure medical
ensure taxi
ensure garbage
ensure clothing
ensure shops
ensure government
ensure admin
ensure mdt
ensure settings-panel
```

---

## Migrațiile de schemă

Sistemul de migrații (hash-based) e descris în [`docs/migrations.md`](migrations.md). Pe scurt:

- Modulul `postgres` aplică automat fiecare `schema.sql` la pornire în ordinea dependențelor
- Hash-ul fiecărei scheme e salvat în tabela `_schema_migrations`
- Dacă conținutul `schema.sql` se schimbă, hash-ul diferă și schema se reaplică
- Convenția pentru modificări: folosește `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...` în schema.sql, nu fișiere de migrație separate
