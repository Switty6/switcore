# Modul: needs

**Locatie:** `[switcore]/needs/`
**Dependente:** `core`, `postgres`, `characters`, `inventory`, `notifications`, `settings`
**Descriere:** Sistem hunger & thirst pentru SwitCore.

## Rol

Mentine si scade in timp foamea/setea fiecarui character. Persistenta prin tabelul de stats al `characters` (sau direct in `character_stats`). Consuma items din `inventory` (mancare/bautura) prin `RegisterUsableItem`. Trimite notificari critice cand valorile sunt scazute si poate aplica damage.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Tick loop, scadere periodica, sync DB |
| `client/client.lua` | UI sync, efecte vizuale la valori critice |

## Exports cheie

```lua
exports.needs:GetHunger(source)              -- 0..100
exports.needs:GetThirst(source)              -- 0..100
exports.needs:SetHunger(source, value)
exports.needs:SetThirst(source, value)
exports.needs:AddHunger(source, delta)
exports.needs:AddThirst(source, delta)
```

## Tabele DB

Foloseste tabelele de stats din `characters` (nu are schema proprie).

## Setari relevante

- `needs.hunger.decay_rate` - viteza scadere foame
- `needs.thirst.decay_rate` - viteza scadere sete
- `needs.damage_threshold` - prag la care incepe damage-ul

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
