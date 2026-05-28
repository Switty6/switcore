# Modul: postgres

**Locatie:** `[switcore]/postgres/`
**Dependente:** niciuna (resursa Node.js)
**Descriere:** Conector PostgreSQL pentru FiveM, expune un pool `pg` reutilizabil de toate celelalte module.

## Rol

Este modulul de baza al framework-ului. Initializeaza pool-ul de conexiuni PostgreSQL la pornirea serverului si ofera API-uri generice de query (SELECT/INSERT/UPDATE/DELETE) si tranzactii. Aplica de asemenea fisierele `schema.sql` ale resurselor care depind de el.

## Fisiere principale

| Fisier | Rol |
|--------|-----|
| `server.js` | Pool initialization, API public, schema autoloader |
| `init.js` | Bootstrap pool si config |
| `config.js` / `config.local.js` | Date conectare DB |
| `check_dependencies.js` | Verifica pachetele npm |

## Exports cheie

```lua
exports.postgres:query(sql, params)        -- result async
exports.postgres:queryOne(sql, params)     -- row|nil
exports.postgres:queryAll(sql, params)     -- rows[]
exports.postgres:insert(sql, params)
exports.postgres:update(sql, params)
exports.postgres:delete(sql, params)
exports.postgres:transaction(callback)
exports.postgres:isReady()                 -- bool
exports.postgres:applySchema(resourceName)
exports.postgres:applySchemasAll()
exports.postgres:pool()                    -- raw pg pool
```

## Tabele DB

Nu creeaza tabele proprii. Aplica `schema.sql` din alte resurse la pornire.

---

> Documentatie completa: TODO - acest stub urmeaza sa fie extins post-v1.0.0.
