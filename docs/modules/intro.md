# Modul: intro

**Locatie:** `[switcore]/intro/`
**Dependente:** `core`
**Descriere:** First-join cinematic overlay cu logo reveal si tagline.

## Rol

La primul join al unui jucator (sau prin trigger explicit), afiseaza un overlay cinematic NUI cu logo-ul SwitCore si un tagline. Folosit pentru branding si onboarding. Trigger-ul vine de pe server (`core` semnaleaza primul login pe baza datelor din `player-data`/DB).

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server/server.lua` | Decide cand sa triggereze intro-ul (first join) |
| `client/client.lua` | Afiseaza/inchide NUI, gestioneaza camera |
| `ui/index.html`, `ui/style.css`, `ui/script.js` | Animatia cinematic |

## Exports cheie

Nu expune exports publice. Comunicarea se face prin evenimente interne `intro:*`.

## Tabele DB

Niciuna - logica de "first join" foloseste flag-ul din `core`/`characters`.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
