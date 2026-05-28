# Modul: clothing

**Locatie:** `[switcore]/clothing/`
**Dependente:** `core`, `postgres`, `characters`, `inventory`, `banking`, `notifications`, `proximity`, `settings`
**Descriere:** Sistem de magazine de haine pentru SwitCore (catalog, fitting, outfit-uri).

## Rol

Permite jucatorilor sa cumpere haine din magazine, sa le incerce in fitting room (preview), sa-si plateasca prin `banking` si sa le salveze ca outfit-uri reutilizabile. Trigger-uri prin `proximity` la coordonatele magazinelor.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | CRUD magazine, items, outfit-uri |
| `server/clothing_manager.lua` | Logica fitting, cumparare, equip |
| `server/exports.lua` | API public |
| `server/callbacks.lua` | Handlere NUI/client events |
| `server/server.lua` | Init, seed |
| `client/client.lua` | Aplicare componente PED, NUI |

## Exports cheie

```lua
exports.clothing:GetStoreItems(storeId)        -- items[]
exports.clothing:GetEquippedClothing(charId)   -- equipped table
```

## Tabele DB

- `clothing_stores` - magazine de haine (coords, name)
- `clothing_items` - catalog items per magazin
- `character_equipped_clothing` - hainele active per character
- `character_outfits` - outfit-uri salvate

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
