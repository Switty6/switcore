# Modul: interiors

**Locatie:** `[switcore]/interiors/`
**Dependente:** niciuna
**Descriere:** Sistem dinamic de incarcare a interioarelor GTA V (IPL-uri).

## Rol

Modul exclusiv client-side care expune un API pentru inregistrarea si fortarea incarcarii interioarelor (apartamente, magazine, dealerships, etc.). Folosit de `showroom`, `garages`, eventuale apartamente sau alte resurse care au nevoie de un IPL activ. Foloseste native-uri precum `GetInteriorAtCoords`, `RefreshInterior`, `EnableInteriorProp`.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `client/client.lua` | Manager interioare, registry, force-load |

## Exports cheie

```lua
exports.interiors:RegisterInterior(name, coords, props)
exports.interiors:UnregisterInterior(name)
exports.interiors:ForceLoadInterior(name)
exports.interiors:IsInteriorLoaded(name)   -- bool
```

## Tabele DB

Niciuna - functioneaza pur client-side.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
