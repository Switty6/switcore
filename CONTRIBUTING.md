# Contribuții

Bug-fix, modul nou, optimizare sau doc: orice îmbunătățire e binevenită.

## Workflow

1. Fork + clone local.
2. Pornește un FiveM local cu PostgreSQL (vezi [README](README.md)).
3. Branch: `git checkout -b nume/scurtă-descriere`.
4. PR către `main`, o singură schimbare logică per PR.

## Convenții de cod

- **`Sw.SecureEvent` peste tot** — orice net event de server se înregistrează prin `Sw.SecureEvent`, nu prin `RegisterNetEvent` direct. El se ocupă de rate-limit, permisiune, personaj activ, validarea argumentelor și notificarea la eroare. Vezi [docs/modules/lib.md](docs/modules/lib.md). Standardul ăsta e obligatoriu la module noi, iar modulele vechi se migrează treptat pe el (`clothing` e exemplul de referință).
- **Biblioteca `Sw`** — folosește funcțiile din `@core/shared/lib.lua` (`Sw.Trim`, `Sw.Round`, `Sw.FormatMoney`, validare etc.) în loc să rescrii utilitare locale.
- **Setările în DB** — nu hardcoda în `config.lua`. Seedează cu `INSERT ... ON CONFLICT DO NOTHING`.
- **Logica în `*_manager.lua`**; `database.lua` doar CRUD, `callbacks.lua` doar handlere subțiri.
- **Queries parametrizate** (`$1`, `$2`...) — fără concatenare în SQL.
- **Permisiuni**: orice event sensibil cere `permission` în `Sw.SecureEvent` (sau verifică ownership). Pentru cazuri în afara unui event, `exports.core:hasPermission(source, 'perm')`.
- **Notificări**: din handler folosește `ctx.error` / `ctx.success` / `ctx.notify`; în rest `TriggerClientEvent('switcore:notify', source, type, msg, duration)`.
- `lua54 'yes'` în `fxmanifest.lua`.
- Codul Lua/JS fără comentarii — explicațiile stau în `docs/`. Textele de UI în română.
- Fără `print` / `console.log` de debug — folosește un flag din `settings`.

## Structura unui modul

```
[switcore]/modul/
├── fxmanifest.lua        # include @core/shared/lib.lua și @core/server/secure.lua
├── config.lua            # gol — setările sunt în DB
├── schema.sql            # dacă folosește DB
├── server/
│   ├── database.lua      # CRUD brut
│   ├── *_manager.lua     # logica
│   ├── exports.lua       # API publică
│   ├── callbacks.lua     # handlere RegisterNetEvent
│   └── server.lua        # init, seed, comenzi
├── client/client.lua
└── ui/                   # opțional
```

## Teste

Logica de server (calcule de bani, comisioane, dobânzi, curs valutar) e acoperită cu [busted](https://lunarmodules.github.io/busted/), în `spec/`. Rulează local cu Lua 5.4 + LuaRocks:

```bash
luarocks install busted
busted
```

Fără toolchain Lua instalat, le poți rula într-un container:

```bash
docker run --rm -v "$PWD:/work" -w /work nickblah/lua:5.4-luarocks-alpine \
  sh -c "apk add --no-cache build-base && luarocks install busted && busted"
```

CI rulează aceleași teste pe Lua 5.4 la fiecare PR. Modulele FiveM nu pot fi rulate direct (depind de native-uri), deci `spec/support/fivem_env.lua` mochează mediul (`exports`, `json`, layerul DB). Testează logica pură, nu handlerele care doar deleagă către DB. Dacă atingi un calcul, adaugă sau actualizează un test.

## Bug-uri

Deschide un issue cu: artifact FiveM, versiune PostgreSQL, modul afectat, pași de reproducere, log-uri.

## Vulnerabilități

**Nu** prin issue public. Vezi [SECURITY.md](SECURITY.md).

## Cod de conduită

Fii respectuos. Critica e binevenită dacă e aplicată la cod, nu la persoană.
