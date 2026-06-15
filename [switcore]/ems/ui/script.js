
const state = {
    currentPatient: null,
    timerInterval:  null,
    timerSeconds:   0,
    respawnAllowed: false,
    currentAmbulancePlate: null,
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

window.addEventListener('message', function(e) {
    const d = e.data;
    switch (d.action) {
        case 'showUnconsciousTimer':  showUnconsciousTimer(d.seconds);       break;
        case 'hideUnconsciousTimer':  hideUnconsciousTimer();                 break;
        case 'openPatientMenu':       openPatientMenu(d.data);                break;
        case 'closePatientMenu':      closePatientMenu();                     break;
        case 'openVehicleInventory':  openVehicleInventory(d.items, d.plate, d.ivTreatments); break;
        case 'closeVehicleInventory': closeVehicleInventory();                break;
    }
});

// Re-randare la schimbarea limbii pentru continutul generat din JS.
document.addEventListener('sw:i18n', () => {
    if (state.currentPatient &&
        !document.getElementById('patient-menu').classList.contains('hidden')) {
        openPatientMenu(state.currentPatient);
    }
});

function showUnconsciousTimer(seconds) {
    state.timerSeconds   = seconds;
    state.respawnAllowed = false;

    document.getElementById('unconscious-overlay').classList.remove('hidden');
    document.getElementById('respawn-btn').classList.add('hidden');

    updateTimerDisplay(seconds);

    if (state.timerInterval) clearInterval(state.timerInterval);
    state.timerInterval = setInterval(() => {
        state.timerSeconds--;
        if (state.timerSeconds <= 0) {
            state.timerSeconds   = 0;
            state.respawnAllowed = true;
            document.getElementById('respawn-btn').classList.remove('hidden');
            clearInterval(state.timerInterval);
        }
        updateTimerDisplay(state.timerSeconds);
    }, 1000);
}

function updateTimerDisplay(sec) {
    const m = Math.floor(sec / 60).toString().padStart(2, '0');
    const s = (sec % 60).toString().padStart(2, '0');
    document.getElementById('uncon-timer').textContent = `${m}:${s}`;
}

function hideUnconsciousTimer() {
    if (state.timerInterval) clearInterval(state.timerInterval);
    document.getElementById('unconscious-overlay').classList.add('hidden');
}

function requestRespawn() {
    postNUI('requestRespawn');
}

function openPatientMenu(data) {
    state.currentPatient = data;
    document.getElementById('patient-menu').classList.remove('hidden');

    document.getElementById('pm-name').textContent = data.name || SwI18n.t('ems.ui.patient');

    const uncBadge = document.getElementById('pm-unconscious-badge');
    const pmTimer  = document.getElementById('pm-timer');
    if (data.unconscious) {
        uncBadge.classList.remove('hidden');
        if (data.timerRemaining > 0) {
            const m = Math.floor(data.timerRemaining / 60).toString().padStart(2, '0');
            const s = (data.timerRemaining % 60).toString().padStart(2, '0');
            pmTimer.textContent = SwI18n.t('ems.ui.timer_remaining', `${m}:${s}`);
            pmTimer.classList.remove('hidden');
        }
    } else {
        uncBadge.classList.add('hidden');
        pmTimer.classList.add('hidden');
    }

    const condContainer = document.getElementById('pm-conditions');
    const conditions    = data.conditions || {};
    const condKeys      = Object.keys(conditions);
    if (condKeys.length === 0) {
        condContainer.innerHTML = `<div class="empty-msg">${escHtml(SwI18n.t('ems.ui.no_conditions'))}</div>`;
    } else {
        condContainer.innerHTML = condKeys.map(cond => {
            const c = conditions[cond];
            return `<div class="condition-row">
                <span class="cond-name">${escHtml(c.label || cond)}</span>
                <span class="badge badge-yellow">${escHtml(SwI18n.t('ems.ui.condition_stage', c.stage || 1))}</span>
            </div>`;
        }).join('');
    }

    const injContainer = document.getElementById('pm-injuries');
    const injuries     = data.injuries || [];
    const injLabelKeys = {
        gunshot_leg: 'ems.ui.injury_gunshot_leg', gunshot_chest: 'ems.ui.injury_gunshot_chest',
        bruise: 'ems.ui.injury_bruise', broken_bone: 'ems.ui.injury_broken_bone', stab: 'ems.ui.injury_stab'
    };
    const sevKeys = { 1: 'ems.ui.sev_minor', 2: 'ems.ui.sev_moderate', 3: 'ems.ui.sev_severe' };

    if (injuries.length === 0) {
        injContainer.innerHTML = `<div class="empty-msg">${escHtml(SwI18n.t('ems.ui.no_injuries'))}</div>`;
    } else {
        injContainer.innerHTML = injuries.map(inj => `
            <div class="injury-row">
                <div>
                    <span class="inj-type">${escHtml(injLabelKeys[inj.type] ? SwI18n.t(injLabelKeys[inj.type]) : inj.type)}</span>
                    <span class="inj-loc">${escHtml(inj.location || '')}</span>
                    <span class="badge badge-red">${escHtml(sevKeys[inj.severity] ? SwI18n.t(sevKeys[inj.severity]) : inj.severity)}</span>
                </div>
                <button class="btn-sm btn-success" onclick="treatInjury(${inj.id})">${escHtml(SwI18n.t('ems.ui.btn_treat'))}</button>
            </div>
        `).join('');
    }

    const btnRevive  = document.getElementById('btn-revive');
    const btnCureAll = document.getElementById('btn-cure-all');
    if (data.unconscious) btnRevive.classList.remove('hidden');
    else btnRevive.classList.add('hidden');
    btnCureAll.classList.remove('hidden');

    const ivSelect = document.getElementById('iv-select');
    const ivRow    = document.getElementById('iv-row');
    const ivList   = (typeof Cfg !== 'undefined' && Cfg && Cfg.ivTreatments) ? Cfg.ivTreatments : [];

    if (ivList && ivList.length > 0) {
        ivRow.classList.remove('hidden');
        ivSelect.innerHTML = ivList.map(iv =>
            `<option value="${escHtml(iv.item)}">${escHtml(iv.label)}</option>`
        ).join('');
    } else {
        ivRow.classList.add('hidden');
    }
}

function closePatientMenu() {
    state.currentPatient = null;
    document.getElementById('patient-menu').classList.add('hidden');
}

function doRevive() {
    if (!state.currentPatient) return;
    postNUI('revivePatient', { patientSrc: state.currentPatient.patientSrc });
}

function treatInjury(injuryId) {
    if (!state.currentPatient) return;
    postNUI('treatInjury', { patientSrc: state.currentPatient.patientSrc, injuryId });
}

function doCureAll() {
    if (!state.currentPatient) return;
    postNUI('cureAllConditions', { patientSrc: state.currentPatient.patientSrc });
}

function doAdministerIV() {
    if (!state.currentPatient) return;
    const itemName = document.getElementById('iv-select').value;
    if (!itemName) return;
    const plate = state.currentAmbulancePlate || '';
    postNUI('administerIV', {
        patientSrc: state.currentPatient.patientSrc,
        itemName,
        plate,
    });
}

function doLogDiagnosis() {
    if (!state.currentPatient) return;
    const notes = document.getElementById('diag-notes').value.trim();
    if (!notes) return;
    postNUI('logDiagnosis', { patientSrc: state.currentPatient.patientSrc, notes });
    document.getElementById('diag-notes').value = '';
}

function openVehicleInventory(items, plate, ivTreatments) {
    state.currentAmbulancePlate = plate;
    document.getElementById('vehicle-inventory').classList.remove('hidden');
    document.getElementById('vi-plate').textContent = plate || '';

    const container = document.getElementById('vi-items');
    if (!items || items.length === 0) {
        container.innerHTML = `<div class="empty-msg">${escHtml(SwI18n.t('ems.ui.empty_inventory'))}</div>`;
        return;
    }

    container.innerHTML = items.map(item => `
        <div class="vi-item">
            <span class="vi-name">${escHtml(item.item_name)}</span>
            <span class="vi-amount">x${item.amount}</span>
            <button class="btn-sm btn-secondary" onclick="takeItem('${escHtml(item.item_name)}', 1)">${escHtml(SwI18n.t('ems.ui.btn_take_one'))}</button>
        </div>
    `).join('');
}

function closeVehicleInventory() {
    document.getElementById('vehicle-inventory').classList.add('hidden');
}

function takeItem(itemName, amount) {
    postNUI('takeFromAmbulance', {
        plate:    state.currentAmbulancePlate,
        itemName,
        amount,
    });
}

function escHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function timeAgoFromISO(iso) {
    try {
        const diff = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
        if (diff < 60)   return `${diff}s`;
        if (diff < 3600) return `${Math.floor(diff / 60)}m`;
        return `${Math.floor(diff / 3600)}h`;
    } catch (e) {
        return '?';
    }
}
