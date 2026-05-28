'use strict';

let allSettings = [];
let categories  = [];
let activeCategory = null;
let pendingSaves = {};

const overlay    = document.getElementById('overlay');
const sidebar    = document.getElementById('sidebar');
const content    = document.getElementById('content');
const searchInput = document.getElementById('searchInput');
const reloadBtn  = document.getElementById('reloadBtn');
const closeBtn   = document.getElementById('closeBtn');
const titleSub   = document.getElementById('titleSub');

window.addEventListener('message', (e) => {
    const { action, payload, data } = e.data;

    if (action === 'open') {
        allSettings = payload.settings || [];
        categories  = payload.categories || [];
        if (!activeCategory && categories.length > 0) {
            activeCategory = categories[0].id;
        }
        renderSidebar();
        renderContent();
        overlay.classList.add('visible');
        titleSub.textContent = `${allSettings.length} setări`;
    }

    if (action === 'close') {
        overlay.classList.remove('visible');
        activeCategory = null;
        searchInput.value = '';
    }

    if (action === 'saveResult') {
        const { key, success, error } = data;
        const fb = document.querySelector(`.save-feedback[data-key="${CSS.escape(key)}"]`);
        if (!fb) return;
        fb.innerHTML = success ? '<i data-lucide="check"></i> Salvat' : `<i data-lucide="x"></i> ${error || 'Eroare'}`;
        fb.className = `save-feedback ${success ? 'ok' : 'err'}`;
        if (window.lucide) lucide.createIcons({ nodes: fb.querySelectorAll('[data-lucide]') });
        clearTimeout(pendingSaves[key]);
        pendingSaves[key] = setTimeout(() => {
            fb.innerHTML = '';
            fb.className = 'save-feedback';
        }, 3000);
    }
});

closeBtn.addEventListener('click', () => nuiPost('close'));
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') nuiPost('close');
});

reloadBtn.addEventListener('click', () => {
    reloadBtn.querySelector('svg')?.closest('button')?.classList.add('spinning');
    reloadBtn.classList.add('spinning');
    nuiPost('reload');
});

searchInput.addEventListener('input', () => renderContent());

function renderSidebar() {
    const counts = {};
    allSettings.forEach(s => {
        counts[s.category] = (counts[s.category] || 0) + 1;
    });

    sidebar.innerHTML = categories.map(cat => `
        <div class="cat-item ${cat.id === activeCategory ? 'active' : ''}" data-cat="${cat.id}">
            <span class="cat-icon">
                <i data-lucide="${cat.icon || 'sliders'}"></i>
            </span>
            <span>${cat.label}</span>
            <span class="cat-count">${counts[cat.id] || 0}</span>
        </div>
    `).join('');

    sidebar.querySelectorAll('.cat-item').forEach(el => {
        el.addEventListener('click', () => {
            activeCategory = el.dataset.cat;
            searchInput.value = '';
            renderSidebar();
            renderContent();
        });
    });

    lucide.createIcons({ nodes: sidebar.querySelectorAll('[data-lucide]') });
}

function renderContent() {
    const query = searchInput.value.trim().toLowerCase();
    let filtered = allSettings;

    if (query) {
        filtered = allSettings.filter(s =>
            s.key.toLowerCase().includes(query) ||
            (s.label || '').toLowerCase().includes(query) ||
            (s.description || '').toLowerCase().includes(query)
        );
    } else if (activeCategory) {
        filtered = allSettings.filter(s => s.category === activeCategory);
    }

    const catLabel = query
        ? `Căutare: "${query}"`
        : (categories.find(c => c.id === activeCategory)?.label || activeCategory || '-');

    content.innerHTML = `
        <div class="content-header">
            <div class="content-title">${catLabel}</div>
            <div class="content-count">${filtered.length} setări</div>
        </div>
        <div class="settings-grid" id="settingsGrid"></div>
    `;

    const grid = document.getElementById('settingsGrid');

    if (filtered.length === 0) {
        grid.innerHTML = `
            <div class="empty-state">
                <i data-lucide="inbox"></i>
                <div>Nicio setare găsită</div>
            </div>`;
        lucide.createIcons({ nodes: grid.querySelectorAll('[data-lucide]') });
        return;
    }

    filtered.forEach(s => {
        const card = document.createElement('div');
        card.className = `setting-card${s.readonly ? ' readonly' : ''}`;
        card.innerHTML = buildCard(s);
        grid.appendChild(card);
        attachCardHandlers(card, s);
    });

    lucide.createIcons({ nodes: grid.querySelectorAll('[data-lucide]') });
}

