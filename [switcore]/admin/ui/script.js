'use strict';

const RES_NAME = 'admin';

const state = {
    tabs:        [],
    perms:       {},
    players:     [],
    currencies:  [],
    primaryCurrency: { code: 'USD', symbol: '$' },
    groups:      [],
    selectedPlayer: null,
    pendingAction:  null,
    colorPrimary:   0,
    colorSecondary: 0,
    activeTab:     null,
    flags: { noclip: false, godmode: false, invisible: false, overlay: false, spectate: false },
    resourceFilter: '',
    resources: [],
    itemCatalog: [],
    itemsCatalog: [],
    itemsFilter:  '',
    editingItem:  null,
    jobsCatalog: [],
    currentInventory: null,
    currentVehicles: [],
};

function $(sel, root = document) { return root.querySelector(sel); }
function $$(sel, root = document) { return [...root.querySelectorAll(sel)]; }

// Traducere prin helperul standard SwI18n (core/ui/i18n.js); fallback pe cheie.
function t(key, ...args) {
    return SwI18n.t(`admin.ui.${key}`, ...args);
}

function nuiPost(endpoint, body = {}) {
    return fetch(`https://${RES_NAME}/${endpoint}`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(body),
    }).catch(() => {});
}

function esc(str) {
    return String(str ?? '')
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function hasPerm(node) {
    if (!node) return true;
    return state.perms['admin.all'] === true || state.perms[node] === true;
}

function applyPermVisibility(root = document) {
    $$('[data-perm]', root).forEach(el => {
        const need = el.dataset.perm;
        el.style.display = hasPerm(need) ? '' : 'none';
    });
}

const app = $('#app');

function openMenu(data) {
    state.tabs       = data.tabs       || [];
    state.perms      = data.perms      || {};
    state.players    = data.players    || [];
    state.currencies = data.currencies || [];
    state.primaryCurrency = data.primaryCurrency || { code: 'USD', symbol: '$' };
    state.groups     = data.groups     || [];

    $$('.nav-btn').forEach(btn => {
        btn.style.display = state.tabs.includes(btn.dataset.tab) ? '' : 'none';
    });

    activateTab(state.tabs[0] || 'players');

    populateCurrencies();
    populateGroups();
    renderPlayers();
    nuiPost('getOverlaySettings');
    applyPermVisibility();

    app.classList.remove('hidden');
}

function closeMenu() {
    app.classList.add('hidden');
    closeModal();
    nuiPost('close');
}

function activateTab(tab) {
    if (!tab) return;
    state.activeTab = tab;
    $$('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    $$('.tab').forEach(p => p.classList.toggle('active', p.id === 'tab-' + tab));

    if (tab === 'world' && hasPerm('admin.world.resources')) nuiPost('getResources');
    if (tab === 'players') nuiPost('getPlayers');
    if (tab === 'items' && hasPerm('admin.items.manage')) nuiPost('getItemsCatalog');
}

$('.sidebar').addEventListener('click', e => {
    const btn = e.target.closest('.nav-btn');
    if (btn && btn.dataset.tab) activateTab(btn.dataset.tab);
});

$('#scrim').addEventListener('click', closeMenu);
$('#closeBtn').addEventListener('click', closeMenu);

document.addEventListener('keydown', e => {
    if (app.classList.contains('hidden')) return;
    if (e.key === 'Escape') {
        if (!$('#playerModal').classList.contains('hidden')) closeModal();
        else closeMenu();
    }
});

const playerList   = $('#playerList');
const playerSearch = $('#playerSearch');

function renderPlayers() {
    const q = playerSearch.value.trim().toLowerCase();
    const list = state.players.filter(p =>
        !q || p.name.toLowerCase().includes(q) || String(p.id).includes(q)
    );

    $('#playerCount').textContent     = `(${state.players.length})`;
    $('#navPlayerCount').textContent  = state.players.length;

    if (!list.length) {
        playerList.innerHTML = `<div class="empty">${esc(t('empty_no_match'))}</div>`;
        return;
    }

    playerList.innerHTML = list.map(p => {
        const groups = (p.groups || []).map(g => {
            const name = g.name || g;
            return `<span class="group-badge ${esc(name)}">${esc(name)}</span>`;
        }).join('');
        const pingColor = p.ping < 100 ? 'var(--success)' : p.ping < 200 ? 'var(--warn)' : 'var(--danger)';
        return `<div class="player-row" data-id="${p.id}">
            <span class="p-id">${p.id}</span>
            <span class="p-name">${esc(p.name)}</span>
            <span class="p-groups">${groups}</span>
            <span class="p-ping" style="color:${pingColor}">${esc(t('ping_suffix', p.ping))}</span>
        </div>`;
    }).join('');

    $$('.player-row', playerList).forEach(row => {
        row.addEventListener('click', () => {
            const id = parseInt(row.dataset.id, 10);
            openPlayerModal(state.players.find(p => p.id === id));
        });
    });
}

playerSearch.addEventListener('input', renderPlayers);
$('#refreshPlayers').addEventListener('click', () => nuiPost('getPlayers'));

const playerModal = $('#playerModal');

function openPlayerModal(player) {
    if (!player) return;
    state.selectedPlayer = player;
    state.pendingAction  = null;

    $('#modalTitle').textContent = `[${player.id}] ${player.name}`;
    $('#modalSub').textContent   = player.dbId ? t('modal_db', player.dbId) : t('modal_no_data');

    $('#reasonBox').classList.add('hidden');
    $('#reasonInput').value = '';
    $('#durationInput').value = '';
    $('#durationInput').classList.add('hidden');

    applyPermVisibility(playerModal);

    const firstTab = $$('.m-tab', playerModal).find(t => {
        const target = $('#mp-' + t.dataset.mtab);
        return target && target.style.display !== 'none' && !target.classList.contains('hidden');
    });
    setModalTab((firstTab && firstTab.dataset.mtab) || 'actions');

    nuiPost('getPlayerInfo', { targetId: player.id });
    $('#infoBlock').innerHTML = esc(t('loading'));

    playerModal.classList.remove('hidden');
}

function closeModal() {
    playerModal.classList.add('hidden');
    state.selectedPlayer = null;
    state.pendingAction  = null;
}

$('#modalClose').addEventListener('click', closeModal);
playerModal.addEventListener('click', e => {
    if (e.target === playerModal) closeModal();
});

function setModalTab(name) {
    $$('.m-tab').forEach(t => t.classList.toggle('active', t.dataset.mtab === name));
    $$('.m-panel').forEach(p => p.classList.toggle('active', p.id === 'mp-' + name));
    const id = state.selectedPlayer && state.selectedPlayer.id;
    if (id == null) return;
    if (name === 'inventory' && hasPerm('admin.players.inventory')) {
        if (!state.itemCatalog.length) nuiPost('getItemCatalog');
        nuiPost('getPlayerInventory', { targetId: id });
    } else if (name === 'needs' && hasPerm('admin.players.needs')) {
        nuiPost('getPlayerNeeds', { targetId: id });
    } else if (name === 'character' && hasPerm('admin.players.character')) {
        nuiPost('getPlayerCharacterInfo', { targetId: id });
    } else if (name === 'vehicles' && hasPerm('admin.players.vehicles')) {
        nuiPost('getPlayerVehicles', { targetId: id });
    } else if (name === 'job' && hasPerm('admin.players.jobs')) {
        if (!state.jobsCatalog.length) nuiPost('getJobsCatalog');
        nuiPost('getPlayerJob', { targetId: id });
    }
}

$$('.m-tab').forEach(t => t.addEventListener('click', () => setModalTab(t.dataset.mtab)));

function requirePlayer() {
    if (!state.selectedPlayer) return null;
    return state.selectedPlayer.id;
}

$('#ma-goto').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('gotoPlayer', { targetId: id });
});
$('#ma-bring').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('bringPlayer', { targetId: id });
    closeModal();
});
$('#ma-spectate').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('spectatePlayer', { targetId: id });
});
$('#ma-freeze').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('freezePlayer', { targetId: id, frozen: true });
});
$('#ma-unfreeze').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('freezePlayer', { targetId: id, frozen: false });
});

