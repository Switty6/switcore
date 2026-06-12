# Localizare

Toate stringurile vizibile jucatorului stau in fisiere de locale per modul, nu in cod. Limba serverului e aleasa de owner si se aplica intregului server.

## Configurare (owner)

In `server.cfg`:

```cfg
setr sw_locale "ro"   # ro sau en
```

Prioritatea la pornire: convar-ul `sw_locale` > setarea `core.default_language` (panou) > `Config.DEFAULT_LANGUAGE` din `core/config.lua` > `ro`.

Pe public selectia per-jucator e dezactivata (`Config.ALLOW_PLAYER_LANGUAGE = false` in `core/config.lua`). Versiunea premium o activeaza si fiecare jucator isi alege limba cu `/language`, persistata in coloana `players.language`.

## Conventia per modul

Fiecare modul are `locales/ro.lua` si `locales/en.lua` cu namespace-ul de top egal cu numele modulului:

```lua
-- banking/locales/ro.lua
return {
    banking = {
        deposit_success = 'Ai depus {1} cu succes.',
    }
}
```

Inregistrarea se face cu o singura linie la inceputul scriptului de server al modulului:

```lua
exports.core:registerModuleLocales(GetCurrentResourceName())
```

Inregistrarea e merge-safe indiferent de ordinea de pornire si retrimite automat dictionarele catre clientii conectati (debounce 500ms).

## Folosire in Lua

`Sw.T` si `Sw.TP` sunt disponibile in orice modul care include `@core/shared/lib.lua` (client si server):

```lua
-- limba serverului (loguri, broadcast, validari)
exports.notifications:Notify('error', Sw.T('admin.access_denied'), 3000)

-- mesaj adresat unui jucator: foloseste MEREU Sw.TP cu source
ctx.error(Sw.TP(source, 'banking.insufficient_funds'))

-- interpolare cu {1}, {2}
Sw.T('banking.bank_created', name, code)  -- 'Banca creata: {1} ({2})'
```

Pe public `Sw.TP` e identic cu `Sw.T`. Conventia conteaza pentru premium: acolo `Sw.TP` foloseste limba aleasa de jucator, fara nicio modificare la call site.

Nu folosi exportul istoric `exports.core:translate` in cod nou; ghiceste daca primul argument numeric e un source si e ambiguu.

## Folosire in NUI

1. Include helperul inainte de scriptul propriu, in `ui/index.html`:

```html
<script src="nui://core/ui/i18n.js"></script>
```

2. Marcheaza elementele statice cu `data-i18n` (textul ramane fallback), `data-i18n-placeholder` sau `data-i18n-title`:

```html
<button class="btn danger" data-i18n="admin.actions.ban">Baneaza</button>
```

3. Pentru stringuri generate din JS foloseste `SwI18n.t('modul.cheie', arg1)`. La schimbarea dictionarului se emite evenimentul DOM `sw:i18n` pentru re-randare.

4. In Lua-ul de client al modulului, trimite dictionarul la fiecare deschidere de UI si la actualizari:

```lua
local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)
-- si apeleaza pushI18n() inainte de fiecare SendNUIMessage({ action = 'open', ... })
```

UI-urile mereu vizibile (hud, notifications) mai fac un push o data, cu un mic delay, la pornire.

## Reguli

- Pluralele se rezolva prin chei separate alese la call site (`x_one`, `x_many`); nu exista engine de plural.
- Datele din DB sau din setari (nume de banci, denumiri de joburi) raman netraduse; sunt date, nu stringuri de cod.
- Testul `spec/locales/locale_completeness_spec.lua` verifica la CI ca ro si en au aceleasi chei si aceleasi placeholdere; adauga modulul in lista `MIGRATED` cand il migrezi.