function buildCard(s) {
    const typeClass = `t-${s.type}`;
    return `
        <div class="setting-top">
            <div class="setting-info">
                <div class="setting-label">${escHtml(s.label || s.key)}</div>
                <div class="setting-key">${escHtml(s.key)}</div>
                ${s.description ? `<div class="setting-desc">${escHtml(s.description)}</div>` : ''}
            </div>
            <span class="type-badge ${typeClass}">${s.type}</span>
        </div>
        <div class="setting-editor">
            ${buildEditor(s)}
            ${s.readonly ? '' : `
            <div class="save-row">
                <button class="btn-save" data-key="${escHtml(s.key)}">
                    <i data-lucide="save"></i> Salvează
                </button>
                <span class="save-feedback" data-key="${escHtml(s.key)}"></span>
            </div>`}
        </div>
    `;
}

function buildEditor(s) {
    switch (s.type) {
        case 'boolean':
            return buildToggle(s);
        case 'number':
            return `<input type="number" data-key="${escHtml(s.key)}" value="${escHtml(s.value)}" step="any">`;
        case 'enum':
            return buildEnum(s);
        case 'json':
            return buildJson(s);
        case 'location_list':
            return buildLocationList(s);
        case 'garage_list':
            return buildGarageList(s);
        case 'dealer_list':
            return buildDealerList(s);
        case 'model_list':
            return buildModelList(s);
        case 'string':
        default:
            return `<input type="text" data-key="${escHtml(s.key)}" value="${escHtml(s.value)}">`;
    }
}

function buildToggle(s) {
    const checked = s.value === 'true' || s.value === '1';
    return `
        <div class="toggle-wrap">
            <label class="toggle">
                <input type="checkbox" data-key="${escHtml(s.key)}" ${checked ? 'checked' : ''}>
                <span class="toggle-track"></span>
            </label>
            <span class="toggle-label">${checked ? 'Activat' : 'Dezactivat'}</span>
        </div>`;
}

function buildEnum(s) {
    let options = [];
    try { options = JSON.parse(s.options || '[]'); } catch {}
    const opts = options.map(o =>
        `<option value="${escHtml(o)}" ${o === s.value ? 'selected' : ''}>${escHtml(o)}</option>`
    ).join('');
    return `<select data-key="${escHtml(s.key)}">${opts}</select>`;
}

function buildJson(s) {
    let pretty = s.value;
    try { pretty = JSON.stringify(JSON.parse(s.value), null, 2); } catch {}
    return `<textarea data-key="${escHtml(s.key)}" rows="6">${escHtml(pretty)}</textarea>`;
}

function buildLocationList(s) {
    let locs = [];
    try { locs = JSON.parse(s.value || '[]'); } catch {}
    const rows = locs.map((loc, i) => buildLocRow(loc, i)).join('');
    return `
        <div class="loc-list-wrap" data-key="${escHtml(s.key)}">
            <table class="loc-table">
                <thead>
                    <tr>
                        <th class="col-label">Label</th>
                        <th class="col-code">Cod bancă</th>
                        <th class="col-coord">X</th>
                        <th class="col-coord">Y</th>
                        <th class="col-coord">Z</th>
                        <th class="col-coord">Heading</th>
                        <th class="col-act"></th>
                    </tr>
                </thead>
                <tbody id="locRows_${escHtml(s.key).replace(/\./g,'_')}">${rows}</tbody>
            </table>
            <button class="btn-add-row loc-add" data-key="${escHtml(s.key)}">
                <i data-lucide="plus"></i> Adaugă locație
            </button>
        </div>`;
}

function buildLocRow(loc, i) {
    return `
        <tr data-row="${i}">
            <td class="col-label"><input type="text"   class="loc-label"   value="${escHtml(loc.label    || '')}"></td>
            <td class="col-code" ><input type="text"   class="loc-code"    value="${escHtml(loc.bankCode || '')}"></td>
            <td class="col-coord"><input type="number" class="loc-x"       value="${loc.x       ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="loc-y"       value="${loc.y       ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="loc-z"       value="${loc.z       ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="loc-heading" value="${loc.heading ?? 0}" step="0.1"></td>
            <td class="col-act">
                <button class="btn-del-row loc-del"><i data-lucide="x"></i></button>
            </td>
        </tr>`;
}

function buildGarageList(s) {
    let locs = [];
    try { locs = JSON.parse(s.value || '[]'); } catch {}
    const rows = locs.map((loc, i) => buildGarageRow(loc, i)).join('');
    return `
        <div class="loc-list-wrap" data-key="${escHtml(s.key)}">
            <table class="loc-table loc-table--wide">
                <thead>
                    <tr>
                        <th class="col-code">Cod</th>
                        <th class="col-label">Nume</th>
                        <th class="col-type">Tip</th>
                        <th class="col-coord">X</th>
                        <th class="col-coord">Y</th>
                        <th class="col-coord">Z</th>
                        <th class="col-coord">SpX</th>
                        <th class="col-coord">SpY</th>
                        <th class="col-coord">SpZ</th>
                        <th class="col-coord">SpH</th>
                        <th class="col-act"></th>
                    </tr>
                </thead>
                <tbody>${rows}</tbody>
            </table>
            <button class="btn-add-row garage-add" data-key="${escHtml(s.key)}">
                <i data-lucide="plus"></i> Adaugă garaj
            </button>
        </div>`;
}

