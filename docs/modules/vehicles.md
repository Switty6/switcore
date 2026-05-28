# Modul: vehicles (+ garages, showroom, tuning)

Sistemul de vehicule este format din 4 module interdependente.

**Ordine obligatorie:** `vehicles` → `garages` → `showroom` → `tuning`

---

## vehicles

**Locație:** `[switcore]/vehicles/`
**Dependențe:** `core`, `postgres`, `characters`, `inventory`, `notifications`, `settings`, `banking`, `proximity`

### Fișiere server

| Fișier | Rol |
|--------|-----|
| `server/vehicles_database.lua` | CRUD owned_vehicles, vehicle_keys |
| `server/vehicles_manager.lua` | createVehicle, saveState, ownership logic |
| `server/fuel_manager.lua` | Consum combustibil, refueling |
| `server/keys_manager.lua` | Give/remove/check chei + item inventar |
| `server/fuel_station_server.lua` | Logică stații de alimentare |
| `server/exports.lua` | API publică |
| `server/callbacks.lua` | RegisterNetEvent handlers |
| `server/server.lua` | Init, seed item 'vehicle_key', seed settings |

### Fișiere client

| Fișier | Rol |
|--------|-----|
| `client/client.lua` | Spawn/despawn entitate, netId map, key listener |
| `client/fuel_station.lua` | UI stație alimentare, consum tick |

### Exports
```lua
-- Ownership
exports.vehicles:createVehicle(characterId, model, category, price)     → {bool, err, vehicle}
exports.vehicles:getOwnedVehicle(vehicleId)                              → vehicle
exports.vehicles:getOwnedVehicleByPlate(plate)                           → vehicle
exports.vehicles:getCharacterVehicles(characterId)                       → vehicle[]
exports.vehicles:saveVehicleState(vehicleId, state)                      → bool
exports.vehicles:spawnVehicleForPlayer(source, vehicleId)                → bool

-- Chei
exports.vehicles:giveVehicleKey(vehicleId, characterId, keyType)         → bool
exports.vehicles:removeVehicleKey(vehicleId, characterId)                → bool
exports.vehicles:hasVehicleKey(vehicleId, characterId)                   → bool
exports.vehicles:getVehicleKeys(vehicleId)                               → keys[]
exports.vehicles:transferOwnership(vehicleId, fromCharId, toCharId)      → bool

-- Impound
exports.vehicles:impoundVehicle(vehicleId, reason)                       → bool
exports.vehicles:releaseVehicle(vehicleId)                               → bool

-- Combustibil & Mileage
exports.vehicles:getVehicleFuel(vehicleId)                               → number
exports.vehicles:setVehicleFuel(vehicleId, amount)                       → bool
exports.vehicles:addMileage(vehicleId, km)                               → bool
```

### Schema DB
```sql
owned_vehicles (
    id              BIGSERIAL PRIMARY KEY,
    character_id    INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    plate           VARCHAR(8) UNIQUE NOT NULL,
    model           VARCHAR(100),
    label           VARCHAR(100),
    category        VARCHAR(30) DEFAULT 'sedan',
    fuel            NUMERIC(5,2) DEFAULT 100.0,
    mileage         NUMERIC(12,2) DEFAULT 0.0,
    body_health     NUMERIC(7,2) DEFAULT 1000.0,
    engine_health   NUMERIC(7,2) DEFAULT 1000.0,
    modifications   JSONB DEFAULT '{}',
    stored          BOOLEAN DEFAULT true,   -- true = în garaj
    impounded       BOOLEAN DEFAULT false,
    last_position   JSONB,
    purchased_at    TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP
)

vehicle_keys (
    id              BIGSERIAL PRIMARY KEY,
    vehicle_id      BIGINT REFERENCES owned_vehicles(id) ON DELETE CASCADE,
    character_id    INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    key_type        VARCHAR(20) DEFAULT 'standard',
    --  key_type: 'owner' | 'standard' | 'valet'
    given_at        TIMESTAMP DEFAULT NOW(),
    UNIQUE (vehicle_id, character_id)
)
```

