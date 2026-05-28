# Modul: blips

**Locatie:** `[switcore]/blips/`
**Dependente:** `settings`, `banking`
**Descriere:** Blips si markere 3D pentru locatii (banci, magazine, garaje, joburi, etc.).

## Rol

Manager centralizat al blip-urilor pe harta. Server-ul trimite configuratia (din `settings` + locatii dinamice ca banci/magazine) catre client la connect, iar client-ul le instantiaza si le actualizeaza. Elimina nevoia ca fiecare modul sa-si gestioneze propriile blip-uri.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Agrega blip-urile, raspunde la `blips:server:getConfig` |
| `client/client.lua` | Instantiaza blip-urile via native FiveM |

## Exports cheie

Modulul nu expune exports publice in `fxmanifest`. Modulele care vor sa adauge blip-uri o fac prin `settings` (configuratia centralizata).

## Evenimente importante

```lua
RegisterNetEvent('blips:server:getConfig')  -- client cere config, server raspunde
```

## Tabele DB

Niciuna - foloseste `settings` pentru config.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