function buildGarageRow(loc, i) {
    const c  = loc.coords     || {};
    const sp = loc.spawnPoint || {};
    return `
        <tr data-row="${i}">
            <td class="col-code" ><input type="text" class="garage-code" value="${escHtml(loc.code || '')}"></td>
            <td class="col-label"><input type="text" class="garage-name" value="${escHtml(loc.name || '')}"></td>
            <td class="col-type">
                <select class="garage-type">
                    <option value="public"  ${loc.type === 'public'  ? 'selected' : ''}>public</option>
                    <option value="impound" ${loc.type === 'impound' ? 'selected' : ''}>impound</option>
                    <option value="private" ${loc.type === 'private' ? 'selected' : ''}>private</option>
                </select>
            </td>
            <td class="col-coord"><input type="number" class="garage-x"   value="${c.x  ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="garage-y"   value="${c.y  ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="garage-z"   value="${c.z  ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="garage-spx" value="${sp.x ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="garage-spy" value="${sp.y ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="garage-spz" value="${sp.z ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="garage-sph" value="${sp.heading ?? 0}" step="0.1"></td>
            <td class="col-act"><button class="btn-del-row garage-del"><i data-lucide="x"></i></button></td>
        </tr>`;
}

function buildDealerList(s) {
    let locs = [];
    try { locs = JSON.parse(s.value || '[]'); } catch {}
    const rows = locs.map((loc, i) => buildDealerRow(loc, i)).join('');
    return `
        <div class="loc-list-wrap" data-key="${escHtml(s.key)}">
            <table class="loc-table loc-table--wide">
                <thead>
                    <tr>
                        <th class="col-code">Cod</th>
                        <th class="col-label">Nume</th>
                        <th class="col-coord">X</th>
                        <th class="col-coord">Y</th>
                        <th class="col-coord">Z</th>
                        <th class="col-label">Model NPC</th>
                        <th class="col-coord">SpX</th>
                        <th class="col-coord">SpY</th>
                        <th class="col-coord">SpZ</th>
                        <th class="col-coord">SpH</th>
                        <th class="col-act"></th>
                    </tr>
                </thead>
                <tbody>${rows}</tbody>
            </table>
            <button class="btn-add-row dealer-add" data-key="${escHtml(s.key)}">
                <i data-lucide="plus"></i> Adaugă dealership
            </button>
        </div>`;
}

function buildDealerRow(loc, i) {
    const c  = loc.coords          || {};
    const sp = loc.testDriveSpawn  || {};
    return `
        <tr data-row="${i}">
            <td class="col-code" ><input type="text"   class="dealer-code"     value="${escHtml(loc.code     || '')}"></td>
            <td class="col-label"><input type="text"   class="dealer-name"     value="${escHtml(loc.name     || '')}"></td>
            <td class="col-coord"><input type="number" class="dealer-x"        value="${c.x  ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="dealer-y"        value="${c.y  ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="dealer-z"        value="${c.z  ?? 0}" step="0.01"></td>
            <td class="col-label"><input type="text"   class="dealer-npc"      value="${escHtml(loc.npcModel || '')}"></td>
            <td class="col-coord"><input type="number" class="dealer-spx"      value="${sp.x ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="dealer-spy"      value="${sp.y ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="dealer-spz"      value="${sp.z ?? 0}" step="0.01"></td>
            <td class="col-coord"><input type="number" class="dealer-sph"      value="${sp.heading ?? 0}" step="0.1"></td>
            <td class="col-act"><button class="btn-del-row dealer-del"><i data-lucide="x"></i></button></td>
        </tr>`;
}

function buildModelList(s) {
    let models = [];
    try { models = JSON.parse(s.value || '[]'); } catch {}
    const items = models.map((m, i) => `
        <div class="model-row" data-row="${i}">
            <input type="text" class="model-val" value="${escHtml(m)}">
            <button class="btn-del-row model-del"><i data-lucide="x"></i></button>
        </div>`).join('');
    return `
        <div class="model-list" data-key="${escHtml(s.key)}">
            ${items}
        </div>
        <button class="btn-add-row model-add" data-key="${escHtml(s.key)}">
            <i data-lucide="plus"></i> Adaugă model
        </button>`;
}

