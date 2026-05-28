# Modul: loadscreen

**Locatie:** `[switcore]/loadscreen/`
**Dependente:** niciuna
**Descriere:** Loading screen custom pentru SwitCore (UI HTML + audio intro).

## Rol

Resursa de tip `loadscreen` afisata in timpul conectarii jucatorului la server, inainte de a intra in joc. Foloseste `loadscreen_manual_shutdown 'yes'` pentru ca lockdown-ul UI-ului sa fie controlat din `client.lua` (de obicei dupa ce `core`/`characters` sunt gata). Include logo SVG, fundal stilizat si jingle audio.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `client/client.lua` | Inchide manual loadscreen-ul la momentul potrivit |
| `ui/index.html`, `ui/style.css`, `ui/script.js` | UI loadscreen |
| `ui/logo.svg`, `ui/audio/intro.wav` | Branding & sound |
| `locales/` | Texte traduse pe limbi |

## Exports cheie

Nu expune exports - functioneaza pasiv prin declaratia `loadscreen 'ui/index.html'` din `fxmanifest`.

## Tabele DB

Niciuna.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
