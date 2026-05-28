# Modul: player-data

**Locatie:** `[gameplay]/player-data/`
**Dependente:** niciuna (resursa CFX default)
**Descriere:** Resursa standard Cfx.re pentru stocarea identificatorilor de jucator (`cfx.re/playerData.v1alpha1`).

## Rol

Resursa minimalista a Cfx ce mentine in memorie identificatorii jucatorilor conectati (license, steam, discord, etc.) si ii expune altor resurse prin provider standard. Nu se modifica - este un building block folosit de `core` la `playerConnecting`/`playerJoining` pentru a accesa identifierele.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server.lua` | Stocheaza si expune identifierele jucatorilor |
| `fxmanifest.lua` | Declara `provides 'cfx.re/playerData.v1alpha1'` |

## Exports cheie

Nu expune exports custom - functioneaza prin sistemul `provides` al FiveM. `core` consuma datele via `GetPlayerIdentifiers(source)` standard.

## Tabele DB

Nu foloseste baza de date - stocaj exclusiv in memorie.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
