
const state = {
    warrants: [],
    officers: [],
    searchResults: [],
    isJailed: false,
    jailRemaining: 0,
    bailAmount: 0,
    warrantSearchTimeout: null,
    searchTimeout: null,
    canManage: false,
    management: null,
};

function postNUI(action, data = {}) {
    if (typeof GetParentResourceName !== 'undefined') {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
    } else {
        console.log('[NUI]', action, data);
    }
}

window.addEventListener('message', function (e) {
    const data = e.data;
    switch (data.action) {
        case 'openMDT':          openMDT(data);              break;
        case 'closeMDT':         closeMDT();                 break;
        case 'searchResults':    renderSearchResults(data.results); break;
        case 'warrantCreated':   onWarrantCreated(data.warrant); break;
        case 'warrantClosed':    onWarrantClosed(data.warrantId); break;
        case 'onDutyOfficers':   renderOfficers(data.officers); break;
        case 'openArrestForm':    openArrestModal(data.targetSrc); break;
        case 'openArmory':        openArmory(data.weapons, data.equipment); break;
        case 'armoryUpdated':     onArmoryUpdated(data.weapons, data.equipment); break;
        case 'fleetVehicleAdded': onFleetVehicleAdded(data.vehicle); break;
        case 'fleetVehicleRemoved': onFleetVehicleRemoved(data.vehicleId); break;
        case 'openCloakroom':    openCloakroom(data.gender); break;
        case 'openGarage':       openGarage(data); break;
        case 'vehicleCheckedOut':onVehicleCheckedOut(data); break;
        case 'vehicleReturned':  onVehicleReturned(); break;
        case 'mileageUpdate':    updateMileageHUD(data.mileage); break;
        case 'jailStart':        startJailHUD(data.remaining, data.reason, data.bail); break;
        case 'jailTimer':        updateJailHUD(data.remaining); break;
        case 'jailEnd':          stopJailHUD();              break;
        case 'handcuffed':       updateCuffHUD(data.state);  break;
    }
});

function openMDT(data) {
    state.warrants   = data.warrants || [];
    state.officers   = data.officers || [];
    state.canManage  = !!data.canManage;
    state.management = data.management || null;

    const mgmtBtn = document.getElementById('tab-management-btn');
    if (mgmtBtn) mgmtBtn.classList.toggle('hidden', !state.canManage);

    document.getElementById('mdt-panel').classList.remove('hidden');
    switchTab('warrants');
    renderWarrants();
}

function closeMDT() {
    document.getElementById('mdt-panel').classList.add('hidden');
}

function switchTab(tabName) {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
    const btn = document.querySelector(`[data-tab="${tabName}"]`);
    if (btn) btn.classList.add('active');
    const content = document.getElementById(`tab-${tabName}`);
    if (content) content.classList.remove('hidden');
    if (tabName === 'officers')   postNUI('getOnDutyOfficers');
    if (tabName === 'management') renderManagement();
}

function renderWarrants() {
    const tbody = document.getElementById('warrants-body');
    if (!state.warrants.length) {
        tbody.innerHTML = '<tr><td colspan="5" class="empty-row">Niciun mandat activ</td></tr>';
        return;
    }
    tbody.innerHTML = state.warrants.map(w => `
        <tr>
            <td>${esc(w.first_name)} ${esc(w.last_name)}</td>
            <td class="charges-cell">${esc(w.charges)}</td>
            <td>${w.bail_amount > 0 ? '$' + w.bail_amount : '-'}</td>
            <td>${formatDate(w.issued_at)}</td>
            <td><button class="btn-danger-sm" onclick="closeWarrant(${w.id})">Inchide</button></td>
        </tr>
    `).join('');
}

function onWarrantCreated(warrant) {
    if (warrant) {
        state.warrants.unshift(warrant);
        renderWarrants();
    }
}

function onWarrantClosed(warrantId) {
    state.warrants = state.warrants.filter(w => w.id !== warrantId);
    renderWarrants();
}

function closeWarrant(warrantId) {
    postNUI('closeWarrant', { warrantId });
}

