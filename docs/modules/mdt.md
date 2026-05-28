# Modul: mdt

**Locatie:** `[switcore]/mdt/`
**Dependente:** `core`, `postgres`, `characters`, `jobs`, `banking`, `notifications`, `settings`, `police`, `ems`
**Descriere:** MDT (Mobile Data Terminal) unificat pentru Politie + EMS.

## Rol

Interfata NUI unificata pentru fortele de ordine si medicale: cautare istoric criminal, citatii (amenzi), BOLO-uri, incidente, impound-uri. Pentru EMS - acces la `medical_records` din `ems`. Comunica cu serverul exclusiv via `RegisterNetEvent('mdt:server:*')`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | CRUD citations, bolos, incidents, impounds |
| `server/police_mdt.lua` | Handlere `mdt:server:*` |
| `client/main.lua` | Acces MDT, deschide NUI |
| `ui/` | UI MDT |

## Exports cheie

Modulul nu expune exports - comunicarea se face prin evenimente.

## Evenimente importante

```lua
RegisterNetEvent('mdt:server:getCriminalHistory')
RegisterNetEvent('mdt:server:createCitation')
RegisterNetEvent('mdt:server:getCitations')
RegisterNetEvent('mdt:server:payCitationOfficer')
RegisterNetEvent('mdt:server:createBOLO')
RegisterNetEvent('mdt:server:getActiveBOLOs')
RegisterNetEvent('mdt:server:closeBOLO')
RegisterNetEvent('mdt:server:createIncident')
RegisterNetEvent('mdt:server:getIncidents')
RegisterNetEvent('mdt:server:impoundVehicle')
RegisterNetEvent('mdt:server:getImpounds')
RegisterNetEvent('mdt:server:retrieveImpound')
```

## Tabele DB

- `police_citations` - amenzi/citatii
- `police_bolos` - "Be On the Look Out" alerte
- `police_incidents` - incidente raportate
- `police_impounds` - vehicule sechestrate via MDT

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
