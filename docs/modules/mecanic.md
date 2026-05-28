# Modul: mecanic

**Locatie:** `[switcore]/mecanic/`
**Dependente:** `core`, `postgres`, `characters`, `banking`, `notifications`, `proximity`, `settings`, `jobs`, `vehicles`, `inventory`
**Descriere:** Job Mecanic Auto - service player-owned cu sistem de componente vehicul.

## Rol

Job de mecanic care permite reparatii in atelier (workshop) si interventii roadside. Vehiculele au "componente" (motor, transmisie, frane, suspensie, racire, electric) care se uzeaza si pot fi inlocuite individual cu piese din `inventory`. Plata clientului via `banking`, salarii prin `jobs`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | Service calls, log |
| `server/server.lua` | Init, despatch, salarii |
| `server/callbacks.lua` | Handlere repair, parts |
| `client/client.lua` | Main job loop |
| `client/workshop.lua` | Atelier (lift, hoist) |
| `client/roadside.lua` | Interventie roadside |
| `client/components.lua` | Sistem componente |
| `client/progress.lua` | Progress bars |
| `client/damage.lua` | Damage tracking pe componente |

## Exports cheie

Modulul nu expune `exports` la nivel public in `fxmanifest`. Integrarea cu alte resurse se face prin evenimente interne (`mecanic:*`) si prin `jobs`.

## Tabele DB

- `mechanic_service_calls` - apeluri service (caller, vehicleId, status, location)
- `mechanic_service_log` - istoric reparatii (piese, cost, mecanic)

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
