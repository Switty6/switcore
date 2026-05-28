# Modul: government

**Locatie:** `[switcore]/government/`
**Dependente:** `postgres`, `settings`, `core`, `characters`, `banking`, `notifications`
**Descriere:** SwitCore Government System - vistierie, legi, partide, alegeri.

## Rol

Implementeaza un guvern in joc: cont de vistierie (treasury) prin `banking`, propuneri si voturi pentru legi, partide politice cu membri, alegeri cu candidati si voturi. Permite "venituri" (taxe, amenzi) si "cheltuieli" (salarii politie, EMS, etc.) cu tracking pe categorii.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/database.lua` | CRUD legi, partide, alegeri, buget |
| `server/government_manager.lua` | Logica treasury, voting, legi active |
| `server/exports.lua` | API public |
| `server/callbacks.lua` | Handlere NUI |
| `server/server.lua` | Init, comenzi |
| `client/client.lua` | UI government |

## Exports cheie

```lua
exports.government:AddIncome(amount, currencyCode, description, category, characterId)
exports.government:AddExpense(amount, currencyCode, description, category, characterId)
exports.government:GetActiveLaws()              -- laws[]
exports.government:GetTreasuryBalance()         -- number
exports.government:IsGovMember(source)          -- bool
```

## Tabele DB

- `government_law_proposals` - propuneri de lege
- `government_law_votes` - voturi pe propuneri
- `government_laws` - legi active
- `government_budget_log` - log buget (venituri/cheltuieli)
- `government_parties` - partide politice
- `government_party_members` - membri partide
- `government_elections` - alegeri
- `government_election_candidates` - candidati
- `government_election_votes` - voturi alegeri

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
