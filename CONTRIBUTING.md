# Contribuții

Bug-fix, modul nou, optimizare sau doc — orice îmbunătățire e binevenită.

## Workflow

1. Fork + clone local.
2. Pornește un FiveM local cu PostgreSQL (vezi [README](README.md)).
3. Branch: `git checkout -b nume/scurtă-descriere`.
4. PR către `main`, o singură schimbare logică per PR.

## Convenții de cod

- **Setările în DB** — nu hardcoda în `config.lua`. Seedează cu `INSERT ... ON CONFLICT DO NOTHING`.
- **Logica în `*_manager.lua`**; `database.lua` doar CRUD, `callbacks.lua` doar handlere subțiri.
- **Queries parametrizate** (`$1`, `$2`...) — fără concatenare în SQL.
- **Permisiuni**: orice event sensibil verifică `exports.core:hasPermission(source, 'perm')` sau ownership.
- **Notificări**: `TriggerClientEvent('switcore:notify', source, type, msg, duration)`.
- `lua54 'yes'` în `fxmanifest.lua`.
- Comentarii și texte UI în română.
- Fără `print` / `console.log` de debug — folosește un flag din `settings`.

## Structura unui modul

```
[switcore]/modul/
├── fxmanifest.lua
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

## Bug-uri

Deschide un issue cu: artifact FiveM, versiune PostgreSQL, modul afectat, pași de reproducere, log-uri.

## Vulnerabilități

**Nu** prin issue public. Vezi [SECURITY.md](SECURITY.md).

## Cod de conduită

Fii respectuos. Critica e binevenită dacă e aplicată la cod, nu la persoană.
