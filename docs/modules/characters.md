# Modul: characters

**Locație:** `[switcore]/characters/`
**Dependențe:** `core`, `postgres`, `settings`

## Fișiere server

| Fișier | Rol |
|--------|-----|
| `server/database.lua` | CRUD characters + stats în PostgreSQL |
| `server/character_cache.lua` | Cache in-memory personaje active per source |
| `server/character_manager.lua` | Logică creare, selecție, ștergere personaj |
| `server/server.lua` | Init, exports, callbacks |

## Fișiere client

| Fișier | Rol |
|--------|-----|
| `client/character_selection.lua` | Flow selecție/creare personaj (NUI) |
| `client/client.lua` | State management personaj activ pe client |

---

## Exports (server-side)

```lua
exports.characters:getCharacter(source)              → character (indiferent activ sau nu)
exports.characters:getActiveCharacter(source)        → character (doar dacă e selectat)
exports.characters:getCharacterId(source)            → characterId (number)
exports.characters:getCharacterData(source)          → characterData (tabel complet)
exports.characters:updateCharacterPosition(source, pos) → bool
exports.characters:updateCharacterStat(source, statName, value) → bool
exports.characters:incrementCharacterStat(source, statName, amount) → bool
exports.characters:getCharacterStatistics(source)   → statistics (tabel stats)
```

### Rezolvare character ID (pattern standard)
```lua
local character = exports.characters:getActiveCharacter(source)
if not character then return end
local characterId = character.id
```

---

## Structura character

```lua
{
    id          = 1,           -- character_id în DB
    player_id   = 42,          -- players.id (core)
    firstname   = "Ion",
    lastname    = "Popescu",
    birthdate   = "1990-05-15",
    gender      = "male",       -- 'male' / 'female'
    -- ... alte câmpuri din DB
}
```

---

## Schema DB

```sql
characters (
    id          SERIAL PRIMARY KEY,
    player_id   BIGINT REFERENCES players(id) ON DELETE CASCADE,
    firstname   VARCHAR(50),
    lastname    VARCHAR(50),
    birthdate   DATE,
    gender      VARCHAR(10),
    created_at  TIMESTAMP DEFAULT NOW(),
    last_played TIMESTAMP
)

character_stats (
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    stat_name    VARCHAR(50),
    stat_value   TEXT,
    PRIMARY KEY (character_id, stat_name)
)
```

---

## UI Flow (character selection)

1. Player join → server verifică câte personaje are (max configurat în settings)
2. Dacă 0 personaje → deschide UI creare personaj
3. Dacă ≥1 personaj → deschide UI selecție personaj
4. Jucătorul selectează/creează → server spawns player
5. `character_cache` salvează personajul activ pentru source

---

## Settings folosite

| Cheie | Descriere |
|-------|-----------|
| `characters.max_characters` | Număr maxim personaje per jucător |
| `characters.spawn_position` | Coordonate spawn după selecție |
