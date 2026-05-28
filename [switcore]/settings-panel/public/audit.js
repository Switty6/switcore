(function () {
    'use strict';

    const token    = localStorage.getItem('sc_token');
    const username = localStorage.getItem('sc_username') || 'Admin';
    const role     = localStorage.getItem('sc_role') || 'staff';

    if (!token) { window.location.href = '/'; return; }

    const ROLE_LEVELS = { staff: 1, moderator: 2, admin: 3, superadmin: 4 };
    const ROLE_LABELS = { superadmin: 'Super Admin', admin: 'Admin', moderator: 'Moderator', staff: 'Staff' };
    const LIMIT = 50;

    const tbody        = document.getElementById('audit-tbody');
    const btnReload    = document.getElementById('btn-reload');
    const btnLogout    = document.getElementById('btn-logout');
    const statTotal    = document.getElementById('stat-total');
    const statPageInfo = document.getElementById('stat-page-info');
    const pgInfo       = document.getElementById('pg-info');
    const pgPrev       = document.getElementById('pg-prev');
    const pgNext       = document.getElementById('pg-next');
    const filterUser   = document.getElementById('filter-user');
    const filterAction = document.getElementById('filter-action');
    const btnClear     = document.getElementById('btn-clear-filters');
    const noAccessMsg  = document.getElementById('no-access-msg');
    const emptyState   = document.getElementById('empty-state');
    const pagination   = document.getElementById('pagination');

    document.getElementById('user-name').textContent       = username;
    document.getElementById('user-avatar').textContent     = username.charAt(0).toUpperCase();
    document.getElementById('user-role-label').textContent = ROLE_LABELS[role] || 'Staff';

    let currentPage  = 1;
    let totalEntries = 0;
    let filterUserVal   = '';
    let filterActionVal = '';

    const canAccess = (ROLE_LEVELS[role] || 0) >= ROLE_LEVELS['admin'];
    if (!canAccess) {
        noAccessMsg.style.display = 'flex';
        tbody.innerHTML = '';
        pagination.style.display = 'none';
    }

    async function api(method, path, body) {
        const opts = {
            method,
            headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' }
        };
        if (body !== undefined) opts.body = JSON.stringify(body);
        const res = await fetch(path, opts);
        if (res.status === 401) { localStorage.clear(); window.location.href = '/'; return; }
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
        return data;
    }

    function toast(msg, type = 'info', dur = 3500) {
        const container = document.getElementById('toast-container');
        const el = document.createElement('div');
        el.className = `toast ${type}`;
        el.innerHTML = `<span class="toast-dot"></span><span class="toast-msg">${msg}</span>`;
        container.appendChild(el);
        setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 220); }, dur);
    }

    function esc(str) {
        return String(str || '').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    }

    function formatTs(iso) {
        if (!iso) return '-';
        const d = new Date(iso);
        return d.toLocaleDateString('ro-RO') + ' ' + d.toLocaleTimeString('ro-RO', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }

    const ACTION_CLASSES = {
        'LOGIN':           'audit-login',
        'UPDATE_SETTING':  'audit-setting',
        'CREATE_USER':     'audit-user',
        'UPDATE_USER':     'audit-user',
        'DELETE_USER':     'audit-danger',
        'BAN_PLAYER':      'audit-danger',
        'UNBAN_PLAYER':    'audit-success',
    };

    function actionBadge(action) {
        const cls = ACTION_CLASSES[action] || 'audit-default';
        return `<span class="audit-badge ${cls}">${esc(action)}</span>`;
    }

    function renderTable(entries) {
        const tableWrap = document.querySelector('.table-wrap');

        if (!entries.length) {
            emptyState.classList.remove('hidden');
            tableWrap.classList.add('hidden');
            pagination.style.display = 'none';
            return;
        }

        emptyState.classList.add('hidden');
        tableWrap.classList.remove('hidden');
        pagination.style.display = 'flex';

        tbody.innerHTML = entries.map(e => `<tr>
            <td style="font-size:.78rem; color:var(--text-2); white-space:nowrap">${formatTs(e.timestamp)}</td>
            <td>
                <div style="display:flex; align-items:center; gap:8px">
                    <div class="user-avatar" style="width:22px; height:22px; font-size:.65rem; flex-shrink:0">
                        ${esc((e.username || '?').charAt(0).toUpperCase())}
                    </div>
                    <span style="font-size:.82rem; color:var(--text)">${esc(e.username || '-')}</span>
                </div>
            </td>
            <td>${actionBadge(e.action)}</td>
            <td>
                <span class="key-cell" style="font-size:.78rem" title="${esc(e.target || '')}">${esc(truncate(e.target, 35))}</span>
            </td>
            <td>
                <span style="color:var(--text-3); font-size:.78rem">${esc(truncate(e.old_value, 30))}</span>
            </td>
            <td>
                <span style="color:var(--text-2); font-size:.78rem">${esc(truncate(e.new_value, 30))}</span>
            </td>
        </tr>`).join('');
    }

    function truncate(str, len) {
        if (!str) return '-';
        return str.length > len ? str.slice(0, len) + '…' : str;
    }

    function updatePagination() {
        const totalPages = Math.max(1, Math.ceil(totalEntries / LIMIT));
        pgInfo.textContent        = `Pagina ${currentPage} / ${totalPages}`;
        statPageInfo.textContent  = `${currentPage} / ${totalPages}`;
        pgPrev.disabled = currentPage <= 1;
        pgNext.disabled = currentPage >= totalPages;
    }

    async function load() {
        if (!canAccess) return;
        try {
            const params = new URLSearchParams({ page: currentPage, limit: LIMIT });
            if (filterUserVal)   params.set('username', filterUserVal);
            if (filterActionVal) params.set('action',   filterActionVal);

            const data = await api('GET', `/api/audit?${params}`);
            totalEntries = data.total;
            statTotal.textContent = data.total;
            renderTable(data.entries);
            updatePagination();
        } catch (err) {
            toast(`Eroare: ${err.message}`, 'error');
        }
    }

    async function loadActions() {
        if (!canAccess) return;
        try {
            const actions = await api('GET', '/api/audit/actions');
            actions.forEach(a => {
                const opt = document.createElement('option');
                opt.value       = a;
                opt.textContent = a;
                filterAction.appendChild(opt);
            });
        } catch {}
    }

    let filterTimeout;
    filterUser.addEventListener('input', () => {
        clearTimeout(filterTimeout);
        filterTimeout = setTimeout(() => {
            filterUserVal = filterUser.value.trim();
            currentPage = 1;
            load();
        }, 400);
    });

    filterAction.addEventListener('change', () => {
        filterActionVal = filterAction.value;
        currentPage = 1;
        load();
    });

    btnClear.addEventListener('click', () => {
        filterUser.value   = '';
        filterAction.value = '';
        filterUserVal      = '';
        filterActionVal    = '';
        currentPage        = 1;
        load();
    });

    pgPrev.addEventListener('click', () => {
        if (currentPage > 1) { currentPage--; load(); }
    });
    pgNext.addEventListener('click', () => {
        const totalPages = Math.ceil(totalEntries / LIMIT);
        if (currentPage < totalPages) { currentPage++; load(); }
    });

    btnReload.addEventListener('click', async () => {
        btnReload.classList.add('spinning');
        await load();
        btnReload.classList.remove('spinning');
        toast('Log reîncărcat', 'info');
    });

    btnLogout.addEventListener('click', () => {
        localStorage.clear();
        window.location.href = '/';
    });

    loadActions();
    load();
})();
