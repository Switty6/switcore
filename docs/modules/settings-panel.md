# Modul: settings-panel

**Locatie:** `[switcore]/settings-panel/`
**Dependente:** `postgres` (acceseaza direct DB, nu prin Lua)
**Descriere:** Panou admin web (Node.js + Express) pentru gestionarea live a setarilor din DB.

## Rol

Resursa Node.js complet separata de gameplay-ul Lua. Porneste un server Express care expune un panou web cu autentificare (JWT + bcrypt), permite admin-ilor sa modifice live valorile din tabelul `settings` fara restart de resurse. Modificarile sunt vazute de modulele Lua dupa `ReloadSettings`. Suporta roluri (admin, superadmin) si grupare setari pe tab-uri.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server.js` | Server Express, API REST, autentificare |
| `preload.js` | Init pool DB, verificari, bootstrap users |
| `config.js` / `config.local.js` | Config DB + JWT secret |
| `public/` | Frontend static (HTML/CSS/JS) |
| `package.json` | Dependinte (`express`, `pg`, `jsonwebtoken`, `bcryptjs`, `cors`) |

## Exports cheie

Nu expune exports Lua - este un serviciu HTTP. Endpoint-uri principale:

```
GET    /api/auth/me              -- info user curent
GET    /api/settings             -- lista toate setarile
GET    /api/settings/groups      -- setari grupate
PUT    /api/settings/:key        -- update o setare
PUT    /api/settings             -- bulk update
GET    /api/users                -- list users (admin)
POST   /api/users                -- creeaza user (superadmin)
```

## Tabele DB

Citeste/scrie direct in `settings` (din modulul `settings`) si are tabele proprii pentru users (vezi `preload.js`).

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