function showWarrantForm() {
    document.getElementById('warrant-modal').classList.remove('hidden');
    document.getElementById('warrant-char-id').value = '';
    document.getElementById('warrant-char-display').classList.add('hidden');
    document.getElementById('warrant-charges').value = '';
    document.getElementById('warrant-bail').value = '0';
    document.getElementById('warrant-search').value = '';
    document.getElementById('warrant-search-results').innerHTML = '';
}

function hideWarrantForm() {
    document.getElementById('warrant-modal').classList.add('hidden');
}

function onWarrantSearch() {
    clearTimeout(state.warrantSearchTimeout);
    const q = document.getElementById('warrant-search').value.trim();
    if (q.length < 2) {
        document.getElementById('warrant-search-results').innerHTML = '';
        return;
    }
    state.warrantSearchTimeout = setTimeout(() => {
        postNUI('mdtSearch', { query: q });
        state._warrantSearchMode = true;
    }, 400);
}

function renderSearchResults(results) {
    if (state._warrantSearchMode) {
        renderWarrantSearchResults(results);
        state._warrantSearchMode = false;
    } else {
        renderMainSearchResults(results);
    }
}

function renderWarrantSearchResults(results) {
    const el = document.getElementById('warrant-search-results');
    if (!results.length) { el.innerHTML = '<div class="empty-msg">Niciun rezultat</div>'; return; }
    el.innerHTML = results.map(c => `
        <div class="result-row" onclick="selectWarrantChar(${c.id}, '${esc(c.first_name)} ${esc(c.last_name)}')">
            <span>${esc(c.first_name)} ${esc(c.last_name)}</span>
            ${c.hasWarrant ? '<span class="badge badge-warn">Mandat</span>' : ''}
            ${c.isJailed   ? '<span class="badge badge-danger">Inchis</span>' : ''}
        </div>
    `).join('');
}

function selectWarrantChar(charId, name) {
    document.getElementById('warrant-char-id').value = charId;
    const display = document.getElementById('warrant-char-display');
    display.textContent = 'Suspect: ' + name;
    display.classList.remove('hidden');
    document.getElementById('warrant-search-results').innerHTML = '';
    document.getElementById('warrant-search').value = '';
}

function submitWarrant() {
    const charId  = document.getElementById('warrant-char-id').value;
    const charges = document.getElementById('warrant-charges').value.trim();
    const bail    = parseInt(document.getElementById('warrant-bail').value) || 0;
    if (!charId || charges.length < 3) {
        alert('Completeaza toate campurile.');
        return;
    }
    postNUI('createWarrant', { characterId: parseInt(charId), charges, bailAmount: bail });
    hideWarrantForm();
}

function onSearchInput() {
    clearTimeout(state.searchTimeout);
    const q = document.getElementById('search-input').value.trim();
    if (q.length < 2) {
        document.getElementById('search-results').innerHTML = '';
        return;
    }
    state.searchTimeout = setTimeout(() => {
        state._warrantSearchMode = false;
        postNUI('mdtSearch', { query: q });
    }, 400);
}

function renderMainSearchResults(results) {
    const el = document.getElementById('search-results');
    if (!results.length) { el.innerHTML = '<div class="empty-msg">Niciun rezultat</div>'; return; }
    el.innerHTML = results.map(c => `
        <div class="person-card">
            <div class="person-card-name">
                ${esc(c.first_name)} ${esc(c.last_name)}
                <span class="person-age">${c.age} ani</span>
            </div>
            <div class="person-card-badges">
                ${c.hasWarrant ? '<span class="badge badge-warn">Mandat activ</span>' : ''}
                ${c.isJailed   ? '<span class="badge badge-danger">Inchis</span>' : ''}
            </div>
            <div class="person-card-actions">
                <button class="btn-secondary-sm" onclick="quickWarrant(${c.id}, '${esc(c.first_name)} ${esc(c.last_name)}')">Emite Mandat</button>
                ${c.isJailed ? `<button class="btn-secondary-sm" onclick="unjailChar(${c.id})">Elibereaza</button>` : ''}
            </div>
        </div>
    `).join('');
}

