
const app       = document.getElementById('app');
const titleEl   = document.getElementById('garageTitle');
const closeBtn  = document.getElementById('closeBtn');
const impoundBadge = document.getElementById('impoundBadge');
const ticketsBadge = document.getElementById('ticketsBadge');

const tabs     = document.querySelectorAll('.tab');
const panes    = document.querySelectorAll('.tab-pane');

let state = {
    garage:    null,
    vehicles:  [],
    impounded: [],
    tickets:   [],
};

const isFiveM = typeof window.invokeNative !== 'undefined';

function postNUI(action, data = {}) {
    if (isFiveM) {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
    } else {
        console.log('[NUI]', action, data);
    }
}

tabs.forEach(tab => {
    tab.addEventListener('click', () => {
        const target = tab.dataset.tab;
        tabs.forEach(t => t.classList.remove('active'));
        panes.forEach(p => p.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById(`tab-${target}`).classList.add('active');
    });
});

closeBtn.addEventListener('click', close);

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') close();
});

function close() {
    app.classList.add('hidden');
    postNUI('close');
}

function open(data) {
    state = { ...state, ...data };
    titleEl.textContent = data.garage?.name || 'Garaj';
    render();
    app.classList.remove('hidden');
    tabs.forEach(t => t.classList.remove('active'));
    panes.forEach(p => p.classList.remove('active'));
    tabs[0].classList.add('active');
    document.getElementById('tab-garage').classList.add('active');
}

function updateData(data) {
    state = { ...state, ...data };
    render();
}

function render() {
    renderVehicles();
    renderImpound();
    renderTickets();
    updateBadges();
}

function updateBadges() {
    const ic = state.impounded?.length || 0;
    const tc = state.tickets?.length || 0;

    impoundBadge.textContent = ic;
    impoundBadge.className = 'badge' + (ic === 0 ? ' zero' : '');

    ticketsBadge.textContent = tc;
    ticketsBadge.className = 'badge' + (tc === 0 ? ' zero' : '');
}

function renderVehicles() {
    const grid  = document.getElementById('vehiclesGrid');
    const empty = document.getElementById('vehiclesEmpty');
    const vehicles = state.vehicles || [];

    grid.querySelectorAll('.vehicle-card').forEach(el => el.remove());

    if (vehicles.length === 0) {
        empty.style.display = '';
        return;
    }
    empty.style.display = 'none';

    vehicles.forEach(v => {
        const card = buildVehicleCard(v);
        grid.appendChild(card);
    });
}

function buildVehicleCard(v) {
    const fuel    = Math.round(parseFloat(v.fuel) || 0);
    const body    = Math.round(parseFloat(v.body_health) || 100);
    const stored  = v.stored;
    const impound = v.impounded;

    let statusClass = 'status-out';
    let statusText  = 'Pe drum';
    if (impound) { statusClass = 'status-impound'; statusText = 'Sechestrat'; }
    else if (stored) { statusClass = 'status-stored'; statusText = 'Parcat'; }

    let fuelClass = 'fuel-high';
    if (fuel < 30) fuelClass = 'fuel-low';
    else if (fuel < 60) fuelClass = 'fuel-medium';

    const card = document.createElement('div');
    card.className = 'vehicle-card';
    card.innerHTML = `
        <div class="vehicle-card-top">
            <div class="vehicle-info">
                <div class="vehicle-label">${esc(v.label || v.model)}</div>
                <div class="vehicle-plate">${esc(v.plate)}</div>
            </div>
            <span class="vehicle-status ${statusClass}">${statusText}</span>
        </div>
        <div class="vehicle-meta">
            <span class="meta-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 22V8l9-6 9 6v14H3zM9 22V12h6v10"/>
                </svg>
                ${esc(v.category || '-')}
            </span>
            <span class="meta-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 22s-8-4.5-8-11.8A8 8 0 0 1 12 2a8 8 0 0 1 8 8.2c0 7.3-8 11.8-8 11.8z"/>
                </svg>
                Combustibil: ${fuel}%
            </span>
            <span class="meta-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
                </svg>
                Caroserie: ${body}%
            </span>
        </div>
        <div class="fuel-bar"><div class="fuel-fill ${fuelClass}" style="width:${fuel}%"></div></div>
        <div class="vehicle-actions">
            ${buildVehicleActions(v)}
        </div>
    `;

    const retrieveBtn = card.querySelector('[data-action="retrieve"]');
    const parkBtn     = card.querySelector('[data-action="park"]');

    if (retrieveBtn) {
        retrieveBtn.addEventListener('click', () => {
            retrieveBtn.disabled = true;
            postNUI('retrieveVehicle', { vehicleId: v.id });
        });
    }
    if (parkBtn) {
        parkBtn.addEventListener('click', () => {
            parkBtn.disabled = true;
            postNUI('parkVehicle', { vehicleId: v.id });
        });
    }

    return card;
}