function openReasonBox(action, withDuration) {
    state.pendingAction = action;
    const box = $('#reasonBox');
    box.classList.remove('hidden');
    $('#reasonInput').classList.remove('error');
    $('#durationInput').classList.toggle('hidden', !withDuration);
    setTimeout(() => $('#reasonInput').focus(), 30);
}

$('#ma-warn').addEventListener('click', () => openReasonBox('warn',  false));
$('#ma-kick').addEventListener('click', () => openReasonBox('kick',  false));
$('#ma-ban').addEventListener('click',  () => openReasonBox('ban',   true));
$('#reasonCancel').addEventListener('click', () => $('#reasonBox').classList.add('hidden'));

$('#reasonConfirm').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const reason = $('#reasonInput').value.trim();
    if (!reason) { $('#reasonInput').classList.add('error'); return; }

    if (state.pendingAction === 'warn') nuiPost('warnPlayer', { targetId: id, reason });
    if (state.pendingAction === 'kick') nuiPost('kickPlayer', { targetId: id, reason });
    if (state.pendingAction === 'ban') {
        const duration = $('#durationInput').value.trim() || 'permanent';
        nuiPost('banPlayer', { targetId: id, reason, duration });
    }
    closeModal();
});

$('#ma-bucket').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const bucket = parseInt($('#bucketInput').value, 10);
    if (Number.isNaN(bucket) || bucket < 0) return;
    nuiPost('setBucket', { targetId: id, bucket });
});

$('#ma-give-cash').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const amount     = parseInt($('#playerCashAmount').value, 10);
    const target     = $('#playerCashTarget').value;
    const currencyId = parseInt($('#playerCurrency').value, 10);
    if (Number.isNaN(amount) || amount === 0) return;
    nuiPost('giveCashToPlayer', { targetId: id, amount, target, currencyId });
    $('#playerCashAmount').value = '';
});

$('#ma-add-group').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const group = $('#groupSelect').value;
    if (!group) return;
    nuiPost('addGroup', { targetId: id, group });
});

$('#ma-remove-group').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const group = $('#groupSelect').value;
    if (!group) return;
    nuiPost('removeGroup', { targetId: id, group });
});

function renderItemCatalog() {
    const dl = $('#invItemDatalist');
    if (!dl) return;
    dl.innerHTML = state.itemCatalog.map(it =>
        `<option value="${esc(it.name)}">${esc(t('inv_item_option', it.label, it.weight))}</option>`
    ).join('');
}

function renderInventory(payload) {
    state.currentInventory = payload;
    const tbl = $('#invTable');
    const sum = $('#invSummary');
    if (!payload || !payload.items || payload.items.length === 0) {
        tbl.innerHTML = `<div class="empty">${esc(t('empty_inv'))}</div>`;
        sum.textContent = t('inv_slots_empty', payload?.maxSlots ?? '-');
        return;
    }
    sum.textContent = t('inv_summary', payload.items.length, payload.maxSlots, payload.maxWeight);
    tbl.innerHTML = `
        <div class="inv-head">
            <span>${esc(t('inv_col_slot'))}</span><span>${esc(t('inv_col_item'))}</span><span>${esc(t('inv_col_label'))}</span><span>${esc(t('inv_col_qty'))}</span><span></span>
        </div>
        ${payload.items.map(it => `
            <div class="inv-row" data-name="${esc(it.name)}" data-slot="${it.slot}">
                <span class="inv-slot">#${it.slot}</span>
                <span class="inv-name">${esc(it.name)}</span>
                <span class="inv-label">${esc(it.label)}</span>
                <span class="inv-qty">x${it.amount}</span>
                <span class="inv-actions">
                    <button class="btn ghost small" data-act="dec">−1</button>
                    <button class="btn ghost small" data-act="inc">+1</button>
                    <button class="btn danger ghost small" data-act="rm">${esc(t('inv_remove'))}</button>
                </span>
            </div>
        `).join('')}
    `;
}

$('#invTable').addEventListener('click', e => {
    const btn = e.target.closest('button[data-act]');
    if (!btn) return;
    const row = btn.closest('.inv-row');
    if (!row) return;
    const id = requirePlayer(); if (id == null) return;
    const itemName = row.dataset.name;
    const slot = parseInt(row.dataset.slot, 10);
    const act = btn.dataset.act;
    if (act === 'inc') nuiPost('givePlayerItem', { targetId: id, itemName, amount: 1 });
    else if (act === 'dec') nuiPost('takePlayerItem', { targetId: id, itemName, amount: 1, slot });
    else if (act === 'rm') {
        const item = state.currentInventory && state.currentInventory.items.find(it => it.slot === slot);
        const amt = item ? item.amount : 1;
        nuiPost('takePlayerItem', { targetId: id, itemName, amount: amt, slot });
    }
});

$('#ma-give-item').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const itemName = $('#invItemSearch').value.trim();
    const amount = parseInt($('#invItemQty').value, 10) || 1;
    if (!itemName || amount <= 0) return;
    nuiPost('givePlayerItem', { targetId: id, itemName, amount });
});

$('#ma-refresh-inv').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('getPlayerInventory', { targetId: id });
});

function renderNeeds(payload) {
    if (!payload) return;
    $('#needHunger').value = Math.round(payload.hunger);
    $('#needHungerVal').textContent = Math.round(payload.hunger);
    $('#needThirst').value = Math.round(payload.thirst);
    $('#needThirstVal').textContent = Math.round(payload.thirst);
}

$('#needHunger').addEventListener('input', e => $('#needHungerVal').textContent = e.target.value);
$('#needThirst').addEventListener('input', e => $('#needThirstVal').textContent = e.target.value);

