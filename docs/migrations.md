# Migrații de bază de date

SwitCore are un sistem automat de aplicare a schemelor SQL implementat în modulul `postgres`. Acest document explică cum funcționează și cum scrii modificări de schemă pentru versiuni viitoare ale unui modul.

## Cum funcționează

La fiecare pornire, modulul `postgres` parcurge toate resursele active și caută `schema.sql` în fiecare folder. Pentru fiecare schema găsită:

1. Calculează un hash **MD5** al conținutului
2. Verifică în tabela `_schema_migrations` dacă acel hash a fost deja aplicat pentru resursa respectivă
3. Dacă hash-ul e diferit (sau lipsește) → rulează `schema.sql` și salvează noul hash
4. Dacă hash-ul e identic → skip (schema deja aplicată)

Resursele sunt procesate în ordinea dependențelor declarate în `fxmanifest.lua`, deci e safe să referențiezi tabele dintr-un modul-părinte (de ex. `characters` poate face foreign key la `players`).

### Tabela `_schema_migrations`

Creată automat la primul start:

```sql
CREATE TABLE _schema_migrations (
    id            SERIAL PRIMARY KEY,
    resource_name VARCHAR(255) NOT NULL,
    schema_hash   VARCHAR(64)  NOT NULL,
    applied_at    TIMESTAMP    DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_resource_schema UNIQUE (resource_name)
);
```

## Convenția pentru schimbări de schemă post-v1.0.0

Sistemul actual NU folosește migration files numerotate (gen `001_add_xyz.sql`). În schimb, **toate modificările trăiesc în același `schema.sql`** și se folosesc clauze idempotente.

### Pattern recomandat

**Initial schema (v1.0.0):**
```sql
CREATE TABLE IF NOT EXISTS owned_vehicles (
    id         SERIAL PRIMARY KEY,
    plate      VARCHAR(8) UNIQUE NOT NULL,
    model      VARCHAR(64) NOT NULL,
    fuel       NUMERIC DEFAULT 100,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Adăugare coloană nouă în v1.1.0:**
```sql
-- Block initial (rămâne neschimbat pentru servere noi)
CREATE TABLE IF NOT EXISTS owned_vehicles (
    id         SERIAL PRIMARY KEY,
    plate      VARCHAR(8) UNIQUE NOT NULL,
    model      VARCHAR(64) NOT NULL,
    fuel       NUMERIC DEFAULT 100,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Migrații pentru servere existente (idempotente)
ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS mileage NUMERIC DEFAULT 0;
ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS damage_state JSONB;
```

La pornire:
- Pe un server nou: rulează blocul `CREATE TABLE` (creează direct coloanele) și `ALTER TABLE` (nu face nimic - coloanele există deja)
- Pe un server existent: `CREATE TABLE IF NOT EXISTS` e skip-uit, dar `ALTER TABLE ADD COLUMN IF NOT EXISTS` adaugă coloanele lipsă

Hash-ul s-a schimbat, deci sistemul rulează schema. `IF NOT EXISTS` peste tot face operațiile idempotente.

### Operațiuni care necesită grijă

| Operație | Cum o faci sigur |
|----------|-----------------|
| Adăugare coloană | `ALTER TABLE x ADD COLUMN IF NOT EXISTS col TYPE` |
| Adăugare index | `CREATE INDEX IF NOT EXISTS idx_name ON x (col)` |
| Adăugare tabelă | `CREATE TABLE IF NOT EXISTS y (...)` |
| Adăugare foreign key | Necesar manual - vezi mai jos |
| Modificare tip coloană | Necesar manual - vezi mai jos |
| Ștergere coloană | NU recomandat în prod - planifică deprecare |
| Redenumire coloană | NU recomandat în prod - adaugă noua, migreaza date, dropează vechea în versiune separată |

### Operațiuni care necesită SQL custom

Pentru schimbări care nu pot fi idempotente trivial (ex: backfill de date, schimbare de tip cu CAST), folosește un block `DO`:

```sql
DO $$
BEGIN
    -- Adaugă coloana doar dacă nu există
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'characters' AND column_name = 'reputation'
    ) THEN
        ALTER TABLE characters ADD COLUMN reputation INTEGER DEFAULT 0;
        -- Backfill din alta coloana
        UPDATE characters SET reputation = COALESCE(playtime / 3600, 0);
    END IF;
END $$;
```

### Foreign keys

PostgreSQL nu are `ADD CONSTRAINT IF NOT EXISTS`. Workaround:

```sql
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_chars_player'
    ) THEN
        ALTER TABLE characters
            ADD CONSTRAINT fk_chars_player
            FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE;
    END IF;
END $$;
```

## Forțarea reaplicării unei scheme

Dacă vrei să forțezi reaplicarea (de exemplu după ce ai dropat manual o tabelă pentru testare):

```sql
DELETE FROM _schema_migrations WHERE resource_name = 'nume-modul';
```

La următorul restart, schema se va reaplica.

## Aplicare manuală (fără auto-discovery)

Poți rula scheme manual cu `psql`:

```bash
psql -U switcore_user -d switcore -f resources/[switcore]/core/schema.sql
```

Dar pierzi tracking-ul în `_schema_migrations`. Recomandat doar pentru migrare inițială sau debugging.

## Best practices

1. **Nu DROP coloane în patch versions** (v1.0.x). Dacă chiar trebuie, fă-o în versiune minor (v1.1.0) și anunță în CHANGELOG.
2. **Testează migrațiile pe o copie a producției** înainte de release - mai ales backfill-uri pe tabele mari.
3. **Documentează modificările în CHANGELOG** la fiecare versiune care atinge schema.
4. **Păstrează schema.sql idempotentă** - trebuie să poată rula de 100 de ori fără efecte adverse.
5. **Foloseste `BIGSERIAL` în loc de `SERIAL`** pentru tabele care vor avea miliarde de înregistrări (transactions, activity_log, etc.).