function buildVehicleActions(v) {
    if (v.impounded) {
        return `<button class="btn btn-ghost" disabled>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
            Sechestrat
        </button>`;
    }
    if (v.stored) {
        return `<button class="btn btn-primary" data-action="retrieve">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="5 9 2 12 5 15"/><path d="M20 4v7a4 4 0 0 1-4 4H2"/>
            </svg>
            Scoate
        </button>`;
    }
    return `<button class="btn btn-ghost" data-action="park">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
            <path d="M9 17V7h4a3 3 0 0 1 0 6H9"/>
        </svg>
        Parcheaza
    </button>`;
}

function renderImpound() {
    const list  = document.getElementById('impoundList');
    const empty = document.getElementById('impoundEmpty');
    const items = state.impounded || [];

    list.querySelectorAll('.list-item').forEach(el => el.remove());

    if (items.length === 0) {
        empty.style.display = '';
        return;
    }
    empty.style.display = 'none';

    items.forEach(v => {
        const el = document.createElement('div');
        el.className = 'list-item';
        el.innerHTML = `
            <div class="list-item-header">
                <div>
                    <div class="list-item-title">${esc(v.label || v.model)}</div>
                    <div class="list-item-sub">${esc(v.plate)}</div>
                </div>
                <div style="text-align:right">
                    <div class="fine-amount">$${fmt(v.total_fine)}</div>
                    <div class="fine-breakdown">Amenzi $${fmt(v.tickets_fine)} + Eliberare $${fmt(v.release_fee)}</div>
                </div>
            </div>
            <button class="btn btn-danger" data-action="release" data-id="${v.id}">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
                </svg>
                Plătește și Eliberează - $${fmt(v.total_fine)}
            </button>
        `;

        el.querySelector('[data-action="release"]').addEventListener('click', e => {
            e.target.disabled = true;
            postNUI('releaseImpound', { vehicleId: v.id });
        });

        list.appendChild(el);
    });
}

function renderTickets() {
    const list  = document.getElementById('ticketsList');
    const empty = document.getElementById('ticketsEmpty');
    const items = state.tickets || [];

    list.querySelectorAll('.list-item').forEach(el => el.remove());

    if (items.length === 0) {
        empty.style.display = '';
        return;
    }
    empty.style.display = 'none';

    items.forEach(t => {
        const el = document.createElement('div');
        el.className = 'list-item';
        el.innerHTML = `
            <div class="list-item-header">
                <div>
                    <div class="list-item-title">${esc(t.plate)}</div>
                    <div class="list-item-sub">${fmtDate(t.issued_at)}</div>
                </div>
                <div class="fine-amount">$${fmt(t.fine_amount)}</div>
            </div>
            <div class="list-item-footer">
                <span class="reason-tag">${esc(t.reason || 'Fără motiv')}</span>
                <button class="btn btn-green" data-action="pay" data-id="${t.id}" style="flex:0;padding:6px 14px;">
                    Plătește
                </button>
            </div>
        `;

        el.querySelector('[data-action="pay"]').addEventListener('click', e => {
            e.target.disabled = true;
            postNUI('payTicket', { ticketId: t.id });
        });

        list.appendChild(el);
    });
}

function esc(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function fmt(n) {
    const num = parseFloat(n) || 0;
    return num.toLocaleString('ro-RO', { maximumFractionDigits: 0 });
}

function fmtDate(str) {
    if (!str) return '';
    try {
        return new Date(str).toLocaleDateString('ro-RO', {
            day: '2-digit', month: 'short', year: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    } catch { return str; }
}

window.addEventListener('message', e => {
    const msg = e.data;
    if (!msg || !msg.action) return;

    if (msg.action === 'open') {
        open(msg);
    } else if (msg.action === 'updateData') {
        updateData(msg);
    } else if (msg.action === 'close') {
        app.classList.add('hidden');
    }
});

if (typeof window.invokeNative === 'undefined') {
    document.body.style.background = '#0a0e14';
    open({
        garage: { name: 'Garaj Public - Mission Row', code: 'PUBLIC_MROW', type: 'public' },
        vehicles: [
            {
                id: 1, plate: 'SWC-00001', model: 'sultan', label: 'Karin Sultan RS',
                category: 'Sport', fuel: 72, body_health: 95, stored: true, impounded: false,
            },
            {
                id: 2, plate: 'SWC-00002', model: 'adder', label: 'Truffade Adder',
                category: 'Super', fuel: 28, body_health: 61, stored: false, impounded: false,
            },
            {
                id: 3, plate: 'SWC-00003', model: 'bf400', label: 'BF400',
                category: 'Motocicleta', fuel: 5, body_health: 40, stored: false, impounded: true,
            },
        ],
        impounded: [
            {
                id: 3, plate: 'SWC-00003', model: 'bf400', label: 'BF400',
                total_fine: 3500, tickets_fine: 1000, release_fee: 2500,
            },
        ],
        tickets: [
            {
                id: 101, plate: 'SWC-00001', fine_amount: 500,
                reason: 'Parcare ilegală în zonă restricționată',
                issued_at: new Date().toISOString(),
            },
            {
                id: 102, plate: 'SWC-00002', fine_amount: 750,
                reason: 'Blocare acces urgențe',
                issued_at: new Date(Date.now() - 86400000).toISOString(),
            },
        ],
    });
}
