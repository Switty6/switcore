# Modul: proximity

**Locatie:** `[switcore]/proximity/`
**Dependente:** `settings`
**Descriere:** Sistem de interactiuni bazate pe proximitate (NUI overlay).

## Rol

Folosit de aproape toate modulele gameplay (banking, inventory, shops, jobs, garages, showroom, mecanic etc.) pentru a inregistra puncte/zone interactive in lume. Cand jucatorul intra in raza si apasa tasta de interactiune, se ruleaza un callback. Suporta interactiuni statice (coordonate fixe), pe entitati, pe modele si zone (triangle/rectangle).

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Inregistrare interactiuni statice partajate |
| `client.lua` | Detectie proximitate, NUI overlay |
| `config.lua` | Setari tasta, distante implicite |
| `ui/` | Overlay-ul NUI cu prompt-ul de interactiune |

## Exports cheie

```lua
exports.proximity:AddInteraction(coords, distance, label, callback)
exports.proximity:AddEntityInteraction(entity, distance, label, callback)
exports.proximity:AddModelInteraction(model, distance, label, callback)
exports.proximity:AddTriangleZone(points, label, callback)
exports.proximity:AddRectangleZone(min, max, label, callback)
exports.proximity:RemoveInteraction(id)
exports.proximity:GetCurrentInteraction()
exports.proximity:IsNearInteraction()
exports.proximity:AddStaticInteraction(coords, distance, label, callback)
exports.proximity:AddStaticEntityInteraction(...)
exports.proximity:AddStaticModelInteraction(...)
exports.proximity:AddStaticTriangleZone(...)
exports.proximity:AddStaticRectangleZone(...)
```

## Tabele DB

Niciuna.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
