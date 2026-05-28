# Modul: medical

**Locatie:** `[switcore]/medical/`
**Dependente:** `core`, `postgres`, `characters`, `inventory`, `notifications`, `settings`
**Descriere:** Sistem medical - boli, simptome, medicamente, rani, transmitere.

## Rol

Layer-ul "background medical" peste `ems`: tine evidenta bolilor (raceala, gripa, etc.) cu simptome (stranut, tuse, febra), rani persistente (impuscaturi, fracturi) cu bleeding, transmitere intre jucatori (contagiune) si imunitati. Medicamentele se folosesc ca usable items via `inventory`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/config_loader.lua` | Incarca config medical |
| `server/database.lua` | CRUD conditii, rani, log |
| `server/conditions.lua` | Logica boli + simptome |
| `server/injuries.lua` | Rani fizice + bleeding |
| `server/transmission.lua` | Contagiune intre jucatori |
| `server/medications.lua` | Items usable medicale |
| `client/main.lua`, `symptoms.lua`, `sneeze.lua`, `injuries.lua` | Efecte si animatii |

## Exports cheie

```lua
exports.medical:GetCharacterConditions(charId)
exports.medical:InfectCharacter(charId, conditionCode)
exports.medical:CureCharacter(charId, conditionCode)
exports.medical:CureAll(charId)
exports.medical:HasCondition(charId, code)        -- bool
exports.medical:GetActiveSymptoms(charId)
exports.medical:IsImmune(charId, code)            -- bool
exports.medical:GetActiveInjuries(charId)
exports.medical:ApplyInjury(charId, injuryCode, severity)
exports.medical:TreatInjury(charId, injuryId)
exports.medical:TreatAllInjuries(charId)
exports.medical:HasInjury(charId, code)
exports.medical:SuppressInjuryBleeding(charId, injuryId)
exports.medical:SuppressSymptom(charId, symptomCode)
```

## Tabele DB

- `medical_conditions` - catalog boli
- `medical_symptoms` - catalog simptome
- `condition_symptoms` - mapping boala -> simptome
- `medical_items` - medicamente
- `character_conditions` - boli active per character
- `character_medication_log` - log administrari
- `character_injuries` - rani active

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
