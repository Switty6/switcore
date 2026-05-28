# Modul: showroom

**Locatie:** `[switcore]/showroom/`
**Dependente:** `core`, `postgres`, `characters`, `vehicles`, `notifications`, `proximity`, `settings`, `banking`, `interiors`
**Descriere:** Showroom auto - catalog vehicule, cumparare cash/finantare, test drive.

## Rol

Dealership-uri unde jucatorii rasfoiesc catalogul de vehicule, fac test drive (folosind un vehicul temporar), si le pot cumpara cash sau prin credit (`banking.createLoan`). Vehiculul cumparat este inregistrat ca `owned_vehicle` in modulul `vehicles` si livrat in `garages`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/showroom_database.lua` | CRUD dealerships, catalog, purchases |
| `server/showroom_manager.lua` | Logica cumparare, finantare, test drive |
| `server/exports.lua` | API public |
| `server/callbacks.lua` | Handlere NUI |
| `client/client.lua` | Catalog NUI, test drive controller |

## Exports cheie

```lua
exports.showroom:getActiveDealerships()
exports.showroom:getDealershipCatalog(dealershipId)
exports.showroom:purchaseVehicle(source, dealershipId, vehicleId, paymentType)
exports.showroom:startTestDrive(source, vehicleId)
exports.showroom:endTestDrive(source)
exports.showroom:getActiveTestDrive(source)
```

## Tabele DB

- `dealerships` - dealership-uri (coords, brand, marker)
- `vehicle_catalog` - vehicule disponibile per dealership cu pret
- `vehicle_purchases` - istoric cumparari
- `test_drives` - sesiuni test drive active

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
