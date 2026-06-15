'use strict';

const state = {
    job:     null,
    stats:   { total_trips: 0, total_earned: 0 },
    recent:  [],
    pending: [],
};

const esc = s => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const fmt = n => Number(n ?? 0).toLocaleString('ro-RO');
const fmtDate = s => s ? new Date(s).toLocaleDateString('ro-RO', { day:'2-digit', month:'2-digit', hour:'2-digit', minute:'2-digit' }) : '-';

function postNUI(action, data) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    }).catch(() => {});
}

// Stub for browser-based dev preview (FiveM provides this natively)
function GetParentResourceName() {
    return typeof window.invokeNative !== 'undefined' ? window.GetParentResourceName?.() ?? 'taxi' : 'taxi';
}

document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
        btn.classList.add('active');
        document.getElementById('tab-' + btn.dataset.tab).classList.remove('hidden');
    });
});

document.getElementById('btnClose').addEventListener('click', () => {
    postNUI('close');
    hidePanel();
});

document.getElementById('btnDuty').addEventListener('click', () => {
    postNUI('clockIn');
    hidePanel();
});

document.getElementById('btnQuit').addEventListener('click', () => {
    if (!confirm(SwI18n.t('taxi.ui.confirm_quit'))) return;
    postNUI('quitJob');
});

function renderStats() {
    const job   = state.job   ?? {};
    const stats = state.stats ?? {};

    document.getElementById('gradeLabel').textContent = job.gradeLabel ?? '-';

    document.getElementById('statTrips').textContent  = fmt(stats.total_trips);
    document.getElementById('statEarned').textContent = fmt(stats.total_earned) + ' ' + SwI18n.t('taxi.ui.currency_suffix');

    const btn = document.getElementById('btnDuty');
    const isOnDuty = job.isOnDuty ?? false;
    btn.textContent = isOnDuty ? SwI18n.t('taxi.ui.btn_clock_out') : SwI18n.t('taxi.ui.btn_clock_in');
    btn.classList.toggle('on-duty', isOnDuty);
}

function renderOrders() {
    const list   = document.getElementById('ordersList');
    const badge  = document.getElementById('ordersBadge');
    const orders = state.pending ?? [];

    badge.textContent = orders.length;
    badge.style.display = orders.length ? 'inline' : 'none';

    if (!orders.length) {
        list.innerHTML = `<div class="empty-msg">${esc(SwI18n.t('taxi.ui.no_orders'))}</div>`;
        return;
    }

    list.innerHTML = orders.map(o => `
        <div class="order-item" data-id="${o.id}">
            <div class="order-info">
                <div class="order-name">${esc(o.passenger_name ?? SwI18n.t('taxi.ui.default_passenger'))}</div>
                <div class="order-time">${fmtDate(o.created_at)}</div>
            </div>
            <button class="accept-btn" data-orderid="${o.id}">${esc(SwI18n.t('taxi.ui.btn_accept'))}</button>
        </div>
    `).join('');

    list.querySelectorAll('.accept-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const orderId = parseInt(btn.dataset.orderid);
            postNUI('acceptOrder', { orderId });
            hidePanel();
        });
    });
}

function renderHistory() {
    const list   = document.getElementById('historyList');
    const trips  = state.recent ?? [];

    if (!trips.length) {
        list.innerHTML = `<div class="empty-msg">${esc(SwI18n.t('taxi.ui.no_history'))}</div>`;
        return;
    }

    list.innerHTML = trips.map(t => `
        <div class="history-item">
            <div>
                <div class="history-km">${parseFloat(t.distance_km ?? 0).toFixed(1)} km</div>
            </div>
            <div class="history-pay">+${fmt(t.pay_amount)} ${esc(SwI18n.t('taxi.ui.currency_suffix'))}</div>
            <div class="history-date">${fmtDate(t.completed_at)}</div>
        </div>
    `).join('');
}

function showPanel() {
    document.getElementById('panel').classList.remove('hidden');
}

function hidePanel() {
    document.getElementById('panel').classList.add('hidden');
}

// re-randare a stringurilor generate din JS la schimbarea dictionarului
document.addEventListener('sw:i18n', () => {
    renderStats();
    renderOrders();
    renderHistory();
});

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.action) return;

    if (d.action === 'open') {
        state.job     = d.job     ?? null;
        state.stats   = d.stats   ?? { total_trips: 0, total_earned: 0 };
        state.recent  = d.recent  ?? [];
        state.pending = d.pending ?? [];
        renderStats();
        renderOrders();
        renderHistory();
        showPanel();
    }

    if (d.action === 'newOrder') {
        const exists = state.pending.find(o => o.id === d.order.id);
        if (!exists) state.pending.unshift(d.order);
        renderOrders();
    }

    if (d.action === 'orderRemoved') {
        state.pending = state.pending.filter(o => o.id !== d.orderId);
        renderOrders();
    }
});

if (typeof window.invokeNative === 'undefined') {
    window.dispatchEvent(new MessageEvent('message', { data: {
        action: 'open',
        job: { gradeLabel: 'Sofer', isOnDuty: true },
        stats: { total_trips: 12, total_earned: 3840 },
        pending: [
            { id: 1, passenger_name: 'Ion Popescu', created_at: new Date().toISOString() },
            { id: 2, passenger_name: 'Maria Ionescu', created_at: new Date().toISOString() },
        ],
        recent: [
            { distance_km: 2.4, pay_amount: 240, completed_at: new Date().toISOString() },
            { distance_km: 1.1, pay_amount: 110, completed_at: new Date().toISOString() },
        ],
    }}));
}
