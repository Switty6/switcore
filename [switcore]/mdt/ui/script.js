
const IS_BROWSER = typeof GetParentResourceName === 'undefined';

// Traducere prin helperul standard SwI18n (core/ui/i18n.js); fallback pe cheie.
function t(key, ...args) {
    if (typeof SwI18n === 'undefined') return key;
    return SwI18n.t(`mdt.${key}`, ...args);
}

// Re-randare a continutului generat din JS la schimbarea limbii.
document.addEventListener('sw:i18n', () => {
    if (!state.job) return;
    if (state.job === 'ems') {
        buildEMSTabs();
    } else {
        buildPoliceTabs();
        renderCitations();
        renderBOLOs();
        renderIncidents();
        renderImpounds();
        renderOfficers(state.officers);
        if (state.activeTab === 'management') renderManagement();
    }
});

const MOCK = {
    jobName: 'police',
    warrants: [
        { id: 1, first_name: 'Ion', last_name: 'Popescu', charges: 'Talharie, Posesie arma', bail_amount: 5000, issued_at: new Date().toISOString() },
        { id: 2, first_name: 'Maria', last_name: 'Ionescu', charges: 'Evaziune fiscala', bail_amount: 0, issued_at: new Date().toISOString() }
    ],
    officers: [
        { first_name: 'Alex', last_name: 'Marin', grade_label: 'Sergent' },
        { first_name: 'Dan', last_name: 'Cretu', grade_label: 'Inspector' }
    ],
    canManage: true,
    management: {
        balance: 250000,
        transactions: [
            { type: 'credit', amount: 5000, description: 'Cautiune Ion Popescu', created_at: new Date().toISOString() },
            { type: 'debit', amount: -45000, description: 'Achizitie vehicul POLIT001', created_at: new Date().toISOString() }
        ],
        fleet: [
            { id: 1, label: 'Patrula Standard', plate: 'POLIT001', fuel: 85, mileage: 12340, is_available: true, purchase_price: 45000 },
            { id: 2, label: 'Patrula Rapida', plate: 'POLIT002', fuel: 42, mileage: 8760, is_available: false, purchase_price: 60000 }
        ],
        fleetModels: [
            { model: 'police', label: 'Patrula Standard', price: 45000 },
            { model: 'police2', label: 'Patrula Rapida', price: 60000 }
        ],
        sellRatio: 0.6,
        armoryWeapons: [
            { itemName: 'weapon_pistol', label: 'Pistol', ammoItem: 'ammo_pistol', ammoAmount: 50 }
        ],
        armoryEquipment: [
            { itemName: 'handcuffs', label: 'Catuse', amount: 1 }
        ]
    },
    citations: [
        { id: 1, first_name: 'Radu', last_name: 'Pop', offense: 'Depasire viteza', fine_amount: 800, is_paid: false, issued_at: new Date().toISOString() }
    ],
    bolos: [
        { id: 1, subject_name: 'Necunoscut', description: 'Suspect in tricou rosu', vehicle_info: 'Masina alba, fara numar', is_active: true, created_at: new Date().toISOString() }
    ],
    incidents: [
        { id: 1, title: 'Altercatie La Bar', description: 'Scandal cu arma alba', created_at: new Date().toISOString() }
    ],
    impounds: [
        { id: 1, plate: 'B123ABC', model: 'Sultan', reason: 'Vehicul neînmatriculat', fee: 2500, is_retrieved: false, impounded_at: new Date().toISOString() }
    ]
};

const state = {
    job: null,
    warrants: [],
    officers: [],
    canManage: false,
    management: null,
    citations: [],
    bolos: [],
    incidents: [],
    impounds: [],
    calls: {},
    activeTab: null,
    activeSubTab: null,
    searchTimeout: null,
    modalSearchTimeout: null,
    modalSearchMode: null,
};

