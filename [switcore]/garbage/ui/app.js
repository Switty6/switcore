'use strict';

const state = {
    job:        null,
    stats:      { total_sessions: 0, total_collected: 0, total_earned: 0 },
    recent:     [],
    routes:     [],
    hasSession: false,
    progress:   { collected: 0, total: 0 },
};

const esc    = s  => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const fmt    = n  => Number(n ?? 0).toLocaleString('ro-RO');
const fmtDate = s => s ? new Date(s).toLocaleDateString('ro-RO', { day:'2-digit', month:'2-digit', hour:'2-digit', minute:'2-digit' }) : '-';

const RESOURCE_NAME = (typeof window.invokeNative !== 'undefined' && typeof window.GetParentResourceName === 'function')
    ? window.GetParentResourceName()
    : 'garbage';

function postNUI(action, data) {
    return fetch(`https://${RESOURCE_NAME}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    }).catch(() => {});
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
    askConfirm(SwI18n.t('garbage.ui.confirm_quit'), () => {
        postNUI('quitJob');
        hidePanel();
    });
});

document.getElementById('btnAbandon').addEventListener('click', () => {
    askConfirm(SwI18n.t('garbage.ui.confirm_abandon'), () => {
        postNUI('abandonRoute', {});
        hidePanel();
    });
});

// native confirm() blocheaza NUI in CEF, deci folosim modal custom
let confirmCallback = null;
const confirmOverlay = document.getElementById('confirmOverlay');
const confirmTextEl  = document.getElementById('confirmText');

function askConfirm(message, onOk) {
    confirmTextEl.textContent = message;
    confirmCallback = onOk;
    confirmOverlay.classList.remove('hidden');
}

function closeConfirm() {
    confirmOverlay.classList.add('hidden');
    confirmCallback = null;
}

document.getElementById('confirmOk').addEventListener('click', () => {
    const cb = confirmCallback;
    closeConfirm();
    if (cb) cb();
});
document.getElementById('confirmCancel').addEventListener('click', closeConfirm);

function renderStats() {
    const job   = state.job   ?? {};
    const stats = state.stats ?? {};

    document.getElementById('gradeLabel').textContent    = job.gradeLabel ?? '-';
    document.getElementById('statSessions').textContent  = fmt(stats.total_sessions);
    document.getElementById('statCollected').textContent = fmt(stats.total_collected);
    document.getElementById('statEarned').textContent    = SwI18n.t('garbage.ui.unit_lei', fmt(stats.total_earned));

    const btn = document.getElementById('btnDuty');
    const isOnDuty = job.isOnDuty ?? false;
    btn.textContent = isOnDuty ? SwI18n.t('garbage.ui.duty_out') : SwI18n.t('garbage.ui.duty_in');
    btn.classList.toggle('on-duty', isOnDuty);

    const activeSection = document.getElementById('activeRouteSection');
    if (state.hasSession) {
        activeSection.classList.remove('hidden');
        document.getElementById('dutyRow').classList.add('hidden');
        updateProgress(state.progress.collected, state.progress.total);
    } else {
        activeSection.classList.add('hidden');
        document.getElementById('dutyRow').classList.remove('hidden');
    }
}

function updateProgress(collected, total) {
    state.progress = { collected, total };
    const pct = total > 0 ? Math.round((collected / total) * 100) : 0;
    document.getElementById('progressBar').style.width = pct + '%';
    document.getElementById('progressText').textContent =
        SwI18n.t('garbage.ui.progress_text', collected, total, pct);
}

function renderRoutes() {
    const list   = document.getElementById('routesList');
    const routes = state.routes ?? [];
    const canStart = !state.hasSession && (state.job?.isOnDuty ?? false);

    if (!routes.length) {
        list.innerHTML = `<div class="empty-msg">${esc(SwI18n.t('garbage.ui.no_routes'))}</div>`;
        return;
    }

    list.innerHTML = routes.map(r => `
        <div class="route-item">
            <div class="route-info">
                <div class="route-name">${esc(r.name)}</div>
                <div class="route-count">${esc(SwI18n.t('garbage.ui.route_count', r.count))}</div>
            </div>
            <button class="start-btn" data-routeid="${r.id}" ${canStart ? '' : 'disabled'}>
                ${esc(state.hasSession ? SwI18n.t('garbage.ui.route_active') : SwI18n.t('garbage.ui.route_start'))}
            </button>
        </div>
    `).join('');

    list.querySelectorAll('.start-btn:not([disabled])').forEach(btn => {
        btn.addEventListener('click', () => {
            const routeId = parseInt(btn.dataset.routeid);
            postNUI('startRoute', { routeId });
            hidePanel();
        });
    });
}

function renderHistory() {
    const list    = document.getElementById('historyList');
    const sessions = state.recent ?? [];

    if (!sessions.length) {
        list.innerHTML = `<div class="empty-msg">${esc(SwI18n.t('garbage.ui.no_sessions'))}</div>`;
        return;
    }

    list.innerHTML = sessions.map(s => {
        const statusClass = s.status === 'completed' ? 'status-completed' : 'status-abandoned';
        const statusLabel = s.status === 'completed'
            ? SwI18n.t('garbage.ui.status_completed')
            : SwI18n.t('garbage.ui.status_abandoned');
        return `
            <div class="history-item">
                <div class="history-info">
                    <div class="history-route">${esc(SwI18n.t('garbage.ui.history_route', s.route_id))}</div>
                    <div class="history-detail">${esc(SwI18n.t('garbage.ui.history_detail', s.collected_count, s.total_waypoints, fmtDate(s.completed_at)))}</div>
                </div>
                <div style="text-align:right">
                    <div class="history-pay">${esc(SwI18n.t('garbage.ui.history_pay', fmt(s.pay_amount)))}</div>
                    <span class="status-badge ${statusClass}">${esc(statusLabel)}</span>
                </div>
            </div>
        `;
    }).join('');
}

function showPanel() { document.getElementById('panel').classList.remove('hidden'); }
function hidePanel() { document.getElementById('panel').classList.add('hidden'); }

const CIRCUMFERENCE = 163.4; // 2π × r=26
let collectingTimer = null;

function showCollectingRing(duration) {
    const overlay = document.getElementById('collectingOverlay');
    const ring    = document.getElementById('ringFill');

    ring.classList.remove('animating');
    ring.style.strokeDashoffset = CIRCUMFERENCE;
    overlay.classList.remove('hidden');

    // Force reflow so the next transition actually animates
    void ring.getBoundingClientRect();

    ring.classList.add('animating');
    ring.style.transitionDuration = duration + 'ms';
    ring.style.strokeDashoffset   = '0';

    if (collectingTimer) clearTimeout(collectingTimer);
    collectingTimer = setTimeout(hideCollectingRing, duration + 300);
}

function hideCollectingRing() {
    if (collectingTimer) { clearTimeout(collectingTimer); collectingTimer = null; }
    const overlay = document.getElementById('collectingOverlay');
    const ring    = document.getElementById('ringFill');
    overlay.classList.add('hidden');
    ring.classList.remove('animating');
    ring.style.strokeDashoffset = CIRCUMFERENCE;
}

// re-randare la schimbarea dictionarului (stringuri generate din JS)
document.addEventListener('sw:i18n', () => {
    renderStats();
    renderRoutes();
    renderHistory();
});

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.action) return;

    if (d.action === 'open') {
        state.job        = d.job        ?? null;
        state.stats      = d.stats      ?? {};
        state.recent     = d.recent     ?? [];
        state.routes     = d.routes     ?? [];
        state.hasSession = d.hasSession ?? false;
        renderStats();
        renderRoutes();
        renderHistory();
        showPanel();
    }

    if (d.action === 'updateProgress') {
        state.hasSession = true;
        updateProgress(d.collected, d.total);
        renderRoutes();
        renderStats();
    }

    if (d.action === 'startCollecting') {
        showCollectingRing(d.duration ?? 1400);
    }

    if (d.action === 'stopCollecting') {
        hideCollectingRing();
    }
});

if (typeof window.invokeNative === 'undefined') {
    window.dispatchEvent(new MessageEvent('message', { data: {
        action: 'open',
        job: { gradeLabel: 'Operator', isOnDuty: true },
        stats: { total_sessions: 7, total_collected: 63, total_earned: 5250 },
        hasSession: false,
        routes: [
            { id: 1, name: 'Ruta Industriala Nord',  count: 8  },
            { id: 2, name: 'Ruta Rezidentiala Sud',   count: 9  },
            { id: 3, name: 'Ruta Comerciala Centru',  count: 10 },
        ],
        recent: [
            { route_id: 1, status: 'completed',  collected_count: 8,  total_waypoints: 8,  pay_amount: 720,  completed_at: new Date().toISOString() },
            { route_id: 2, status: 'abandoned',  collected_count: 4,  total_waypoints: 9,  pay_amount: 260,  completed_at: new Date().toISOString() },
            { route_id: 3, status: 'completed',  collected_count: 10, total_waypoints: 10, pay_amount: 850,  completed_at: new Date().toISOString() },
        ],
    }}));
}
