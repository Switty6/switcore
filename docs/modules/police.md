# Modul: police

**Locatie:** `[switcore]/police/`
**Dependente:** `core`, `postgres`, `characters`, `jobs`, `banking`, `inventory`, `notifications`, `proximity`, `settings`
**Descriere:** Sistem de politie - arest, inchisoare, MDT, armament, vestiar, fleet.

## Rol

Implementeaza joburile de politie deasupra modulului generic `jobs`: catuse (handcuffs), arestare, sentinte de inchisoare, mandate (warrants), gestiunea armamentului din vestiar si parcul auto al politiei. Interfata MDT specifica e mostenita prin modulul `mdt` unificat.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | CRUD sentinte, warrants, fleet, armory logs |
| `server/server.lua` | Init, comenzi, lifecycle inchisoare |
| `server/callbacks.lua` | Handlere actiuni officer |
| `client/client.lua` | Main loop officer |
| `client/handcuffs.lua` | Catuse animatie + control jucator |
| `client/mdt.lua` | Bridge MDT |
| `client/vehicles.lua` | Vehicule politie (sirene, fleet) |

## Exports cheie

```lua
exports.police:IsPlayerJailed(source)         -- bool
exports.police:JailCharacter(charId, minutes, reason)
exports.police:ReleaseCharacter(charId)
exports.police:GetActiveWarrant(charId)
exports.police:IsCharacterHandcuffed(source)  -- bool
```

## Tabele DB

- `police_jail_sentences` - sentinte active/istoric
- `police_warrants` - mandate de arestare
- `police_armory_logs` - log iesiri/intrari armament
- `police_fleet` - vehicule politie
- `police_fleet_logs` - log fleet

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
