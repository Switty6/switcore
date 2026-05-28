(function () {
    'use strict';

    const token    = localStorage.getItem('sc_token');
    const username = localStorage.getItem('sc_username') || 'Admin';
    const role     = localStorage.getItem('sc_role') || 'staff';

    if (!token) { window.location.href = '/'; return; }

    const ROLE_LEVELS = { staff: 1, moderator: 2, admin: 3, superadmin: 4 };
    const ROLE_LABELS = { superadmin: 'Super Admin', admin: 'Admin', moderator: 'Moderator', staff: 'Staff' };

    const tbody       = document.getElementById('users-tbody');
    const btnAddUser  = document.getElementById('btn-add-user');
    const btnReload   = document.getElementById('btn-reload');
    const btnLogout   = document.getElementById('btn-logout');
    const noAccessMsg = document.getElementById('no-access-msg');

    document.getElementById('user-name').textContent       = username;
    document.getElementById('user-avatar').textContent     = username.charAt(0).toUpperCase();
    document.getElementById('user-role-label').textContent = ROLE_LABELS[role] || 'Staff';

    const statTotal     = document.getElementById('stat-total');
    const statSuperadmin = document.getElementById('stat-superadmin');
    const statAdmin     = document.getElementById('stat-admin');
    const statModerator = document.getElementById('stat-moderator');
    const statStaff     = document.getElementById('stat-staff');

    const userModal     = document.getElementById('user-modal');
    const deleteModal   = document.getElementById('delete-modal');
    const modalTitle    = document.getElementById('modal-title');
    const modalUsername = document.getElementById('modal-username');
    const modalPassword = document.getElementById('modal-password');
    const modalRole     = document.getElementById('modal-role');
    const modalError    = document.getElementById('modal-error');
    const pwHint        = document.getElementById('pw-hint');
    const pwLabel       = document.getElementById('pw-label');
    const optSuperadmin = document.getElementById('opt-superadmin');
    const deleteUsername = document.getElementById('delete-username');

    let allUsers   = [];
    let editTarget = null; // username being edited, or null for create

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

    function formatDate(iso) {
        if (!iso) return '-';
        return new Date(iso).toLocaleString('ro-RO', { dateStyle: 'short', timeStyle: 'short' });
    }

    const myLevel = ROLE_LEVELS[role] || 0;
    const canManage = myLevel >= ROLE_LEVELS['admin'];
    const isSuperadmin = myLevel >= ROLE_LEVELS['superadmin'];

    if (!canManage) {
        noAccessMsg.style.display = 'flex';
    }

    if (isSuperadmin) {
        btnAddUser.style.display = 'flex';
    }

    if (!isSuperadmin) {
        optSuperadmin.style.display = 'none';
    }

    function renderTable() {
        if (!allUsers.length) {
            document.getElementById('empty-state').classList.remove('hidden');
            document.querySelector('.table-wrap').classList.add('hidden');
            return;
        }
        document.getElementById('empty-state').classList.add('hidden');
        document.querySelector('.table-wrap').classList.remove('hidden');

        tbody.innerHTML = allUsers.map(u => {
            const isSelf = u.username === username;
            const targetLevel = ROLE_LEVELS[u.role] || 0;
            const canEdit   = isSuperadmin && !isSelf;
            const canDelete = isSuperadmin && !isSelf && targetLevel < myLevel;

            const editBtn = canEdit
                ? `<button class="row-btn" data-action="edit" data-username="${esc(u.username)}" title="Editează">
                       <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                           <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                           <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                       </svg>
                   </button>`
                : '';

            const deleteBtn = canDelete
                ? `<button class="row-btn row-btn--danger" data-action="delete" data-username="${esc(u.username)}" title="Șterge">
                       <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                           <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/>
                           <path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/>
                       </svg>
                   </button>`
                : '';

            const selfTag = isSelf ? '<span class="self-tag">eu</span>' : '';

            return `<tr>
                <td style="text-align:center">
                    <div class="user-avatar" style="margin:0 auto; background:var(--accent-dim); color:var(--accent)">
                        ${esc(u.username.charAt(0).toUpperCase())}
                    </div>
                </td>
                <td>
                    <span style="font-weight:600; color:var(--text)">${esc(u.username)}</span>
                    ${selfTag}
                </td>
                <td><span class="role-badge role-${esc(u.role)}">${esc(ROLE_LABELS[u.role] || u.role)}</span></td>
                <td style="color:var(--text-2); font-size:.82rem">${formatDate(u.created_at)}</td>
                <td style="color:var(--text-2); font-size:.82rem">${formatDate(u.last_login)}</td>
                <td style="text-align:center">
                    <div style="display:flex; gap:4px; justify-content:center">
                        ${editBtn}${deleteBtn}
                    </div>
                </td>
            </tr>`;
        }).join('');
    }

    function updateStats() {
        statTotal.textContent      = allUsers.length;
        statSuperadmin.textContent = allUsers.filter(u => u.role === 'superadmin').length;
        statAdmin.textContent      = allUsers.filter(u => u.role === 'admin').length;
        statModerator.textContent  = allUsers.filter(u => u.role === 'moderator').length;
        statStaff.textContent      = allUsers.filter(u => u.role === 'staff').length;
    }

    async function load() {
        if (!canManage) {
            tbody.innerHTML = '';
            updateStats();
            return;
        }
        try {
            allUsers = await api('GET', '/api/users');
            updateStats();
            renderTable();
        } catch (err) {
            toast(`Eroare: ${err.message}`, 'error');
        }
    }

    function openCreateModal() {
        editTarget = null;
        modalTitle.textContent = 'Adaugă utilizator';
        modalUsername.value    = '';
        modalUsername.disabled = false;
        modalPassword.value    = '';
        modalRole.value        = 'staff';
        pwLabel.textContent    = 'Parolă';
        pwHint.style.display   = 'none';
        showModalError('');
        userModal.classList.remove('hidden');
        setTimeout(() => modalUsername.focus(), 50);
    }

    function openEditModal(uname) {
        const user = allUsers.find(u => u.username === uname);
        if (!user) return;
        editTarget = uname;
        modalTitle.textContent = `Editează: ${uname}`;
        modalUsername.value    = uname;
        modalUsername.disabled = true;
        modalPassword.value    = '';
        modalRole.value        = user.role;
        pwLabel.textContent    = 'Parolă nouă';
        pwHint.style.display   = 'block';
        showModalError('');
        userModal.classList.remove('hidden');
        setTimeout(() => modalPassword.focus(), 50);
    }

    function closeUserModal() {
        userModal.classList.add('hidden');
        editTarget = null;
    }

    function showModalError(msg) {
        modalError.textContent = msg;
        modalError.classList.toggle('hidden', !msg);
    }

    let deleteTarget = null;

    function openDeleteModal(uname) {
        deleteTarget = uname;
        deleteUsername.textContent = uname;
        deleteModal.classList.remove('hidden');
    }

    function closeDeleteModal() {
        deleteModal.classList.add('hidden');
        deleteTarget = null;
    }

    document.getElementById('modal-cancel').addEventListener('click', closeUserModal);
    document.getElementById('delete-cancel').addEventListener('click', closeDeleteModal);

    userModal.addEventListener('click',   (e) => { if (e.target === userModal)   closeUserModal(); });
    deleteModal.addEventListener('click', (e) => { if (e.target === deleteModal) closeDeleteModal(); });

    document.getElementById('toggle-modal-pw').addEventListener('click', () => {
        const isText = modalPassword.type === 'text';
        modalPassword.type = isText ? 'password' : 'text';
    });

    document.getElementById('modal-confirm').addEventListener('click', async () => {
        const uname    = modalUsername.value.trim();
        const password = modalPassword.value;
        const roleVal  = modalRole.value;

        if (!editTarget) {
            if (!uname)    { showModalError('Username-ul este obligatoriu'); return; }
            if (!password) { showModalError('Parola este obligatorie'); return; }
            if (password.length < 6) { showModalError('Parola trebuie să aibă cel puțin 6 caractere'); return; }
            try {
                await api('POST', '/api/users', { username: uname, password, role: roleVal });
                toast(`Utilizatorul <strong>${esc(uname)}</strong> a fost creat`, 'success');
                closeUserModal();
                await load();
            } catch (err) {
                showModalError(err.message);
            }
        } else {
            const body = { role: roleVal };
            if (password) {
                if (password.length < 6) { showModalError('Parola trebuie să aibă cel puțin 6 caractere'); return; }
                body.password = password;
            }
            try {
                await api('PUT', `/api/users/${encodeURIComponent(editTarget)}`, body);
                toast(`Utilizatorul <strong>${esc(editTarget)}</strong> a fost actualizat`, 'success');
                closeUserModal();
                await load();
            } catch (err) {
                showModalError(err.message);
            }
        }
    });

    [modalUsername, modalPassword].forEach(el => {
        el.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') document.getElementById('modal-confirm').click();
        });
    });

    document.getElementById('delete-confirm').addEventListener('click', async () => {
        if (!deleteTarget) return;
        try {
            await api('DELETE', `/api/users/${encodeURIComponent(deleteTarget)}`);
            toast(`Utilizatorul <strong>${esc(deleteTarget)}</strong> a fost șters`, 'success');
            closeDeleteModal();
            await load();
        } catch (err) {
            toast(`Eroare: ${err.message}`, 'error');
            closeDeleteModal();
        }
    });

    tbody.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-action]');
        if (!btn) return;
        const action = btn.dataset.action;
        const uname  = btn.dataset.username;
        if (action === 'edit')   openEditModal(uname);
        if (action === 'delete') openDeleteModal(uname);
    });

    btnAddUser.addEventListener('click', openCreateModal);

    btnReload.addEventListener('click', async () => {
        btnReload.classList.add('spinning');
        await load();
        btnReload.classList.remove('spinning');
        toast('Date reîncărcate', 'info');
    });

    btnLogout.addEventListener('click', () => {
        localStorage.clear();
        window.location.href = '/';
    });

    load();
})();