### Modifications JSONB shape
```json
{
    "engine": 2, "brakes": 1, "transmission": 0, "turbo": 0,
    "suspension": 1, "armor": 0,
    "color_primary": "#FF0000", "color_secondary": "#000000",
    "livery": -1, "wheels": 12, "extras": [1, 3]
}
```

### Settings
| Cheie | Implicit | Descriere |
|-------|---------|-----------|
| `vehicles.default_fuel` | `100` | Combustibil vehicul nou |
| `vehicles.fuel_consumption_rate` | `0.02` | % combustibil/secundă |
| `vehicles.fuel_tick_interval` | `5000` | ms tick consum |
| `vehicles.save_interval` | `30000` | ms auto-save stare active |
| `vehicles.impound_fee_per_day` | `500` | Taxă sechestru/zi |
| `vehicles.delete_after_impound_days` | `30` | Zile până la ștergere auto |
| `vehicles.enable_fuel_system` | `true` | Activează combustibil |
| `vehicles.enable_mileage` | `true` | Activează mileage |

---

## garages

**Locație:** `[switcore]/garages/`
**Dependențe:** `vehicles`, `banking`, `proximity`, `notifications`

### Exports
```lua
exports.garages:ParkVehicle(characterId, vehicleId, garageCode, state)   → {bool, err}
exports.garages:RetrieveVehicle(characterId, vehicleId, garageCode)      → {bool, err, vehicle}
exports.garages:GetGarageVehicles(characterId, garageCode)               → vehicle[]
exports.garages:ImpoundToGarage(vehicleId, reason)                       → bool
exports.garages:GetImpoundedVehicles(characterId)                        → vehicle[]
exports.garages:IssueTicket(characterId, vehicleId, amount, reason, by)  → {bool, ticketId}
exports.garages:PayTicket(characterId, ticketId, paymentMethod)          → {bool, err}
exports.garages:GetCharacterTickets(characterId)                         → ticket[]
exports.garages:GetImpoundFineTotal(vehicleId)                           → amount
```

### Locații garaj (config.lua)
```lua
Config.GarageLocations = {
    { coords=vector3(215.36,-809.56,29.73),   label='Garaj Public - Mission Row',
      code='PUBLIC_MROW',   type='public',  spawnPoint=vector3(213.0,-816.0,29.73),   heading=0.0 },
    { coords=vector3(-1085.02,-328.57,13.94), label='Garaj Public - Morningwood',
      code='PUBLIC_MWOOD',  type='public',  spawnPoint=vector3(-1088.0,-335.0,13.94), heading=180.0 },
    { coords=vector3(444.12,-1020.38,28.39),  label='Parcul de Sechestru LSIA',
      code='IMPOUND_LSIA',  type='impound', spawnPoint=vector3(448.0,-1027.0,28.39),  heading=90.0 },
}
```

### Schema DB
```sql
garages (id, name, code UNIQUE, type, coords JSONB, spawn_point JSONB, is_active)
--  type: 'public' | 'private' | 'impound' | 'vip'

garage_logs (id, vehicle_id, character_id, garage_id, action, fuel_at_action, created_at)
--  action: 'parked' | 'retrieved'

parking_tickets (id, character_id, vehicle_id, plate, fine_amount, reason,
                 paid, issued_by, issued_at, paid_at)
```

### Settings
| Cheie | Implicit |
|-------|---------|
| `garages.impound_release_fee` | `2500` |
| `garages.parking_ticket_base_fine` | `500` |
| `garages.max_tickets_before_impound` | `3` |
| `garages.impound_garage_code` | `'IMPOUND_LSIA'` |

---

## showroom

**Locație:** `[switcore]/showroom/`
**Dependențe:** `vehicles`, `banking`, `proximity`, `notifications`, `core`

### Exports
```lua
exports.showroom:GetActiveDealerships()                                  → dealership[]
exports.showroom:GetDealershipCatalog(dealershipCode, isVip)             → catalog[]
exports.showroom:PurchaseVehicle(source, charId, catalogId, method, term) → {bool, err, vehicle}
--  method: 'cash' | 'bank' | 'finance'
exports.showroom:StartTestDrive(characterId, catalogId)                  → {bool, err, testDrive}
exports.showroom:EndTestDrive(characterId)                               → bool
exports.showroom:GetActiveTestDrive(characterId)                         → testDrive
```

