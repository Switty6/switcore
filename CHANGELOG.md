# Changelog

Format [Keep a Changelog](https://keepachangelog.com/ro/1.1.0/), versionare [SemVer](https://semver.org/lang/ro/).

---

## [Nelansat]

---

## [1.2.0] - 2026-06-19

### Adăugat

- **Sistem de localizare (i18n)** cu limbă unică pe server (ro + en):
  - Exporturile `t` / `tp` și helperele `Sw.T` / `Sw.TP` disponibile în toate modulele.
  - `registerModuleLocales`: un modul își înregistrează `locales/ro.lua` + `en.lua` cu o singură linie; broadcast cu debounce către clienții conectați.
  - Limba serverului din convar-ul `sw_locale` (`setr`), cu fallback pe setarea `core.default_language` și `Config.DEFAULT_LANGUAGE`.
  - `Config.ALLOW_PLAYER_LANGUAGE` (false pe public): pe premium activează selecția de limbă per jucător, fără modificări la call site-uri.
  - Helper NUI `core/ui/i18n.js` (`data-i18n` + `SwI18n.t`) și exportul `getLocaleDict`.
- Fișiere `locales/ro.lua` și `locales/en.lua` pentru toate modulele.
- Spec `locale_completeness` rulat în CI: `ro` și `en` au aceleași chei și aceleași placeholdere.
- Documentație: [docs/localization.md](docs/localization.md).

### Schimbat

- Mesajele de validare din `lib.lua` și cele din `Sw.SecureEvent` mutate în locale.
- Evenimentele `switcore:setLanguage`, `getLocalizedMessage` și `requestLocale` migrate pe `Sw.SecureEvent` cu rate limit.

### Reparat

- Cascadă de erori `IsReady` la pornirea serverului (#14): `settings` apela sincron `exports.core:registerModuleLocales` înainte ca `core` să fie pornit, ceea ce oprea înregistrarea exportului `IsReady` și dărâma în lanț core, banking, vehicles, medical, police, inventory, jobs și restul modulelor. Apelul se face acum într-un thread care așteaptă pornirea resursei `core`.
- Buguri raportate pe module (#13): taxi (crash meniu, triplicare, focus blocat), benzinărie (furtun dublu, curățare distanță, ESC), tuning (cameră orbit, culori presetate, livery, auto-close), dealership (ieșire test-drive, buton finanțare), salubritate (Sesiune Invalidă), vehicule (căutare plăcuță), admin (godmode respawn), efecte (blur needs/ems), poliție (blocaj uniformă).
- Interpolarea string-urilor: caracterul `%` din argumente nu mai e tratat ca referință de captură.

---

## [1.1.0] - 2026-06-12

### Adăugat

- **Bibliotecă shared `Sw`** (`core/shared/lib.lua`) - utilitare pure (string, numeric, table, `FormatMoney`) plus motor de validare `Sw.ValidateArgs`, disponibile client + server prin `@core/shared/lib.lua`.
- **Framework `Sw.SecureEvent`** (`core/server/secure.lua`) - net events sigure cu rate-limit, permisiune, fetch personaj activ, validare argumente și notificare automată la eroare, înlocuind boilerplate-ul repetat din handlere.
- **Rate limiter glisant** (`core/server/ratelimit.lua`) - expus ca `exports.core:checkRateLimit`, fereastră glisantă per `(source, cheie)`, folosit de `Sw.SecureEvent`.
- **Rate limiting reutilizabil** pentru evenimente de rețea sensibile (`exports.core:isRateLimited`).
- **Logging centralizat** controlat de setarea `core.log_level` (`exports.core:log`).
- Teste de logică (busted) pentru `banking` și `core`, rulate în CI pe Lua 5.4.
- `docker-compose.yml` pentru PostgreSQL, fără configurare manuală.
- **`setup.bat`** pentru instalare rapidă pe Windows: rulează `npm install` pentru `postgres` și `settings-panel` și creează `config.local.js` pentru ambele module (date de conectare la bază plus JWT secret generat automat pentru panou).
- `.editorconfig` și `.gitattributes` pentru consistență de formatare și EOL.
- Documentație: [docs/modules/lib.md](docs/modules/lib.md).

### Schimbat

- `server.cfg.example`: scoase convarurile `switcore_postgres_*` și `switcore_panel_*` (configurarea bazei și a panoului se face din `config.local.js`, generat de `setup.bat`); URL-ul de licență actualizat la `portal.cfx.re`.
- Modulul `clothing` migrat pe `Sw.SecureEvent` ca exemplu de referință (comportament identic).
- Net events de server migrate pe `Sw.SecureEvent` în toate modulele cu interacțiuni client: `banking`, `characters`, `inventory`, `police`, `ems`, `government`, `admin`, plus familia vehicule (`vehicles`, `garages`, `showroom`, `tuning`), joburile (`jobs`, `mecanic`, `medical`, `taxi`, `garbage`), `mdt` și `shops`. Fiecare handler primește rate-limit, verificare personaj activ și validare argumente, păstrând logica de business, permisiunile și anti-cheat-ul existent.

### Reparat

- Showroom: la selecția rapidă de vehicule rămâneau modele suprapuse care nu se mai ștergeau; doar ultima selecție mai creează vehiculul.
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
