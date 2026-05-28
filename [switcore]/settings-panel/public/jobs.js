(function () {
    'use strict';

    const token    = localStorage.getItem('sc_token');
    const username = localStorage.getItem('sc_username') || 'Admin';
    const role     = localStorage.getItem('sc_role') || 'staff';

    if (!token) { window.location.href = '/'; return; }

    const ROLE_LABELS = { superadmin: 'Super Admin', admin: 'Admin', moderator: 'Moderator', staff: 'Staff' };
    document.getElementById('user-name').textContent       = username;
    document.getElementById('user-avatar').textContent     = username.charAt(0).toUpperCase();
    document.getElementById('user-role-label').textContent = ROLE_LABELS[role] || 'Staff';

    const jobSelect    = document.getElementById('job-select');
    const btnReload    = document.getElementById('btn-reload');
    const btnLogout    = document.getElementById('btn-logout');
    const btnAssign    = document.getElementById('btn-assign');
    const tbody        = document.getElementById('roster-tbody');
    const emptyState   = document.getElementById('empty-state');
    const demoBadge    = document.getElementById('demo-badge');
    const statTotal    = document.getElementById('stat-total');
    const statOnDuty   = document.getElementById('stat-on-duty');
    const statJobType  = document.getElementById('stat-job-type');

    const assignModal  = document.getElementById('assign-modal');
    const assignJobSel = document.getElementById('assign-job-select');
    const assignGrSel  = document.getElementById('assign-grade-select');
    const assignCharId = document.getElementById('assign-char-id');
    const assignError  = document.getElementById('assign-error');
    const assignCancel = document.getElementById('assign-cancel');
    const assignConfirm= document.getElementById('assign-confirm');

    const gradeModal   = document.getElementById('grade-modal');
    const gradeMember  = document.getElementById('grade-member-name');
    const gradeSelect  = document.getElementById('grade-select');
    const gradeError   = document.getElementById('grade-error');
    const gradeCancel  = document.getElementById('grade-cancel');
    const gradeConfirm = document.getElementById('grade-confirm');

    let allJobs   = [];
    let allGrades = {};   // jobName -> [{ grade, label }]
    let roster    = [];
    let selectedJob = null;
    let gradeTarget = null;  // { characterId, name }

    async function api(method, path, body) {
        const opts = {
            method,
            headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' }
        };
        if (body !== undefined) opts.body = JSON.stringify(body);
        const res = await fetch(path, opts);
        if (res.status === 401) { localStorage.clear(); window.location.href = '/'; return null; }
        return res.ok ? res.json() : null;
    }

    function toast(msg, type = 'success') {
        const container = document.getElementById('toast-container');
        const t = document.createElement('div');
        t.className = 'toast toast-' + type;
        t.textContent = msg;
        container.appendChild(t);
        setTimeout(() => t.remove(), 3500);
    }

    async function loadJobs() {
        allJobs = await api('GET', '/api/jobs') || [];
        if (allJobs.dummy) demoBadge.classList.remove('hidden');

        jobSelect.innerHTML = '<option value="">- Selectează jobul -</option>';
        assignJobSel.innerHTML = '';

        const TYPE_LABELS = { whitelisted: 'Legal', self_serve: 'Liber', illegal: 'Ilegal' };

        allJobs.forEach(j => {
            const opt = document.createElement('option');
            opt.value = j.name;
            opt.textContent = j.label + ' (' + (TYPE_LABELS[j.type] || j.type) + ')';
            jobSelect.appendChild(opt.cloneNode(true));
            assignJobSel.appendChild(opt);
        });

        btnAssign.disabled = false;
    }

    async function loadGrades(jobName) {
        if (allGrades[jobName]) return allGrades[jobName];
        const grades = await api('GET', '/api/jobs/' + jobName + '/grades') || [];
        allGrades[jobName] = grades;
        return grades;
    }

    async function loadRoster(jobName) {
        if (!jobName) return;
        roster = await api('GET', '/api/jobs/' + jobName + '/roster') || [];
        const grades = await loadGrades(jobName);
        renderRoster(roster, grades);
    }

    function renderRoster(members, grades) {
        const onDuty = members.filter(m => m.is_on_duty).length;
        statTotal.textContent   = members.length;
        statOnDuty.textContent  = onDuty;

        const job = allJobs.find(j => j.name === selectedJob);
        const TYPE_LABELS = { whitelisted: 'Legal', self_serve: 'Liber', illegal: 'Ilegal' };
        statJobType.textContent = job ? (TYPE_LABELS[job.type] || job.type) : '-';

        tbody.innerHTML = '';
        emptyState.classList.toggle('hidden', members.length > 0);

        if (members.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5"><div class="loading-state">Niciun membru</div></td></tr>';
            return;
        }

        members.forEach(m => {
            const gradeObj = grades.find(g => g.grade === m.grade);
            const gradeLabel = (gradeObj && gradeObj.label) || ('Grade ' + m.grade);
            const hiredAt = m.hired_at ? new Date(m.hired_at).toLocaleDateString('ro-RO') : '-';

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>
                    <span class="status-dot ${m.is_on_duty ? 'status-dot--online' : ''}"></span>
                </td>
                <td><strong>${esc(m.first_name + ' ' + m.last_name)}</strong><br>
                    <small style="color:var(--text-3)">ID: ${m.id}</small>
                </td>
                <td>${esc(gradeLabel)} <small style="color:var(--text-3)">(${m.grade})</small></td>
                <td style="color:var(--text-3); font-size:.85rem">${hiredAt}</td>
                <td>
                    <button class="btn-action" data-char-id="${m.id}" data-name="${esc(m.first_name + ' ' + m.last_name)}" data-action="grade">
                        Schimbă Grad
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });

        tbody.querySelectorAll('[data-action="grade"]').forEach(btn => {
            btn.addEventListener('click', () => openGradeModal(
                parseInt(btn.dataset.charId),
                btn.dataset.name,
                grades
            ));
        });
    }

    function openGradeModal(characterId, name, grades) {
        gradeTarget = { characterId, name };
        gradeMember.textContent = name;
        gradeSelect.innerHTML = '';
        grades.forEach(g => {
            const opt = document.createElement('option');
            opt.value       = g.grade;
            opt.textContent = g.grade + ' - ' + g.label;
            gradeSelect.appendChild(opt);
        });
        const current = roster.find(m => m.id === characterId);
        if (current) gradeSelect.value = current.grade;
        gradeError.classList.add('hidden');
        gradeModal.classList.remove('hidden');
    }

    gradeCancel.addEventListener('click', () => gradeModal.classList.add('hidden'));
    gradeConfirm.addEventListener('click', async () => {
        if (!gradeTarget) return;
        const newGrade = parseInt(gradeSelect.value);
        gradeConfirm.disabled = true;
        const result = await api('POST', '/api/jobs/grade', {
            characterId: gradeTarget.characterId, grade: newGrade
        });
        gradeConfirm.disabled = false;
        if (result && result.success) {
            gradeModal.classList.add('hidden');
            toast('Grad actualizat cu succes.');
            loadRoster(selectedJob);
        } else {
            gradeError.textContent = 'Eroare la actualizare.';
            gradeError.classList.remove('hidden');
        }
    });

    btnAssign.addEventListener('click', () => {
        assignCharId.value = '';
        assignError.classList.add('hidden');
        if (assignJobSel.value) updateAssignGrades(assignJobSel.value);
        assignModal.classList.remove('hidden');
    });

    assignJobSel.addEventListener('change', () => updateAssignGrades(assignJobSel.value));

    async function updateAssignGrades(jobName) {
        const grades = await loadGrades(jobName);
        assignGrSel.innerHTML = '';
        grades.forEach(g => {
            const opt = document.createElement('option');
            opt.value       = g.grade;
            opt.textContent = g.grade + ' - ' + g.label;
            assignGrSel.appendChild(opt);
        });
    }

    assignCancel.addEventListener('click', () => assignModal.classList.add('hidden'));
    assignConfirm.addEventListener('click', async () => {
        const characterId = parseInt(assignCharId.value);
        const jobName     = assignJobSel.value;
        const grade       = parseInt(assignGrSel.value) || 0;
        if (!characterId || !jobName) {
            assignError.textContent = 'Completează toate câmpurile.';
            assignError.classList.remove('hidden');
            return;
        }
        assignConfirm.disabled = true;
        const result = await api('POST', '/api/jobs/assign', { characterId, jobName, grade });
        assignConfirm.disabled = false;
        if (result && result.success) {
            assignModal.classList.add('hidden');
            toast('Job atribuit cu succes.');
            if (selectedJob === jobName) loadRoster(selectedJob);
        } else {
            assignError.textContent = 'Eroare la atribuire.';
            assignError.classList.remove('hidden');
        }
    });

    jobSelect.addEventListener('change', () => {
        selectedJob = jobSelect.value || null;
        if (selectedJob) {
            loadRoster(selectedJob);
        } else {
            roster = [];
            tbody.innerHTML = '<tr><td colspan="5"><div class="loading-state">Selectează un job pentru a vedea membrii</div></td></tr>';
            statTotal.textContent  = '-';
            statOnDuty.textContent = '-';
            statJobType.textContent= '-';
        }
    });

    btnReload.addEventListener('click', () => {
        if (selectedJob) loadRoster(selectedJob);
        else loadJobs();
    });

    btnLogout.addEventListener('click', () => {
        localStorage.clear();
        window.location.href = '/';
    });

    [assignModal, gradeModal].forEach(modal => {
        modal.addEventListener('click', e => {
            if (e.target === modal) modal.classList.add('hidden');
        });
    });

    function esc(str) {
        return String(str || '')
            .replace(/&/g, '&amp;').replace(/</g, '&lt;')
            .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    loadJobs();

})();