$('#ma-set-hunger').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('setPlayerNeed', { targetId: id, key: 'hunger', value: parseInt($('#needHunger').value, 10) });
});
$('#ma-set-thirst').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('setPlayerNeed', { targetId: id, key: 'thirst', value: parseInt($('#needThirst').value, 10) });
});
$('#ma-heal-target').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('healTarget', { targetId: id });
});
$('#ma-revive-target').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('reviveTarget', { targetId: id });
});
$('#ma-refresh-needs').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('getPlayerNeeds', { targetId: id });
});

function genderLabel(g) {
    if (g == null || g === '') return '-';
    const s = String(g).toLowerCase();
    if (s === 'm' || s === 'male' || s === 'masculin') return t('gender_male');
    if (s === 'f' || s === 'female' || s === 'feminin') return t('gender_female');
    return String(g);
}

function renderCharacterInfo(payload) {
    if (!payload) return;
    const card = $('#charCard');
    if (!payload.active) {
        card.innerHTML = `<span class="muted">${esc(t('char_no_active'))}</span>`;
    } else {
        const a = payload.active;
        card.innerHTML = `
            <div><span class="ik">${esc(t('char_name'))}</span> <span class="iv">${esc(a.firstName ?? '-')} ${esc(a.lastName ?? '')}</span></div>
            <div><span class="ik">${esc(t('char_id'))}</span> <span class="iv">${a.id ?? '-'}</span></div>
            <div><span class="ik">${esc(t('char_age'))}</span> <span class="iv">${a.age ?? '-'}</span></div>
            <div><span class="ik">${esc(t('char_gender'))}</span> <span class="iv">${esc(genderLabel(a.gender))}</span></div>
            ${payload.coords ? `<div><span class="ik">${esc(t('char_coord'))}</span> <span class="iv">${payload.coords.x.toFixed(1)}, ${payload.coords.y.toFixed(1)}, ${payload.coords.z.toFixed(1)}</span></div>` : ''}
        `;
    }
    const list = $('#charList');
    if (!payload.characters || !payload.characters.length) {
        list.innerHTML = '<span class="muted small">-</span>';
    } else {
        list.innerHTML = payload.characters.map(c => `
            <div class="char-row">
                <span class="iv">#${c.id}</span>
                <span class="iv">${esc(c.firstName ?? '')} ${esc(c.lastName ?? '')}</span>
                <span class="muted small">${esc(t('char_age_suffix', c.age ?? ''))}</span>
                <span class="muted small">${esc((c.lastPlayed || c.createdAt || '').toString().slice(0, 16))}</span>
            </div>
        `).join('');
    }
}

$('#ma-tp-target').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const x = parseFloat($('#charTpX').value), y = parseFloat($('#charTpY').value), z = parseFloat($('#charTpZ').value);
    if ([x, y, z].some(Number.isNaN)) return;
    nuiPost('teleportTargetToCoords', { targetId: id, x, y, z });
});

function renderVehicles(payload) {
    state.currentVehicles = (payload && payload.vehicles) || [];
    const sum = $('#vehSummary');
    const list = $('#vehList');
    if (!state.currentVehicles.length) {
        sum.textContent = t('veh_count_zero');
        list.innerHTML = `<div class="empty">${esc(t('empty_no_veh'))}</div>`;
        return;
    }
    sum.textContent = t('veh_count', state.currentVehicles.length);
    list.innerHTML = state.currentVehicles.map(v => {
        let stateLbl = t('veh_state_garage');
        let stateCls = 'ok';
        if (v.impounded) { stateLbl = t('veh_state_impounded'); stateCls = 'err'; }
        else if (!v.stored) { stateLbl = t('veh_state_out'); stateCls = 'warn'; }
        return `
            <div class="veh-row" data-id="${v.id}">
                <div class="veh-head">
                    <span class="veh-plate">${esc(v.plate)}</span>
                    <span class="veh-model">${esc(v.label)} <span class="muted small">(${esc(v.model)})</span></span>
                    <span class="veh-state ${stateCls}">${esc(stateLbl)}</span>
                </div>
                <div class="veh-meta muted small">
                    ${v.category ? esc(v.category) + ' · ' : ''}${esc(t('veh_meta', (v.mileage || 0).toFixed(1), Math.floor(v.fuel)))}
                </div>
                <div class="veh-actions">
                    <button class="btn small" data-act="spawn" ${v.impounded ? 'disabled' : ''}>${esc(t('veh_spawn'))}</button>
                    <button class="btn danger ghost small" data-act="impound" ${v.impounded ? 'disabled' : ''}>${esc(t('veh_impound'))}</button>
                    <button class="btn success ghost small" data-act="release" ${!v.impounded ? 'disabled' : ''}>${esc(t('veh_release'))}</button>
                    <input type="number" class="input w-90" data-fuel-input value="${Math.floor(v.fuel)}" min="0" max="100">
                    <button class="btn ghost small" data-act="fuel">${esc(t('veh_set_fuel'))}</button>
                </div>
            </div>
        `;
    }).join('');
}

$('#vehList').addEventListener('click', e => {
    const btn = e.target.closest('button[data-act]');
    if (!btn) return;
    const row = btn.closest('.veh-row');
    if (!row) return;
    const vehicleId = parseInt(row.dataset.id, 10);
    const id = requirePlayer();
    const act = btn.dataset.act;
    if (act === 'spawn' && id != null) {
        nuiPost('spawnPlayerVehicle', { targetId: id, vehicleId });
    } else if (act === 'impound') {
        nuiPost('impoundPlayerVehicle', { vehicleId, reason: 'Admin impound' });
        setTimeout(() => id != null && nuiPost('getPlayerVehicles', { targetId: id }), 400);
    } else if (act === 'release') {
        nuiPost('releasePlayerVehicle', { vehicleId });
        setTimeout(() => id != null && nuiPost('getPlayerVehicles', { targetId: id }), 400);
    } else if (act === 'fuel') {
        const input = row.querySelector('[data-fuel-input]');
        const amount = parseInt(input.value, 10);
        if (Number.isNaN(amount)) return;
        nuiPost('setVehicleFuelAdmin', { vehicleId, amount });
    }
});

$('#ma-refresh-veh').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('getPlayerVehicles', { targetId: id });
});

function renderJobsCatalog() {
    const sel = $('#jobSelect');
    sel.innerHTML = state.jobsCatalog.map(j =>
        `<option value="${esc(j.name)}">${esc(j.label)}</option>`
    ).join('') || `<option value="">${esc(t('job_none'))}</option>`;
    refreshGradeDropdown();
}

