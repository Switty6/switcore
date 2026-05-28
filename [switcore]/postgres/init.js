const crypto = require('crypto');

async function checkConnection(pool) {
    try {
        const result = await pool.query('SELECT NOW() as now, version() as version');
        console.log('[POSTGRES] ✓ Conectat cu succes la baza de date PostgreSQL');
        console.log(`[POSTGRES] ✓ Timp baza de date: ${result.rows[0].now}`);
        console.log(`[POSTGRES] ✓ Versiune PostgreSQL: ${result.rows[0].version.split(',')[0]}`);
        return true;
    } catch (error) {
        console.error('[POSTGRES] ✗ Eșec la conectarea la baza de date:', error.message);
        return false;
    }
}

async function ensureMigrationsTable(pool) {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS _schema_migrations (
            id SERIAL PRIMARY KEY,
            resource_name VARCHAR(255) NOT NULL,
            schema_hash VARCHAR(64) NOT NULL,
            applied_at TIMESTAMP DEFAULT NOW() NOT NULL,
            CONSTRAINT unique_resource_schema UNIQUE (resource_name)
        )
    `);
}

function hashContent(content) {
    return crypto.createHash('md5').update(content).digest('hex');
}

async function isSchemaApplied(pool, resourceName, schemaHash) {
    const result = await pool.query(
        'SELECT schema_hash FROM _schema_migrations WHERE resource_name = $1',
        [resourceName]
    );
    if (result.rows.length === 0) {
        return false;
    }
    return result.rows[0].schema_hash === schemaHash;
}

async function markSchemaApplied(pool, resourceName, schemaHash) {
    await pool.query(`
        INSERT INTO _schema_migrations (resource_name, schema_hash, applied_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (resource_name)
        DO UPDATE SET schema_hash = $2, applied_at = NOW()
    `, [resourceName, schemaHash]);
}

async function applySchemaForResource(pool, resourceName) {
    const schemaContent = LoadResourceFile(resourceName, 'schema.sql');
    if (!schemaContent || schemaContent.trim() === '') {
        return false;
    }

    const schemaHash = hashContent(schemaContent);

    const alreadyApplied = await isSchemaApplied(pool, resourceName, schemaHash);
    if (alreadyApplied) {
        console.log(`[POSTGRES] ✓ Schema pentru '${resourceName}' este la zi (skip)`);
        return true;
    }

    try {
        await pool.query(schemaContent);
        await markSchemaApplied(pool, resourceName, schemaHash);
        console.log(`[POSTGRES] ✓ Schema aplicată cu succes pentru '${resourceName}'`);
        return true;
    } catch (error) {
        console.error(`[POSTGRES] ✗ Eroare la aplicarea schemei pentru '${resourceName}':`, error.message);
        return false;
    }
}

const schemaCache = new Map();

function loadSchemaCached(resName) {
    if (schemaCache.has(resName)) return schemaCache.get(resName);
    const content = LoadResourceFile(resName, 'schema.sql');
    schemaCache.set(resName, content);
    return content;
}

function getResourceDependencyOrder() {
    const resources = [];
    const dependencies = {};

    const numResources = GetNumResources();
    for (let i = 0; i < numResources; i++) {
        const resName = GetResourceByFindIndex(i);
        if (!resName) continue;

        const schemaContent = loadSchemaCached(resName);
        if (!schemaContent || schemaContent.trim() === '') continue;

        resources.push(resName);

        const manifest = LoadResourceFile(resName, 'fxmanifest.lua');
        const deps = [];
        if (manifest) {
            const depsMatch = manifest.match(/dependencies\s*\{([^}]*)\}/);
            if (depsMatch) {
                const depsStr = depsMatch[1];
                const depNames = depsStr.match(/'([^']+)'/g);
                if (depNames) {
                    depNames.forEach(d => {
                        const depName = d.replace(/'/g, '');
                        // postgres ar crea ciclu - e mereu Tier 1, deja aplicat
                        if (depName !== 'postgres') {
                            deps.push(depName);
                        }
                    });
                }
            }
        }
        dependencies[resName] = deps;
    }

    const sorted = [];
    const visited = new Set();
    const visiting = new Set();

    function visit(resName) {
        if (visited.has(resName)) return;
        if (visiting.has(resName)) {
            console.warn(`[POSTGRES] ⚠ Dependență circulară detectată pentru '${resName}', se ignoră`);
            return;
        }

        visiting.add(resName);

        const deps = dependencies[resName] || [];
        for (const dep of deps) {
            if (resources.includes(dep)) {
                visit(dep);
            }
        }

        visiting.delete(resName);
        visited.add(resName);
        sorted.push(resName);
    }

    for (const res of resources) {
        visit(res);
    }

    return sorted;
}

async function applySchemasAutomatically(pool) {
    console.log('[POSTGRES] Verificare schema-uri SQL...');

    await ensureMigrationsTable(pool);

    const orderedResources = getResourceDependencyOrder();

    if (orderedResources.length === 0) {
        console.log('[POSTGRES] Nu s-au găsit resurse cu schema.sql');
        return;
    }

    console.log(`[POSTGRES] Resurse cu schema.sql găsite (${orderedResources.length}): ${orderedResources.join(', ')}`);

    let applied = 0;
    let skipped = 0;
    let failed = 0;

    for (const resourceName of orderedResources) {
        const schemaContent = loadSchemaCached(resourceName);
        if (!schemaContent) continue;

        const schemaHash = hashContent(schemaContent);
        const alreadyApplied = await isSchemaApplied(pool, resourceName, schemaHash);

        if (alreadyApplied) {
            skipped++;
            continue;
        }

        try {
            await pool.query(schemaContent);
            await markSchemaApplied(pool, resourceName, schemaHash);
            console.log(`[POSTGRES] ✓ Schema aplicată: '${resourceName}'`);
            applied++;
        } catch (error) {
            console.error(`[POSTGRES] ✗ Eroare schema '${resourceName}':`, error.message);
            failed++;
        }
    }

    console.log(`[POSTGRES] Schema-uri: ${applied} aplicate, ${skipped} la zi, ${failed} erori`);
}

async function initialize(pool) {
    console.log('[POSTGRES] Verificare conexiune...');

    const connected = await checkConnection(pool);
    if (!connected) {
        console.error('[POSTGRES] Nu s-a putut conecta la baza de date. Verifică config.js');
        return false;
    }

    await applySchemasAutomatically(pool);

    console.log('[POSTGRES] ✓ Baza de date este gata de utilizare');
    return true;
}

module.exports = {
    initialize,
    checkConnection,
    applySchemaForResource,
    applySchemasAutomatically
};

