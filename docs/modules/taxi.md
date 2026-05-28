# Modul: taxi

**Locatie:** `[switcore]/taxi/`
**Dependente:** `core`, `postgres`, `characters`, `banking`, `notifications`, `proximity`, `settings`, `jobs`
**Descriere:** Job Taxi - transport la cerere, plata per km.

## Rol

Job de tip on-call: clientii (jucatori) cer un taxi, dispecerul (sistem automat sau alt jucator) trimite comanda celui mai apropiat sofer disponibil. Sistemul calculeaza distanta parcursa si plata se face automat catre soferul de taxi prin `banking`. Suporta si curse NPC pentru cand nu sunt clienti reali.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | Orders, stats |
| `server/server.lua` | Dispatch, salarii, lifecycle cursa |
| `server/callbacks.lua` | Handlere accept/finalizare |
| `client/client.lua` | Main loop sofer |
| `client/dispatch.lua` | UI dispecer / acceptare |
| `client/npc.lua` | Curse cu pasageri NPC |

## Exports cheie

Modulul nu expune `exports` publice in `fxmanifest`. Comunicarea cu alte module se face prin `jobs` si evenimente `taxi:*`.

## Tabele DB

- `taxi_orders` - comenzi (client, sofer, pickup, dropoff, fare, status)
- `taxi_stats` - statistici sofer (curse, km, castiguri)

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