function refreshGradeDropdown() {
    const sel = $('#jobSelect');
    const grSel = $('#jobGradeSelect');
    const job = state.jobsCatalog.find(j => j.name === sel.value);
    const grades = (job && job.grades) || [];
    const sym = state.primaryCurrency.symbol || '';
    grSel.innerHTML = grades.map(g =>
        `<option value="${g.grade}">${g.grade} · ${esc(g.label)} (${esc(sym)}${g.salary})</option>`
    ).join('') || '<option value="0">0</option>';
}

function renderPlayerJob(payload) {
    const card = $('#jobCard');
    if (!payload || !payload.job) {
        card.innerHTML = `<span class="muted">${esc(t('job_no_job'))}</span>`;
        return;
    }
    const j = payload.job;
    const sym = state.primaryCurrency.symbol || '';
    card.innerHTML = `
        <div><span class="ik">${esc(t('job_label'))}</span> <span class="iv">${esc(j.label ?? j.name)} <span class="muted small">(${esc(j.name)})</span></span></div>
        <div><span class="ik">${esc(t('job_grade'))}</span> <span class="iv">${j.grade} · ${esc(j.gradeLabel ?? '-')}</span></div>
        <div><span class="ik">${esc(t('job_salary'))}</span> <span class="iv">${esc(sym)}${j.salary ?? 0}</span></div>
        <div><span class="ik">${esc(t('job_duty'))}</span> <span class="iv">${j.onDuty ? esc(t('duty_on')) : esc(t('duty_off'))}</span></div>
    `;
    const sel = $('#jobSelect');
    if (sel.value !== j.name && state.jobsCatalog.length) {
        sel.value = j.name;
        refreshGradeDropdown();
    }
    $('#jobGradeSelect').value = String(j.grade);
}

$('#jobSelect').addEventListener('change', refreshGradeDropdown);

$('#ma-set-job').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    const jobName = $('#jobSelect').value;
    const grade = parseInt($('#jobGradeSelect').value, 10) || 0;
    if (!jobName) return;
    nuiPost('setPlayerJob', { targetId: id, jobName, grade });
    setTimeout(() => nuiPost('getPlayerJob', { targetId: id }), 400);
});

$('#ma-fire').addEventListener('click', () => {
    const id = requirePlayer(); if (id == null) return;
    nuiPost('firePlayer', { targetId: id });
    setTimeout(() => nuiPost('getPlayerJob', { targetId: id }), 400);
});

function populateCurrencies() {
    const opts = state.currencies.map(c =>
        `<option value="${c.id}">${esc(c.symbol || '')} ${esc(c.code)}</option>`
    ).join('') || `<option value="">${esc(t('currency_none'))}</option>`;
    $('#selfCurrency').innerHTML   = opts;
    $('#playerCurrency').innerHTML = opts;
}

function populateGroups() {
    const opts = state.groups.map(g =>
        `<option value="${esc(g.name)}">${esc(g.displayName || g.name)}</option>`
    ).join('') || `<option value="">${esc(t('group_none'))}</option>`;
    $('#groupSelect').innerHTML = opts;
}

function setToggleCard(btnId, on, flagKey, sidebarId) {
    const btn = document.getElementById(btnId);
    if (btn) {
        btn.classList.toggle('on', !!on);
        const stateLbl = btn.querySelector('.tc-state');
        if (stateLbl) stateLbl.textContent = on ? t('toggle_on') : t('toggle_off');
    }
    if (flagKey) state.flags[flagKey] = !!on;
    if (sidebarId) {
        const el = document.getElementById(sidebarId);
        if (el) {
            el.classList.toggle('on', !!on);
            const tag = el.querySelector('.status-off, .status-on');
            if (tag) {
                tag.textContent = on ? t('state_on') : t('state_off');
                tag.className   = on ? 'status-on' : 'status-off';
            }
        }
    }
}

$('#btn-noclip').addEventListener('click',    () => nuiPost('toggleNoclip'));
$('#btn-godmode').addEventListener('click',   () => nuiPost('toggleGodmode'));
$('#btn-invisible').addEventListener('click', () => nuiPost('toggleInvisible'));
$('#btn-overlay').addEventListener('click',   () => nuiPost('toggleEntityOverlay'));

$('#btn-heal').addEventListener('click',   () => nuiPost('healSelf'));
$('#btn-armor').addEventListener('click',  () => nuiPost('armorSelf'));
$('#btn-revive').addEventListener('click', () => nuiPost('reviveSelf'));
$('#btn-tp-waypoint').addEventListener('click', () => nuiPost('teleportWaypoint'));

$('#btn-tp-coords').addEventListener('click', () => {
    const x = parseFloat($('#tpX').value), y = parseFloat($('#tpY').value), z = parseFloat($('#tpZ').value);
    if ([x, y, z].some(Number.isNaN)) return;
    nuiPost('teleportCoords', { x, y, z });
});

$('#btn-my-coords').addEventListener('click', () => nuiPost('getMyCoords'));

$('#btn-give-weapon').addEventListener('click', () => {
    const weapon = $('#weaponName').value.trim();
    const ammo   = parseInt($('#weaponAmmo').value, 10) || 250;
    if (!weapon) return;
    nuiPost('giveWeapon', { weapon, ammo });
});

$('#btn-remove-weapons').addEventListener('click', () => nuiPost('removeWeapons'));

$('#btn-self-cash').addEventListener('click', () => {
    const amount     = parseInt($('#selfCashAmount').value, 10);
    const target     = $('#selfCashTarget').value;
    const currencyId = parseInt($('#selfCurrency').value, 10);
    if (Number.isNaN(amount) || amount === 0) return;
    nuiPost('giveCashToSelf', { amount, target, currencyId });
    $('#selfCashAmount').value = '';
});

$('#btn-set-model').addEventListener('click', () => {
    const model = $('#pedModel').value.trim();
    if (!model) return;
    nuiPost('setPedModel', { model });
});

const WEAPON_PRESETS = ['PISTOL', 'COMBATPISTOL', 'APPISTOL', 'PUMPSHOTGUN', 'SMG', 'CARBINERIFLE', 'ASSAULTRIFLE', 'SNIPERRIFLE', 'MICROSMG', 'BAT', 'KNIFE', 'STUNGUN', 'FLASHLIGHT'];
$('#weaponPresets').innerHTML = WEAPON_PRESETS.map(w =>
    `<span class="chip" data-weapon="WEAPON_${w}">${w.toLowerCase()}</span>`
).join('');
$('#weaponPresets').addEventListener('click', e => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    $('#weaponName').value = chip.dataset.weapon;
});

const OV_MAP = [
    'showVeh','showPed','showObj','showSelf',
    ['veh','model','plate','netId','handle','dist','speed','bodyHp','engineHp','coords','heading','occupants','networked'],
    ['ped','label','model','netId','handle','serverId','dist','hp','armour','heading','weapon','isDead','coords'],
    ['obj','model','netId','handle','dist','coords','networked'],
    ['self','coords','heading','speed','street','zone','fps'],
];

