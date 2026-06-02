# SwitCore

Framework de roleplay pentru FiveM. PostgreSQL pentru date, Lua 5.4 pentru scripturi, Node.js pentru conectorul DB și panoul de setări. Toate setările trăiesc în baza de date — nu editezi `config.lua`.

## Module

- **Fundație:** `postgres`, `player-data`, `settings`
- **Core:** `core` (grupuri, permisiuni, moderare), `characters` (multi-char + stats)
- **UI / onboarding:** `loadscreen`, `intro`, `welcome`, `hud`, `notifications`, `proximity`
- **Gameplay:** `inventory`, `banking` (multi-valută, credite, conturi org), `needs`, `clothing`, `shops`, `interiors`
- **Vehicule:** `vehicles` (ownership, chei, fuel, damage), `garages`, `showroom`, `tuning`
- **Joburi:** `jobs` + `police`, `ems`, `mecanic`, `medical`, `taxi`, `garbage`
- **Admin:** `admin`, `mdt`, `blips`, `government`, `settings-panel`

## Cerințe

- FXServer artifact 6683+
- PostgreSQL 14+
- Node.js 18+

## Instalare

**1. PostgreSQL**

Creezi DB-ul și user-ul:
```sql
CREATE DATABASE switcore;
CREATE USER switcore_user WITH PASSWORD 'parola';
GRANT ALL PRIVILEGES ON DATABASE switcore TO switcore_user;
```

Asigură-te că PostgreSQL acceptă conexiuni de la `127.0.0.1` (`pg_hba.conf` cu `md5` sau `scram-sha-256`).

**2. Clonează în `resources/`**

```bash
git clone https://github.com/Switty6/switcore.git
```

Mută folderele `[switcore]`, `[gameplay]`, `[managers]`, `[system]`, `[gamemodes]` în `resources/`.

**3. Credențiale DB**

În `server.cfg`:
```
set switcore_postgres_host     "localhost"
set switcore_postgres_port     "5432"
set switcore_postgres_database "switcore"
set switcore_postgres_user     "switcore_user"
set switcore_postgres_password "parola"
```

Alternative: `cp resources/[switcore]/postgres/config.local.js.example config.local.js`, sau env vars (`POSTGRES_HOST`, etc.).

**4. Pornește framework-ul**

Schemele se aplică automat la pornire. În `server.cfg`:
```
ensure baseevents
ensure sessionmanager
ensure hardcap
ensure mapmanager
ensure spawnmanager
ensure yarn
ensure webpack
ensure [switcore]
ensure chat
ensure playernames
ensure basic-gamemode
```

Vezi `server.cfg.example` pentru fișierul complet.

**5. Panou de setări** (opțional)

```bash
cd resources/[switcore]/settings-panel
npm install
```

Convars:
```
set switcore_panel_jwt_secret      "<random 32+ caractere>"
set switcore_panel_admin_username  "admin"
set switcore_panel_admin_password  "<parolă>"
set switcore_panel_db_host         "localhost"
set switcore_panel_db_user         "switcore_user"
set switcore_panel_db_password     "<parolă DB>"
set switcore_panel_cors_origins    "http://localhost:8080"
```

Panou disponibil la `http://server:8080`.

## Configurare runtime

Setările trăiesc în tabela `settings`:

```lua
local val = exports.settings:GetSetting('modul.cheie', 'implicit')
```

Le modifici din panoul web sau direct în DB; reîncărci cu `exports.settings:ReloadSettings()` — fără restart.

## Documentație

- [Arhitectură](docs/architecture.md)
- [Bibliotecă shared `Sw` & Secure Events](docs/modules/lib.md)
- [Core](docs/modules/core.md) · [Characters](docs/modules/characters.md) · [Banking](docs/modules/banking.md)
- [Jobs](docs/modules/jobs.md) · [Vehicles](docs/modules/vehicles.md) · [Inventory](docs/modules/inventory.md)

## Altele

- [CONTRIBUTING.md](CONTRIBUTING.md) — cum trimiți un PR
- [SECURITY.md](SECURITY.md) — raportare vulnerabilități (privat)
- [CHANGELOG.md](CHANGELOG.md)

## Licență

[MIT](LICENSE)
