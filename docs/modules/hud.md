# Modul: hud

**Locatie:** `[switcore]/hud/`
**Dependente:** `core`, `characters`, `banking`, `settings`
**Descriere:** HUD custom pentru SwitCore - health, armor, hunger, thirst, cash, timp, speedometer.

## Rol

Inlocuieste HUD-ul nativ GTA cu un overlay NUI care agrega informatii din mai multe module: viata/armor (game native), needs (`needs`), cash (`banking`), data/ora (`settings` sau ceas server), vitezometru (calculat pe client), indicatoare auto (combustibil din `vehicles`).

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Sync periodic catre clienti (cash, etc.) |
| `client/client.lua` | Render loop, fetch valori, push catre NUI |
| `config.lua` | Componente activate, layout |
| `ui/` | HTML overlay |

## Exports cheie

```lua
exports.hud:ShowHUD()
exports.hud:HideHUD()
exports.hud:SetHUDComponent(component, visible)
```

## Tabele DB

Niciuna - citeste date din alte module.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