function eachOvField(fn) {
    OV_MAP.forEach(entry => {
        if (typeof entry === 'string') fn(entry, [entry], 'ov-' + entry);
        else {
            const grp = entry[0];
            for (let i = 1; i < entry.length; i++) {
                const k = entry[i];
                fn(k, [grp, k], 'ov-' + grp + '-' + k);
            }
        }
    });
}

function collectOverlaySettings() {
    const s = { veh:{}, ped:{}, obj:{}, self:{} };
    s.maxDist = parseInt($('#ov-maxDist').value, 10) || 80;
    eachOvField((_, path, id) => {
        const el = document.getElementById(id);
        if (!el) return;
        const v = el.type === 'checkbox' ? el.checked : parseFloat(el.value);
        if (path.length === 1) s[path[0]] = v;
        else s[path[0]][path[1]] = v;
    });
    return s;
}

function applyOverlayUI(s) {
    if (!s) return;
    if (s.maxDist != null) {
        $('#ov-maxDist').value = s.maxDist;
        $('#ov-maxDist-val').textContent = s.maxDist + 'm';
    }
    eachOvField((_, path, id) => {
        const el = document.getElementById(id);
        if (!el) return;
        const v = path.length === 1 ? s[path[0]] : (s[path[0]] && s[path[0]][path[1]]);
        if (v !== undefined) el.checked = !!v;
    });
}

$('#ov-maxDist').addEventListener('input', e => {
    $('#ov-maxDist-val').textContent = e.target.value + 'm';
});

$('#btn-save-overlay').addEventListener('click', e => {
    e.stopPropagation();
    nuiPost('saveOverlaySettings', { settings: collectOverlaySettings() });
    const btn = e.currentTarget;
    const orig = btn.innerHTML;
    btn.innerHTML = `<i data-lucide="check"></i> ${esc(t('saved_btn'))}`;
    if (window.lucide) lucide.createIcons({ nodes: [btn] });
    setTimeout(() => {
        btn.innerHTML = orig;
        if (window.lucide) lucide.createIcons({ nodes: [btn] });
    }, 1300);
});

const espCard = $('#espCard');
$('#espToggle').addEventListener('click', e => {
    if (e.target.closest('button')) return;
    espCard.classList.toggle('collapsed');
});

const VEH_PRESETS = ['adder', 'zentorno', 't20', 'sultan', 'kuruma', 'comet5', 'turismor', 'banshee', 'bati', 'sanchez', 'sandking', 'baller', 'cavalcade'];
$('#vehPresets').innerHTML = VEH_PRESETS.map(v => `<span class="chip" data-model="${v}">${v}</span>`).join('');
$('#vehPresets').addEventListener('click', e => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    $('#spawnModel').value = chip.dataset.model;
});

$('#btn-spawn').addEventListener('click', () => {
    const model = $('#spawnModel').value.trim();
    if (!model) return;
    nuiPost('spawnVehicle', { model, enter: $('#spawnEnter').checked });
});

$('#btn-del-veh').addEventListener('click',    () => nuiPost('deleteVehicle'));
$('#btn-del-nearby').addEventListener('click', () => nuiPost('deleteNearbyVehicles'));
$('#btn-repair').addEventListener('click',     () => nuiPost('repairVehicle'));
$('#btn-refuel').addEventListener('click',     () => nuiPost('refuelVehicle'));
$('#btn-flip').addEventListener('click',       () => nuiPost('flipVehicle'));
$('#btn-engine').addEventListener('click',     () => nuiPost('toggleEngine'));
$('#btn-lock').addEventListener('click',       () => nuiPost('toggleLock'));

$('#btn-set-plate').addEventListener('click', () => {
    const plate = $('#plateInput').value.trim();
    if (!plate) return;
    nuiPost('setPlate', { plate });
});

$('#btn-set-livery').addEventListener('click', () => {
    const livery = parseInt($('#liveryInput').value, 10) || 0;
    nuiPost('setLivery', { livery });
});

$('#btn-set-tint').addEventListener('click', () => {
    const tint = parseInt($('#tintInput').value, 10) || 0;
    nuiPost('setWindowTint', { tint });
});

$('#btn-set-color').addEventListener('click', () => {
    nuiPost('setVehicleColor', { primary: state.colorPrimary, secondary: state.colorSecondary });
});

const colorGrid = $('#colorGrid');
const colorHex = (i) => {
    const table = [
        '#0d0d0d','#191b1f','#262626','#404040','#5c5c5c','#737373','#969696','#b2b2b2','#cccccc','#e6e6e6',
        '#5a1212','#7a1717','#9b1c1c','#bf2424','#e02f2f','#ff4444','#ff6666','#ff8888','#ffaaaa','#ffcccc',
        '#3a2818','#5a3b1f','#7a4c25','#9b5e30','#bc7140','#dd8550','#ee9966','#f5ad7e','#f8c39a','#fbd9b8',
        '#5a4012','#7a5817','#9b701c','#bc8a24','#dca42f','#f5be3f','#ffce5a','#ffdc7d','#ffe9a0','#fff3c3',
        '#1f3a18','#2c5524','#387032','#458b3f','#52a64d','#6bc46b','#88d488','#a8e4a8','#c8efc8','#e3f7e3',
        '#0d3540','#16505a','#206b73','#2b878c','#37a3a5','#48bfbf','#65cdcd','#85dada','#a8e6e6','#caf0f0',
        '#0d2b50','#16407a','#1f55a3','#296acc','#357fe6','#4894f0','#62a8f0','#84baf0','#a8ccf0','#cad9f0',
        '#280d4a','#3d176b','#52218c','#682ba8','#7e35bc','#9550d4','#a96be0','#bf85e0','#d4a0e8','#e8c0f0',
        '#3a0d30','#5a164c','#7a1f66','#9b297f','#bc329a','#dd44b5','#ee69c4','#f590d4','#f8b3e0','#fbd2eb',
        '#1f1f1f','#2e2e2e','#3a3a3a','#474747','#555555','#626262','#707070','#808080','#909090','#a0a0a0',
        '#1a4733','#235a40','#2d6e4d','#37835c','#43996c','#52ad7c','#67bd92','#81ccaa','#9cdac1','#bee5d5',
        '#1a2e3a','#23415a','#2d557a','#37699b','#437dbc','#5290dd','#6da6ee','#8bb9f0','#a7c8f0','#c5d9f0',
        '#3a1a2e','#5a2342','#7a2c56','#9b366a','#bc4080','#dd4a95','#ee65a8','#f386bd','#f7a8cd','#fbcadc',
        '#332b1f','#403524','#4d402b','#594b34','#665740','#73654d','#80735a','#8c8268','#998f77','#a69d87',
        '#3a3a1f','#494924','#56562b','#646434','#727240','#80804d','#8d8d5a','#9a9a68','#a7a777','#b4b487',
        '#440c0c','#5e1010','#791515','#931a1a','#ad1f1f','#c72525','#dc4040','#e86060','#f08080','#f4a0a0',
    ];
    return table[i] || '#7a7a7a';
};