function quickWarrant(charId, name) {
    showWarrantForm();
    selectWarrantChar(charId, name);
}

function unjailChar(charId) {
    if (!confirm('Esti sigur ca vrei sa eliberezi acest personaj?')) return;
    postNUI('unjailEarly', { characterId: charId });
}

function renderOfficers(officers) {
    state.officers = officers || [];
    const el = document.getElementById('officers-list');
    if (!officers.length) { el.innerHTML = '<div class="empty-msg">Niciun ofiter activ</div>'; return; }
    el.innerHTML = officers.map(o => `
        <div class="officer-row">
            <span class="officer-name">${esc(o.first_name)} ${esc(o.last_name)}</span>
            <span class="grade-chip">${esc(o.grade_label)}</span>
        </div>
    `).join('');
}

function openArrestModal(targetSrc) {
    document.getElementById('arrest-target-src').value = targetSrc;
    document.getElementById('arrest-reason').value = '';
    document.getElementById('arrest-minutes').value = '10';
    document.getElementById('arrest-bail').value = '0';
    document.getElementById('arrest-modal').classList.remove('hidden');
}

function submitArrest() {
    const targetSrc = document.getElementById('arrest-target-src').value;
    const reason    = document.getElementById('arrest-reason').value.trim();
    const minutes   = parseInt(document.getElementById('arrest-minutes').value) || 10;
    const bail      = parseInt(document.getElementById('arrest-bail').value) || 0;
    if (reason.length < 3) { alert('Introdu un motiv valid.'); return; }
    postNUI('submitArrest', { targetSrc: parseInt(targetSrc), reason, minutes, bail });
    document.getElementById('arrest-modal').classList.add('hidden');
}

function openArmory(weapons, equipment) {
    document.getElementById('armory-panel').classList.remove('hidden');
    document.getElementById('armory-weapons').innerHTML = (weapons || []).map(w => `
        <div class="armory-item">
            <span>${esc(w.label)}</span>
            <button class="btn-primary-sm" onclick="takeItem('${esc(w.itemName)}', true)">Ridica</button>
        </div>
    `).join('') || '<div class="empty-msg">Nicio arma configurata</div>';
    document.getElementById('armory-equipment').innerHTML = (equipment || []).map(e => `
        <div class="armory-item">
            <span>${esc(e.label)}</span>
            <button class="btn-primary-sm" onclick="takeItem('${esc(e.itemName)}', false)">Ridica</button>
        </div>
    `).join('') || '<div class="empty-msg">Niciun echipament configurat</div>';
}

function takeItem(itemName, isWeapon) {
    postNUI('takeArmoryItem', { itemName, isWeapon });
}

function closeArmory() {
    document.getElementById('armory-panel').classList.add('hidden');
    postNUI('closeArmory');
}

function openCloakroom(gender) {
    document.getElementById('cloakroom-panel').classList.remove('hidden');
}

function closeCloakroom() {
    document.getElementById('cloakroom-panel').classList.add('hidden');
    postNUI('closeCloakroom');
}

function wearUniform() {
    document.getElementById('cloakroom-panel').classList.add('hidden');
    postNUI('wearUniform');
}

function wearCivilian() {
    document.getElementById('cloakroom-panel').classList.add('hidden');
    postNUI('wearCivilian');
}

let garageCurrentId = null;
let garageMileageUnit = 'km';

function openGarage(data) {
    garageCurrentId   = data.currentId || null;
    garageMileageUnit = data.mileageUnit || 'km';

    document.getElementById('garage-panel').classList.remove('hidden');

    const bar = document.getElementById('active-vehicle-bar');
    bar.classList.add('hidden');

    renderFleet(data.fleet || []);
}

