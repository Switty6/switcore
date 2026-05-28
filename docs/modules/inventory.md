# Modul: inventory

**Locație:** `[switcore]/inventory/`
**Dependențe:** `core`, `postgres`, `proximity`, `settings`
**fx_version:** `cerulean` (diferit de restul modulelor care folosesc `bodacious`)

## Fișiere server

| Fișier | Rol |
|--------|-----|
| `server/main.lua` | Init, exports, event handlers |
| `server/database_sync.lua` | Sincronizare inventar cu DB |
| `server/actions.lua` | Folosire items (usable items) |

## Fișiere client

| Fișier | Rol |
|--------|-----|
| `client/main.lua` | UI inventar, drag-drop, use item |

---

## Exports (server-side)

```lua
exports.inventory:AddItem(characterId, itemName, quantity)      → bool
exports.inventory:RemoveItem(characterId, itemName, quantity)   → bool
exports.inventory:HasItem(characterId, itemName, quantity)      → bool
exports.inventory:GetInventory(characterId)                     → inventory[]
exports.inventory:RegisterUsableItem(itemName, callback)        -- înregistrare acțiune use
exports.inventory:GetItemConfig(itemName)                       → config{}
```

---

## RegisterUsableItem

Pattern pentru înregistrarea unui item folosibil:

```lua
-- Apelat la init modul, în server.lua
exports.inventory:RegisterUsableItem('vehicle_key', function(source, item)
    -- item.metadata poate conține vehicleId, plate, etc.
    local vehicleId = item.metadata and item.metadata.vehicleId
    if vehicleId then
        -- deschide UI chei vehicul
        TriggerClientEvent('vehicles:client:openKeyUI', source, vehicleId)
    end
end)
```

---

## Schema DB

```sql
items (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) UNIQUE,
    label       VARCHAR(200),
    description TEXT,
    weight      NUMERIC(8,2) DEFAULT 0,
    stackable   BOOLEAN DEFAULT true,
    usable      BOOLEAN DEFAULT false,
    image       VARCHAR(200)   -- path în ui/img/items/
)

character_inventory (
    id           BIGSERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    item_id      INTEGER REFERENCES items(id) ON DELETE CASCADE,
    quantity     INTEGER DEFAULT 1,
    metadata     JSONB DEFAULT '{}'   -- date extra (vehicleId, durability, etc.)
)
```

---

## Items cunoscuți în sistem

| Item | Modul | Descriere |
|------|-------|-----------|
| `vehicle_key` | vehicles | Cheie vehicul (metadata: vehicleId, plate) |

---

## Settings folosite

| Cheie | Descriere |
|-------|-----------|
| `inventory.max_weight` | Greutate maximă inventar |
| `inventory.slots` | Număr sloturi inventar |
