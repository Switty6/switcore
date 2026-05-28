# Modul: tuning

**Locatie:** `[switcore]/tuning/`
**Dependente:** `core`, `postgres`, `characters`, `banking`, `notifications`, `settings`, `proximity`, `vehicles`
**Descriere:** Sistem de tuning - upgrade motor, frane, suspensie, culori si mai mult.

## Rol

Tuning shop-uri unde jucatorii instaleaza upgrade-uri pe vehiculele proprii (performance, vopsea, exterior, interior). Plata via `banking`, persistenta in `vehicles.state` JSON. Pretul fiecarui mod este definit in DB si scalabil pe nivel.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/tuning_data.lua` | Definitii mod types, costuri |
| `server/tuning_database.lua` | CRUD shops, prices, logs |
| `server/tuning_manager.lua` | Logica aplicare/calcul cost |
| `server/exports.lua` | API public |
| `server/callbacks.lua` | Handlere NUI |
| `client/client.lua` | UI tuning + aplicare native pe vehicul |

## Exports cheie

```lua
exports.tuning:GetTuningShops()
exports.tuning:GetTuningPrices(shopId)
exports.tuning:GetVehicleMods(vehicleId)
exports.tuning:ApplyMod(source, vehicleId, modType, modIndex)
exports.tuning:ResetMods(vehicleId)
exports.tuning:CalculateUpgradeCost(modType, modIndex)
```

## Tabele DB

- `tuning_shops` - tuning shops (cod, coords, specializare)
- `tuning_prices` - preturi per mod type/shop
- `tuning_logs` - istoric instalari

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