function postNUI(action, data = {}) {
    if (IS_BROWSER) { console.log('[NUI]', action, data); return; }
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

window.addEventListener('message', function(e) {
    const d = e.data;
    switch (d.action) {
        case 'openMDT':          openMDT(d);                   break;
        case 'closeMDT':         closeMDT();                   break;
        // Police
        case 'searchResults':    onPoliceSearch(d.results);    break;
        case 'warrantCreated':   onWarrantCreated(d.warrant);  break;
        case 'warrantClosed':    onWarrantClosed(d.warrantId); break;
        case 'onDutyOfficers':   renderOfficers(d.officers);   break;
        case 'fleetVehicleAdded':   onFleetAdded(d.vehicle);   break;
        case 'fleetVehicleRemoved': onFleetRemoved(d.vehicleId); break;
        case 'armoryUpdated':    onArmoryUpdated(d.weapons, d.equipment); break;
        case 'criminalHistory':  renderCriminalHistory(d.data); break;
        case 'citationsData':    onCitationsData(d.data);      break;
        case 'bolosData':        onBolosData(d.data);          break;
        case 'incidentsData':    onIncidentsData(d.data);      break;
        case 'impoundsData':     onImpoundsData(d.data);       break;
        // EMS
        case 'updateCalls':      renderCalls(d.data);          break;
        case 'addCall':          addCall(d.data);              break;
        case 'searchResults':    onPatientSearch(d.data);      break;  // EMS uses same key
        case 'patientHistory':   renderPatientHistory(d.data); break;
        case 'updateRoster':     renderRoster(d.data);         break;
    }
});

function openMDT(data) {
    state.job        = data.jobName || 'police';
    state.warrants   = data.warrants   || [];
    state.officers   = data.officers   || [];
    state.canManage  = !!data.canManage;
    state.management = data.management || null;

    const panel = document.getElementById('mdt-panel');
    panel.classList.remove('hidden', 'ems-mode');

    if (state.job === 'ems') {
        panel.classList.add('ems-mode');
        document.getElementById('mdt-badge').textContent = t('header.badge_ems');
        document.getElementById('mdt-title').textContent = t('header.title_ems');
        buildEMSTabs();
    } else {
        document.getElementById('mdt-badge').textContent = t('header.badge_police');
        document.getElementById('mdt-title').textContent = t('header.title_police');
        buildPoliceTabs();
    }
}

function closeMDT() {
    document.getElementById('mdt-panel').classList.add('hidden');
    state.job = null;
}

const POLICE_TABS = [
    { id: 'warrants',    key: 'tab.warrants'   },
    { id: 'search',      key: 'tab.search'     },
    { id: 'criminal',    key: 'tab.criminal'   },
    { id: 'citations',   key: 'tab.citations'  },
    { id: 'bolos',       key: 'tab.bolos'      },
    { id: 'incidents',   key: 'tab.incidents'  },
    { id: 'impounds',    key: 'tab.impounds'   },
    { id: 'officers',    key: 'tab.officers'   },
    { id: 'management',  key: 'tab.management', requireManage: true },
];

const EMS_TABS = [
    { id: 'calls',       key: 'tab.calls'   },
    { id: 'patient',     key: 'tab.patient' },
    { id: 'medical',     key: 'tab.medical' },
    { id: 'team',        key: 'tab.team'    },
];

function buildPoliceTabs() {
    const tabsEl = document.getElementById('mdt-tabs');
    const bodyEl = document.getElementById('tab-body');

    const visibleTabs = POLICE_TABS.filter(t => !t.requireManage || state.canManage);

    tabsEl.innerHTML = visibleTabs.map(tab =>
        `<button class="tab-btn" data-tab="${tab.id}" onclick="switchTab('${tab.id}')">${t(tab.key)}</button>`
    ).join('');

    bodyEl.innerHTML = visibleTabs.map(tab =>
        `<div class="tab-content" id="tab-${tab.id}">${getPoliceTabContent(tab.id)}</div>`
    ).join('');

    renderWarrants();
    switchTab('warrants');
}

function buildEMSTabs() {
    const tabsEl = document.getElementById('mdt-tabs');
    const bodyEl = document.getElementById('tab-body');

    tabsEl.innerHTML = EMS_TABS.map(tab =>
        `<button class="tab-btn" data-tab="${tab.id}" onclick="switchTab('${tab.id}')">${t(tab.key)}</button>`
    ).join('');

    bodyEl.innerHTML = EMS_TABS.map(tab =>
        `<div class="tab-content" id="tab-${tab.id}">${getEMSTabContent(tab.id)}</div>`
    ).join('');

    switchTab('calls');
    postNUI('getCalls');
}

function getPoliceTabContent(id) {
    switch (id) {
        case 'warrants': return `
            <div class="tab-toolbar">
                <button class="btn-primary" onclick="showModal('warrant-modal')">${t('warrants.add_btn')}</button>
            </div>
            <table class="data-table">
                <thead><tr><th>${t('warrants.col_name')}</th><th>${t('warrants.col_charges')}</th><th>${t('warrants.col_bail')}</th><th>${t('warrants.col_date')}</th><th></th></tr></thead>
                <tbody id="warrants-body"></tbody>
            </table>`;

        case 'search': return `
            <div class="search-bar">
                <input type="text" id="search-input" placeholder="${t('search.placeholder')}" oninput="onSearchInput(this.value)" />
            </div>
            <div id="search-results-main"></div>`;

        case 'criminal': return `
            <div class="search-bar">
                <input type="text" id="criminal-search-input" placeholder="${t('criminal.search_placeholder')}" oninput="onCriminalSearch(this.value)" />
            </div>
            <div class="search-layout" style="flex:1;overflow:hidden">
                <div class="search-results-list" id="criminal-results-list"></div>
                <div class="search-detail" id="criminal-detail"><div class="empty-msg">${t('criminal.select_prompt')}</div></div>
            </div>`;

        case 'citations': return `
            <div class="tab-toolbar">
                <button class="btn-primary" onclick="showModal('citation-modal')">${t('citations.add_btn')}</button>
                <button class="btn-secondary" onclick="postNUI('getCitations')">${t('common.refresh')}</button>
            </div>
            <table class="data-table">
                <thead><tr><th>${t('citations.col_suspect')}</th><th>${t('citations.col_offense')}</th><th>${t('citations.col_fine')}</th><th>${t('citations.col_status')}</th><th>${t('citations.col_date')}</th><th></th></tr></thead>
                <tbody id="citations-body"></tbody>
            </table>`;

        case 'bolos': return `
            <div class="tab-toolbar">
                <button class="btn-primary" onclick="showModal('bolo-modal')">${t('bolos.add_btn')}</button>
                <button class="btn-secondary" onclick="postNUI('getActiveBOLOs')">${t('common.refresh')}</button>
            </div>
            <table class="data-table">
                <thead><tr><th>${t('bolos.col_subject')}</th><th>${t('bolos.col_description')}</th><th>${t('bolos.col_vehicle')}</th><th>${t('bolos.col_date')}</th><th></th></tr></thead>
                <tbody id="bolos-body"></tbody>
            </table>`;

        case 'incidents': return `
            <div class="tab-toolbar">
                <button class="btn-primary" onclick="showModal('incident-modal')">${t('incidents.add_btn')}</button>
                <button class="btn-secondary" onclick="postNUI('getIncidents')">${t('common.refresh')}</button>
            </div>
            <table class="data-table">
                <thead><tr><th>${t('incidents.col_title')}</th><th>${t('incidents.col_description')}</th><th>${t('incidents.col_date')}</th></tr></thead>
                <tbody id="incidents-body"></tbody>
            </table>`;

        case 'impounds': return `
            <div class="tab-toolbar">
                <button class="btn-primary" onclick="showModal('impound-modal')">${t('impounds.add_btn')}</button>
                <button class="btn-secondary" onclick="postNUI('getImpounds')">${t('common.refresh')}</button>
            </div>
            <table class="data-table">
                <thead><tr><th>${t('impounds.col_plate')}</th><th>${t('impounds.col_model')}</th><th>${t('impounds.col_reason')}</th><th>${t('impounds.col_fee')}</th><th>${t('impounds.col_status')}</th><th>${t('impounds.col_date')}</th><th></th></tr></thead>
                <tbody id="impounds-body"></tbody>
            </table>`;

        case 'officers': return `
            <div class="tab-toolbar">
                <button class="btn-secondary" onclick="postNUI('getOnDutyOfficers')">${t('common.refresh')}</button>
            </div>
            <div id="officers-list"></div>`;

        case 'management': return `
            <div class="sub-tabs">
                <button class="sub-tab-btn" data-stab="budget"      onclick="switchSubTab('budget')">${t('management.sub_budget')}</button>
                <button class="sub-tab-btn" data-stab="mgmt-fleet"  onclick="switchSubTab('mgmt-fleet')">${t('management.sub_fleet')}</button>
                <button class="sub-tab-btn" data-stab="mgmt-armory" onclick="switchSubTab('mgmt-armory')">${t('management.sub_armory')}</button>
            </div>
            <div id="stab-budget" class="sub-tab-content">
                <div class="budget-header">
                    <div class="budget-balance-chip">
                        <span class="budget-label">${t('management.budget_available')}</span>
                        <span id="budget-balance" class="budget-amount">$0</span>
                    </div>
                </div>
                <table class="data-table" id="budget-tx-table">
                    <thead><tr><th>${t('management.tx_col_type')}</th><th>${t('management.tx_col_amount')}</th><th>${t('management.tx_col_description')}</th><th>${t('management.tx_col_date')}</th></tr></thead>
                    <tbody id="budget-tx-body"></tbody>
                </table>
            </div>
            <div id="stab-mgmt-fleet" class="sub-tab-content">
                <div class="mgmt-section">
                    <h3 class="mgmt-section-title">${t('management.fleet_current')}</h3>
                    <div id="mgmt-fleet-list"></div>
                </div>
                <div class="mgmt-section">
                    <h3 class="mgmt-section-title">${t('management.fleet_purchase')}</h3>
                    <div id="mgmt-models-list"></div>
                </div>
            </div>
            <div id="stab-mgmt-armory" class="sub-tab-content">
                <div class="mgmt-section">
                    <h3 class="mgmt-section-title">${t('management.armory_weapons')}</h3>
                    <div id="mgmt-armory-weapons"></div>
                    <div class="mgmt-add-form">
                        <h4>${t('management.add_weapon')}</h4>
                        <input type="text" id="new-weapon-item" placeholder="${t('management.ph_item_name')}" />
                        <input type="text" id="new-weapon-label" placeholder="${t('management.ph_display_name')}" />
                        <input type="text" id="new-weapon-ammo" placeholder="${t('management.ph_ammo_item')}" />
                        <input type="number" id="new-weapon-ammo-amount" placeholder="${t('management.ph_ammo_amount')}" value="0" min="0" />
                        <button class="btn-primary" onclick="submitAddWeapon()">${t('common.add')}</button>
                    </div>
                </div>
                <div class="mgmt-section">
                    <h3 class="mgmt-section-title">${t('management.armory_equipment')}</h3>
                    <div id="mgmt-armory-equipment"></div>
                    <div class="mgmt-add-form">
                        <h4>${t('management.add_equipment')}</h4>
                        <input type="text" id="new-equip-item" placeholder="${t('management.ph_item_name')}" />
                        <input type="text" id="new-equip-label" placeholder="${t('management.ph_display_name')}" />
                        <input type="number" id="new-equip-amount" placeholder="${t('management.ph_amount')}" value="1" min="1" />
                        <button class="btn-primary" onclick="submitAddEquipment()">${t('common.add')}</button>
                    </div>
                </div>
            </div>`;

        default: return `<div class="empty-msg">${t('tab.unavailable')}</div>`;
    }
}

function getEMSTabContent(id) {
    switch (id) {
        case 'calls': return `
            <div class="tab-toolbar">
                <button class="btn-secondary" onclick="postNUI('getCalls')">${t('common.refresh')}</button>
            </div>
            <table class="data-table">
                <thead><tr><th>${t('calls.col_caller')}</th><th>${t('calls.col_message')}</th><th>${t('calls.col_time')}</th><th>${t('calls.col_status')}</th><th>${t('calls.col_actions')}</th></tr></thead>
                <tbody id="calls-body"><tr><td colspan="5" class="empty-row">${t('calls.empty')}</td></tr></tbody>
            </table>`;

        case 'patient': return `
            <div class="search-bar">
                <input type="text" id="patient-search-input" placeholder="${t('patient.search_placeholder')}" oninput="onPatientSearchInput(this.value)" />
            </div>
            <div class="search-layout" style="flex:1;overflow:hidden">
                <div class="search-results-list" id="patient-results-list"></div>
                <div class="search-detail" id="patient-detail"><div class="empty-msg">${t('patient.select_prompt')}</div></div>
            </div>`;

        case 'medical': return `
            <div class="search-bar">
                <input type="text" id="medical-search-input" placeholder="${t('medical.search_placeholder')}" oninput="onMedicalSearch(this.value)" />
            </div>
            <div id="medical-results"></div>`;

        case 'team': return `
            <div class="tab-toolbar">
                <button class="btn-secondary" onclick="postNUI('getOnDutyEMS')">${t('common.refresh')}</button>
            </div>
            <div id="team-list"></div>`;

        default: return `<div class="empty-msg">${t('tab.unavailable')}</div>`;
    }
}

function switchTab(tabId) {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

    const btn = document.querySelector(`[data-tab="${tabId}"]`);
    const content = document.getElementById(`tab-${tabId}`);
    if (btn) btn.classList.add('active');
    if (content) content.classList.add('active');

    state.activeTab = tabId;

    if (tabId === 'management') renderManagement();
    if (tabId === 'officers')   postNUI('getOnDutyOfficers');
    if (tabId === 'citations')  postNUI('getCitations');
    if (tabId === 'bolos')      postNUI('getActiveBOLOs');
    if (tabId === 'incidents')  postNUI('getIncidents');
    if (tabId === 'impounds')   postNUI('getImpounds');
    if (tabId === 'team')       postNUI('getOnDutyEMS');
    if (tabId === 'calls')      postNUI('getCalls');
}

function switchSubTab(stabId) {
    document.querySelectorAll('.sub-tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.sub-tab-content').forEach(c => c.classList.remove('active'));
    const btn = document.querySelector(`[data-stab="${stabId}"]`);
    const content = document.getElementById(`stab-${stabId}`);
    if (btn) btn.classList.add('active');
    if (content) content.classList.add('active');
    state.activeSubTab = stabId;
}

function renderWarrants() {
    const tbody = document.getElementById('warrants-body');
    if (!tbody) return;
    if (!state.warrants.length) {
        tbody.innerHTML = `<tr><td colspan="5" class="empty-row">${t('warrants.empty')}</td></tr>`;
        return;
    }
    tbody.innerHTML = state.warrants.map(w => `
        <tr>
            <td><strong>${esc(w.first_name)} ${esc(w.last_name)}</strong></td>
            <td class="cell-truncate">${esc(w.charges)}</td>
            <td>${w.bail_amount > 0 ? '$' + w.bail_amount.toLocaleString('ro-RO') : '-'}</td>
            <td>${formatDate(w.issued_at)}</td>
            <td><button class="btn-danger-sm" onclick="closeWarrant(${w.id})">${t('warrants.close_btn')}</button></td>
        </tr>`).join('');
}

function onWarrantCreated(warrant) {
    if (warrant) { state.warrants.unshift(warrant); renderWarrants(); }
}

function onWarrantClosed(warrantId) {
    state.warrants = state.warrants.filter(w => w.id !== warrantId);
    renderWarrants();
}

function closeWarrant(id) { postNUI('closeWarrant', { warrantId: id }); }

function submitWarrant() {
    const charId  = document.getElementById('warrant-char-id').value;
    const charges = document.getElementById('warrant-charges').value.trim();
    const bail    = parseInt(document.getElementById('warrant-bail').value) || 0;
    if (!charId || charges.length < 3) { alert(t('alert.fill_all')); return; }
    postNUI('createWarrant', { characterId: parseInt(charId), charges, bailAmount: bail });
    hideModal('warrant-modal');
}

function onSearchInput(val) {
    clearTimeout(state.searchTimeout);
    const el = document.getElementById('search-results-main');
    if (!el) return;
    if (!val || val.length < 2) { el.innerHTML = ''; return; }
    state.searchTimeout = setTimeout(() => {
        state._searchMode = 'main';
        postNUI('mdtSearch', { query: val });
    }, 400);
}

function onPoliceSearch(results) {
    if (state._searchMode === 'main') {
        renderMainSearch(results);
    } else if (state._searchMode === 'modal') {
        renderModalSearch(results, state.modalSearchMode);
    }
}

function renderMainSearch(results) {
    const el = document.getElementById('search-results-main');
    if (!el) return;
    if (!results || !results.length) { el.innerHTML = `<div class="empty-msg">${t('common.no_results')}</div>`; return; }
    el.innerHTML = results.map(c => `
        <div class="person-card">
            <div class="person-card-name">
                ${esc(c.first_name)} ${esc(c.last_name)}
                <span class="person-age">${t('search.age_suffix', c.age)}</span>
            </div>
            <div class="person-card-badges">
                ${c.hasWarrant ? `<span class="badge badge-warn">${t('search.badge_warrant')}</span>` : ''}
                ${c.isJailed   ? `<span class="badge badge-danger">${t('search.badge_jailed')}</span>` : ''}
            </div>
            <div class="person-card-actions">
                <button class="btn-secondary-sm" onclick="quickWarrant(${c.id}, '${esc(c.first_name)} ${esc(c.last_name)}')">${t('search.emit_warrant')}</button>
                ${c.isJailed ? `<button class="btn-secondary-sm" onclick="unjailChar(${c.id})">${t('search.release')}</button>` : ''}
                <button class="btn-secondary-sm" onclick="viewCriminalHistory(${c.id}, '${esc(c.first_name)} ${esc(c.last_name)}')">${t('search.criminal_record')}</button>
            </div>
        </div>`).join('');
}

function quickWarrant(charId, name) {
    showModal('warrant-modal');
    selectModalChar('warrant', charId, name);
}

function unjailChar(charId) {
    if (!confirm(t('search.confirm_unjail'))) return;
    postNUI('unjailEarly', { characterId: charId });
}

function viewCriminalHistory(charId, name) {
    switchTab('criminal');
    const detailEl = document.getElementById('criminal-detail');
    if (detailEl) detailEl.innerHTML = `<div class="loading">${t('criminal.loading', esc(name))}</div>`;
    postNUI('getCriminalHistory', { characterId: charId });
}

let criminalSearchDebounce = null;
function onCriminalSearch(val) {
    clearTimeout(criminalSearchDebounce);
    const listEl = document.getElementById('criminal-results-list');
    if (!listEl) return;
    if (!val || val.length < 2) { listEl.innerHTML = ''; return; }
    criminalSearchDebounce = setTimeout(() => {
        state._searchMode = 'criminal';
        postNUI('mdtSearch', { query: val });
    }, 400);
}

function renderCriminalSearchResults(results) {
    const listEl = document.getElementById('criminal-results-list');
    if (!listEl) return;
    if (!results || !results.length) { listEl.innerHTML = `<div class="empty-msg">${t('common.no_results')}</div>`; return; }
    listEl.innerHTML = results.map(c => `
        <div class="result-row" onclick="loadCriminalHistory(${c.id}, '${esc(c.first_name)} ${esc(c.last_name)}')">
            <span class="result-name">${esc(c.first_name)} ${esc(c.last_name)}</span>
            ${c.hasWarrant ? `<span class="badge badge-warn">${t('criminal.badge_warrant')}</span>` : ''}
            ${c.isJailed   ? `<span class="badge badge-danger">${t('criminal.badge_jailed')}</span>` : ''}
        </div>`).join('');
}

function loadCriminalHistory(charId, name) {
    document.querySelectorAll('#criminal-results-list .result-row').forEach(r => r.classList.remove('selected'));
    event && event.currentTarget && event.currentTarget.classList.add('selected');
    const detailEl = document.getElementById('criminal-detail');
    if (detailEl) detailEl.innerHTML = `<div class="loading">${t('criminal.loading', esc(name))}</div>`;
    postNUI('getCriminalHistory', { characterId: charId });
}

function renderCriminalHistory(data) {
    const detailEl = document.getElementById('criminal-detail');
    if (!detailEl) return;
    if (!data) { detailEl.innerHTML = `<div class="empty-msg">${t('common.data_unavailable')}</div>`; return; }

    const jails    = data.jails    || [];
    const warrants = data.warrants || [];
    const citations= data.citations|| [];

    let html = '';

    html += `<div class="history-section">
        <div class="history-section-title">${t('criminal.section_arrests', jails.length)}</div>`;
    if (!jails.length) {
        html += `<div class="empty-msg" style="padding:10px">${t('criminal.no_arrests')}</div>`;
    } else {
        jails.forEach(j => {
            html += `<div class="history-row">
                <div class="history-row-header">
                    <span class="badge badge-danger">${t('criminal.badge_arrest')}</span>
                    <span>${esc(j.reason)}</span>
                    <span class="history-row-date">${formatDate(j.arrested_at)}</span>
                </div>
                <div class="history-row-detail">${t('criminal.arrest_detail', j.sentence_minutes, j.bail_amount)}</div>
            </div>`;
        });
    }
    html += '</div>';

    html += `<div class="history-section">
        <div class="history-section-title">${t('criminal.section_warrants', warrants.length)}</div>`;
    if (!warrants.length) {
        html += `<div class="empty-msg" style="padding:10px">${t('criminal.no_warrants')}</div>`;
    } else {
        warrants.forEach(w => {
            html += `<div class="history-row">
                <div class="history-row-header">
                    <span class="badge ${w.is_active ? 'badge-warn' : 'badge-gray'}">${w.is_active ? t('criminal.warrant_active') : t('criminal.warrant_closed')}</span>
                    <span>${esc(w.charges)}</span>
                    <span class="history-row-date">${formatDate(w.issued_at)}</span>
                </div>
            </div>`;
        });
    }
    html += '</div>';

    html += `<div class="history-section">
        <div class="history-section-title">${t('criminal.section_citations', citations.length)}</div>`;
    if (!citations.length) {
        html += `<div class="empty-msg" style="padding:10px">${t('criminal.no_citations')}</div>`;
    } else {
        citations.forEach(c => {
            html += `<div class="history-row">
                <div class="history-row-header">
                    <span class="badge ${c.is_paid ? 'badge-ok' : 'badge-warn'}">${c.is_paid ? t('criminal.citation_paid') : t('criminal.citation_unpaid')}</span>
                    <span>${esc(c.offense)}</span>
                    <span class="history-row-date">${formatDate(c.issued_at)}</span>
                </div>
                <div class="history-row-detail">${t('criminal.citation_fine', c.fine_amount)}</div>
            </div>`;
        });
    }
    html += '</div>';

    detailEl.innerHTML = html;
}

function onCitationsData(data) {
    state.citations = data || [];
    renderCitations();
}

function renderCitations() {
    const tbody = document.getElementById('citations-body');
    if (!tbody) return;
    if (!state.citations.length) {
        tbody.innerHTML = `<tr><td colspan="6" class="empty-row">${t('citations.empty')}</td></tr>`;
        return;
    }
    tbody.innerHTML = state.citations.map(c => `
        <tr>
            <td>${esc(c.first_name)} ${esc(c.last_name)}</td>
            <td class="cell-truncate">${esc(c.offense)}</td>
            <td>$${c.fine_amount}</td>
            <td><span class="badge ${c.is_paid ? 'badge-ok' : 'badge-warn'}">${c.is_paid ? t('citations.status_paid') : t('citations.status_unpaid')}</span></td>
            <td>${formatDate(c.issued_at)}</td>
            <td>${!c.is_paid ? `<button class="btn-success-sm" onclick="markCitationPaid(${c.id})">${t('citations.mark_paid')}</button>` : ''}</td>
        </tr>`).join('');
}

function markCitationPaid(id) {
    postNUI('payCitationOfficer', { citationId: id });
    state.citations = state.citations.map(c => c.id === id ? { ...c, is_paid: true } : c);
    renderCitations();
}

function submitCitation() {
    const charId  = document.getElementById('citation-char-id').value;
    const offense = document.getElementById('citation-offense').value.trim();
    const fine    = parseInt(document.getElementById('citation-fine').value) || 500;
    if (!charId || offense.length < 3) { alert(t('alert.fill_all')); return; }
    postNUI('createCitation', { characterId: parseInt(charId), offense, fineAmount: fine });
    hideModal('citation-modal');
}

function onBolosData(data) {
    state.bolos = data || [];
    renderBOLOs();
}

function renderBOLOs() {
    const tbody = document.getElementById('bolos-body');
    if (!tbody) return;
    if (!state.bolos.length) {
        tbody.innerHTML = `<tr><td colspan="5" class="empty-row">${t('bolos.empty')}</td></tr>`;
        return;
    }
    tbody.innerHTML = state.bolos.map(b => `
        <tr>
            <td><strong>${esc(b.subject_name)}</strong></td>
            <td class="cell-truncate">${esc(b.description)}</td>
            <td>${esc(b.vehicle_info) || '-'}</td>
            <td>${formatDate(b.created_at)}</td>
            <td><button class="btn-danger-sm" onclick="closeBOLO(${b.id})">${t('bolos.close_btn')}</button></td>
        </tr>`).join('');
}

function closeBOLO(id) {
    postNUI('closeBOLO', { boloId: id });
    state.bolos = state.bolos.filter(b => b.id !== id);
    renderBOLOs();
}

function submitBOLO() {
    const subject = document.getElementById('bolo-subject').value.trim();
    const desc    = document.getElementById('bolo-description').value.trim();
    const vehicle = document.getElementById('bolo-vehicle').value.trim();
    if (!subject || desc.length < 3) { alert(t('alert.fill_subject_desc')); return; }
    postNUI('createBOLO', { subjectName: subject, description: desc, vehicleInfo: vehicle });
    hideModal('bolo-modal');
}

function onIncidentsData(data) {
    state.incidents = data || [];
    renderIncidents();
}

function renderIncidents() {
    const tbody = document.getElementById('incidents-body');
    if (!tbody) return;
    if (!state.incidents.length) {
        tbody.innerHTML = `<tr><td colspan="3" class="empty-row">${t('incidents.empty')}</td></tr>`;
        return;
    }
    tbody.innerHTML = state.incidents.map(i => `
        <tr>
            <td><strong>${esc(i.title)}</strong></td>
            <td class="cell-truncate">${esc(i.description)}</td>
            <td>${formatDate(i.created_at)}</td>
        </tr>`).join('');
}

function submitIncident() {
    const title    = document.getElementById('incident-title').value.trim();
    const desc     = document.getElementById('incident-desc').value.trim();
    const involved = document.getElementById('incident-involved').value.trim();
    if (title.length < 3 || desc.length < 3) { alert(t('alert.fill_title_desc')); return; }
    const involvedIds = involved ? involved.split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n)) : [];
    postNUI('createIncident', { title, description: desc, involvedCharacters: involvedIds });
    hideModal('incident-modal');
}