function attachCardHandlers(card, s) {
    if (s.type === 'boolean') {
        const cb = card.querySelector('input[type="checkbox"]');
        const lbl = card.querySelector('.toggle-label');
        if (cb && lbl) {
            cb.addEventListener('change', () => {
                lbl.textContent = cb.checked ? 'Activat' : 'Dezactivat';
            });
        }
    }

    const saveBtn = card.querySelector('.btn-save');
    if (saveBtn) {
        saveBtn.addEventListener('click', () => saveCard(card, s));
    }

    if (s.type === 'location_list') {
        card.querySelector('.loc-add')?.addEventListener('click', () => addLocRow(card, s));
        card.addEventListener('click', (e) => {
            const delBtn = e.target.closest('.loc-del');
            if (delBtn) delBtn.closest('tr').remove();
        });
        lucide.createIcons({ nodes: card.querySelectorAll('[data-lucide]') });
    }

    if (s.type === 'garage_list') {
        card.querySelector('.garage-add')?.addEventListener('click', () => {
            const tbody = card.querySelector('tbody');
            const i = tbody.querySelectorAll('tr').length;
            const tr = document.createElement('tr');
            tr.dataset.row = i;
            tr.innerHTML = buildGarageRow({ code: '', name: '', type: 'public', coords: {}, spawnPoint: {} }, i).replace(/<tr[^>]*>|<\/tr>/g, '');
            tbody.appendChild(tr);
            lucide.createIcons({ nodes: tr.querySelectorAll('[data-lucide]') });
        });
        card.addEventListener('click', (e) => {
            const delBtn = e.target.closest('.garage-del');
            if (delBtn) delBtn.closest('tr').remove();
        });
        lucide.createIcons({ nodes: card.querySelectorAll('[data-lucide]') });
    }

    if (s.type === 'dealer_list') {
        card.querySelector('.dealer-add')?.addEventListener('click', () => {
            const tbody = card.querySelector('tbody');
            const i = tbody.querySelectorAll('tr').length;
            const tr = document.createElement('tr');
            tr.dataset.row = i;
            tr.innerHTML = buildDealerRow({ code: '', name: '', coords: {}, npcModel: '', testDriveSpawn: {} }, i).replace(/<tr[^>]*>|<\/tr>/g, '');
            tbody.appendChild(tr);
            lucide.createIcons({ nodes: tr.querySelectorAll('[data-lucide]') });
        });
        card.addEventListener('click', (e) => {
            const delBtn = e.target.closest('.dealer-del');
            if (delBtn) delBtn.closest('tr').remove();
        });
        lucide.createIcons({ nodes: card.querySelectorAll('[data-lucide]') });
    }

    if (s.type === 'model_list') {
        card.querySelector('.model-add')?.addEventListener('click', () => addModelRow(card, s));
        card.addEventListener('click', (e) => {
            const delBtn = e.target.closest('.model-del');
            if (delBtn) delBtn.closest('.model-row').remove();
        });
    }
}

function addLocRow(card, s) {
    const tbody = card.querySelector('tbody');
    const i = tbody.querySelectorAll('tr').length;
    const tr = document.createElement('tr');
    tr.dataset.row = i;
    tr.innerHTML = buildLocRow({ label: '', bankCode: '', x: 0, y: 0, z: 0, heading: 0 }, i).replace(/<tr[^>]*>|<\/tr>/g, '');
    tbody.appendChild(tr);
    lucide.createIcons({ nodes: tr.querySelectorAll('[data-lucide]') });
}

function addModelRow(card, s) {
    const list = card.querySelector('.model-list');
    const i = list.querySelectorAll('.model-row').length;
    const div = document.createElement('div');
    div.className = 'model-row';
    div.dataset.row = i;
    div.innerHTML = `<input type="text" class="model-val" value=""><button class="btn-del-row model-del"><i data-lucide="x"></i></button>`;
    list.appendChild(div);
    lucide.createIcons({ nodes: div.querySelectorAll('[data-lucide]') });
}

