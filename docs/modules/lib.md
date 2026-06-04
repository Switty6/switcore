# Biblioteca shared (`Sw`) și Secure Events

În modulul `core` stau două lucruri pe care le folosește restul framework-ului:

1. **`Sw`** - o colecție de funcții ajutătoare, fără stare și fără dependențe, disponibile peste tot.
2. **`Sw.SecureEvent`** - un mod mai sigur de a înregistra net events, care scapă fiecare handler de pe server de codul repetitiv.

Unde le găsești:
- [`core/shared/lib.lua`](../../[switcore]/core/shared/lib.lua) - `Sw` și motorul de validare
- [`core/server/ratelimit.lua`](../../[switcore]/core/server/ratelimit.lua) - limitatorul de cereri
- [`core/server/secure.lua`](../../[switcore]/core/server/secure.lua) - `Sw.SecureEvent`

---

## Cum aduci biblioteca într-un modul

În `fxmanifest.lua`-ul modulului tău incluzi fișierele din `core` cu prefixul `@core/...`. Contează ordinea: `lib.lua` (shared) trebuie să se încarce înaintea lui `secure.lua` (server), fiindcă al doilea se bazează pe primul.

```lua
shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/callbacks.lua'
}
```

Așa, `Sw` ajunge un global pe care îl ai la îndemână în resursa ta, și pe client și pe server (funcțiile din `lib.lua`); `Sw.SecureEvent` e doar pe server.

Nu trebuie să-ți faci griji cu ordinea de pornire: `core` are grijă singur să pornească după `postgres` și `settings`, așa că atunci când rulează handlerele tale, exporturile lui (`hasPermission`, `checkRateLimit`) sunt deja pregătite.

---

## `Sw.SecureEvent(name, opts, handler)`

Ia tot ce scrii la început de handler și îl strânge într-un singur loc. Înainte arăta așa:

```lua
RegisterNetEvent('clothing:buyItem', function(storeItemId, texture)
    local source = source
    local character = exports.characters:getActiveCharacter(source)
    if not character then return end
    storeItemId = tonumber(storeItemId)
    if not storeItemId then return end
    -- restul logicii
end)
```

Cu `Sw.SecureEvent` declari ce ai nevoie și primești totul gata verificat:

```lua
Sw.SecureEvent('clothing:buyItem', {
    character = true,
    rateLimit = { max = 5, window = 2000 },
    args = {
        { name = 'storeItemId', type = 'int', min = 1 },
        { name = 'texture',     type = 'int', min = 0, optional = true },
    },
}, function(ctx)
    -- ai deja: ctx.source, ctx.character, ctx.args.storeItemId, ctx.args.texture
end)
```

### Ce poți cere prin `opts`

| Opțiune | Tip | La ce e |
|---------|-----|---------|
| `permission` | string | Permisiunea de care e nevoie (verificată cu `exports.core:hasPermission`). |
| `character` | bool | Dacă e `true`, jucătorul trebuie să aibă personaj activ; îl primești în `ctx.character`. |
| `args` | table | Regulile după care se validează argumentele (vezi mai jos). |
| `rateLimit` | table | `{ max, window }` - câte cereri sunt permise într-o fereastră (în ms). |
| `permissionMessage` | string | Mesajul afișat când lipsește permisiunea. |
| `characterMessage` | string | Mesajul afișat când nu există personaj activ. |
| `rateLimitMessage` | string | Mesajul afișat când jucătorul trimite prea des. |
| `silent` | bool | Dacă e `true`, la eșec doar se oprește, fără să trimită vreo notificare. |

Verificările se fac pe rând, în ordinea asta: **rate-limit → permisiune → validare argumente → personaj**. La prima care pică, handlerul nici nu mai e apelat, iar jucătorul primește o notificare de eroare (afară de cazul în care ai pus `silent`).

Dacă nu ai nevoie de nimic special, poți trece direct funcția în loc de `opts`:

```lua
Sw.SecureEvent('modul:ping', function(ctx) ctx.success('pong') end)
```

### Ce primești în `ctx`

