# Changelog

Format [Keep a Changelog](https://keepachangelog.com/ro/1.1.0/), versionare [SemVer](https://semver.org/lang/ro/).

---

## [Nepublicat]

### Adăugat
- Rate limiting reutilizabil pentru evenimente de rețea sensibile (`exports.core:isRateLimited`).
- Logging centralizat controlat de setarea `core.log_level` (`exports.core:log`).
- Teste de logică (busted) pentru `banking` și `core`, rulate în CI pe Lua 5.4.
- `docker-compose.yml` pentru PostgreSQL, fără configurare manuală.
- `.editorconfig` și `.gitattributes` pentru consistență de formatare și EOL.

### Reparat
- Plata creditelor cu scadența pe 29/30/31 eșua în lunile scurte (data invalidă respinsă de coloana `DATE`). Ziua se clampează acum la ultima zi a lunii.
- `math.pow` înlocuit cu operatorul `^` în calculul ratei la credite (negarantat în Lua 5.4).

---

## [1.0.0] - 2026-05-28

Prima lansare publică.

### Module (32)

- **Fundație:** `postgres` (pool + migrații hash-based), `player-data`, `settings` (key-value în DB, reload fără restart)
- **Core:** `core` (grupuri, permisiuni, moderare, localizare), `characters` (multi-char + stats)
- **UI:** `loadscreen`, `intro`, `welcome`, `proximity`, `notifications`, `hud`
- **Gameplay:** `inventory`, `banking` (multi-valută, credite, conturi org, inflație), `needs`, `clothing`, `shops`, `interiors`
- **Vehicule:** `vehicles` (ownership, chei, fuel, damage, impound), `garages`, `showroom` (cu finanțare), `tuning`
- **Joburi:** `jobs` (grade, salarii, roster, manageri), `police`, `ems`, `mecanic`, `medical`, `taxi`, `garbage`
- **Admin:** `admin` (cu audit log), `mdt` (police + EMS), `blips`, `government` (taxe, buget, salarii), `settings-panel`

### Caracteristici

- Toate setările în DB, zero hardcoded în `config.lua`
- Lua 5.4 peste tot
- Queries parametrizate
- Permission checks pe toate evenimentele sensibile
- Audit log pentru acțiuni de admin
- Migrații automate, idempotente ([docs/migrations.md](docs/migrations.md))
- Localizare integrată (RO implicit)
- CI: validare fxmanifest + scheme SQL pe PostgreSQL 14

### Cerințe

FXServer artifact 6683+ · PostgreSQL 14+ · Node.js 18+ · Lua 5.4 (vine cu FXServer)