function readCardValue(card, s) {
    switch (s.type) {
        case 'boolean': {
            const cb = card.querySelector(`input[type="checkbox"]`);
            return cb ? String(cb.checked) : s.value;
        }
        case 'number': {
            const inp = card.querySelector(`input[type="number"]`);
            return inp ? inp.value : s.value;
        }
        case 'enum': {
            const sel = card.querySelector('select');
            return sel ? sel.value : s.value;
        }
        case 'json': {
            const ta = card.querySelector('textarea');
            if (!ta) return s.value;
            try {
                return JSON.stringify(JSON.parse(ta.value));
            } catch {
                showFeedback(card, s.key, false, 'JSON invalid');
                return null;
            }
        }
        case 'location_list': {
            const rows = card.querySelectorAll('tbody tr');
            const locs = [];
            rows.forEach(tr => {
                locs.push({
                    label:    tr.querySelector('.loc-label')?.value   || '',
                    bankCode: tr.querySelector('.loc-code')?.value    || '',
                    x:        parseFloat(tr.querySelector('.loc-x')?.value)       || 0,
                    y:        parseFloat(tr.querySelector('.loc-y')?.value)       || 0,
                    z:        parseFloat(tr.querySelector('.loc-z')?.value)       || 0,
                    heading:  parseFloat(tr.querySelector('.loc-heading')?.value) || 0,
                });
            });
            return JSON.stringify(locs);
        }
        case 'garage_list': {
            const rows = card.querySelectorAll('tbody tr');
            const locs = [];
            rows.forEach(tr => {
                locs.push({
                    code:  tr.querySelector('.garage-code')?.value?.trim() || '',
                    name:  tr.querySelector('.garage-name')?.value?.trim() || '',
                    type:  tr.querySelector('.garage-type')?.value         || 'public',
                    coords: {
                        x: parseFloat(tr.querySelector('.garage-x')?.value) || 0,
                        y: parseFloat(tr.querySelector('.garage-y')?.value) || 0,
                        z: parseFloat(tr.querySelector('.garage-z')?.value) || 0,
                    },
                    spawnPoint: {
                        x:       parseFloat(tr.querySelector('.garage-spx')?.value) || 0,
                        y:       parseFloat(tr.querySelector('.garage-spy')?.value) || 0,
                        z:       parseFloat(tr.querySelector('.garage-spz')?.value) || 0,
                        heading: parseFloat(tr.querySelector('.garage-sph')?.value) || 0,
                    },
                });
            });
            return JSON.stringify(locs);
        }
        case 'dealer_list': {
            const rows = card.querySelectorAll('tbody tr');
            const locs = [];
            rows.forEach(tr => {
                locs.push({
                    code:     tr.querySelector('.dealer-code')?.value?.trim() || '',
                    name:     tr.querySelector('.dealer-name')?.value?.trim() || '',
                    npcModel: tr.querySelector('.dealer-npc')?.value?.trim()  || '',
                    coords: {
                        x: parseFloat(tr.querySelector('.dealer-x')?.value) || 0,
                        y: parseFloat(tr.querySelector('.dealer-y')?.value) || 0,
                        z: parseFloat(tr.querySelector('.dealer-z')?.value) || 0,
                    },
                    testDriveSpawn: {
                        x:       parseFloat(tr.querySelector('.dealer-spx')?.value) || 0,
                        y:       parseFloat(tr.querySelector('.dealer-spy')?.value) || 0,
                        z:       parseFloat(tr.querySelector('.dealer-spz')?.value) || 0,
                        heading: parseFloat(tr.querySelector('.dealer-sph')?.value) || 0,
                    },
                });
            });
            return JSON.stringify(locs);
        }
        case 'model_list': {
            const rows = card.querySelectorAll('.model-row');
            const models = [];
            rows.forEach(r => {
                const v = r.querySelector('.model-val')?.value?.trim();
                if (v) models.push(v);
            });
            return JSON.stringify(models);
        }
        default: {
            const inp = card.querySelector(`input[type="text"]`);
            return inp ? inp.value : s.value;
        }
    }
}

function saveCard(card, s) {
    const value = readCardValue(card, s);
    if (value === null) return;
    nuiPost('save', { key: s.key, value });
    const idx = allSettings.findIndex(x => x.key === s.key);
    if (idx !== -1) allSettings[idx].value = value;
}

function showFeedback(card, key, success, msg) {
    const fb = card.querySelector(`.save-feedback[data-key="${CSS.escape(key)}"]`);
    if (!fb) return;
    fb.innerHTML = success ? '<i data-lucide="check"></i> Salvat' : `<i data-lucide="x"></i> ${msg || 'Eroare'}`;
    fb.className = `save-feedback ${success ? 'ok' : 'err'}`;
    if (window.lucide) lucide.createIcons({ nodes: fb.querySelectorAll('[data-lucide]') });
}