colorGrid.innerHTML = Array.from({ length: 160 }, (_, i) =>
    `<div class="color-swatch" data-idx="${i}" style="background:${colorHex(i)}" title="${esc(t('color_swatch_title', i))}"></div>`
).join('');

colorGrid.addEventListener('click', e => {
    const sw = e.target.closest('.color-swatch');
    if (!sw) return;
    const idx = parseInt(sw.dataset.idx, 10);
    if (e.ctrlKey) {
        state.colorSecondary = idx;
        $$('.color-swatch').forEach(s => s.classList.remove('selected-secondary'));
        sw.classList.add('selected-secondary');
        $('#colorSecondary').textContent = idx;
    } else {
        state.colorPrimary = idx;
        $$('.color-swatch').forEach(s => s.classList.remove('selected-primary'));
        sw.classList.add('selected-primary');
        $('#colorPrimary').textContent = idx;
    }
});

const WEATHERS = [
    { id: 'EXTRASUNNY', icon: 'sun',             key: 'weather_extrasunny' },
    { id: 'CLEAR',      icon: 'cloud-sun',       key: 'weather_clear' },
    { id: 'CLOUDS',     icon: 'cloud',           key: 'weather_clouds' },
    { id: 'OVERCAST',   icon: 'cloudy',          key: 'weather_overcast' },
    { id: 'RAIN',       icon: 'cloud-rain',      key: 'weather_rain' },
    { id: 'CLEARING',   icon: 'cloud-sun-rain',  key: 'weather_clearing' },
    { id: 'THUNDER',    icon: 'cloud-lightning', key: 'weather_thunder' },
    { id: 'SMOG',       icon: 'cloud-fog',       key: 'weather_smog' },
    { id: 'FOGGY',      icon: 'cloud-fog',       key: 'weather_foggy' },
    { id: 'SNOW',       icon: 'snowflake',       key: 'weather_snow' },
    { id: 'BLIZZARD',   icon: 'cloud-snow',      key: 'weather_blizzard' },
    { id: 'SNOWLIGHT',  icon: 'cloud-snow',      key: 'weather_snowlight' },
    { id: 'XMAS',       icon: 'tree-pine',       key: 'weather_xmas' },
    { id: 'HALLOWEEN',  icon: 'ghost',           key: 'weather_halloween' },
    { id: 'NEUTRAL',    icon: 'scale',           key: 'weather_neutral' },
];
function renderWeatherGrid() {
    $('#weatherGrid').innerHTML = WEATHERS.map(w =>
        `<button class="weather-btn" data-weather="${w.id}"><i data-lucide="${w.icon}"></i> ${esc(t(w.key))}</button>`
    ).join('');
    if (window.lucide) lucide.createIcons({ nodes: $$('#weatherGrid [data-lucide]') });
}
renderWeatherGrid();
$('#weatherGrid').addEventListener('click', e => {
    const btn = e.target.closest('.weather-btn');
    if (!btn) return;
    $$('.weather-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    nuiPost('syncWeather', { weather: btn.dataset.weather });
});

const TIME_PRESETS = [['06:00', 6, 0], ['09:00', 9, 0], ['12:00', 12, 0], ['18:00', 18, 0], ['21:00', 21, 0], ['00:00', 0, 0]];
$('#timePresets').innerHTML = TIME_PRESETS.map(([l, h, m]) =>
    `<span class="chip" data-h="${h}" data-m="${m}">${l}</span>`
).join('');
$('#timePresets').addEventListener('click', e => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    $('#timeHour').value   = chip.dataset.h;
    $('#timeMinute').value = chip.dataset.m;
});

$('#btn-set-time').addEventListener('click', () => {
    const hour   = parseInt($('#timeHour').value, 10) || 0;
    const minute = parseInt($('#timeMinute').value, 10) || 0;
    const freeze = $('#freezeTime').checked;
    nuiPost('syncTime', { hour, minute, freeze });
});

$('#btn-announce').addEventListener('click', () => {
    const message = $('#announceInput').value.trim();
    if (!message) return;
    nuiPost('announce', { message });
    $('#announceInput').value = '';
});

const resList   = $('#resourceList');
const resSearch = $('#resSearch');

function renderResources() {
    const q = state.resourceFilter.toLowerCase();
    const filtered = state.resources.filter(r => !q || r.name.toLowerCase().includes(q));
    if (!filtered.length) {
        resList.innerHTML = `<div class="empty">${esc(t('empty_no_resource'))}</div>`;
        return;
    }
    resList.innerHTML = filtered.map(r => `
        <div class="res-row">
            <span class="res-name">${esc(r.name)}</span>
            <span class="res-state ${esc(r.state)}">${esc(r.state)}</span>
            <span class="res-actions">
                <button class="btn ghost small" data-action="restart" data-name="${esc(r.name)}" title="${esc(t('res_restart_title'))}">↻</button>
                ${r.state === 'started'
                    ? `<button class="btn danger ghost small" data-action="stop" data-name="${esc(r.name)}">${esc(t('res_stop'))}</button>`
                    : `<button class="btn success small" data-action="start" data-name="${esc(r.name)}">${esc(t('res_start'))}</button>`
                }
            </span>
        </div>
    `).join('');
}

resSearch.addEventListener('input', () => {
    state.resourceFilter = resSearch.value.trim();
    renderResources();
});

resList.addEventListener('click', e => {
    const btn = e.target.closest('button[data-action]');
    if (!btn) return;
    const name = btn.dataset.name;
    const action = btn.dataset.action;
    if (action === 'restart') nuiPost('restartResource', { resourceName: name });
    if (action === 'start')   nuiPost('startResource',   { resourceName: name });
    if (action === 'stop')    nuiPost('stopResource',    { resourceName: name });
    setTimeout(() => nuiPost('getResources'), 600);
});

$('#btn-refresh-resources').addEventListener('click', () => nuiPost('getResources'));

const itemsList    = $('#itemsList');
const itemSearchEl = $('#itemSearch');