Handlerul e apelat cu un singur argument, `ctx`, în care ai tot ce-ți trebuie:

| Câmp | Ce conține |
|------|------------|
| `ctx.source` | Sursa jucătorului. |
| `ctx.character` | Personajul activ (doar dacă ai cerut `opts.character = true`). |
| `ctx.args` | Argumentele deja validate, pe care le iei și după poziție (`ctx.args[1]`) și după nume (`ctx.args.storeItemId`). |
| `ctx.notify(kind, msg, duration)` | Trimite o notificare (`'success'`, `'error'`, `'info'` etc.). |
| `ctx.error(msg, duration)` | Pe scurt, o notificare de eroare. |
| `ctx.success(msg, duration)` | Pe scurt, o notificare de succes. |

---

## Validarea argumentelor (`Sw.ValidateArgs`)

`Sw.SecureEvent` o folosește din spate prin `opts.args`, dar o poți chema și singur.

Fiecare regulă verifică un argument, în ordinea în care vin:

```lua
{
    { name = 'storeItemId', type = 'int', min = 1 },
    { name = 'texture',     type = 'int', min = 0, optional = true, default = 0 },
    { name = 'outfitName',  type = 'string', minLen = 1, maxLen = 50 },
    { name = 'method',      type = 'string', oneOf = { 'cash', 'bank' } },
}
```

| Cheie | Pentru | Ce face |
|-------|--------|---------|
| `type` | toate | `'int'`, `'number'`, `'string'`, `'boolean'`, `'table'` sau `'any'`. |
| `optional` | toate | Dacă e `true`, valoarea poate lipsi (se ia `default`, dacă l-ai pus). |
| `default` | toate | Ce valoare se folosește când argumentul lipsește și e opțional. |
| `min` / `max` | `int`, `number` | Limitele între care trebuie să fie numărul. |
| `minLen` | `string` | Lungimea minimă (măsurată după ce se taie spațiile). |
| `maxLen` | `string` | Textul se **taie** la lungimea asta, nu e considerat eroare. |
| `oneOf` | toate | Lista de valori acceptate. |

La `int` și `number` se face conversia cu `tonumber`, așa că un `"5"` venit de la client devine `5`.

```lua
local ok, result = Sw.ValidateArgs({ '12', 'tshirt' }, schema)
-- dacă e ok: result = { 12, 'tshirt', storeItemId = 12, ... }
-- dacă nu: ok = false, iar result e mesajul de eroare (text)
```

---

## Funcțiile `Sw`

Le ai și pe client, și pe server.

| Funcție | Ce face |
|---------|---------|
| `Sw.Trim(s)` | Taie spațiile de la capete. Merge și pe ce nu e text. |
| `Sw.Truncate(s, n)` | Scurtează textul la `n` caractere. |
| `Sw.IsBlank(s)` | `true` dacă e `nil` sau doar spații. |
| `Sw.Round(n, decimals)` | Rotunjește (implicit fără zecimale). |
| `Sw.Clamp(n, min, max)` | Ține numărul între cele două limite. |
| `Sw.FormatMoney(amount, symbol)` | `Sw.FormatMoney(12345, '$')` → `'$12,345'`. |
| `Sw.TableContains(tbl, value)` | `true` dacă valoarea se află în tabel. |
| `Sw.TableCount(tbl)` | Numără câte elemente are tabelul (și cele cu chei text). |
| `Sw.DeepCopy(tbl)` | Face o copie completă, pe toate nivelurile. |

---

## Limitatorul de cereri, folosit direct

`Sw.SecureEvent` îl pornește singur prin `opts.rateLimit`, dar îl poți chema și pe cont propriu, când ai nevoie de altceva:

```lua
if not exports.core:checkRateLimit(source, 'cheie_unica', 5, 1000) then
    return -- jucătorul a trimis prea des în ultima secundă
end
```

Merge pe o fereastră glisantă, ținută separat pentru fiecare pereche `(source, cheie)`. Când jucătorul pleacă de pe server (`playerDropped`), starea lui se șterge singură.
