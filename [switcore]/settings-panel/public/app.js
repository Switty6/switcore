(function () {
    'use strict';

    const token    = localStorage.getItem('sc_token');
    const username = localStorage.getItem('sc_username') || 'Admin';
    const role     = localStorage.getItem('sc_role') || 'staff';

    if (!token) { window.location.href = '/'; return; }

    const ROLE_LABELS = { superadmin: 'Super Admin', admin: 'Admin', moderator: 'Moderator', staff: 'Staff' };
    const roleLabel = document.getElementById('user-role-label');
    if (roleLabel) roleLabel.textContent = ROLE_LABELS[role] || 'Staff';

    let allSettings  = [];
    let dirtyMap     = {};          // unsaved edits: { key: newValue }
    let activeGroup  = 'all';
    let searchQuery  = '';

    const tbody        = document.getElementById('settings-tbody');
    const groupList    = document.getElementById('group-list');
    const searchInput  = document.getElementById('search');
    const searchClear  = document.getElementById('search-clear');
    const btnSaveAll   = document.getElementById('btn-save-all');
    const btnReload    = document.getElementById('btn-reload');
    const btnLogout    = document.getElementById('btn-logout');
    const saveCount    = document.getElementById('save-count');
    const statTotal    = document.getElementById('stat-total');
    const statModified = document.getElementById('stat-modified');
    const statGroups   = document.getElementById('stat-groups');
    const emptyState   = document.getElementById('empty-state');
    const emptyQuery   = document.getElementById('empty-query');
    const bcCurrent    = document.getElementById('breadcrumb-current');
    const badgeAll     = document.getElementById('badge-all');
    const userNameEl   = document.getElementById('user-name');
    const userAvatar   = document.getElementById('user-avatar');

    userNameEl.textContent = username;
    userAvatar.textContent  = username.charAt(0).toUpperCase();

    async function api(method, path, body) {
        const opts = {
            method,
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type':  'application/json'
            }
        };
        if (body !== undefined) opts.body = JSON.stringify(body);

        const res = await fetch(path, opts);

        if (res.status === 401) {
            localStorage.removeItem('sc_token');
            localStorage.removeItem('sc_username');
            window.location.href = '/';
            return;
        }

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
        return data;
    }

    function toast(msg, type = 'info', duration = 3000) {
        const container = document.getElementById('toast-container');
        const el = document.createElement('div');
        el.className = `toast ${type}`;
        el.innerHTML = `<span class="toast-dot"></span><span class="toast-msg">${msg}</span>`;
        container.appendChild(el);

        setTimeout(() => {
            el.classList.add('out');
            setTimeout(() => el.remove(), 220);
        }, duration);
    }

    function detectJsonSubtype(obj) {
        if (Array.isArray(obj)) {
            if (obj.every(v => typeof v !== 'object' || v === null)) return 'json_tags';
            return 'json_complex';
        }
        if (typeof obj === 'object' && obj !== null) {
            const keys = Object.keys(obj);

            // Color: {r,g,b} or {r,g,b,a}
            const isColor = keys.includes('r') && keys.includes('g') && keys.includes('b') &&
                            keys.every(k => ['r','g','b','a'].includes(k));
            if (isColor) return 'json_color';

            // Fee map: every value is an object with fee_type_value + fee_amount
            const vals = Object.values(obj);
            if (vals.length > 0 && vals.every(v =>
                typeof v === 'object' && v !== null &&
                'fee_type_value' in v && 'fee_amount' in v
            )) return 'json_fees';

            const hasXYZ = keys.includes('x') && keys.includes('y') && keys.includes('z');
            if (!hasXYZ) return 'json_complex';
            const extra = keys.filter(k => !['x','y','z','heading'].includes(k));
            if (extra.length === 0) return 'json_coord';
            const blipExtras = keys.filter(k => !['x','y','z','sprite','color','scale','label'].includes(k));
            if (blipExtras.length === 0) return 'json_blip';
            return 'json_complex';
        }
        return null;
    }

    function detectType(value) {
        if (value === 'true' || value === 'false') return 'boolean';
        if (!isNaN(parseFloat(value)) && isFinite(value)) return 'number';
        const trimmed = String(value).trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            try {
                const parsed = JSON.parse(trimmed);
                const sub = detectJsonSubtype(parsed);
                if (sub) return sub;
            } catch (_) {}
        }
        return 'text';
    }

    // Simulates Lua string.format with a fixed sample number, then maps
    // ^ → random letter and # → random digit so plate templates can be previewed in the UI.
    function previewPlateFormat(fmt) {
        try {
            let result = fmt.replace(/%-?(\d+)?([dsouxX])/g, (_, width, spec) => {
                const n = 123;
                const w = parseInt(width) || 0;
                let s;
                switch (spec) {
                    case 'd': case 'i': s = String(n); break;
                    case 'o': s = n.toString(8); break;
                    case 'u': s = String(Math.abs(n)); break;
                    case 'x': s = n.toString(16); break;
                    case 'X': s = n.toString(16).toUpperCase(); break;
                    case 's': s = 'abc'; break;
                    default:  s = String(n);
                }
                if (width && width.startsWith('0') && w > 0) s = s.padStart(w, '0');
                else if (w > 0) s = s.padStart(w, ' ');
                return s;
            });
            result = result.replace(/\^/g, 'X').replace(/#/g, '7');
            return result;
        } catch (_) { return fmt; }
    }

    function renderValue(key, value, setting = {}) {
        // Default to auto-detect; DB-declared type wins only for enum/plate_format widgets
        let type = detectType(value);

        if (setting.type === 'enum' && setting.options) {
            type = 'enum';
        } else if (setting.type === 'plate_format') {
            type = 'plate_format';
        }

        const current = dirtyMap[key] !== undefined ? dirtyMap[key] : value;

        if (type === 'enum') {
            try {
                const opts = JSON.parse(setting.options);
                const optionsHtml = opts.map(o => 
                    `<option value="${escHtml(o)}" ${String(current) === String(o) ? 'selected' : ''}>${escHtml(o)}</option>`
                ).join('');
                return `
                    <select class="val-select" data-key="${key}">
                        ${optionsHtml}
                    </select>
                `;
            } catch (err) {
                type = 'text';
            }
        }

        if (type === 'boolean') {
            const checked = current === 'true';
            return `
                <div class="toggle-wrap">
                    <label class="toggle">
                        <input type="checkbox" data-key="${key}" ${checked ? 'checked' : ''}>
                        <span class="toggle-slider"></span>
                    </label>
                    <span class="toggle-val">${checked ? 'ON' : 'OFF'}</span>
                </div>`;
        }

        if (type === 'number') {
            return `<input
                type="number"
                class="val-number"
                data-key="${key}"
                value="${escHtml(current)}"
                step="any">`;
        }

        let parsed;
        try { parsed = JSON.parse(current); } catch(_) { parsed = null; }

        if (type === 'json_coord' && parsed) {
            const h = parsed.heading !== undefined;
            return `<div class="json-coord" data-key="${key}">
                <div class="jc-field"><label>X</label><input type="number" step="any" class="jc-input" data-axis="x" value="${escHtml(parsed.x)}"></div>
                <div class="jc-field"><label>Y</label><input type="number" step="any" class="jc-input" data-axis="y" value="${escHtml(parsed.y)}"></div>
                <div class="jc-field"><label>Z</label><input type="number" step="any" class="jc-input" data-axis="z" value="${escHtml(parsed.z)}"></div>
                ${h ? `<div class="jc-field jc-heading"><label>H</label><input type="number" step="any" class="jc-input" data-axis="heading" value="${escHtml(parsed.heading)}"></div>` : ''}
            </div>`;
        }

        if (type === 'json_blip' && parsed) {
            return `<div class="json-blip" data-key="${key}">
                <div class="jb-row">
                    <div class="jc-field"><label>X</label><input type="number" step="any" class="jb-input" data-field="x" value="${escHtml(parsed.x)}"></div>
                    <div class="jc-field"><label>Y</label><input type="number" step="any" class="jb-input" data-field="y" value="${escHtml(parsed.y)}"></div>
                    <div class="jc-field"><label>Z</label><input type="number" step="any" class="jb-input" data-field="z" value="${escHtml(parsed.z)}"></div>
                </div>
                <div class="jb-row">
                    <div class="jc-field jc-sm"><label>Sprite</label><input type="number" step="1" class="jb-input" data-field="sprite" value="${escHtml(parsed.sprite ?? '')}"></div>
                    <div class="jc-field jc-sm"><label>Color</label><input type="number" step="1" class="jb-input" data-field="color" value="${escHtml(parsed.color ?? '')}"></div>
                    <div class="jc-field jc-sm"><label>Scale</label><input type="number" step="0.1" class="jb-input" data-field="scale" value="${escHtml(parsed.scale ?? '')}"></div>
                </div>
                <div class="jb-row">
                    <div class="jc-field jc-full"><label>Label</label><input type="text" class="jb-input" data-field="label" value="${escHtml(parsed.label ?? '')}"></div>
                </div>
            </div>`;
        }

        if (type === 'json_tags' && Array.isArray(parsed)) {
            const tags = parsed.map(v => `<span class="jtag" data-val="${escHtml(String(v))}">${escHtml(String(v))}<button class="jtag-del" title="Șterge"><i data-lucide="x"></i></button></span>`).join('');
            return `<div class="json-tags" data-key="${key}">
                <div class="jtag-list">${tags}</div>
                <div class="jtag-add-row">
                    <input type="text" class="jtag-input" placeholder="Adaugă valoare…">
                    <button class="jtag-add-btn">+</button>
                </div>
            </div>`;
        }

        if (type === 'json_color' && parsed) {
            const r = parsed.r ?? 0, g = parsed.g ?? 0, b = parsed.b ?? 0, a = parsed.a ?? 255;
            // alpha is intentionally dropped from the hex preview (<input type="color"> has no alpha channel)
            const toHex = n => Math.max(0,Math.min(255,Math.round(n))).toString(16).padStart(2,'0');
            const hex = `#${toHex(r)}${toHex(g)}${toHex(b)}`;
            return `<div class="json-color" data-key="${key}">
                <input type="color" class="jcolor-pick" value="${escHtml(hex)}" title="Alege culoarea">
                <div class="jcolor-fields">
                    <div class="jc-field jc-sm"><label>R</label><input type="number" min="0" max="255" step="1" class="jc-input jcolor-ch" data-ch="r" value="${r}"></div>
                    <div class="jc-field jc-sm"><label>G</label><input type="number" min="0" max="255" step="1" class="jc-input jcolor-ch" data-ch="g" value="${g}"></div>
                    <div class="jc-field jc-sm"><label>B</label><input type="number" min="0" max="255" step="1" class="jc-input jcolor-ch" data-ch="b" value="${b}"></div>
                    ${'a' in parsed ? `<div class="jc-field jc-sm"><label>A</label><input type="number" min="0" max="255" step="1" class="jc-input jcolor-ch" data-ch="a" value="${a}"></div>` : ''}
                </div>
            </div>`;
        }

        if (type === 'json_fees' && parsed) {
            const FEE_LABEL = {
                transfer_same_bank:      'Transfer aceea\u015fi banc\u0103',
                transfer_different_bank: 'Transfer alt\u0103 banc\u0103',
                withdrawal:              'Retragere',
                deposit:                 'Depunere',
                currency_exchange:       'Schimb valutar',
            };
            const rows = Object.entries(parsed).map(([feeKey, v]) => {
                const label = FEE_LABEL[feeKey] || feeKey;
                const typeVal = escHtml(v.fee_type_value || 'fixed');
                const amtVal  = escHtml(String(v.fee_amount ?? 0));
                return `<tr class="jfee-row" data-fee="${escHtml(feeKey)}">
                    <td class="jfee-name">${escHtml(label)}</td>
                    <td><select class="jfee-type">
                        <option value="fixed"${typeVal==='fixed'?' selected':''}>fix (RON)</option>
                        <option value="percentage"${typeVal==='percentage'?' selected':''}>% procent</option>
                    </select></td>
                    <td><input type="number" step="0.01" min="0" class="jc-input jfee-amt" value="${amtVal}"></td>
                </tr>`;
            }).join('');
            return `<div class="json-fees" data-key="${key}">
                <table class="jfee-table">
                    <thead><tr><th>Comision</th><th>Tip</th><th>Valoare</th></tr></thead>
                    <tbody>${rows}</tbody>
                </table>
            </div>`;
        }

        if (type === 'text') {
            return `<input
                type="text"
                class="val-text"
                data-key="${key}"
                value="${escHtml(current)}"`+'>';
        }

        if (type === 'plate_format') {
            const preview = previewPlateFormat(current);
            const isTooLong = preview.length > 8;
            const lengthColor = isTooLong ? 'color: var(--red);' : '';
            const lengthWarn = isTooLong ? ' <b style="color: var(--red);">(Atenție: Depășește 8 caractere!)</b>' : '';
            
            return `<div class="plate-fmt-wrap" data-key="${key}">
                <input type="text" class="val-text plate-fmt-input" data-key="${key}" value="${escHtml(current)}">
                <div class="plate-preview">
                    <span class="plate-preview-label">Live Preview →</span>
                    <span class="plate-preview-val" style="${lengthColor}">${escHtml(preview)}</span>${lengthWarn}
                </div>
                <div class="plate-hint" style="line-height: 1.6;">
                    <strong>Legendă simboluri:</strong><br>
                    <code>^</code> - literă random (A-Z) &nbsp;·&nbsp; <code>#</code> - cifră random (0-9)<br>
                    <code>%03d</code> - număr secvențial cu zero-uri (ex: 001)<br>
                    <small><em>Limită maximă FiveM: 8 caractere rezultate. Spațiile contează.</em></small>
                </div>
            </div>`;
        }

        const pretty = parsed !== null ? JSON.stringify(parsed, null, 2) : String(current);
        return `<div class="json-editor" data-key="${key}">
            <div class="je-toolbar">
                <span class="je-badge">JSON</span>
                <button class="je-fmt-btn" title="Formatează JSON">Format</button>
                <span class="je-status"></span>
            </div>
            <textarea class="je-textarea" rows="3" spellcheck="false">${escHtml(pretty)}</textarea>
        </div>`;
    }

    function escHtml(str) {
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    }

    function renderKey(key) {
        const dot = key.indexOf('.');
        if (dot === -1) return `<span class="key-cell">${escHtml(key)}</span>`;
        const prefix = key.slice(0, dot + 1);
        const rest   = key.slice(dot + 1);
        return `<span class="key-cell"><span class="key-prefix">${escHtml(prefix)}</span>${escHtml(rest)}</span>`;
    }

    function renderTable() {
        let rows = allSettings;

        if (activeGroup !== 'all') {
            rows = rows.filter(s => s.key.startsWith(activeGroup + '.'));
        }

        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            rows = rows.filter(s =>
                s.key.toLowerCase().includes(q) ||
                (s.description || '').toLowerCase().includes(q)
            );
        }

        emptyState.classList.toggle('hidden', rows.length > 0);
        document.querySelector('.table-wrap').classList.toggle('hidden', rows.length === 0);

        if (rows.length === 0) {
            emptyQuery.textContent = searchQuery || activeGroup;
            tbody.innerHTML = '';
            return;
        }

        tbody.innerHTML = rows.map(s => {
            const isDirty = dirtyMap[s.key] !== undefined;
            return `<tr data-key="${escHtml(s.key)}" class="${isDirty ? 'dirty' : ''}">
                <td>${renderKey(s.key)}</td>
                <td>${renderValue(s.key, s.value, s)}</td>
                <td class="desc-cell">${escHtml(s.description || '-')}</td>
                <td>
                    <button class="row-action-btn" data-key="${escHtml(s.key)}" title="Salvează">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                            <polyline points="20 6 9 17 4 12"/>
                        </svg>
                    </button>
                </td>
            </tr>`;
        }).join('');

        if (window.lucide) lucide.createIcons();
        updateDirtyBadge();
    }

    function updateDirtyBadge() {
        const count = Object.keys(dirtyMap).length;
        statModified.textContent = count;
        saveCount.textContent    = count;

        if (count > 0) {
            btnSaveAll.classList.remove('hidden');
        } else {
            btnSaveAll.classList.add('hidden');
        }
    }

    function markDirty(key, value) {
        const original = allSettings.find(s => s.key === key);
        if (original && String(original.value) === String(value)) {
            delete dirtyMap[key];
        } else {
            dirtyMap[key] = value;
        }

        const row = tbody.querySelector(`tr[data-key="${key}"]`);
        if (row) row.classList.toggle('dirty', dirtyMap[key] !== undefined);

        updateDirtyBadge();
    }

    async function saveRow(key) {
        const value = dirtyMap[key];
        if (value === undefined) return;

        const row = tbody.querySelector(`tr[data-key="${key}"]`);
        if (row) row.classList.add('saving');

        try {
            await api('PUT', `/api/settings/${encodeURIComponent(key)}`, { value });

            const s = allSettings.find(s => s.key === key);
            if (s) s.value = value;
            delete dirtyMap[key];

            if (row) {
                row.classList.remove('saving', 'dirty');
                row.classList.add('saved-ok');
                setTimeout(() => row.classList.remove('saved-ok'), 1500);
            }

            updateDirtyBadge();
            toast(`<strong>${key}</strong> salvat`, 'success');
        } catch (err) {
            if (row) row.classList.remove('saving');
            toast(`Eroare: ${err.message}`, 'error');
        }
    }

    async function saveAll() {
        if (Object.keys(dirtyMap).length === 0) return;

        btnSaveAll.disabled = true;
        const spinner = document.createElement('svg');
        spinner.setAttribute('viewBox', '0 0 24 24');
        spinner.setAttribute('fill', 'none');
        spinner.setAttribute('stroke', 'currentColor');
        spinner.setAttribute('stroke-width', '2.5');
        spinner.className = 'spin';
        spinner.style.width = '14px'; spinner.style.height = '14px';
        spinner.innerHTML = '<path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>';
        btnSaveAll.prepend(spinner);

        try {
            const res = await api('PUT', '/api/settings', { ...dirtyMap });

            for (const [k, v] of Object.entries(dirtyMap)) {
                const s = allSettings.find(s => s.key === k);
                if (s) s.value = v;
            }

            dirtyMap = {};
            renderTable();
            toast(`${res.count} setări salvate cu succes`, 'success');
        } catch (err) {
            toast(`Eroare la salvare: ${err.message}`, 'error');
        } finally {
            btnSaveAll.disabled = false;
            spinner.remove();
        }
    }

    async function loadSettings() {
        try {
            allSettings = await api('GET', '/api/settings');
            statTotal.textContent = allSettings.length;
            dirtyMap = {};
            renderTable();
        } catch (err) {
            toast(`Eroare încărcare: ${err.message}`, 'error');
        }
    }

    async function loadGroups() {
        try {
            const groups = await api('GET', '/api/settings/groups');
            statGroups.textContent = groups.length;
            badgeAll.textContent   = allSettings.length;

            const icons = {
                core:          '<i data-lucide="settings"></i>',
                characters:    '<i data-lucide="user"></i>',
                inventory:     '<i data-lucide="backpack"></i>',
                banking:       '<i data-lucide="credit-card"></i>',
                notifications: '<i data-lucide="bell"></i>',
                hud:           '<i data-lucide="bar-chart-3"></i>',
                proximity:     '<i data-lucide="map-pin"></i>',
                needs:         '<i data-lucide="utensils"></i>',
                police:        '<i data-lucide="siren"></i>',
                ems:           '<i data-lucide="ambulance"></i>',
                medical:       '<i data-lucide="stethoscope"></i>',
                blips:         '<i data-lucide="map"></i>',
                garages:       '<i data-lucide="car"></i>',
                showroom:      '<i data-lucide="store"></i>',
                jobs:          '<i data-lucide="briefcase"></i>',
                vehicles:      '<i data-lucide="fuel"></i>',
                tuning:        '<i data-lucide="wrench"></i>',
            };

            groups.forEach(g => {
                const li = document.createElement('li');
                li.innerHTML = `
                    <button class="group-btn" data-group="${escHtml(g.name)}">
                        <span class="group-icon">${icons[g.name] || '<i data-lucide="hexagon"></i>'}</span>
                        <span class="group-name">${escHtml(g.name)}</span>
                        <span class="group-badge">${g.count}</span>
                    </button>`;
                groupList.appendChild(li);
            });
            if (window.lucide) lucide.createIcons();

            document.querySelectorAll('.group-btn').forEach(btn => {
                btn.addEventListener('click', () => {
                    document.querySelectorAll('.group-btn').forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    activeGroup = btn.dataset.group;
                    bcCurrent.textContent = activeGroup === 'all' ? 'Toate' : activeGroup;
                    renderTable();
                });
            });
        } catch (err) {
            toast(`Eroare încărcare grupuri: ${err.message}`, 'error');
        }
    }

    tbody.addEventListener('change', (e) => {
        const el  = e.target;
        const key = el.dataset.key;

        if (el.type === 'checkbox' && key) {
            const val = el.checked ? 'true' : 'false';
            el.parentElement.nextElementSibling.textContent = el.checked ? 'ON' : 'OFF';
            markDirty(key, val);
            return;
        }

        if (el.classList.contains('jcolor-pick')) {
            const colorWrap = el.closest('.json-color');
            if (!colorWrap) return;
            const hex = el.value;
            const r = parseInt(hex.slice(1,3),16);
            const g = parseInt(hex.slice(3,5),16);
            const b = parseInt(hex.slice(5,7),16);
            const setField = (ch, val) => {
                const inp = colorWrap.querySelector(`[data-ch="${ch}"]`);
                if (inp) inp.value = val;
            };
            setField('r', r); setField('g', g); setField('b', b);
            markDirty(colorWrap.dataset.key, serializeColor(colorWrap));
            return;
        }

        const feesWrap = el.closest('.json-fees');
        if (feesWrap) {
            markDirty(feesWrap.dataset.key, serializeFees(feesWrap));
            return;
        }

        if (el.classList.contains('plate-fmt-input')) {
            const wrap = el.closest('.plate-fmt-wrap');
            if (wrap) {
                const previewEl = wrap.querySelector('.plate-preview-val');
                const fmt = previewPlateFormat(el.value);
                const isTooLong = fmt.length > 8;
                if (previewEl) {
                    previewEl.textContent = fmt;
                    previewEl.style.color = isTooLong ? 'var(--red)' : '';

                    let warnEl = wrap.querySelector('b');
                    if (isTooLong && !warnEl) {
                        previewEl.insertAdjacentHTML('afterend', ' <b style="color: var(--red);">(Atenție: Depășește 8 caractere!)</b>');
                    } else if (!isTooLong && warnEl) {
                        warnEl.remove();
                    }
                }
                markDirty(el.dataset.key, el.value);
            }
            return;
        }
    });

    function serializeCoord(container) {
        const inputs = container.querySelectorAll('.jc-input');
        const obj = {};
        inputs.forEach(inp => {
            const axis = inp.dataset.axis;
            obj[axis] = parseFloat(inp.value) || 0;
        });
        return JSON.stringify(obj);
    }

    function serializeBlip(container) {
        const inputs = container.querySelectorAll('.jb-input');
        const obj = {};
        inputs.forEach(inp => {
            const f = inp.dataset.field;
            if (f === 'label') { obj[f] = inp.value; }
            else { const n = parseFloat(inp.value); if (!isNaN(n)) obj[f] = n; }
        });
        return JSON.stringify(obj);
    }

    function serializeTags(container) {
        const tags = container.querySelectorAll('.jtag');
        const arr = [...tags].map(t => t.dataset.val);
        return JSON.stringify(arr);
    }

    function serializeColor(container) {
        const obj = {};
        container.querySelectorAll('.jcolor-ch').forEach(inp => {
            obj[inp.dataset.ch] = Math.max(0, Math.min(255, parseInt(inp.value) || 0));
        });
        return JSON.stringify(obj);
    }

    function serializeFees(container) {
        const obj = {};
        container.querySelectorAll('.jfee-row').forEach(row => {
            const feeKey = row.dataset.fee;
            obj[feeKey] = {
                fee_type_value: row.querySelector('.jfee-type').value,
                fee_amount:     parseFloat(row.querySelector('.jfee-amt').value) || 0,
            };
        });
        return JSON.stringify(obj);
    }

    tbody.addEventListener('input', (e) => {
        const el  = e.target;
        if (!el || el.type === 'checkbox') return;

        const key = el.dataset.key;
        if (key) {
            markDirty(key, el.value);
            return;
        }

        const coordWrap = el.closest('.json-coord');
        if (coordWrap) {
            markDirty(coordWrap.dataset.key, serializeCoord(coordWrap));
            return;
        }

        const blipWrap = el.closest('.json-blip');
        if (blipWrap) {
            markDirty(blipWrap.dataset.key, serializeBlip(blipWrap));
            return;
        }

        const colorWrap = el.closest('.json-color');
        if (colorWrap) {
            const toHex = n => Math.max(0,Math.min(255,n)).toString(16).padStart(2,'0');
            const r = colorWrap.querySelector('[data-ch="r"]').value;
            const g = colorWrap.querySelector('[data-ch="g"]').value;
            const b = colorWrap.querySelector('[data-ch="b"]').value;
            const picker = colorWrap.querySelector('.jcolor-pick');
            if (picker) picker.value = `#${toHex(+r)}${toHex(+g)}${toHex(+b)}`;
            markDirty(colorWrap.dataset.key, serializeColor(colorWrap));
            return;
        }

        const feesWrap = el.closest('.json-fees');
        if (feesWrap) {
            markDirty(feesWrap.dataset.key, serializeFees(feesWrap));
            return;
        }

        const jeWrap = el.closest('.json-editor');
        if (jeWrap) {
            const status = jeWrap.querySelector('.je-status');
            try {
                JSON.parse(el.value);
                status.innerHTML = '<i data-lucide="check"></i> Valid';
                status.className = 'je-status je-ok';
                if (window.lucide) lucide.createIcons();
                markDirty(jeWrap.dataset.key, el.value);
            } catch (_) {
                status.innerHTML = '<i data-lucide="x"></i> JSON invalid';
                status.className = 'je-status je-err';
                if (window.lucide) lucide.createIcons();
                // do not mark dirty while JSON is invalid - prevents saving bad payloads
            }
            return;
        }
    });

    tbody.addEventListener('click', (e) => {
        const btn = e.target.closest('.row-action-btn');
        if (btn) { saveRow(btn.dataset.key); return; }

        const fmtBtn = e.target.closest('.je-fmt-btn');
        if (fmtBtn) {
            const jeWrap  = fmtBtn.closest('.json-editor');
            const textarea = jeWrap.querySelector('.je-textarea');
            const status   = jeWrap.querySelector('.je-status');
            try {
                const parsed = JSON.parse(textarea.value);
                textarea.value = JSON.stringify(parsed, null, 2);
                status.innerHTML = '<i data-lucide="check"></i> Formatat';
                status.className = 'je-status je-ok';
                if (window.lucide) lucide.createIcons();
                markDirty(jeWrap.dataset.key, textarea.value);
            } catch (_) {
                status.innerHTML = '<i data-lucide="x"></i> JSON invalid';
                status.className = 'je-status je-err';
                if (window.lucide) lucide.createIcons();
            }
            return;
        }

        const delBtn = e.target.closest('.jtag-del');
        if (delBtn) {
            const tagEl  = delBtn.closest('.jtag');
            const tagWrap = tagEl.closest('.json-tags');
            tagEl.remove();
            markDirty(tagWrap.dataset.key, serializeTags(tagWrap));
            return;
        }

        const addBtn = e.target.closest('.jtag-add-btn');
        if (addBtn) {
            const tagWrap = addBtn.closest('.json-tags');
            const inp     = tagWrap.querySelector('.jtag-input');
            const val     = inp.value.trim();
            if (!val) return;
            const list = tagWrap.querySelector('.jtag-list');
            const span = document.createElement('span');
            span.className = 'jtag';
            span.dataset.val = val;
            span.innerHTML = `${escHtml(val)}<button class="jtag-del" title="Șterge"><i data-lucide="x"></i></button>`;
            if (window.lucide) lucide.createIcons();
            list.appendChild(span);
            inp.value = '';
            markDirty(tagWrap.dataset.key, serializeTags(tagWrap));
            return;
        }
    });

    tbody.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter') return;
        const inp = e.target.closest('.jtag-input');
        if (!inp) return;
        e.preventDefault();
        inp.closest('.json-tags').querySelector('.jtag-add-btn').click();
    });

    searchInput.addEventListener('input', () => {
        searchQuery = searchInput.value.trim();
        searchClear.classList.toggle('hidden', !searchQuery);
        renderTable();
    });

    searchClear.addEventListener('click', () => {
        searchInput.value = '';
        searchQuery = '';
        searchClear.classList.add('hidden');
        renderTable();
    });

    btnSaveAll.addEventListener('click', saveAll);

    btnReload.addEventListener('click', async () => {
        if (Object.keys(dirtyMap).length > 0) {
            if (!confirm('Ai modificări nesalvate. Le pierzi dacă reîncarci. Continui?')) return;
        }
        btnReload.classList.add('spinning');
        await loadSettings();
        btnReload.classList.remove('spinning');
        toast('Setări reîncărcate din DB', 'info');
    });

    btnLogout.addEventListener('click', () => {
        localStorage.removeItem('sc_token');
        localStorage.removeItem('sc_username');
        window.location.href = '/';
    });

    document.addEventListener('keydown', (e) => {
        if ((e.ctrlKey || e.metaKey) && e.key === 's') {
            e.preventDefault();
            saveAll();
        }
        if (e.key === '/' && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
            e.preventDefault();
            searchInput.focus();
        }
    });

    async function init() {
        await loadSettings();
        await loadGroups();
    }

    init();
})();