function onImpoundsData(data) {
    state.impounds = data || [];
    renderImpounds();
}

function renderImpounds() {
    const tbody = document.getElementById('impounds-body');
    if (!tbody) return;
    if (!state.impounds.length) {
        tbody.innerHTML = `<tr><td colspan="7" class="empty-row">${t('impounds.empty')}</td></tr>`;
        return;
    }
    tbody.innerHTML = state.impounds.map(i => `
        <tr>
            <td><code style="font-family:monospace;color:var(--text-dim)">${esc(i.plate)}</code></td>
            <td>${esc(i.model) || '-'}</td>
            <td class="cell-truncate">${esc(i.reason)}</td>
            <td>$${i.fee}</td>
            <td><span class="badge ${i.is_retrieved ? 'badge-ok' : 'badge-warn'}">${i.is_retrieved ? t('impounds.status_retrieved') : t('impounds.status_impounded')}</span></td>
            <td>${formatDate(i.impounded_at)}</td>
            <td>${!i.is_retrieved ? `<button class="btn-success-sm" onclick="retrieveImpound(${i.id})">${t('impounds.release_btn')}</button>` : ''}</td>
        </tr>`).join('');
}

function retrieveImpound(id) {
    postNUI('retrieveImpound', { impoundId: id });
    state.impounds = state.impounds.map(i => i.id === id ? { ...i, is_retrieved: true } : i);
    renderImpounds();
}

