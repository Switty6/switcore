# Modul: garages

**Locatie:** `[switcore]/garages/`
**Dependente:** `core`, `postgres`, `characters`, `vehicles`, `notifications`, `proximity`, `settings`, `banking`
**Descriere:** Sistem de garaje pentru SwitCore - parcare, scoatere vehicule, sechestru si amenzi.

## Rol

Permite jucatorilor sa-si parcheze masinile in garaje publice/private si sa le scoata ulterior. Include sistem de impound (sechestru de catre politie) cu plata amenzilor pentru a recupera vehiculul. Garajele si tarifele sunt configurabile via DB.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/garages_database.lua` | CRUD garaje, logs |
| `server/garages_manager.lua` | Logica parcare/retrieval |
| `server/impound_manager.lua` | Impound + amenzi |
| `server/exports.lua` | API public |
| `server/callbacks.lua` | Handlere |
| `client/client.lua` | NUI, interactiuni |

## Exports cheie

```lua
exports.garages:getGarageByCode(code)
exports.garages:getGarageVehicles(garageCode, charId)
exports.garages:parkVehicle(vehicleId, garageCode)
exports.garages:retrieveVehicle(vehicleId, garageCode)
exports.garages:impoundToGarage(vehicleId, reason)
exports.garages:getImpoundedVehicles(charId)
exports.garages:issueTicket(charId, amount, reason)
exports.garages:payTicket(ticketId)
exports.garages:getCharacterTickets(charId)
exports.garages:getImpoundFineTotal(charId)
```

## Tabele DB

- `garages` - garaje (cod, nume, coords, tip)
- `garage_logs` - istoric parcari/scoateri
- `parking_tickets` - amenzi parcare/impound

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
