# Modul: admin

**Locatie:** `[switcore]/admin/`
**Dependente:** `core`, `notifications`, `banking`, `characters`, `postgres`
**Descriere:** SwitCore Admin Menu - Player Management, Dev Tools, Vehicle Tools, World.

## Rol

Panou administrativ NUI accesibil cu `/admin` (gated pe permisiuni din `core`). Include: gestiune jucatori (kick, ban, warn, set group), unelte dev (noclip, spectate, dev overlay), tool-uri vehicule (spawn, repair, delete), unelte de lume (weather, time, teleport). Logheaza actiunile in `admin_audit_log`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Permisiuni, audit, routing bucket, comenzi |
| `client/client.lua` | Comanda `/admin`, NUI dispatcher |
| `client/noclip.lua` | Implementare noclip |
| `client/spectate.lua` | Spectate alt jucator |
| `client/devoverlay.lua` | Debug overlay |
| `config.lua` | Configurari UI |
| `ui/` | Panou NUI |

## Exports cheie

```lua
exports.admin:setPlayerBucket(source, bucketId)
exports.admin:getPlayerBucket(source)              -- routing bucket
exports.admin:defineBucketRule(bucketId, rules)
```

## Comenzi

- `/admin` - deschide panoul (client)
- `/devoverlay` - toggle overlay debug (client)
- `/tpm` - teleport to marker (server)

## Tabele DB

- `admin_audit_log` - audit complet al actiunilor admin (cine, ce, cand, target)

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