function renderItemsCatalog() {
    const q = state.itemsFilter.toLowerCase();
    const filtered = state.itemsCatalog.filter(it =>
        !q || it.name.toLowerCase().includes(q)
           || (it.label || '').toLowerCase().includes(q)
           || (it.type  || '').toLowerCase().includes(q)
    );

    $('#itemsSummary').textContent = t('items_count_filtered', filtered.length, state.itemsCatalog.length);

    if (!filtered.length) {
        itemsList.innerHTML = `<div class="empty">${esc(t('empty_no_item'))}</div>`;
        return;
    }

    itemsList.innerHTML = filtered.map(it => {
        const thumb = it.image_url
            ? `<img class="item-thumb" src="${esc(it.image_url)}" alt="" onerror="this.style.display='none'">`
            : `<img class="item-thumb" src="nui://inventory/ui/img/items/${esc(it.name)}.png" alt="" onerror="this.style.display='none'">`;
        return `
        <div class="item-row" data-name="${esc(it.name)}">
            ${thumb}
            <div class="item-body">
                <div class="item-head">
                    <span class="item-name">${esc(it.name)}</span>
                    <span class="item-label">${esc(it.label || '-')}</span>
                    <span class="item-type muted small">${esc(it.type || 'misc')}</span>
                </div>
                <div class="item-meta muted small">
                    ${(it.weight ?? 0)}kg ·
                    ${it.usable ? esc(t('item_usable_yes')) : esc(t('item_usable_no'))} ·
                    ${it.stackable ? esc(t('item_stackable_yes')) : esc(t('item_stackable_no'))}
                    ${it.drop_prop ? ' · ' + esc(t('item_prop_prefix', it.drop_prop)) : ''}
                    ${it.description ? ' · ' + esc(it.description) : ''}
                </div>
            </div>
            <div class="item-actions">
                <button class="btn small" data-act="edit">${esc(t('edit_btn'))}</button>
                <button class="btn danger ghost small" data-act="del">${esc(t('delete_btn'))}</button>
            </div>
        </div>
        `;
    }).join('');
}

function updateItemImagePreview() {
    const preview = $('#itemImagePreview');
    if (!preview) return;
    const url = $('#itemImageUrl').value.trim();
    if (url) {
        preview.style.backgroundImage = `url("${url.replace(/"/g, '\\"')}")`;
    } else {
        const name = $('#itemName').value.trim();
        preview.style.backgroundImage = name
            ? `url("nui://inventory/ui/img/items/${name}.png")`
            : '';
    }
}

function resetItemForm() {
    state.editingItem = null;
    $('#itemFormTitle').textContent = t('item_form_add');
    $('#itemName').value         = '';
    $('#itemName').disabled      = false;
    $('#itemLabel').value        = '';
    $('#itemType').value         = 'misc';
    $('#itemWeight').value       = '';
    $('#itemUsable').checked     = false;
    $('#itemStackable').checked  = true;
    $('#itemDescription').value  = '';
    if ($('#itemImageUrl'))      $('#itemImageUrl').value      = '';
    if ($('#itemDropProp'))      $('#itemDropProp').value      = '';
    if ($('#itemDropAnimDict'))  $('#itemDropAnimDict').value  = '';
    if ($('#itemDropAnimName'))  $('#itemDropAnimName').value  = '';
    updateItemImagePreview();
}

function loadItemIntoForm(name) {
    const it = state.itemsCatalog.find(i => i.name === name);
    if (!it) return;
    state.editingItem = name;
    $('#itemFormTitle').textContent = t('item_form_edit', it.name);
    $('#itemName').value         = it.name;
    $('#itemName').disabled      = true;
    $('#itemLabel').value        = it.label || '';
    $('#itemType').value         = it.type || 'misc';
    if ($('#itemType').value === '') $('#itemType').value = 'misc';
    $('#itemWeight').value       = it.weight ?? 0;
    $('#itemUsable').checked     = !!it.usable;
    $('#itemStackable').checked  = !!it.stackable;
    $('#itemDescription').value  = it.description || '';
    if ($('#itemImageUrl'))      $('#itemImageUrl').value      = it.image_url      || '';
    if ($('#itemDropProp'))      $('#itemDropProp').value      = it.drop_prop      || '';
    if ($('#itemDropAnimDict'))  $('#itemDropAnimDict').value  = it.drop_anim_dict || '';
    if ($('#itemDropAnimName'))  $('#itemDropAnimName').value  = it.drop_anim_name || '';
    updateItemImagePreview();
}

itemSearchEl.addEventListener('input', () => {
    state.itemsFilter = itemSearchEl.value.trim();
    renderItemsCatalog();
});

$('#btn-reload-items').addEventListener('click', () => nuiPost('reloadItemsCatalog'));
$('#btn-item-reset').addEventListener('click', resetItemForm);

$('#btn-item-save').addEventListener('click', () => {
    const name  = $('#itemName').value.trim().toLowerCase().replace(/\s+/g, '_');
    const label = $('#itemLabel').value.trim();
    if (!name || !label) return;
    nuiPost('saveItem', {
        name,
        label,
        type:           $('#itemType').value || 'misc',
        weight:         parseFloat($('#itemWeight').value) || 0,
        usable:         $('#itemUsable').checked,
        stackable:      $('#itemStackable').checked,
        description:    $('#itemDescription').value.trim(),
        image_url:      ($('#itemImageUrl')     ? $('#itemImageUrl').value.trim()     : ''),
        drop_prop:      ($('#itemDropProp')     ? $('#itemDropProp').value.trim()     : ''),
        drop_anim_dict: ($('#itemDropAnimDict') ? $('#itemDropAnimDict').value.trim() : ''),
        drop_anim_name: ($('#itemDropAnimName') ? $('#itemDropAnimName').value.trim() : ''),
    });
});

['#itemImageUrl', '#itemName'].forEach(sel => {
    const el = document.querySelector(sel);
    if (el) el.addEventListener('input', updateItemImagePreview);
});

itemsList.addEventListener('click', e => {
    const btn = e.target.closest('button[data-act]');
    if (!btn) return;
    const row = btn.closest('.item-row');
    if (!row) return;
    const name = row.dataset.name;
    if (btn.dataset.act === 'edit') {
        loadItemIntoForm(name);
        window.scrollTo({ top: 0, behavior: 'smooth' });
    } else if (btn.dataset.act === 'del') {
        if (confirm(t('confirm_delete_item', name))) {
            nuiPost('deleteItem', { name });
            if (state.editingItem === name) resetItemForm();
        }
    }
});