function submitImpound() {
    const plate  = document.getElementById('impound-plate').value.trim().toUpperCase();
    const model  = document.getElementById('impound-model').value.trim();
    const reason = document.getElementById('impound-reason').value.trim();
    const fee    = parseInt(document.getElementById('impound-fee').value) || 2500;
    if (!plate || reason.length < 3) { alert(t('alert.fill_plate_reason')); return; }
    postNUI('impoundVehicle', { plate, model, reason, fee });
    hideModal('impound-modal');
}

function renderOfficers(officers) {
    state.officers = officers || [];
    const el = document.getElementById('officers-list');
    if (!el) return;
    if (!state.officers.length) { el.innerHTML = `<div class="empty-msg">${t('officers.empty')}</div>`; return; }
    el.innerHTML = state.officers.map(o => `
        <div class="officer-row">
            <span class="officer-name">${esc(o.first_name)} ${esc(o.last_name)}</span>
            <span class="grade-chip">${esc(o.grade_label)}</span>
        </div>`).join('');
}

function renderManagement() {
    const m = state.management;
    if (!m) return;
    renderBudget(m.balance, m.transactions);
    renderMgmtFleet(m.fleet, m.fleetModels, m.sellRatio, m.balance);
    renderMgmtArmory(m.armoryWeapons, m.armoryEquipment);
    switchSubTab('budget');
}