function renderFleet(fleet) {
    const el = document.getElementById('fleet-list');
    if (!fleet.length) {
        el.innerHTML = '<div class="empty-msg">Niciun vehicul in flota</div>';
        return;
    }
    el.innerHTML = fleet.map(v => {
        const isCurrentUser = garageCurrentId && v.id === garageCurrentId;
        const unavailable   = !v.is_available && !isCurrentUser;
        const mileageStr    = formatMileage(v.mileage, garageMileageUnit);
        const fuelPct       = Math.round(v.fuel || 0);
        const statusLabel   = v.is_available ? 'Disponibil' : (isCurrentUser ? 'Al tau' : 'Preluat');
        const statusClass   = v.is_available ? 'badge-ok' : (isCurrentUser ? 'badge-warn' : 'badge-danger');

        return `
        <div class="fleet-card ${unavailable ? 'fleet-card-unavailable' : ''}">
            <div class="fleet-card-main">
                <span class="fleet-model">${esc(v.label)}</span>
                <span class="fleet-plate">${esc(v.plate)}</span>
                <span class="badge ${statusClass}">${statusLabel}</span>
            </div>
            <div class="fleet-card-stats">
                <span class="fleet-stat"><i data-lucide="map-pin"></i> ${mileageStr}</span>
                <span class="fleet-stat"><i data-lucide="fuel"></i> ${fuelPct}%</span>
                <div class="fuel-bar"><div class="fuel-fill" style="width:${fuelPct}%"></div></div>
            </div>
            <div class="fleet-card-actions">
                ${isCurrentUser
                    ? `<button class="btn-danger-sm" onclick="postNUI('returnVehicle'); closeGaragePanel()">Returneaza</button>`
                    : v.is_available
                        ? `<button class="btn-primary-sm" onclick="checkoutVehicle(${v.id})">Preia</button>`
                        : ''
                }
            </div>
        </div>`;
    }).join('');
    if (window.lucide) lucide.createIcons();
}

function formatMileage(km, unit) {
    if (!km) km = 0;
    if (unit === 'miles') return (km * 0.621371).toFixed(1) + ' mi';
    return km.toFixed(1) + ' km';
}

function checkoutVehicle(vehicleId) {
    postNUI('checkoutVehicle', { vehicleId });
}

function closeGaragePanel() {
    document.getElementById('garage-panel').classList.add('hidden');
    postNUI('closeGarage');
}

function onVehicleCheckedOut(data) {
    document.getElementById('garage-panel').classList.add('hidden');
    document.getElementById('mileage-hud').classList.remove('hidden');
    updateMileageHUD(data.mileage);
}

function onVehicleReturned() {
    document.getElementById('mileage-hud').classList.add('hidden');
}

function updateMileageHUD(mileageStr) {
    document.getElementById('mileage-display').textContent = mileageStr || '0.0 km';
}

let jailInterval = null;

function startJailHUD(remaining, reason, bail) {
    state.isJailed      = true;
    state.jailRemaining = remaining;
    state.bailAmount    = bail || 0;

    const hud = document.getElementById('jail-hud');
    hud.classList.remove('hidden');

    const bailBtn = document.getElementById('bail-btn');
    if (state.bailAmount > 0) {
        bailBtn.textContent = 'Plateste Cautiune ($' + state.bailAmount + ')';
        bailBtn.classList.remove('hidden');
    } else {
        bailBtn.classList.add('hidden');
    }

    updateJailTimer(remaining);

    if (jailInterval) clearInterval(jailInterval);
    jailInterval = setInterval(() => {
        state.jailRemaining = Math.max(0, state.jailRemaining - 1);
        updateJailTimer(state.jailRemaining);
    }, 1000);
}

function updateJailHUD(remaining) {
    state.jailRemaining = remaining;
    updateJailTimer(remaining);
}

function stopJailHUD() {
    state.isJailed = false;
    document.getElementById('jail-hud').classList.add('hidden');
    if (jailInterval) { clearInterval(jailInterval); jailInterval = null; }
}

function updateJailTimer(seconds) {
    const m = Math.floor(seconds / 60).toString().padStart(2, '0');
    const s = (seconds % 60).toString().padStart(2, '0');
    document.getElementById('jail-timer').textContent = `${m}:${s}`;
}

function payBail() {
    postNUI('payBail');
}

function updateCuffHUD(cuffed) {
    document.getElementById('cuff-hud').classList.toggle('hidden', !cuffed);
}

