# Modul: ems

**Locatie:** `[switcore]/ems/`
**Dependente:** `core`, `postgres`, `characters`, `jobs`, `banking`, `inventory`, `notifications`, `proximity`, `settings`, `medical`
**Descriere:** Sistem EMS - inconstienta, 112, targa, MDT medical, ambulanta.

## Rol

Gestioneaza starea de "down" / inconstienta a jucatorilor cand viata scade la 0 (bleed-out timer), gestioneaza apelurile 112, transport pe targa, resuscitare, inventarul ambulantei si istoricul medical pe character (impreuna cu `medical` pentru boli/rani de fond).

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | Calls, records, vehicle inventory |
| `server/unconscious.lua` | Logica down/timer/respawn |
| `server/calls.lua` | Apeluri 112 |
| `server/treatment.lua` | Resuscitare, tratament |
| `server/vehicles.lua` | Ambulante |
| `client/main.lua`, `client/patient.lua`, `client/mdt.lua`, `client/ambulance.lua` | Logica client |

## Exports cheie

```lua
exports.ems:IsUnconscious(source)         -- bool
exports.ems:GetUnconsciousData(source)    -- table
exports.ems:SetUnconscious(source, opts)
exports.ems:RevivePlayer(source)
```

## Tabele DB

- `ems_calls` - apeluri 112 (locatie, status)
- `ems_medical_records` - istoric medical character
- `ems_vehicle_inventory` - inventar pe vehicul ambulanta

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
