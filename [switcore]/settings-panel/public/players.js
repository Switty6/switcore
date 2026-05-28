(function () {
    'use strict';

    const token    = localStorage.getItem('sc_token');
    const username = localStorage.getItem('sc_username') || 'Admin';
    const role     = localStorage.getItem('sc_role') || 'staff';

    if (!token) { window.location.href = '/'; return; }

    const tbody       = document.getElementById('players-tbody');
    const searchInput = document.getElementById('search');
    const searchClear = document.getElementById('search-clear');
    const btnReload   = document.getElementById('btn-reload');
    const btnLogout   = document.getElementById('btn-logout');
    const statTotal   = document.getElementById('stat-total');
    const statOnline  = document.getElementById('stat-online');
    const statBanned  = document.getElementById('stat-banned');
    const emptyState  = document.getElementById('empty-state');
    const emptyQuery  = document.getElementById('empty-query');
    const demoBadge   = document.getElementById('demo-badge');
    const banModal    = document.getElementById('ban-modal');
    const kickModal   = document.getElementById('kick-modal');

    const ROLE_LABELS = { superadmin: 'Super Admin', admin: 'Admin', moderator: 'Moderator', staff: 'Staff' };
    document.getElementById('user-name').textContent       = username;
    document.getElementById('user-avatar').textContent     = username.charAt(0).toUpperCase();
    document.getElementById('user-role-label').textContent = ROLE_LABELS[role] || 'Staff';

    let allPlayers   = [];
    let activeFilter = 'all';
    let searchQuery  = '';
    let banTarget    = null;
    let kickTarget   = null;

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

    function toast(msg, type = 'info', duration = 3500) {
        const container = document.getElementById('toast-container');
        const el = document.createElement('div');
        el.className = `toast ${type}`;
        el.innerHTML = `<span class="toast-dot"></span><span class="toast-msg">${msg}</span>`;
        container.appendChild(el);
        setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 220); }, duration);
    }

    function formatPlaytime(seconds) {
        if (!seconds || seconds < 60) return '< 1 min';
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    function timeAgo(isoDate) {
        if (!isoDate) return '-';
        const diff = Date.now() - new Date(isoDate).getTime();
        const s = Math.floor(diff / 1000);
        if (s < 60)    return 'acum câteva secunde';
        if (s < 3600)  return `acum ${Math.floor(s / 60)} min`;
        if (s < 86400) return `acum ${Math.floor(s / 3600)}h`;
        return `acum ${Math.floor(s / 86400)} zile`;
    }

    function esc(str) {
        return String(str || '').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    }

    function renderTable() {
        let rows = allPlayers;

        if (activeFilter === 'online') rows = rows.filter(p => p.online);
        if (activeFilter === 'banned') rows = rows.filter(p => p.banned);

        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            rows = rows.filter(p =>
                (p.name || '').toLowerCase().includes(q) ||
                (p.license || '').toLowerCase().includes(q)
            );
        }

        const tableWrap = document.querySelector('.table-wrap');
        emptyState.classList.toggle('hidden', rows.length > 0);
        tableWrap.classList.toggle('hidden', rows.length === 0);

        if (rows.length === 0) {
            emptyQuery.textContent = searchQuery || activeFilter;
            tbody.innerHTML = '';
            return;
        }

        const canAct = ['superadmin', 'admin', 'moderator'].includes(role);

        tbody.innerHTML = rows.map(p => {
            const statusClass = p.banned ? 'status-banned' : (p.online ? 'status-online' : 'status-offline');
            const statusTitle = p.banned ? 'Banat' : (p.online ? 'Online' : 'Offline');
            const licenseTrunc = p.license.length > 30 ? p.license.slice(0, 30) + '…' : p.license;

            let actions = '';
            if (canAct) {
                if (p.online && !p.banned) {
                    actions += `<button class="row-btn row-btn--warning"
                        data-action="kick"
                        data-license="${esc(p.license)}"
                        data-name="${esc(p.name)}"
                        title="Kick">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
                        </svg>
                    </button>`;
                }
                if (p.banned) {
                    actions += `<button class="row-btn row-btn--success"
                        data-action="unban"
                        data-license="${esc(p.license)}"
                        data-name="${esc(p.name)}"
                        title="Ridică ban">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                            <polyline points="20 6 9 17 4 12"/>
                        </svg>
                    </button>`;
                } else {
                    actions += `<button class="row-btn row-btn--danger"
                        data-action="ban"
                        data-license="${esc(p.license)}"
                        data-name="${esc(p.name)}"
                        title="Banează">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                            <circle cx="12" cy="12" r="10"/>
                            <line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/>
                        </svg>
                    </button>`;
                }
            }

            return `<tr class="${p.banned ? 'row-banned' : ''}">
                <td style="text-align:center">
                    <span class="status-dot ${statusClass}" title="${statusTitle}"></span>
                </td>
                <td>
                    <div class="player-name">${esc(p.name || 'Necunoscut')}</div>
                    ${p.steam ? `<div class="player-sub">${esc(p.steam)}</div>` : ''}
                </td>
                <td>
                    <span class="key-cell" title="${esc(p.license)}">${esc(licenseTrunc)}</span>
                </td>
                <td style="text-align:center; color:var(--text-2)">${p.character_count ?? 0}</td>
                <td style="color:var(--text-2)">${formatPlaytime(p.playtime)}</td>
                <td style="color:var(--text-2); font-size:.8rem">${timeAgo(p.last_seen)}</td>
                <td>
                    <div style="display:flex; gap:4px; justify-content:center">${actions}</div>
                </td>
            </tr>`;
        }).join('');
    }

    async function load(search = '') {
        try {
            const url = search ? `/api/players?search=${encodeURIComponent(search)}` : '/api/players';
            const data = await api('GET', url);
            allPlayers = data.players;
            statTotal.textContent  = data.total;
            statOnline.textContent = data.online;
            statBanned.textContent = data.banned;
            if (data.dummyMode) demoBadge.classList.remove('hidden');
            renderTable();
        } catch (err) {
            toast(`Eroare: ${err.message}`, 'error');
        }
    }

    const confirmModal   = document.getElementById('confirm-modal');
    const confirmTitle   = document.getElementById('confirm-title');
    const confirmMessage = document.getElementById('confirm-message');
    const confirmYes     = document.getElementById('confirm-yes');
    const confirmNo      = document.getElementById('confirm-no');
    let confirmResolve   = null;

    function showConfirm(title, message, yesLabel = 'Confirmă', yesClass = 'btn-danger-solid') {
        return new Promise(resolve => {
            confirmResolve = resolve;
            confirmTitle.textContent   = title;
            confirmMessage.textContent = message;
            confirmYes.textContent     = yesLabel;
            confirmYes.className       = yesClass;
            confirmModal.classList.remove('hidden');
        });
    }

    confirmYes.addEventListener('click', () => {
        confirmModal.classList.add('hidden');
        if (confirmResolve) { confirmResolve(true);  confirmResolve = null; }
    });
    confirmNo.addEventListener('click', () => {
        confirmModal.classList.add('hidden');
        if (confirmResolve) { confirmResolve(false); confirmResolve = null; }
    });
    confirmModal.addEventListener('click', (e) => {
        if (e.target === confirmModal) {
            confirmModal.classList.add('hidden');
            if (confirmResolve) { confirmResolve(false); confirmResolve = null; }
        }
    });

    const banDurationSelect  = document.getElementById('ban-duration');
    const customDurationRow  = document.getElementById('custom-duration-row');
    const banCustomValue     = document.getElementById('ban-custom-value');
    const banCustomUnit      = document.getElementById('ban-custom-unit');
    const durationPreview    = document.getElementById('duration-preview');
    const banError           = document.getElementById('ban-error');

    banDurationSelect.addEventListener('change', () => {
        const isCustom = banDurationSelect.value === 'custom';
        customDurationRow.classList.toggle('hidden', !isCustom);
        if (isCustom) {
            banCustomValue.focus();
            updateDurationPreview();
        } else {
            durationPreview.classList.add('hidden');
        }
    });

    function updateDurationPreview() {
        const val  = parseInt(banCustomValue.value);
        const mult = parseInt(banCustomUnit.value);
        if (!val || val < 1 || isNaN(val)) {
            durationPreview.classList.add('hidden');
            return;
        }
        const totalHours = val * mult;
        const preview    = formatDuration(totalHours);
        durationPreview.textContent = `= ${preview}`;
        durationPreview.classList.remove('hidden');
    }

    banCustomValue.addEventListener('input', updateDurationPreview);
    banCustomUnit.addEventListener('change', updateDurationPreview);

    function formatDuration(hours) {
        if (hours < 1)    return `${Math.round(hours * 60)} minute`;
        if (hours < 24)   return `${hours} ${hours === 1 ? 'oră' : 'ore'}`;
        if (hours < 168)  { const d = Math.round(hours / 24);  return `${d} ${d === 1 ? 'zi' : 'zile'}`; }
        if (hours < 720)  { const w = Math.round(hours / 168); return `${w} ${w === 1 ? 'săptămână' : 'săptămâni'}`; }
        const m = Math.round(hours / 720);
        return `${m} ${m === 1 ? 'lună' : 'luni'}`;
    }

    function showBanError(msg) {
        banError.textContent = msg;
        banError.classList.toggle('hidden', !msg);
    }

    function openBanModal(license, name) {
        banTarget = license;
        document.getElementById('ban-player-name').textContent = name;
        document.getElementById('ban-reason').value = '';
        banDurationSelect.value = '';
        banCustomValue.value    = '';
        banCustomUnit.value     = '24';
        customDurationRow.classList.add('hidden');
        durationPreview.classList.add('hidden');
        showBanError('');
        banModal.classList.remove('hidden');
        setTimeout(() => document.getElementById('ban-reason').focus(), 50);
    }

    function closeBanModal() {
        banModal.classList.add('hidden');
        banTarget = null;
    }

    document.getElementById('ban-cancel').addEventListener('click', closeBanModal);
    banModal.addEventListener('click', (e) => { if (e.target === banModal) closeBanModal(); });

    document.getElementById('ban-confirm').addEventListener('click', async () => {
        if (!banTarget) return;

        showBanError('');
        const reason = document.getElementById('ban-reason').value.trim();
        let durationHours = null;

        const durVal = banDurationSelect.value;
        if (durVal === 'custom') {
            const val  = parseInt(banCustomValue.value);
            const mult = parseInt(banCustomUnit.value);
            if (!val || val < 1 || isNaN(val)) {
                showBanError('Introdu o durată validă (minim 1).');
                banCustomValue.focus();
                return;
            }
            durationHours = val * mult;
        } else if (durVal) {
            durationHours = parseInt(durVal);
        }

        try {
            await api('POST', `/api/players/${encodeURIComponent(banTarget)}/ban`, {
                reason:         reason || null,
                duration_hours: durationHours
            });
            const durText = durationHours ? formatDuration(durationHours) : 'permanent';
            toast(`Jucător banat - <strong>${durText}</strong>`, 'success');
            closeBanModal();
            await load(searchQuery);
        } catch (err) {
            showBanError(err.message);
        }
    });

    function openKickModal(license, name) {
        kickTarget = license;
        document.getElementById('kick-player-name').textContent = name;
        document.getElementById('kick-reason').value = '';
        kickModal.classList.remove('hidden');
        setTimeout(() => document.getElementById('kick-reason').focus(), 50);
    }

    function closeKickModal() {
        kickModal.classList.add('hidden');
        kickTarget = null;
    }

    document.getElementById('kick-cancel').addEventListener('click', closeKickModal);
    kickModal.addEventListener('click', (e) => { if (e.target === kickModal) closeKickModal(); });

    document.getElementById('kick-confirm').addEventListener('click', async () => {
        if (!kickTarget) return;
        const reason = document.getElementById('kick-reason').value.trim();
        try {
            await api('POST', `/api/players/${encodeURIComponent(kickTarget)}/kick`, {
                reason: reason || null
            });
            toast('Kick adăugat în coadă - va fi procesat de FiveM', 'warning');
            closeKickModal();
            await load(searchQuery);
        } catch (err) {
            toast(`Eroare: ${err.message}`, 'error');
            closeKickModal();
        }
    });

    document.getElementById('kick-reason').addEventListener('keydown', (e) => {
        if (e.key === 'Enter') document.getElementById('kick-confirm').click();
    });

    tbody.addEventListener('click', async (e) => {
        const btn = e.target.closest('[data-action]');
        if (!btn) return;

        const action  = btn.dataset.action;
        const license = btn.dataset.license;
        const name    = btn.dataset.name;

        if (action === 'ban') {
            openBanModal(license, name);

        } else if (action === 'kick') {
            openKickModal(license, name);

        } else if (action === 'unban') {
            const ok = await showConfirm(
                'Ridică ban',
                `Ești sigur că vrei să ridici banul jucătorului ${name || license}?\nJucătorul va putea intra din nou pe server.`,
                'Ridică ban',
                'btn-save'
            );
            if (!ok) return;
            try {
                await api('DELETE', `/api/players/${encodeURIComponent(license)}/ban`);
                toast('Ban ridicat cu succes', 'success');
                await load(searchQuery);
            } catch (err) {
                toast(`Eroare: ${err.message}`, 'error');
            }
        }
    });

    document.querySelectorAll('.chip').forEach(chip => {
        chip.addEventListener('click', () => {
            document.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
            chip.classList.add('active');
            activeFilter = chip.dataset.filter;
            renderTable();
        });
    });

    let searchTimeout;
    searchInput.addEventListener('input', () => {
        searchQuery = searchInput.value.trim();
        searchClear.classList.toggle('hidden', !searchQuery);
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => load(searchQuery), 350);
    });

    searchClear.addEventListener('click', () => {
        searchInput.value = '';
        searchQuery = '';
        searchClear.classList.add('hidden');
        load();
    });

    btnReload.addEventListener('click', async () => {
        btnReload.classList.add('spinning');
        await load(searchQuery);
        btnReload.classList.remove('spinning');
        toast('Date reîncărcate', 'info');
    });

    btnLogout.addEventListener('click', () => {
        localStorage.clear();
        window.location.href = '/';
    });

    load();
})();