function nuiPost(endpoint, data = {}) {
    fetch(`/${getResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

function getResourceName() {
    return window.location.pathname.split('/')[1] || 'settings';
}

// Dev seed pentru preview in browser; sare cand pagina ruleaza in FiveM (protocol nui:)
(function devSeed() {
    if (window.location.protocol === 'nui:') return;

    const SEED_CATEGORIES = [
        { id: 'core',          label: 'Core',             icon: 'settings' },
        { id: 'characters',    label: 'Personaje',        icon: 'user' },
        { id: 'inventory',     label: 'Inventar',         icon: 'package' },
        { id: 'banking',       label: 'Banking',          icon: 'landmark' },
        { id: 'vehicles',      label: 'Vehicule',         icon: 'car' },
        { id: 'garages',       label: 'Garaje',           icon: 'parking-square' },
        { id: 'showroom',      label: 'Showroom',         icon: 'store' },
        { id: 'notifications', label: 'Notificări',       icon: 'bell' },
        { id: 'hud',           label: 'HUD',              icon: 'monitor' },
        { id: 'proximity',     label: 'Proximity',        icon: 'radio' },
        { id: 'needs',         label: 'Nevoi',            icon: 'heart' },
        { id: 'blips',         label: 'Blips & Markere',  icon: 'map-pin' },
    ];

    const SEED_SETTINGS = [
        { key: 'core.default_language',         value: 'ro',            type: 'string',        label: 'Limbă implicită',                     category: 'core',          options: null,  readonly: false, description: 'Limba implicită a serverului' },
        { key: 'vehicles.plate_format',         value: 'SWC-%05d',      type: 'string',        label: 'Format plăcuță înmatriculare',        category: 'vehicles',      options: null,  readonly: false, description: 'Formatul plăcuțelor generate automat' },
        { key: 'garages.impound_garage_code',   value: 'IMPOUND_LSIA',  type: 'string',        label: 'Cod garaj sechestru',                 category: 'garages',       options: null,  readonly: false, description: 'Codul garajului de sechestru' },
        { key: 'hud.primary_currency',          value: 'USD',           type: 'string',        label: 'Monedă principală',                   category: 'hud',           options: null,  readonly: false, description: 'Moneda principală afișată în HUD' },
        { key: 'hud.primary_symbol',            value: '$',             type: 'string',        label: 'Simbol monedă principală',            category: 'hud',           options: null,  readonly: false, description: 'Simbolul monedei principale' },
        { key: 'showroom.default_finance_bank_code', value: 'MAZE',     type: 'string',        label: 'Bancă finanțare implicită',           category: 'showroom',      options: null,  readonly: false, description: 'Codul băncii folosite pentru credite auto' },
        { key: 'inventory.default_drop_prop',   value: 'prop_paper_bag_01', type: 'string',    label: 'Prop drop implicit',                  category: 'inventory',     options: null,  readonly: false, description: 'Model prop folosit la aruncarea item-urilor' },
        { key: 'proximity.interaction_key_name', value: 'E',            type: 'string',        label: 'Tastă interacțiune',                  category: 'proximity',     options: null,  readonly: false, description: 'Tasta folosită pentru confirmare interacțiune' },

        { key: 'core.playtime_update_interval', value: '60',            type: 'number',        label: 'Interval salvare playtime (s)',        category: 'core',          options: null,  readonly: false, description: 'Cât de des se salvează playtime-ul în DB' },
        { key: 'characters.max_per_player',     value: '3',             type: 'number',        label: 'Personaje per cont',                  category: 'characters',    options: null,  readonly: false, description: 'Numărul maxim de personaje per cont' },
        { key: 'characters.min_age',            value: '18',            type: 'number',        label: 'Vârstă minimă personaj',              category: 'characters',    options: null,  readonly: false, description: 'Vârsta minimă a personajului' },
        { key: 'inventory.max_weight',          value: '30.0',          type: 'number',        label: 'Greutate maximă inventar (kg)',        category: 'inventory',     options: null,  readonly: false, description: 'Greutatea maximă a inventarului' },
        { key: 'inventory.max_slots',           value: '40',            type: 'number',        label: 'Sloturi inventar',                    category: 'inventory',     options: null,  readonly: false, description: 'Numărul de sloturi al inventarului' },
        { key: 'banking.atm_distance',          value: '1.5',           type: 'number',        label: 'Distanță interacțiune ATM (m)',        category: 'banking',       options: null,  readonly: false, description: 'Distanța de interacțiune ATM' },
        { key: 'banking.min_loan_term_months',  value: '6',             type: 'number',        label: 'Termen minim credit (luni)',           category: 'banking',       options: null,  readonly: false, description: 'Durata minimă a unui credit' },
        { key: 'vehicles.save_interval',        value: '30000',         type: 'number',        label: 'Interval salvare vehicule (ms)',       category: 'vehicles',      options: null,  readonly: false, description: 'Cât de des se salvează starea vehiculelor' },
        { key: 'garages.impound_release_fee',   value: '2500',          type: 'number',        label: 'Taxă eliberare sechestru',            category: 'garages',       options: null,  readonly: false, description: 'Taxa pentru eliberarea unui vehicul sechestrat' },
        { key: 'notifications.default_duration', value: '5000',         type: 'number',        label: 'Durată notificare (ms)',               category: 'notifications', options: null,  readonly: false, description: 'Durata implicită a notificărilor' },
        { key: 'hud.max_speed',                 value: '240',           type: 'number',        label: 'Viteză maximă vitezometru',           category: 'hud',           options: null,  readonly: false, description: 'Viteza maximă a vitezometrului (km/h)' },
        { key: 'proximity.proximity_distance',  value: '2.0',           type: 'number',        label: 'Distanță detecție proximity (m)',      category: 'proximity',     options: null,  readonly: false, description: 'Distanța de detecție proximity' },
        { key: 'needs.hunger_decay_rate',       value: '2.0',           type: 'number',        label: 'Rată scădere hunger',                 category: 'needs',         options: null,  readonly: false, description: 'Cât scade hunger-ul per interval' },
        { key: 'blips.marker_draw_distance',    value: '30.0',          type: 'number',        label: 'Distanță desenare markere 3D (m)',     category: 'blips',         options: null,  readonly: false, description: 'Distanța maximă la care se desenează markere 3D' },

        { key: 'core.log_commands',             value: 'true',          type: 'boolean',       label: 'Logare comenzi admin',                category: 'core',          options: null,  readonly: false, description: 'Activează logarea comenzilor admin' },
        { key: 'characters.enable_deletion',    value: 'true',          type: 'boolean',       label: 'Permite ștergerea personajelor',      category: 'characters',    options: null,  readonly: false, description: 'Permite ștergerea personajelor' },
        { key: 'banking.log_transactions',      value: 'true',          type: 'boolean',       label: 'Logare tranzacții',                   category: 'banking',       options: null,  readonly: false, description: 'Activează logarea tranzacțiilor' },
        { key: 'banking.auto_calculate_interest', value: 'false',       type: 'boolean',       label: 'Calculare automată dobânzi',          category: 'banking',       options: null,  readonly: false, description: 'Calculează dobânzile automat' },
        { key: 'hud.hide_native_hud',           value: 'true',          type: 'boolean',       label: 'Ascunde HUD nativ FiveM',             category: 'hud',           options: null,  readonly: false, description: 'Ascunde HUD-ul nativ FiveM' },
        { key: 'hud.component_speedometer',     value: 'true',          type: 'boolean',       label: 'Componentă vitezometru',              category: 'hud',           options: null,  readonly: false, description: 'Afișează vitezometrul în vehicul' },
        { key: 'proximity.show_marker',         value: 'true',          type: 'boolean',       label: 'Afișează markere',                    category: 'proximity',     options: null,  readonly: false, description: 'Afișează markere la punctele de interacțiune' },
        { key: 'proximity.show_text',           value: 'true',          type: 'boolean',       label: 'Afișează text',                       category: 'proximity',     options: null,  readonly: false, description: 'Afișează text la punctele de interacțiune' },
        { key: 'proximity.debug',               value: 'false',         type: 'boolean',       label: 'Modul debug proximity',               category: 'proximity',     options: null,  readonly: true,  description: 'Modul debug (doar dezvoltatori)' },
        { key: 'blips.enabled',                 value: 'true',          type: 'boolean',       label: 'Activează blips-uri',                 category: 'blips',         options: null,  readonly: false, description: 'Afișează blips-urile pe minimapă' },

        { key: 'core.default_language_enum',    value: 'ro',            type: 'enum',          label: 'Limbă implicită (enum)',              category: 'core',          options: '["ro","en","fr","de"]', readonly: false, description: 'Limba implicită a serverului' },
        { key: 'notifications.position',        value: 'right-middle',  type: 'enum',          label: 'Poziție notificări',                  category: 'notifications', options: '["top-left","top-right","bottom-left","bottom-right","right-middle","left-middle"]', readonly: false, description: 'Poziția notificărilor pe ecran' },
        { key: 'showroom.default_loan_type',    value: 'personal',      type: 'enum',          label: 'Tip credit implicit',                 category: 'showroom',      options: '["personal","mortgage","business"]', readonly: false, description: 'Tipul creditului implicit pentru finanțare auto' },

        { key: 'proximity.marker_color',        value: '{"r":0,"g":255,"b":0,"a":200}',        type: 'json',   label: 'Culoare marker proximity',     category: 'proximity', options: null, readonly: false, description: 'Culoarea RGBA a markerelor de interacțiune' },
        { key: 'proximity.entity_offset',       value: '{"x":0.0,"y":0.0,"z":0.5}',           type: 'json',   label: 'Offset entitate proximity',    category: 'proximity', options: null, readonly: false, description: 'Offset-ul față de entitate' },
        { key: 'characters.creator_room',       value: '{"camera":{"x":-1045.0,"y":-2750.0,"z":21.36,"fov":35.0},"child":{"x":-1042.0,"y":-2745.0,"z":21.36,"heading":240.0}}', type: 'json', label: 'Configurare cameră creator personaj', category: 'characters', options: null, readonly: false, description: 'Pozițiile camerei în ecranul de creare personaj' },
        { key: 'blips.banking',                 value: '{"sprite":108,"color":34,"scale":0.8,"label":"Bancă","showMarker":true,"markerType":1,"markerColor":{"r":0,"g":180,"b":255,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}', type: 'json', label: 'Configurare blip bănci', category: 'blips', options: null, readonly: false, description: 'Sprite, culoare și marker pentru locațiile băncilor' },
        { key: 'blips.garages',                 value: '{"sprite":357,"color":2,"scale":0.8,"label":"Garaj","showMarker":true,"markerType":1,"markerColor":{"r":0,"g":255,"b":100,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',  type: 'json', label: 'Configurare blip garaje',  category: 'blips', options: null, readonly: false, description: 'Sprite, culoare și marker pentru garaje' },
        { key: 'blips.impound',                 value: '{"sprite":68,"color":1,"scale":0.8,"label":"Sechestru","showMarker":true,"markerType":1,"markerColor":{"r":255,"g":60,"b":60,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}', type: 'json', label: 'Configurare blip sechestru', category: 'blips', options: null, readonly: false, description: 'Sprite, culoare și marker pentru parcul de sechestru' },
        { key: 'blips.showroom',                value: '{"sprite":326,"color":5,"scale":0.8,"label":"Showroom","showMarker":true,"markerType":1,"markerColor":{"r":255,"g":200,"b":0,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}', type: 'json', label: 'Configurare blip showroom', category: 'blips', options: null, readonly: false, description: 'Sprite, culoare și marker pentru dealership-uri' },
        { key: 'banking.default_bank_fees',     value: '{"transfer_same_bank":{"fee_type_value":"fixed","fee_amount":0.0},"transfer_different_bank":{"fee_type_value":"percentage","fee_amount":1.5},"withdrawal":{"fee_type_value":"fixed","fee_amount":5.0}}', type: 'json', label: 'Comisioane implicite (seed)', category: 'banking', options: null, readonly: false, description: 'Comisioanele aplicate automat pentru fiecare bancă' },

        { key: 'banking.bank_locations', type: 'location_list', label: 'Locații bănci', category: 'banking', options: null, readonly: false,
          description: 'Coordonatele băncilor pentru interacțiunea proximity',
          value: JSON.stringify([
              { label: 'Fleeca Bank - Hawick',        bankCode: 'FLEC', x: 149.47,  y: -1040.46, z: 29.37,  heading: 0 },
              { label: 'Fleeca Bank - Burton',         bankCode: 'FLEC', x: 314.19,  y: -278.73,  z: 54.16,  heading: 0 },
              { label: 'Fleeca Bank - Rockford Hills', bankCode: 'FLEC', x: -350.99, y: -49.99,   z: 49.04,  heading: 0 },
              { label: 'Maze Bank Tower',              bankCode: 'MAZE', x: 247.03,  y: 223.78,   z: 106.29, heading: 0 },
              { label: 'Maze Bank West',               bankCode: 'MAZE', x: -75.01,  y: -818.22,  z: 326.18, heading: 0 },
          ]) },

        { key: 'garages.locations', type: 'garage_list', label: 'Locații garaje', category: 'garages', options: null, readonly: false,
          description: 'Locațiile garajelor publice și ale sechestrelor',
          value: JSON.stringify([
              { code: 'PUBLIC_MROW',  name: 'Garaj Public - Mission Row', type: 'public',  coords: { x: 215.36,   y: -809.56,  z: 29.73 }, spawnPoint: { x: 213.0,   y: -816.0,  z: 29.73, heading: 0.0   } },
              { code: 'PUBLIC_MWOOD', name: 'Garaj Public - Morningwood', type: 'public',  coords: { x: -1085.02, y: -328.57,  z: 13.94 }, spawnPoint: { x: -1088.0, y: -335.0,  z: 13.94, heading: 180.0 } },
              { code: 'PUBLIC_AIRP',  name: 'Garaj Public - Aeroport',    type: 'public',  coords: { x: -1037.0,  y: -2738.0,  z: 20.17 }, spawnPoint: { x: -1040.0, y: -2745.0, z: 20.17, heading: 90.0  } },
              { code: 'IMPOUND_LSIA', name: 'Parc Sechestru LSIA',        type: 'impound', coords: { x: 444.12,   y: -1020.38, z: 28.39 }, spawnPoint: { x: 448.0,   y: -1027.0, z: 28.39, heading: 90.0  } },
          ]) },

        { key: 'showroom.dealership_locations', type: 'dealer_list', label: 'Locații dealership-uri', category: 'showroom', options: null, readonly: false,
          description: 'Locațiile dealership-urilor și configurarea NPC-urilor',
          value: JSON.stringify([
              { code: 'PDM',    name: 'Premium Deluxe Motorsport', coords: { x: -47.09,   y: -1098.67, z: 26.42 }, npcModel: 'a_m_m_business_01', testDriveSpawn: { x: -33.0,   y: -1095.0, z: 26.42, heading: 340.0 } },
              { code: 'LEGACY', name: 'Legacy Motorsport',          coords: { x: -1393.1,  y: -626.5,   z: 30.9  }, npcModel: 'a_m_m_business_02', testDriveSpawn: { x: -1380.0, y: -630.0,  z: 30.9,  heading: 200.0 } },
          ]) },

        { key: 'banking.atm_models', type: 'model_list', label: 'Modele ATM', category: 'banking', options: null, readonly: false,
          description: 'Lista de modele prop pentru ATM-uri',
          value: JSON.stringify(['prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm']) },
    ];

    window.dispatchEvent(new MessageEvent('message', {
        data: {
            action: 'open',
            payload: { categories: SEED_CATEGORIES, settings: SEED_SETTINGS },
        },
    }));
})();

function escHtml(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