function esc(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function formatDate(iso) {
    if (!iso) return '-';
    const d = new Date(iso);
    return d.toLocaleDateString('ro-RO') + ' ' + d.toLocaleTimeString('ro-RO', { hour: '2-digit', minute: '2-digit' });
}

function switchSubTab(stabName) {
    document.querySelectorAll('.sub-tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.sub-tab-content').forEach(c => c.classList.add('hidden'));
    const btn = document.querySelector(`[data-stab="${stabName}"]`);
    if (btn) btn.classList.add('active');
    const content = document.getElementById(`stab-${stabName}`);
    if (content) content.classList.remove('hidden');
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
    document.getElementById('budget-balance').textContent = '$' + Math.floor(balance || 0).toLocaleString('ro-RO');

    const tbody = document.getElementById('budget-tx-body');
    if (!transactions || !transactions.length) {
        tbody.innerHTML = '<tr><td colspan="4" class="empty-row">Nicio tranzactie</td></tr>';
        return;
    }
    tbody.innerHTML = transactions.map(t => {
        const amt    = parseFloat(t.amount) || 0;
        const cls    = amt >= 0 ? 'tx-credit' : 'tx-debit';
        const prefix = amt >= 0 ? '+' : '';
        return `<tr>
            <td><span class="badge ${cls}">${esc(t.type)}</span></td>
            <td class="${cls}">${prefix}$${Math.abs(amt).toLocaleString('ro-RO')}</td>
            <td>${esc(t.description || '-')}</td>
            <td>${formatDate(t.created_at)}</td>
        </tr>`;
    }).join('');
}

function renderMgmtFleet(fleet, models, sellRatio, balance) {
    const fleetEl  = document.getElementById('mgmt-fleet-list');
    const modelsEl = document.getElementById('mgmt-models-list');

    if (!fleet || !fleet.length) {
        fleetEl.innerHTML = '<div class="empty-msg">Niciun vehicul in flota</div>';
    } else {
        fleetEl.innerHTML = fleet.map(v => {
            const sellPrice  = Math.floor((parseFloat(v.purchase_price) || 0) * (sellRatio || 0.6));
            const unavail    = !v.is_available;
            return `<div class="mgmt-fleet-row ${unavail ? 'mgmt-fleet-inuse' : ''}">
                <span class="fleet-model">${esc(v.label)}</span>
                <span class="fleet-plate">${esc(v.plate)}</span>
                <span class="badge ${v.is_available ? 'badge-ok' : 'badge-danger'}">${v.is_available ? 'Liber' : 'In uz'}</span>
                ${v.is_available
                    ? `<button class="btn-danger-sm" onclick="sellVehicle(${v.id}, '${esc(v.plate)}', '${esc(v.label)}', ${sellPrice})">
                         Vinde $${sellPrice.toLocaleString('ro-RO')}
                       </button>`
                    : '<span class="mgmt-inuse-label">Nu poate fi vandut</span>'
                }
            </div>`;
        }).join('');
    }

    if (!models || !models.length) {
        modelsEl.innerHTML = '<div class="empty-msg">Niciun model configurat</div>';
    } else {
        modelsEl.innerHTML = models.map(m => {
            const price    = parseInt(m.price) || 0;
            const canAfford = (balance || 0) >= price;
            return `<div class="mgmt-model-row">
                <span class="mgmt-model-label">${esc(m.label)}</span>
                <span class="mgmt-model-price">$${price.toLocaleString('ro-RO')}</span>
                <button class="btn-primary-sm ${canAfford ? '' : 'btn-disabled'}"
                    onclick="${canAfford ? `purchaseVehicle('${esc(m.model)}', '${esc(m.label)}')` : ''}"
                    ${canAfford ? '' : 'disabled title="Fonduri insuficiente"'}>
                    Achizitioneaza
                </button>
            </div>`;
        }).join('');
    }
}

function purchaseVehicle(model, label) {
    if (!confirm(`Achizitionezi "${label}"? Suma va fi dedusa din bugetul departamentului.`)) return;
    postNUI('purchaseFleetVehicle', { model });
}

function sellVehicle(vehicleId, plate, label, sellPrice) {
    if (!confirm(`Vinzi vehiculul ${label} (${plate}) pentru $${sellPrice}?`)) return;
    postNUI('sellFleetVehicle', { vehicleId });
}

function onFleetVehicleAdded(vehicle) {
    if (!state.management) return;
    state.management.fleet = state.management.fleet || [];
    state.management.fleet.unshift(vehicle);
    renderMgmtFleet(state.management.fleet, state.management.fleetModels, state.management.sellRatio, state.management.balance);
}

function onFleetVehicleRemoved(vehicleId) {
    if (!state.management) return;
    state.management.fleet = (state.management.fleet || []).filter(v => v.id !== vehicleId);
    renderMgmtFleet(state.management.fleet, state.management.fleetModels, state.management.sellRatio, state.management.balance);
}

function renderMgmtArmory(weapons, equipment) {
    const weaponsEl   = document.getElementById('mgmt-armory-weapons');
    const equipmentEl = document.getElementById('mgmt-armory-equipment');

    if (!weapons || !weapons.length) {
        weaponsEl.innerHTML = '<div class="empty-msg">Nicio arma configurata</div>';
    } else {
        weaponsEl.innerHTML = weapons.map(w => `
            <div class="mgmt-armory-row">
                <span>${esc(w.label)}</span>
                <code class="item-code">${esc(w.itemName)}</code>
                ${w.ammoItem ? `<span class="ammo-info">${esc(w.ammoItem)} ×${w.ammoAmount}</span>` : ''}
                <button class="btn-danger-sm" onclick="removeArmoryWeapon('${esc(w.itemName)}')">Sterge</button>
            </div>
        `).join('');
    }

    if (!equipment || !equipment.length) {
        equipmentEl.innerHTML = '<div class="empty-msg">Niciun echipament configurat</div>';
    } else {
        equipmentEl.innerHTML = equipment.map(e => `
            <div class="mgmt-armory-row">
                <span>${esc(e.label)}</span>
                <code class="item-code">${esc(e.itemName)}</code>
                <span class="ammo-info">×${e.amount}</span>
                <button class="btn-danger-sm" onclick="removeArmoryEquipment('${esc(e.itemName)}')">Sterge</button>
            </div>
        `).join('');
    }
}

function submitAddWeapon() {
    const itemName   = document.getElementById('new-weapon-item').value.trim();
    const label      = document.getElementById('new-weapon-label').value.trim();
    const ammoItem   = document.getElementById('new-weapon-ammo').value.trim();
    const ammoAmount = parseInt(document.getElementById('new-weapon-ammo-amount').value) || 0;
    if (!itemName || !label) { alert('Completeaza itemName si numele afișat.'); return; }
    postNUI('addArmoryWeapon', { itemName, label, ammoItem, ammoAmount });
    document.getElementById('new-weapon-item').value  = '';
    document.getElementById('new-weapon-label').value = '';
    document.getElementById('new-weapon-ammo').value  = '';
    document.getElementById('new-weapon-ammo-amount').value = '0';
}

function submitAddEquipment() {
    const itemName = document.getElementById('new-equip-item').value.trim();
    const label    = document.getElementById('new-equip-label').value.trim();
    const amount   = parseInt(document.getElementById('new-equip-amount').value) || 1;
    if (!itemName || !label) { alert('Completeaza itemName si numele afișat.'); return; }
    postNUI('addArmoryEquipment', { itemName, label, amount });
    document.getElementById('new-equip-item').value   = '';
    document.getElementById('new-equip-label').value  = '';
    document.getElementById('new-equip-amount').value = '1';
}

function removeArmoryWeapon(itemName) {
    if (!confirm('Stergi arma "' + itemName + '" din armament?')) return;
    postNUI('removeArmoryWeapon', { itemName });
}

function removeArmoryEquipment(itemName) {
    if (!confirm('Stergi echipamentul "' + itemName + '" din armament?')) return;
    postNUI('removeArmoryEquipment', { itemName });
}

function onArmoryUpdated(weapons, equipment) {
    if (state.management) {
        state.management.armoryWeapons   = weapons   || [];
        state.management.armoryEquipment = equipment || [];
    }
    renderMgmtArmory(weapons, equipment);
}
