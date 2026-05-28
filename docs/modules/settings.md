# Modul: settings

**Locatie:** `[switcore]/settings/`
**Dependente:** `postgres`
**Descriere:** Configurare centralizata key-value (cu typing) stocata in baza de date. Inlocuieste `config.lua` static.

## Rol

Toate modulele citesc setarile lor (preturi, coords, tabele JSON, flag-uri) din tabelul `settings` via acest modul. Modulele isi fac seed propriu la pornire (`INSERT ... ON CONFLICT DO NOTHING`), iar valorile pot fi modificate live prin `settings-panel`. Cache local in memorie pe server, cu `ReloadSettings` cand admin schimba valori.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Cache, getters tipizati, persistenta |
| `client/client.lua` | Sync minimal pentru flag-uri client-side |
| `schema.sql` | Tabel `settings` |
| `ui/` | UI minimal in joc (folosit principal panoul Node.js separat) |

## Exports cheie

```lua
exports.settings:IsReady()                       -- bool
exports.settings:GetSetting(key, default)        -- string
exports.settings:GetSettingNumber(key, default)  -- number
exports.settings:GetSettingBool(key, default)    -- bool
exports.settings:GetSettingJSON(key, default)    -- table
exports.settings:GetSettingList(key)             -- array
exports.settings:SetSetting(key, value)          -- bool
exports.settings:ReloadSettings()
```

## Tabele DB

- `settings` - `key` (PK), `value`, `description`, `updated_at`

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
