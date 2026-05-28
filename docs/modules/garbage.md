# Modul: garbage

**Locatie:** `[switcore]/garbage/`
**Dependente:** `core`, `postgres`, `characters`, `banking`, `notifications`, `proximity`, `settings`, `jobs`
**Descriere:** Job Salubritate - colectare gunoi pe rute predefinite, plata per container.

## Rol

Job casual de tip "start de tura": jucatorul ia un camion de gunoi, urmeaza o ruta predefinita, opreste la fiecare container si ridica saci de gunoi via animatii. Plata pe container colectat se face prin `banking`. Rutele sunt configurabile via DB.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | Sessions, stats |
| `server/server.lua` | Init, atribuire rute, plata |
| `server/callbacks.lua` | Handlere progres ruta |
| `client/client.lua` | Main loop |
| `client/route.lua` | Logica ruta + waypoint-uri |

## Exports cheie

Modulul nu expune `exports` publice in `fxmanifest`. Integrarea cu alte resurse se face prin `jobs`.

## Tabele DB

- `garbage_sessions` - sesiuni de lucru (start, end, ruta, castig)
- `garbage_stats` - stats lifetime per character

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
