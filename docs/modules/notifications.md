# Modul: notifications

**Locatie:** `[switcore]/notifications/`
**Dependente:** `core`, `settings`
**Descriere:** Sistem de notificari NUI pentru SwitCore (success/error/info/warning + bani).

## Rol

Singura cale standardizata de a afisa notificari toast in framework. Apelat fie via `TriggerClientEvent('switcore:notify', src, type, msg, duration)` de pe server, fie direct prin export pe client. Are si o varianta speciala pentru afisarea castigurilor/pierderilor financiare. Suporta localizare prin `locales/`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Reta event `switcore:notify` catre client |
| `client/client.lua` | Mesageria NUI |
| `config.lua` | Durate implicite, pozitionare |
| `locales/` | Traduceri |
| `ui/` | Toast overlay |

## Exports cheie

```lua
exports.notifications:Notify(type, message, duration)
exports.notifications:NotifyCash(amount, currencyCode, description)
```

## Evenimente

```lua
TriggerClientEvent('switcore:notify', source, type, message, duration)
-- type: 'success' | 'error' | 'info' | 'warning'
```

## Tabele DB

Niciuna.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
