# Modul: welcome

**Locatie:** `[switcore]/welcome/`
**Dependente:** `core`, `notifications`
**Descriere:** Camera cinematic + notificari de bun venit la primul spawn.

## Rol

Dupa ce intro-ul s-a terminat si jucatorul intra in joc cu un character, modulul orchestreaza o camera cinematic scurta peste harta si trimite notificari de bun venit prin sistemul `notifications`. Activat de evenimentul `switcore:characterLoaded`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Asculta `switcore:characterLoaded` si declanseaza welcome flow |
| `client/client.lua` | Camera cinematic + apel `notifications` |

## Evenimente importante

```lua
RegisterNetEvent('switcore:characterLoaded')  -- declanseaza welcome
```

## Exports cheie

Nu expune exports publice.

## Tabele DB

Niciuna.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