### Flux cumpărare
```
showroom:server:purchaseVehicle
    → fetch catalog item, VIP check (exports.core:hasPermission source 'vip')
    → plată: exports.banking:withdraw (cash/bank) sau exports.banking:createLoan (finance)
    → exports.vehicles:createVehicle → owned_vehicles + cheie inventar
    → INSERT vehicle_purchases
    → TriggerClientEvent('vehicles:client:spawnVehicle', source, vehicleData)
```

### Locații dealership (config.lua)
```lua
Config.DealershipLocations = {
    { code='PDM',    name='Premium Deluxe Motorsport',
      coords=vector3(-47.00,-1104.00,26.42), npcModel='ig_trafficwarden',
      testDriveSpawn=vector3(-44.0,-1096.0,26.42) },
    { code='LEGACY', name='Legacy Motorsport',
      coords=vector3(-1256.65,-369.34,37.20), npcModel='ig_trafficwarden',
      testDriveSpawn=vector3(-1252.0,-365.0,37.20) },
}
```

### Schema DB
```sql
dealerships (id, name, code UNIQUE, coords JSONB, npc_model, is_active)

vehicle_catalog (id, dealership_id, model, label, category, price,
                 finance_eligible, vip_only, sort_order, is_active)

vehicle_purchases (id, character_id, catalog_id, vehicle_id, price_paid,
                   payment_method, loan_id, purchased_at)
-- payment_method: 'cash' | 'bank' | 'finance'

test_drives (id, character_id, catalog_id, plate, started_at, expires_at, returned)
```

### Settings
| Cheie | Implicit |
|-------|---------|
| `showroom.test_drive_duration_minutes` | `5` |
| `showroom.finance_min_price` | `5000` |
| `showroom.default_finance_bank_code` | `'MAZE'` |
| `showroom.default_loan_type` | `'personal'` |

---

## tuning

**Locație:** `[switcore]/tuning/`
**Dependențe:** `vehicles`, `banking`, `proximity`, `notifications`, `core`

### Exports
```lua
exports.tuning:GetTuningShops()                                          → shop[]
exports.tuning:GetTuningPrices()                                         → prices{}
exports.tuning:GetVehicleMods(vehicleId)                                 → mods{}
exports.tuning:ApplyMod(source, charId, vehicleId, category, tier, method) → {bool, err, newMods}
exports.tuning:ResetMods(characterId, vehicleId, paymentMethod)          → {bool, err}
exports.tuning:CalculateUpgradeCost(vehicleId, category, targetTier)     → amount
```

### Preview flow (fără cost)
```
UI: Preview → NUICallback('previewMod')
    → client: SetVehicleMod(entity, category, tier) - local, fără server event
UI: Close fără confirm → client: restaurează originalMods pe entitate
UI: Aplică → TriggerServerEvent('tuning:server:applyMod')
    → server: plată + SaveVehicleState + apply pe entitate
```

### Locații shop (config.lua)
```lua
Config.TuningShops = {
    { code='LSC_BURTON',  name='LS Customs - Burton',
      coords=vector3(-352.29,-133.94,38.87) },
    { code='LSC_ELYSIAN', name='LS Customs - Elysian Island',
      coords=vector3(709.72,-1082.87,22.17) },
}
Config.VipOnlyMods = {
    engine = { 4 },   -- tier 4 motor exclusiv VIP
    armor  = { 5 },   -- blindaj maxim exclusiv VIP
}
```

### Schema DB
```sql
tuning_shops (id, name, code UNIQUE, coords JSONB, is_active)

tuning_prices (id, category, tier, price, vip_only,
               UNIQUE(category, tier))

tuning_logs (id, character_id, vehicle_id, shop_id, category,
             tier_before, tier_after, price_paid, applied_at)
```

### Settings
| Cheie | Implicit |
|-------|---------|
| `tuning.reset_mods_cost` | `1500` |
| `tuning.vip_discount` | `0.15` |
| `tuning.interaction_distance` | `3.0` |