function renderBudget(balance, transactions) {
    const el = document.getElementById('budget-balance');
    if (el) el.textContent = '$' + Math.floor(balance || 0).toLocaleString('ro-RO');
    const tbody = document.getElementById('budget-tx-body');
    if (!tbody) return;
    if (!transactions || !transactions.length) {
        tbody.innerHTML = `<tr><td colspan="4" class="empty-row">${t('management.tx_empty')}</td></tr>`; return;
    }
    tbody.innerHTML = transactions.map(t => {
        const amt = parseFloat(t.amount) || 0;
        const cls = amt >= 0 ? 'tx-credit' : 'tx-debit';
        const pfx = amt >= 0 ? '+' : '';
        return `<tr>
            <td><span class="badge ${amt >= 0 ? 'badge-ok' : 'badge-danger'}">${esc(t.type)}</span></td>
            <td class="${cls}">${pfx}$${Math.abs(amt).toLocaleString('ro-RO')}</td>
            <td>${esc(t.description || '-')}</td>
            <td>${formatDate(t.created_at)}</td>
        </tr>`;
    }).join('');
}

function renderMgmtFleet(fleet, models, sellRatio, balance) {
    const fleetEl  = document.getElementById('mgmt-fleet-list');
    const modelsEl = document.getElementById('mgmt-models-list');
    if (!fleetEl || !modelsEl) return;

    if (!fleet || !fleet.length) {
        fleetEl.innerHTML = `<div class="empty-msg">${t('management.fleet_empty')}</div>`;
    } else {
        fleetEl.innerHTML = fleet.map(v => {
            const sellPrice = Math.floor((parseFloat(v.purchase_price) || 0) * (sellRatio || 0.6));
            const unavail   = !v.is_available;
            return `<div class="mgmt-fleet-row ${unavail ? 'mgmt-fleet-inuse' : ''}">
                <span class="fleet-model">${esc(v.label)}</span>
                <span class="fleet-plate">${esc(v.plate)}</span>
                <span class="badge ${v.is_available ? 'badge-ok' : 'badge-danger'}">${v.is_available ? t('management.fleet_free') : t('management.fleet_in_use')}</span>
                ${v.is_available
                    ? `<button class="btn-danger-sm" onclick="sellVehicle(${v.id}, '${esc(v.plate)}', '${esc(v.label)}', ${sellPrice})">${t('management.fleet_sell', sellPrice.toLocaleString('ro-RO'))}</button>`
                    : `<span class="mgmt-inuse-label">${t('management.fleet_in_use')}</span>`
                }
            </div>`;
        }).join('');
    }

    if (!models || !models.length) {
        modelsEl.innerHTML = `<div class="empty-msg">${t('management.models_empty')}</div>`;
    } else {
        modelsEl.innerHTML = models.map(m => {
            const price    = parseInt(m.price) || 0;
            const canAfford = (balance || 0) >= price;
            return `<div class="mgmt-model-row">
                <span class="mgmt-model-label">${esc(m.label)}</span>
                <span class="mgmt-model-price">$${price.toLocaleString('ro-RO')}</span>
                <button class="btn-primary-sm ${canAfford ? '' : 'btn-disabled'}"
                    onclick="${canAfford ? `purchaseVehicle('${esc(m.model)}', '${esc(m.label)}')` : ''}"
                    ${canAfford ? '' : 'disabled'}>${t('management.buy_btn')}</button>
            </div>`;
        }).join('');
    }
}

