# Modul: shops

**Locatie:** `[switcore]/shops/`
**Dependente:** `core`, `postgres`, `characters`, `inventory`, `banking`, `notifications`, `proximity`, `settings`
**Descriere:** Sistem de magazine statice NPC (24/7, ammunation generic, etc.) pentru SwitCore.

## Rol

Magazine cu vanzator NPC unde jucatorii cumpara items definite in DB. Plata via `banking` (cash sau cont), livrare via `inventory`. Pozitiile, items si preturile sunt configurate in `shops`/`shop_items` din DB, deci pot fi modificate live fara restart.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | CRUD magazine si items |
| `server/shop_manager.lua` | Logica de cumparare, validari |
| `server/exports.lua` | API public |
| `server/callbacks.lua` | Handlere NUI |
| `server/server.lua` | Init, seed, spawn NPC-uri |
| `client/client.lua` | NUI catalog, interactiune |

## Exports cheie

```lua
exports.shops:GetShopByName(name)        -- shop
exports.shops:GetShopItems(shopId)       -- items[]
exports.shops:BuyItem(source, shopId, itemName, qty)
```

## Tabele DB

- `shops` - magazine (cod, nume, coords, model NPC)
- `shop_items` - items vandute per magazin cu pret si stock

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