window.addEventListener('message', e => {
    const d = e.data || {};
    switch (d.action) {
        case 'open': openMenu(d); break;
        case 'close': app.classList.add('hidden'); closeModal(); break;

        case 'updatePlayers':
            state.players = d.players || [];
            renderPlayers();
            break;

        case 'playerInfo': renderPlayerInfo(d.info); break;

        case 'playerInventory': renderInventory(d.payload); break;
        case 'itemCatalog':
            state.itemCatalog = d.catalog || [];
            renderItemCatalog();
            break;
        case 'playerNeeds':         renderNeeds(d.payload); break;
        case 'playerCharacterInfo': renderCharacterInfo(d.payload); break;
        case 'playerVehicles':      renderVehicles(d.payload); break;
        case 'jobsCatalog':
            state.jobsCatalog = d.catalog || [];
            renderJobsCatalog();
            break;
        case 'playerJob':           renderPlayerJob(d.payload); break;
        case 'resourceList':
            state.resources = d.list || [];
            renderResources();
            break;
        case 'itemsCatalog':
            state.itemsCatalog = d.catalog || [];
            renderItemsCatalog();
            if (state.editingItem && !state.itemsCatalog.find(i => i.name === state.editingItem)) {
                resetItemForm();
            }
            break;

        case 'overlaySettings':
            applyOverlayUI(d.settings);
            setToggleCard('btn-overlay', d.active, 'overlay', 'statESP');
            break;
        case 'overlayState':   setToggleCard('btn-overlay',   d.active, 'overlay',   'statESP');   break;
        case 'noclipState':    setToggleCard('btn-noclip',    d.active, 'noclip',    'statNoclip'); break;
        case 'godmodeState':   setToggleCard('btn-godmode',   d.active, 'godmode',   'statGod');   break;
        case 'invisibleState': setToggleCard('btn-invisible', d.active, 'invisible', 'statInvis'); break;
        case 'spectateState':  state.flags.spectate = !!d.active; break;

        case 'myCoords':
            $('#tpX').value = d.x;
            $('#tpY').value = d.y;
            $('#tpZ').value = d.z;
            break;

        case 'esp:setActive':
            ESP.setActive(!!d.active);
            break;
        case 'esp:update':
            ESP.renderSelf(d.self);
            ESP.renderLabels(d.labels || []);
            break;
    }
});

const ESP = {
    overlay: null,
    selfEl:  null,
    labelsEl: null,
    pool:    new Map(),
    seen:    new Set(),

    init() {
        this.overlay  = document.getElementById('esp-overlay');
        this.selfEl   = document.getElementById('esp-self');
        this.labelsEl = document.getElementById('esp-labels');
    },

    setActive(active) {
        if (!this.overlay) return;
        if (active) {
            this.overlay.classList.remove('hidden');
        } else {
            this.overlay.classList.add('hidden');
            this.labelsEl.innerHTML = '';
            this.pool.clear();
            this.selfEl.classList.add('hidden');
            this.selfEl.innerHTML = '';
        }
    },

    _renderLines(title, lines) {
        let html = '';
        if (title) html += `<div class="esp-title">${esc(title)}</div>`;
        for (const l of lines || []) {
            const cls = l.cls ? ` ${l.cls}` : '';
            html += `<div class="esp-row"><span class="esp-key">${esc(l.k)}</span><span class="esp-val${cls}">${esc(l.v)}</span></div>`;
        }
        return html;
    },

    renderSelf(self) {
        if (!self || !self.lines || self.lines.length === 0) {
            this.selfEl.classList.add('hidden');
            return;
        }
        this.selfEl.classList.remove('hidden');
        this.selfEl.innerHTML = this._renderLines(self.title || 'Self', self.lines);
    },

    renderLabels(labels) {
        this.seen.clear();
        for (const lbl of labels) {
            this.seen.add(lbl.id);
            let el = this.pool.get(lbl.id);
            if (!el) {
                el = document.createElement('div');
                el.className = 'esp-label kind-' + lbl.kind;
                el.dataset.kind = lbl.kind;
                this.labelsEl.appendChild(el);
                this.pool.set(lbl.id, el);
            } else if (el.dataset.kind !== lbl.kind) {
                el.className = 'esp-label kind-' + lbl.kind;
                el.dataset.kind = lbl.kind;
            }
            el.style.left = (lbl.x * 100).toFixed(3) + '%';
            el.style.top  = (lbl.y * 100).toFixed(3) + '%';
            el.innerHTML  = this._renderLines(lbl.title, lbl.lines);
        }
        for (const [id, el] of this.pool) {
            if (!this.seen.has(id)) {
                el.remove();
                this.pool.delete(id);
            }
        }
    },
};

ESP.init();

// re-randare a stringurilor generate din JS la schimbarea dictionarului
document.addEventListener('sw:i18n', () => {
    renderPlayers();
    if (state.itemCatalog.length) renderItemCatalog();
    if (state.currentInventory) renderInventory(state.currentInventory);
    if (state.jobsCatalog.length) renderJobsCatalog();
    if (state.currencies.length) populateCurrencies();
    if (state.groups.length) populateGroups();
    renderResources();
    renderItemsCatalog();
    const activeWeather = $('#weatherGrid .weather-btn.active');
    const activeWeatherId = activeWeather && activeWeather.dataset.weather;
    renderWeatherGrid();
    if (activeWeatherId) {
        const btn = $(`#weatherGrid .weather-btn[data-weather="${activeWeatherId}"]`);
        if (btn) btn.classList.add('active');
    }
});

function renderPlayerInfo(info) {
    if (!info) {
        $('#infoBlock').innerHTML = `<span class="muted">${esc(t('info_no_data'))}</span>`;
        return;
    }
    const ids = (info.identifiers || []).map(i => `<div>${esc(i)}</div>`).join('');
    const groups = (info.groups || [])
        .map(g => `<span class="group-badge ${esc(g.name || g)}">${esc(g.name || g)}</span>`)
        .join('') || '<span class="muted">-</span>';

    $('#infoBlock').innerHTML = `
        <div><span class="ik">${esc(t('info_id'))}</span>      <span class="iv">${info.id}</span></div>
        <div><span class="ik">${esc(t('info_name'))}</span>    <span class="iv">${esc(info.name)}</span></div>
        <div><span class="ik">${esc(t('info_db_id'))}</span>   <span class="iv">${info.dbId ?? '-'}</span></div>
        <div><span class="ik">${esc(t('info_char_id'))}</span> <span class="iv">${info.characterId ?? '-'}</span></div>
        <div><span class="ik">${esc(t('info_ping'))}</span>    <span class="iv">${esc(t('ping_suffix', info.ping))}</span></div>
        <div><span class="ik">${esc(t('info_bucket'))}</span>  <span class="iv">${info.bucket ?? 0}</span></div>
        <hr>
        <div><span class="ik">${esc(t('info_groups'))}</span></div>
        <div>${groups}</div>
        <hr>
        ${info.coords ? `<div><span class="ik">${esc(t('info_coord'))}</span> <span class="iv">${info.coords.x.toFixed(1)}, ${info.coords.y.toFixed(1)}, ${info.coords.z.toFixed(1)}</span></div>` : ''}
        ${info.heading != null ? `<div><span class="ik">${esc(t('info_heading'))}</span> <span class="iv">${Math.floor(info.heading)}°</span></div>` : ''}
        <hr>
        <div><span class="ik">${esc(t('info_identifiers'))}</span></div>
        ${ids || '<span class="muted">-</span>'}
    `;

    $('#bucketCurrent').textContent = info.bucket ?? 0;
    $('#bucketInput').value         = info.bucket ?? 0;

    $('#currentGroups').innerHTML = (info.groups || [])
        .map(g => `<span class="group-badge ${esc(g.name || g)}">${esc(g.name || g)}</span>`)
        .join('') || `<span class="muted small">${esc(t('group_none'))}</span>`;
}