function purchaseVehicle(model, label) {
    if (!confirm(t('management.confirm_buy', label))) return;
    postNUI('purchaseFleetVehicle', { model });
}
function sellVehicle(id, plate, label, sellPrice) {
    if (!confirm(t('management.confirm_sell', label, plate, sellPrice))) return;
    postNUI('sellFleetVehicle', { vehicleId: id });
}
function onFleetAdded(vehicle) {
    if (!state.management) return;
    state.management.fleet = state.management.fleet || [];
    state.management.fleet.unshift(vehicle);
    renderMgmtFleet(state.management.fleet, state.management.fleetModels, state.management.sellRatio, state.management.balance);
}
function onFleetRemoved(vehicleId) {
    if (!state.management) return;
    state.management.fleet = (state.management.fleet || []).filter(v => v.id !== vehicleId);
    renderMgmtFleet(state.management.fleet, state.management.fleetModels, state.management.sellRatio, state.management.balance);
}

function renderMgmtArmory(weapons, equipment) {
    const wEl = document.getElementById('mgmt-armory-weapons');
    const eEl = document.getElementById('mgmt-armory-equipment');
    if (!wEl || !eEl) return;

    wEl.innerHTML = (!weapons || !weapons.length)
        ? `<div class="empty-msg">${t('management.weapons_empty')}</div>`
        : weapons.map(w => `
            <div class="mgmt-armory-row">
                <span>${esc(w.label)}</span>
                <code class="item-code">${esc(w.itemName)}</code>
                ${w.ammoItem ? `<span class="ammo-info">${esc(w.ammoItem)} ×${w.ammoAmount}</span>` : ''}
                <button class="btn-danger-sm" onclick="removeArmoryWeapon('${esc(w.itemName)}')">${t('management.delete_btn')}</button>
            </div>`).join('');

    eEl.innerHTML = (!equipment || !equipment.length)
        ? `<div class="empty-msg">${t('management.equipment_empty')}</div>`
        : equipment.map(e => `
            <div class="mgmt-armory-row">
                <span>${esc(e.label)}</span>
                <code class="item-code">${esc(e.itemName)}</code>
                <span class="ammo-info">×${e.amount}</span>
                <button class="btn-danger-sm" onclick="removeArmoryEquipment('${esc(e.itemName)}')">${t('management.delete_btn')}</button>
            </div>`).join('');
}

