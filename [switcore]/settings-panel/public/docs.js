(function () {
    'use strict';

    const token    = localStorage.getItem('sc_token');
    const username = localStorage.getItem('sc_username') || 'Admin';
    if (!token) { window.location.href = '/'; return; }

    document.getElementById('user-name').textContent   = username;
    document.getElementById('user-avatar').textContent = username.charAt(0).toUpperCase();
    document.getElementById('btn-logout').addEventListener('click', () => {
        localStorage.removeItem('sc_token');
        localStorage.removeItem('sc_username');
        window.location.href = '/';
    });

    const DOCS = [
        {
            id: 'architecture',
            title: 'Arhitectură',
            icon: '<i data-lucide="building"></i>',
            overview: `SwitCore este un framework modular pentru FiveM, construit pe Lua 5.4 (server/client) și PostgreSQL. Fiecare modul este un resource independent cu exports bine definite - comunicarea între scripturi se face exclusiv prin <code>exports</code> și <code>TriggerEvent</code>, fără dependențe circulare.`,
            sections: [
                {
                    type: 'tree',
                    title: 'Structura resurselor',
                    content: `[switcore]/
├── core/           - Lifecycle jucători, grupuri, permisiuni
├── characters/     - Sistem multi-personaj, creator, stats
├── inventory/      - Inventar weight-based, iteme, hotbar
├── banking/        - Conturi, tranzacții, valute, ATM/bancă
├── notifications/  - Sistem de notificări NUI
├── hud/            - HUD: viteză, cash, stats, oră
├── proximity/      - Zone de interacțiune apropiată
├── needs/          - Foame/sete, decay, damage
├── settings/       - Config DB key-value (dependință globală)
└── settings-panel/ - Panou web extern (Node.js/Express)`
                },
                {
                    type: 'info',
                    title: 'Ordinea de pornire (server.cfg)',
                    content: `<code>postgres → settings → core → characters → inventory → banking → proximity → notifications → hud → needs</code><br><br>Fiecare script care folosește <code>settings</code> trebuie să aștepte <code>exports.settings:IsReady()</code> înainte de a citi configurări.`
                },
                {
                    type: 'info',
                    title: 'Pattern de așteptare settings',
                    content: `<pre><code>-- La începutul oricărui script dependent de settings:
CreateThread(function()
    while not exports.settings:IsReady() do
        Wait(100)
    end
    -- acum poți citi settings
    local val = exports.settings:GetSettingNumber('core.playtime_update_interval', 60)
end)</code></pre>`
                }
            ]
        },
        {
            id: 'core',
            title: 'Core',
            icon: '<i data-lucide="settings"></i>',
            overview: `Modulul <strong>core</strong> gestionează ciclul de viață al jucătorilor: autentificare, asociere cu caractere, grupuri și permisiuni, tracking playtime. Este prima dependință a tuturor celorlalte module după <code>settings</code>.`,
            sections: [
                {
                    type: 'exports',
                    title: 'Exports server',
                    rows: [
                        { name: 'GetPlayerData(source)',       returns: 'table / nil',   desc: 'Returnează datele complete ale jucătorului (identifiers, group, characterId activ).' },
                        { name: 'GetCharacterData(source)',    returns: 'table / nil',   desc: 'Returnează datele personajului selectat curent (name, job, stats etc.).' },
                        { name: 'GetPlayerGroup(source)',      returns: 'string',        desc: 'Returnează grupul jucătorului (ex: "admin", "user").' },
                        { name: 'HasPermission(source, perm)', returns: 'boolean',       desc: 'Verifică dacă jucătorul are o permisiune specifică.' },
                    ]
                },
                {
                    type: 'events',
                    title: 'Evenimente server',
                    rows: [
                        { name: 'switcore:playerLoaded',     side: 'Server',  desc: 'Tras când un jucător s-a conectat și datele lui sunt gata.' },
                        { name: 'switcore:characterSelected',side: 'Server',  desc: 'Tras când jucătorul selectează un personaj din creator/lista de personaje. Payload: source, characterId.' },
                        { name: 'switcore:characterLoaded',  side: 'Server',  desc: 'Tras după ce personajul a fost complet inițializat și spawn-uit.' },
                        { name: 'switcore:playerDropped',    side: 'Server',  desc: 'Tras la deconectarea jucătorului. Toate modulele salvează starea aici.' },
                    ]
                },
                {
                    type: 'config',
                    title: 'Chei settings',
                    rows: [
                        { key: 'core.playtime_update_interval', default: '60',   desc: 'Intervalul (secunde) la care se salvează playtime-ul în DB.' },
                        { key: 'core.default_language',         default: 'ro',   desc: 'Limba implicită pentru mesajele server-side.' },
                        { key: 'core.log_commands',             default: 'true', desc: 'Dacă se loghează comenzile administrative în consolă.' },
                    ]
                },
                {
                    type: 'example',
                    title: 'Exemplu: Verificare permisiune',
                    code: `-- Server-side
RegisterNetEvent('myResource:server:doAdminAction', function()
    local src = source
    if not exports.core:HasPermission(src, 'admin.manage') then
        TriggerClientEvent('notifications:client:show', src, {
            type    = 'error',
            title   = 'Acces refuzat',
            message = 'Nu ai permisiunea necesară.'
        })
        return
    end
    -- execută acțiunea...
end)`
                }
            ]
        },
        {
            id: 'characters',
            title: 'Characters',
            icon: '<i data-lucide="user"></i>',
            overview: `Sistemul <strong>characters</strong> implementează crearea și gestionarea personajelor multiple per jucător. Include un character creator NUI (multi-step: gen, nume, vârstă), salvarea stats-urilor în JSONB și spawn la coordonate configurabile.`,
            sections: [
                {
                    type: 'exports',
                    title: 'Exports server',
                    rows: [
                        { name: 'getCharacters(citizenId)',           returns: 'table[]',  desc: 'Returnează lista de personaje ale unui jucător după citizenId.' },
                        { name: 'createCharacter(citizenId, data)',   returns: 'table',    desc: 'Creează un personaj nou. `data` = { firstName, lastName, gender, age }.' },
                        { name: 'deleteCharacter(charId)',            returns: 'boolean',  desc: 'Șterge un personaj dacă characters.enable_deletion este true.' },
                        { name: 'updateCharacterStat(charId, k, v)',  returns: 'void',     desc: 'Actualizează o statistică (hunger, thirst, health etc.) în JSONB stats.' },
                        { name: 'getCharacterById(charId)',           returns: 'table/nil',desc: 'Returnează datele complete ale unui personaj după ID.' },
                    ]
                },
                {
                    type: 'events',
                    title: 'Evenimente',
                    rows: [
                        { name: 'characters:client:showCreator',  side: 'Client', desc: 'Deschide NUI-ul de creare personaj.' },
                        { name: 'characters:client:showSelector', side: 'Client', desc: 'Afișează lista de personaje existente.' },
                        { name: 'switcore:characterSelected',     side: 'Server', desc: 'Emis după selectarea unui personaj. Payload: source, characterId.' },
                    ]
                },
                {
                    type: 'config',
                    title: 'Chei settings',
                    rows: [
                        { key: 'characters.max_per_player',         default: '3',                  desc: 'Numărul maxim de personaje per jucător.' },
                        { key: 'characters.min_age',                default: '18',                 desc: 'Vârsta minimă la creare.' },
                        { key: 'characters.max_age',                default: '80',                 desc: 'Vârsta maximă la creare.' },
                        { key: 'characters.enable_deletion',        default: 'true',               desc: 'Permite sau blochează ștergerea personajelor.' },
                        { key: 'characters.first_name_min_length',  default: '2',                  desc: 'Lungime minimă prenume.' },
                        { key: 'characters.first_name_max_length',  default: '20',                 desc: 'Lungime maximă prenume.' },
                        { key: 'characters.spawn_x',                default: '-269.4',             desc: 'Coordonata X de spawn după selectare personaj.' },
                        { key: 'characters.spawn_y',                default: '-955.3',             desc: 'Coordonata Y de spawn.' },
                        { key: 'characters.spawn_z',                default: '31.2',               desc: 'Coordonata Z de spawn.' },
                        { key: 'characters.spawn_heading',          default: '205.8',              desc: 'Heading-ul (direcția) de spawn.' },
                    ]
                },
                {
                    type: 'example',
                    title: 'Exemplu: Obținere personaje jucător',
                    code: `-- Server-side
local citizenId = GetPlayerIdentifierByType(source, 'license')
local characters = exports.characters:getCharacters(citizenId)

for _, char in ipairs(characters) do
    print(char.id, char.first_name, char.last_name)
end`
                }
            ]
        },
        {
            id: 'inventory',
            title: 'Inventory',
            icon: '<i data-lucide="backpack"></i>',
            overview: `Inventarul SwitCore este bazat pe <strong>greutate + sloturi</strong>. Fiecare jucător are un inventar persistent în DB, un hotbar de 5 sloturi vizibil în HUD și un sistem de iteme usable. Drop-urile pe sol sunt sincronizate între toți jucătorii din apropiere.`,
            sections: [
                {
                    type: 'exports',
                    title: 'Exports server',
                    rows: [
                        { name: 'GetInventory(source)',                    returns: 'table',    desc: 'Returnează inventarul complet al jucătorului (items + metadata).' },
                        { name: 'AddItem(source, item, qty, meta)',         returns: 'boolean',  desc: 'Adaugă un item. Verifică greutate și sloturi disponibile.' },
                        { name: 'RemoveItem(source, item, qty)',            returns: 'boolean',  desc: 'Elimină un item. Returnează false dacă nu există suficientă cantitate.' },
                        { name: 'HasItem(source, item, qty)',               returns: 'boolean',  desc: 'Verifică dacă jucătorul are cel puțin `qty` din itemul specificat.' },
                        { name: 'GetItemCount(source, item)',               returns: 'number',   desc: 'Returnează cantitatea totală a unui item din inventar.' },
                        { name: 'RegisterUsableItem(item, callback)',       returns: 'void',     desc: 'Înregistrează un item ca usable. Callback primește source ca argument.' },
                    ]
                },
                {
                    type: 'events',
                    title: 'Evenimente client',
                    rows: [
                        { name: 'inventory:client:update',   side: 'Client', desc: 'Trimis la fiecare modificare a inventarului. Payload: lista de items actualizată.' },
                        { name: 'inventory:client:openUI',   side: 'Client', desc: 'Deschide NUI-ul de inventar.' },
                    ]
                },
                {
                    type: 'config',
                    title: 'Chei settings',
                    rows: [
                        { key: 'inventory.max_weight',            default: '30.0', desc: 'Greutatea maximă a inventarului (kg).' },
                        { key: 'inventory.max_slots',             default: '40',   desc: 'Numărul maxim de sloturi din inventar.' },
                        { key: 'inventory.hotbar_slots',          default: '5',    desc: 'Numărul de sloturi din hotbar (afișate în HUD).' },
                        { key: 'inventory.drop_interaction_range',default: '2.0',  desc: 'Distanța (m) de la care poți ridica un drop de pe jos.' },
                    ]
                },
                {
                    type: 'example',
                    title: 'Exemplu: Item usable - sandwich',
                    code: `-- Server-side, în resources/food/server.lua
exports.inventory:RegisterUsableItem('sandwich', function(source)
    local removed = exports.inventory:RemoveItem(source, 'sandwich', 1)
    if not removed then return end

    exports.needs:AddHunger(source, 40)
    exports.needs:AddThirst(source, 10)

    TriggerClientEvent('notifications:client:show', source, {
        type    = 'success',
        title   = 'Ai mâncat',
        message = 'Foame +40'
    })
end)`
                }
            ]
        },
        {
            id: 'banking',
            title: 'Banking',
            icon: '<i data-lucide="credit-card"></i>',
            overview: `Modulul <strong>banking</strong> implementează un sistem bancar complet: conturi curente și de economii, tranzacții cu istoric, împrumuturi, depozite la termen, valute multiple și rate de schimb dinamice. ATM-urile și băncile sunt locații fizice în lume.`,
            sections: [
                {
                    type: 'exports',
                    title: 'Exports server',
                    rows: [
                        { name: 'GetBalance(charId, currency)',          returns: 'number',   desc: 'Returnează soldul curent pentru o valută (default: USD).' },
                        { name: 'GetCashBalance(charId)',                returns: 'number',   desc: 'Returnează cash-ul din buzunar al personajului.' },
                        { name: 'AddMoney(charId, amount, currency)',    returns: 'boolean',  desc: 'Adaugă bani în contul bancar.' },
                        { name: 'RemoveMoney(charId, amount, currency)', returns: 'boolean',  desc: 'Scade bani. Returnează false dacă soldul e insuficient.' },
                        { name: 'AddCash(charId, amount)',               returns: 'boolean',  desc: 'Adaugă cash în buzunar.' },
                        { name: 'RemoveCash(charId, amount)',            returns: 'boolean',  desc: 'Scade cash din buzunar.' },
                        { name: 'TransferMoney(fromId, toId, amount)',   returns: 'boolean',  desc: 'Transfer între două personaje. Loghează tranzacția dacă banking.log_transactions=true.' },
                    ]
                },
                {
                    type: 'events',
                    title: 'Evenimente client',
                    rows: [
                        { name: 'banking:client:cashData',  side: 'Client', desc: 'Trimis periodic sau la modificare. Payload: { cash, bankBalance, currency }.' },
                        { name: 'banking:client:openATM',   side: 'Client', desc: 'Deschide NUI-ul ATM.' },
                        { name: 'banking:client:openBank',  side: 'Client', desc: 'Deschide NUI-ul bancă (funcții complete).' },
                    ]
                },
                {
                    type: 'config',
                    title: 'Chei settings relevante',
                    rows: [
                        { key: 'banking.log_transactions',                    default: 'true',        desc: 'Loghează toate tranzacțiile în tabelul bank_transactions.' },
                        { key: 'banking.min_transaction_amount',              default: '0.01',        desc: 'Suma minimă per tranzacție.' },
                        { key: 'banking.max_transaction_amount',              default: '999999999.99',desc: 'Suma maximă per tranzacție.' },
                        { key: 'banking.atm_distance',                        default: '1.5',         desc: 'Distanța (m) de interacțiune cu ATM.' },
                        { key: 'banking.inflation_calculation_interval',      default: '3600',        desc: 'Intervalul (secunde) de recalculare a inflației.' },
                        { key: 'banking.dynamic_exchange_rate_update_interval',default: '300',        desc: 'Intervalul (secunde) de actualizare a cursului de schimb.' },
                    ]
                },
                {
                    type: 'example',
                    title: 'Exemplu: Plată serviciu',
                    code: `-- Server-side
RegisterNetEvent('garage:server:payParkingFee', function(fee)
    local src = source
    local charData = exports.core:GetCharacterData(src)
    if not charData then return end

    local ok = exports.banking:RemoveCash(charData.id, fee)
    if not ok then
        TriggerClientEvent('notifications:client:show', src, {
            type = 'error', title = 'Fonduri insuficiente',
            message = ('Ai nevoie de $%s cash.'):format(fee)
        })
        return
    end
    -- continuă cu parcarea...
end)`
                }
            ]
        },
        {
            id: 'needs',
            title: 'Needs',
            icon: '<i data-lucide="utensils"></i>',
            overview: `Modulul <strong>needs</strong> implementează sistemul de foame și sete. Valorile scad periodic în timp (decay), sunt afișate în HUD și provoacă damage când ating 0. Iteme usable (bread, water, burger) sunt înregistrate automat în inventory.`,
            sections: [
                {
                    type: 'exports',
                    title: 'Exports server',
                    rows: [
                        { name: 'GetHunger(source)',         returns: 'number',  desc: 'Returnează valoarea curentă a foamei (0–100).' },
                        { name: 'GetThirst(source)',         returns: 'number',  desc: 'Returnează valoarea curentă a setei (0–100).' },
                        { name: 'SetHunger(source, value)',  returns: 'void',    desc: 'Setează foamea la o valoare exactă (clamp 0–100).' },
                        { name: 'SetThirst(source, value)',  returns: 'void',    desc: 'Setează setea la o valoare exactă.' },
                        { name: 'AddHunger(source, amount)', returns: 'void',    desc: 'Adaugă la foame (pozitiv = crește, negativ = scade).' },
                        { name: 'AddThirst(source, amount)', returns: 'void',    desc: 'Adaugă la sete.' },
                    ]
                },
                {
                    type: 'events',
                    title: 'Evenimente',
                    rows: [
                        { name: 'switcore:needsUpdate',        side: 'Client', desc: 'Emis la fiecare tick de decay. Payload: hunger (number), thirst (number). HUD-ul ascultă acest eveniment.' },
                        { name: 'needs:client:applyDamage',    side: 'Client', desc: 'Emis când foamea SAU setea e sub threshold. Client scade HP cu damage_amount.' },
                    ]
                },
                {
                    type: 'config',
                    title: 'Chei settings',
                    rows: [
                        { key: 'needs.hunger_decay_rate', default: '0.5',  desc: 'Cât scade foamea per interval de update (unități/tick).' },
                        { key: 'needs.thirst_decay_rate', default: '0.8',  desc: 'Cât scade setea per interval.' },
                        { key: 'needs.damage_threshold',  default: '10.0', desc: 'Sub ce valoare (foame sau sete) se aplică damage.' },
                        { key: 'needs.damage_amount',     default: '2',    desc: 'HP scăzut per tick de damage.' },
                        { key: 'needs.update_interval',   default: '60',   desc: 'Intervalul (secunde) dintre tick-uri de decay.' },
                        { key: 'needs.save_interval',     default: '300',  desc: 'Intervalul (secunde) de salvare a needs în DB.' },
                    ]
                },
                {
                    type: 'example',
                    title: 'Exemplu: Item custom care crește foamea',
                    code: `-- Server-side, în orice resource
CreateThread(function()
    -- Așteaptă inventory să fie gata
    Wait(2000)

    exports.inventory:RegisterUsableItem('pizza', function(source)
        local removed = exports.inventory:RemoveItem(source, 'pizza', 1)
        if not removed then return end

        exports.needs:AddHunger(source, 60)
        exports.needs:AddThirst(source, 5)

        TriggerClientEvent('notifications:client:show', source, {
            type = 'success', title = 'Mmm, pizza!',
            message = 'Foame +60, Sete +5'
        })
    end)
end)`
                }
            ]
        },
        {
            id: 'settings',
            title: 'Settings API',
            icon: '<i data-lucide="wrench"></i>',
            overview: `Modulul <strong>settings</strong> stochează toate configurările runtime în tabelul PostgreSQL <code>settings</code> (key-value TEXT). La pornire, toate cheile sunt citite o dată în memorie (cache). Modificările prin <code>SetSetting</code> actualizează simultan cache-ul și DB-ul. Panoul web de față folosește același API.`,
            sections: [
                {
                    type: 'exports',
                    title: 'Exports server',
                    rows: [
                        { name: 'IsReady()',                         returns: 'boolean', desc: 'True când cache-ul a fost încărcat din DB. Folosit pentru sincronizare la startup.' },
                        { name: 'GetSetting(key, default)',          returns: 'string',  desc: 'Returnează valoarea ca string. Dacă cheia nu există returnează default.' },
                        { name: 'GetSettingNumber(key, default)',    returns: 'number',  desc: 'Returnează valoarea convertită la number.' },
                        { name: 'GetSettingBool(key, default)',      returns: 'boolean', desc: 'Returnează valoarea convertită la boolean ("true"/"1"/"yes" → true).' },
                        { name: 'GetSettingJSON(key, default)',      returns: 'table',   desc: 'Returnează valoarea decodificată din JSON ca table Lua.' },
                        { name: 'SetSetting(key, value)',            returns: 'void',    desc: 'Actualizează o cheie în cache și persistă în DB (upsert).' },
                        { name: 'ReloadSettings()',                  returns: 'void',    desc: 'Forțează re-citirea tuturor cheilor din DB în cache.' },
                    ]
                },
                {
                    type: 'info',
                    title: 'Schema DB',
                    content: `<pre><code>CREATE TABLE IF NOT EXISTS settings (
    key         VARCHAR(100) PRIMARY KEY,
    value       TEXT NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);</code></pre>
Seed-urile sunt inserate cu <code>ON CONFLICT (key) DO NOTHING</code> - valorile modificate de admin nu sunt suprascrise la restart.`
                },
                {
                    type: 'example',
                    title: 'Exemplu: Folosire în propriul resource',
                    code: `-- fxmanifest.lua - adaugă 'settings' la dependencies
dependencies {
    'core',
    'settings',    -- <-- adaugă asta
}

-- server.lua - așteaptă settings, apoi citește
CreateThread(function()
    while not exports.settings:IsReady() do
        Wait(100)
    end

    local maxPlayers = exports.settings:GetSettingNumber('mymod.max_players', 32)
    local debugMode  = exports.settings:GetSettingBool('mymod.debug', false)
    local prefix     = exports.settings:GetSetting('mymod.chat_prefix', '[MOD]')

    print(('Pornit: max=%d debug=%s prefix=%s'):format(maxPlayers, debugMode, prefix))
end)`
                },
                {
                    type: 'example',
                    title: 'Exemplu: Adăugare seed-uri noi',
                    code: `-- În settings/server/server.lua, adaugă în applySchema():
{ 'mymod.max_players', '32',    'Numărul maxim de jucători pentru mymod' },
{ 'mymod.debug',       'false', 'Activează modul debug pentru mymod' },
{ 'mymod.chat_prefix', '[MOD]', 'Prefixul mesajelor de chat' },`
                }
            ]
        }
    ];

    function esc(str) {
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function renderSection(s) {
        switch (s.type) {
            case 'exports':
            case 'events':
            case 'config':
                return `
                <div class="doc-section">
                    <h3 class="doc-section-title">${esc(s.title)}</h3>
                    <div class="doc-table-wrap">
                        <table class="doc-table">
                            <thead><tr>
                                ${s.type === 'exports' ? '<th>Export</th><th>Returnează</th><th>Descriere</th>' : ''}
                                ${s.type === 'events'  ? '<th>Eveniment</th><th>Side</th><th>Descriere</th>' : ''}
                                ${s.type === 'config'  ? '<th>Cheie</th><th>Default</th><th>Descriere</th>' : ''}
                            </tr></thead>
                            <tbody>
                                ${s.rows.map(r => `<tr>
                                    <td><code>${esc(r.name || r.key)}</code></td>
                                    <td><span class="doc-badge">${esc(r.returns || r.side || r.default)}</span></td>
                                    <td>${esc(r.desc)}</td>
                                </tr>`).join('')}
                            </tbody>
                        </table>
                    </div>
                </div>`;

            case 'example':
                return `
                <div class="doc-section">
                    <h3 class="doc-section-title">${esc(s.title)}</h3>
                    <pre class="code-block"><code>${esc(s.code)}</code></pre>
                </div>`;

            case 'tree':
                return `
                <div class="doc-section">
                    <h3 class="doc-section-title">${esc(s.title)}</h3>
                    <pre class="code-block code-block--tree"><code>${esc(s.content)}</code></pre>
                </div>`;

            case 'info':
                return `
                <div class="doc-section">
                    <h3 class="doc-section-title">${esc(s.title)}</h3>
                    <div class="doc-info">${s.content}</div>
                </div>`;

            default:
                return '';
        }
    }

    function renderModule(mod) {
        return `
        <div class="doc-module" id="mod-${mod.id}">
            <div class="doc-module-header">
                <span class="doc-module-icon">${mod.icon}</span>
                <h2 class="doc-module-title">${esc(mod.title)}</h2>
            </div>
            <p class="doc-overview">${mod.overview}</p>
            ${mod.sections.map(renderSection).join('')}
        </div>`;
    }

    let activeId     = 'architecture';
    let searchQuery  = '';

    const navEl = document.getElementById('doc-nav');
    DOCS.forEach(mod => {
        const li  = document.createElement('li');
        li.innerHTML = `
            <button class="group-btn${mod.id === activeId ? ' active' : ''}" data-id="${mod.id}">
                <span class="group-icon">${mod.icon}</span>
                <span class="group-name">${mod.title}</span>
            </button>`;
        navEl.appendChild(li);
    });
    if (window.lucide) lucide.createIcons();

    navEl.addEventListener('click', e => {
        const btn = e.target.closest('[data-id]');
        if (!btn) return;
        setActive(btn.dataset.id);
    });

    function setActive(id) {
        activeId = id;
        navEl.querySelectorAll('.group-btn').forEach(b => b.classList.toggle('active', b.dataset.id === id));
        const mod = DOCS.find(m => m.id === id);
        document.getElementById('breadcrumb-current').textContent = mod ? mod.title : id;
        renderContent();
        document.querySelector('.docs-content').scrollTop = 0;
    }

    function renderContent() {
        const contentEl = document.getElementById('doc-content');

        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            const results = [];

            DOCS.forEach(mod => {
                const modMatch = mod.title.toLowerCase().includes(q) || mod.overview.toLowerCase().includes(q);
                const sectionMatches = mod.sections.filter(s => {
                    const text = JSON.stringify(s).toLowerCase();
                    return text.includes(q);
                });

                if (modMatch || sectionMatches.length > 0) {
                    results.push(mod);
                }
            });

            if (results.length === 0) {
                contentEl.innerHTML = `<div class="doc-empty">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
                    </svg>
                    <p>Niciun rezultat pentru <strong>"${esc(searchQuery)}"</strong></p>
                </div>`;
            } else {
                contentEl.innerHTML = results.map(renderModule).join('<hr class="doc-divider">');
            }
            if (window.lucide) lucide.createIcons();
            return;
        }

        const mod = DOCS.find(m => m.id === activeId);
        contentEl.innerHTML = mod ? renderModule(mod) : '';
        if (window.lucide) lucide.createIcons();
    }

    const searchInput = document.getElementById('doc-search');
    const searchClear = document.getElementById('search-clear');

    searchInput.addEventListener('input', () => {
        searchQuery = searchInput.value.trim();
        searchClear.classList.toggle('hidden', !searchQuery);
        renderContent();
    });

    searchClear.addEventListener('click', () => {
        searchInput.value = '';
        searchQuery = '';
        searchClear.classList.add('hidden');
        renderContent();
    });

    document.addEventListener('keydown', e => {
        if (e.key === '/' && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
            e.preventDefault();
            searchInput.focus();
        }
    });

    setActive('architecture');

})();