function submitAddWeapon() {
    const itemName   = document.getElementById('new-weapon-item').value.trim();
    const label      = document.getElementById('new-weapon-label').value.trim();
    const ammoItem   = document.getElementById('new-weapon-ammo').value.trim();
    const ammoAmount = parseInt(document.getElementById('new-weapon-ammo-amount').value) || 0;
    if (!itemName || !label) { alert(t('alert.fill_item_label')); return; }
    postNUI('addArmoryWeapon', { itemName, label, ammoItem, ammoAmount });
    ['new-weapon-item','new-weapon-label','new-weapon-ammo'].forEach(id => document.getElementById(id).value = '');
    document.getElementById('new-weapon-ammo-amount').value = '0';
}
function submitAddEquipment() {
    const itemName = document.getElementById('new-equip-item').value.trim();
    const label    = document.getElementById('new-equip-label').value.trim();
    const amount   = parseInt(document.getElementById('new-equip-amount').value) || 1;
    if (!itemName || !label) { alert(t('alert.fill_item_label')); return; }
    postNUI('addArmoryEquipment', { itemName, label, amount });
    ['new-equip-item','new-equip-label'].forEach(id => document.getElementById(id).value = '');
    document.getElementById('new-equip-amount').value = '1';
}
function removeArmoryWeapon(item) {
    if (!confirm(t('management.confirm_delete_weapon', item))) return;
    postNUI('removeArmoryWeapon', { itemName: item });
}
function removeArmoryEquipment(item) {
    if (!confirm(t('management.confirm_delete_equipment', item))) return;
    postNUI('removeArmoryEquipment', { itemName: item });
}
function onArmoryUpdated(weapons, equipment) {
    if (state.management) {
        state.management.armoryWeapons   = weapons   || [];
        state.management.armoryEquipment = equipment || [];
    }
    renderMgmtArmory(weapons, equipment);
}

function renderCalls(callsObj) {
    state.calls = callsObj || {};
    const tbody = document.getElementById('calls-body');
    if (!tbody) return;
    const calls = Object.values(callsObj || {});
    if (!calls.length) {
        tbody.innerHTML = `<tr><td colspan="5" class="empty-row">${t('calls.empty')}</td></tr>`; return;
    }
    tbody.innerHTML = calls.map(call => {
        const statusBadge = call.status === 'pending'
            ? `<span class="badge badge-warn">${t('calls.status_pending')}</span>`
            : `<span class="badge badge-ok">${t('calls.status_active')}</span>`;
        const actions = [];
        if (call.coords) actions.push(`<button class="btn-secondary-sm" onclick="setWaypoint(${call.coords.x||0},${call.coords.y||0})"><i data-lucide="map-pin"></i></button>`);
        if (call.status === 'pending') actions.push(`<button class="btn-success-sm" onclick="acceptCall(${call.id})"><i data-lucide="check"></i> ${t('calls.accept')}</button>`);
        if (call.status === 'active')  actions.push(`<button class="btn-danger-sm" onclick="resolveCall(${call.id})">${t('calls.resolve')}</button>`);
        return `<tr class="call-row-${call.status}">
            <td>${esc(call.callerName || '?')}</td>
            <td>${esc(call.message || '')}</td>
            <td>${timeAgo(call.createdAt)}</td>
            <td>${statusBadge}</td>
            <td style="display:flex;gap:4px">${actions.join('')}</td>
        </tr>`;
    }).join('');
    if (window.lucide) lucide.createIcons();
}

function addCall(call) {
    if (!call || !call.id) return;
    state.calls[call.id] = call;
    renderCalls(state.calls);
}

function setWaypoint(x, y) { postNUI('setWaypoint', { x, y }); }
function acceptCall(id)     { postNUI('acceptCall',  { callId: id }); }
function resolveCall(id)    { postNUI('resolveCall', { callId: id }); }

let patientSearchDebounce = null;
function onPatientSearchInput(val) {
    clearTimeout(patientSearchDebounce);
    const listEl = document.getElementById('patient-results-list');
    if (!listEl) return;
    if (!val || val.length < 2) { listEl.innerHTML = ''; return; }
    patientSearchDebounce = setTimeout(() => {
        postNUI('searchPatient', { query: val });
    }, 400);
}

function onPatientSearch(results) {
    const listEl = document.getElementById('patient-results-list');
    if (!listEl) return;
    if (!results || !results.length) { listEl.innerHTML = `<div class="empty-msg">${t('common.no_results')}</div>`; return; }
    listEl.innerHTML = results.map(r => `
        <div class="result-row" onclick="loadPatientHistory(${r.id}, '${esc(r.first_name)} ${esc(r.last_name)}')">
            <span class="result-name">${esc(r.first_name)} ${esc(r.last_name)}</span>
            <span style="color:var(--text-dim);font-size:11px">#${r.id}</span>
        </div>`).join('');
}

function loadPatientHistory(charId, name) {
    const detailEl = document.getElementById('patient-detail');
    if (detailEl) detailEl.innerHTML = `<div class="loading">${t('patient.loading', esc(name))}</div>`;
    postNUI('getPatientHistory', { characterId: charId });
}

function renderPatientHistory(records) {
    const detailEl = document.getElementById('patient-detail');
    if (!detailEl) return;
    if (!records || !records.length) { detailEl.innerHTML = `<div class="empty-msg">${t('patient.empty')}</div>`; return; }
    const icons = { revive: 'heart', treatment: 'pill', hospital: 'hospital', diagnosis: 'search' };
    detailEl.innerHTML = records.map(r => {
        const icon    = icons[r.record_type] || 'clipboard-list';
        const details = typeof r.details === 'object' ? JSON.stringify(r.details) : (r.details || '');
        const ems     = (r.ems_first && r.ems_last) ? `${r.ems_first} ${r.ems_last}` : t('patient.ems_system');
        return `<div class="history-record">
            <div class="hr-header">
                <span><i data-lucide="${icon}"></i> <strong>${r.record_type}</strong></span>
                <span class="hr-ems">${esc(ems)}</span>
                <span class="hr-date">${formatDate(r.created_at)}</span>
            </div>
            <div class="hr-details">${esc(details)}</div>
        </div>`;
    }).join('');
    if (window.lucide) lucide.createIcons();
}

let medicalSearchDebounce = null;
function onMedicalSearch(val) {
    clearTimeout(medicalSearchDebounce);
    if (!val || val.length < 2) { const el = document.getElementById('medical-results'); if (el) el.innerHTML = ''; return; }
    medicalSearchDebounce = setTimeout(() => {
        postNUI('searchPatient', { query: val });
        state._searchMode = 'medical';
    }, 400);
}

function renderRoster(roster) {
    const el = document.getElementById('team-list');
    if (!el) return;
    if (!roster || !roster.length) { el.innerHTML = `<div class="empty-msg">${t('team.empty')}</div>`; return; }
    el.innerHTML = `<table class="data-table"><thead><tr><th>${t('team.col_name')}</th><th>${t('team.col_grade')}</th><th>${t('team.col_status')}</th></tr></thead><tbody>` +
        roster.map(m => `<tr>
            <td>${esc(m.name || (m.first_name + ' ' + m.last_name) || '?')}</td>
            <td>${esc(m.gradeLabel || m.grade_label || '?')}</td>
            <td><span class="badge ${(m.isOnDuty || m.is_on_duty) ? 'badge-ok' : 'badge-gray'}">${(m.isOnDuty || m.is_on_duty) ? t('team.on_duty') : t('team.off_duty')}</span></td>
        </tr>`).join('') + '</tbody></table>';
}

function showModal(id) {
    const modal = document.getElementById(id);
    if (!modal) return;
    modal.classList.remove('hidden');
    // Reset common fields
    modal.querySelectorAll('input:not([type=hidden]):not([type=number]), textarea').forEach(el => {
        if (!['warrant-bail', 'citation-fine', 'impound-fee'].includes(el.id)) el.value = '';
    });
    modal.querySelectorAll('.selected-char').forEach(el => el.classList.add('hidden'));
    modal.querySelectorAll('input[type=hidden]').forEach(el => el.value = '');
    modal.querySelectorAll('.compact-results').forEach(el => el.innerHTML = '');
}

function hideModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.add('hidden');
}

// Modal character search (shared by warrant + citation modals)
function onModalSearch(mode) {
    clearTimeout(state.modalSearchTimeout);
    const input = document.getElementById(`${mode}-search`);
    if (!input) return;
    const val = input.value.trim();
    if (val.length < 2) { document.getElementById(`${mode}-search-results`).innerHTML = ''; return; }
    state.modalSearchTimeout = setTimeout(() => {
        state._searchMode = 'modal';
        state.modalSearchMode = mode;
        postNUI('mdtSearch', { query: val });
    }, 400);
}

function renderModalSearch(results, mode) {
    const el = document.getElementById(`${mode}-search-results`);
    if (!el) return;
    if (!results || !results.length) { el.innerHTML = `<div class="empty-msg">${t('common.no_results')}</div>`; return; }
    el.innerHTML = results.map(c => `
        <div class="result-row" onclick="selectModalChar('${mode}', ${c.id}, '${esc(c.first_name)} ${esc(c.last_name)}')">
            <span>${esc(c.first_name)} ${esc(c.last_name)}</span>
            ${c.hasWarrant ? `<span class="badge badge-warn">${t('criminal.badge_warrant')}</span>` : ''}
            ${c.isJailed   ? `<span class="badge badge-danger">${t('criminal.badge_jailed')}</span>` : ''}
        </div>`).join('');
}

function selectModalChar(mode, charId, name) {
    document.getElementById(`${mode}-char-id`).value = charId;
    const display = document.getElementById(`${mode}-char-display`);
    if (display) { display.textContent = t('modal.suspect_prefix', name); display.classList.remove('hidden'); }
    const resultsEl = document.getElementById(`${mode}-search-results`);
    if (resultsEl) resultsEl.innerHTML = '';
    const inputEl = document.getElementById(`${mode}-search`);
    if (inputEl) inputEl.value = '';
}

// Route search results based on mode
function routeSearchResults(results) {
    switch (state._searchMode) {
        case 'main':     renderMainSearch(results);          break;
        case 'modal':    renderModalSearch(results, state.modalSearchMode); break;
        case 'criminal': renderCriminalSearchResults(results); break;
        case 'medical':  renderMedicalSearchResults(results); break;
    }
}

function renderMedicalSearchResults(results) {
    const el = document.getElementById('medical-results');
    if (!el) return;
    if (!results || !results.length) { el.innerHTML = `<div class="empty-msg">${t('common.no_results')}</div>`; return; }
    el.innerHTML = results.map(r => `
        <div class="result-row" onclick="loadMedicalRecord(${r.id}, '${esc(r.first_name)} ${esc(r.last_name)}')">
            <span class="result-name">${esc(r.first_name)} ${esc(r.last_name)}</span>
        </div>`).join('');
}

function loadMedicalRecord(charId, name) {
    postNUI('getPatientHistory', { characterId: charId });
}

// Fix message router to route search results correctly
window.addEventListener('message', function(e) {
    if (e.data && e.data.action === 'searchResults') {
        if (state.job === 'ems') onPatientSearch(e.data.data || e.data.results);
        else routeSearchResults(e.data.results || e.data.data);
    }
}, true);

function esc(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function formatDate(iso) {
    if (!iso) return '-';
    try {
        const d = new Date(iso);
        return d.toLocaleDateString('ro-RO') + ' ' + d.toLocaleTimeString('ro-RO', { hour: '2-digit', minute: '2-digit' });
    } catch { return '-'; }
}

function timeAgo(iso) {
    try {
        const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
        if (diff < 60)   return `${diff}s`;
        if (diff < 3600) return `${Math.floor(diff / 60)}m`;
        return `${Math.floor(diff / 3600)}h`;
    } catch { return '?'; }
}

if (IS_BROWSER) {
    document.addEventListener('DOMContentLoaded', () => {
        // Toggle between police/ems preview with ?job=ems
        const params = new URLSearchParams(window.location.search);
        const jobParam = params.get('job') || MOCK.jobName;
        MOCK.jobName = jobParam;
        openMDT({ ...MOCK, jobName: jobParam });
        if (jobParam === 'ems') {
            renderCalls({
                1: { id: 1, callerName: 'Ion Popescu', message: 'Accident pe DN1', status: 'pending', coords: {x:0,y:0}, createdAt: new Date().toISOString() },
                2: { id: 2, callerName: 'Maria Ionescu', message: 'Persoana inconstienta', status: 'active', coords: {x:0,y:0}, createdAt: new Date().toISOString() }
            });
        } else {
            onCitationsData(MOCK.citations);
            onBolosData(MOCK.bolos);
            onIncidentsData(MOCK.incidents);
            onImpoundsData(MOCK.impounds);
            renderOfficers(MOCK.officers);
        }
    });
}
