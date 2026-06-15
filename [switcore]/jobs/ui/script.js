
const app         = document.getElementById('app');
const headerTitle = document.getElementById('headerTitle');
const closeBtn    = document.getElementById('closeBtn');
const tabs        = document.querySelectorAll('.tab');
const panes       = document.querySelectorAll('.tab-pane');

const isFiveM = typeof window.invokeNative !== 'undefined';

let state = {
    job:       null,
    grades:    [],
    coworkers: [],
    roster:    [],
    allJobs:   [],
    canManage: false,
};

function postNUI(action, data = {}) {
    if (isFiveM) {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify(data),
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
        document.getElementById('tab-' + target).classList.add('active');

        if (target === 'roster' && state.roster.length === 0) {
            refreshRoster();
        }
    });
});

closeBtn.addEventListener('click', close);
document.addEventListener('keydown', e => { if (e.key === 'Escape') close(); });

function close() {
    app.classList.add('hidden');
    postNUI('close');
}

function open(data) {
    state.job       = data.job       || null;
    state.grades    = data.grades    || [];
    state.coworkers = data.coworkers || [];
    state.allJobs   = data.allJobs   || [];
    state.canManage = data.job && data.job.canManage;
    state.roster    = [];

    renderMyJob();
    renderCoworkers();
    renderRoster();
    updateRosterTab();

    // Reset to first tab
    tabs.forEach(t => t.classList.remove('active'));
    panes.forEach(p => p.classList.remove('active'));
    tabs[0].classList.add('active');
    document.getElementById('tab-myJob').classList.add('active');

    headerTitle.textContent = (data.job && data.job.label) ? data.job.label : SwI18n.t('jobs.ui.header_title');
    app.classList.remove('hidden');
}

function updateRosterTab() {
    const tab = document.getElementById('tabRoster');
    if (state.canManage) {
        tab.style.display = '';
    } else {
        tab.style.display = 'none';
    }
}

function renderMyJob() {
    const job = state.job;
    if (!job) return;

    document.getElementById('jobLabel').textContent   = esc(job.label   || '-');
    document.getElementById('gradeLabel').textContent = esc(job.gradeLabel || '-');
    document.getElementById('salaryLabel').textContent = job.salary > 0 ? SwI18n.t('jobs.ui.salary_per_shift', fmt(job.salary), (job.currencySymbol || '$')) : SwI18n.t('jobs.ui.salary_unpaid');

    const typeBadge = document.getElementById('typeBadge');
    const typeMap   = { whitelisted: SwI18n.t('jobs.ui.type_legal'), self_serve: SwI18n.t('jobs.ui.type_free'), illegal: SwI18n.t('jobs.ui.type_illegal') };
    typeBadge.textContent  = typeMap[job.type] || job.type;
    typeBadge.className    = 'type-badge type-' + (job.type || 'self_serve');

    // Duty section
    const dutySection = document.getElementById('dutySection');
    if (job.type === 'illegal' || job.name === 'unemployed') {
        dutySection.style.display = 'none';
    } else {
        dutySection.style.display = '';
        updateDutyButton(job.isOnDuty);
    }

    // Permissions
    renderPermissions(job.permissions || []);
}

function updateDutyButton(isOnDuty) {
    const btn    = document.getElementById('dutyBtn');
    const status = document.getElementById('dutyStatus');
    if (isOnDuty) {
        btn.className   = 'duty-btn on';
        btn.innerHTML   = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>
        </svg> ${esc(SwI18n.t('jobs.ui.clock_out'))}`;
        status.textContent = SwI18n.t('jobs.ui.duty_on');
        status.style.color = 'var(--green)';
    } else {
        btn.className   = 'duty-btn off';
        btn.innerHTML   = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>
        </svg> ${esc(SwI18n.t('jobs.ui.clock_in'))}`;
        status.textContent = SwI18n.t('jobs.ui.duty_inactive');
        status.style.color = '';
    }
}

function renderPermissions(perms) {
    const list = document.getElementById('permsList');
    list.innerHTML = '';
    if (!perms || perms.length === 0) {
        list.innerHTML = `<span class="empty-inline">${esc(SwI18n.t('jobs.ui.perms_empty'))}</span>`;
        return;
    }
    perms.forEach(p => {
        const tag = document.createElement('span');
        tag.className   = 'perm-tag';
        tag.textContent = esc(p);
        list.appendChild(tag);
    });
}

function renderCoworkers() {
    const list  = document.getElementById('coworkersList');
    const items = state.coworkers || [];
    list.innerHTML = '';
    if (items.length === 0) {
        list.innerHTML = `<div class="empty-state-sm">${esc(SwI18n.t('jobs.ui.coworkers_empty'))}</div>`;
        return;
    }
    items.forEach(c => {
        const el = document.createElement('div');
        el.className = 'coworker-item';
        el.innerHTML = `
            <span class="coworker-name">${esc(c.first_name + ' ' + c.last_name)}</span>
            <span class="coworker-grade">${esc(c.grade_label || '')}</span>
        `;
        list.appendChild(el);
    });
}

function toggleDuty() {
    postNUI('clockIn');
}

function refreshRoster() {
    const jobName = state.job && state.job.name;
    if (jobName) {
        postNUI('refreshRoster', { jobName });
    }
}

function renderRoster() {
    const list  = document.getElementById('rosterList');
    const count = document.getElementById('rosterCount');
    const badge = document.getElementById('rosterBadge');
    const items = state.roster || [];

    count.textContent = SwI18n.t('jobs.ui.roster_count', items.length);
    badge.textContent = items.length;
    badge.className   = 'badge' + (items.length === 0 ? ' zero' : '');

    list.innerHTML = '';

    if (items.length === 0) {
        list.innerHTML = `<div class="empty-state">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="9" cy="7" r="4"/>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
            </svg>
            <p>${esc(SwI18n.t('jobs.ui.roster_hint'))}</p>
        </div>`;
        return;
    }

    const myGrade = state.job ? (state.job.grade || 0) : 0;

    items.forEach(member => {
        const el = document.createElement('div');
        el.className = 'roster-item';

        const canPromote = member.grade < myGrade - 1 && member.grade < (state.grades.length - 2);
        const canDemote  = member.grade > 0 && member.grade < myGrade;
        const isMe       = state.job && member.id === state.job.characterId;

        el.innerHTML = `
            <div class="roster-item-top">
                <span class="roster-name">${esc(member.first_name + ' ' + member.last_name)}</span>
                <div class="roster-meta">
                    <span class="duty-dot ${member.is_on_duty ? 'on' : ''}"></span>
                    <span class="grade-chip">${esc(member.grade_label || SwI18n.t('jobs.ui.grade_fallback', member.grade))}</span>
                </div>
            </div>
            ${!isMe ? `<div class="roster-actions">
                ${canPromote ? `<button class="btn btn-promote btn-sm" data-id="${member.id}" data-grade="${member.grade + 1}">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="18 15 12 9 6 15"/></svg>
                    ${esc(SwI18n.t('jobs.ui.promote'))}
                </button>` : ''}
                ${canDemote ? `<button class="btn btn-demote btn-sm" data-id="${member.id}" data-grade="${member.grade - 1}">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                    ${esc(SwI18n.t('jobs.ui.demote'))}
                </button>` : ''}
            </div>` : ''}
        `;

        el.querySelectorAll('[data-id]').forEach(btn => {
            btn.addEventListener('click', () => {
                btn.disabled = true;
                postNUI('manageGrade', {
                    characterId: parseInt(btn.dataset.id),
                    grade:       parseInt(btn.dataset.grade),
                });
                setTimeout(() => { btn.disabled = false; }, 1500);
            });
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
    return (parseFloat(n) || 0).toLocaleString('ro-RO', { maximumFractionDigits: 0 });
}

window.addEventListener('message', e => {
    const msg = e.data;
    if (!msg || !msg.action) return;

    switch (msg.action) {
        case 'open':
            open(msg);
            break;

        case 'jobUpdated':
            state.job       = msg.job       || state.job;
            state.coworkers = msg.coworkers || state.coworkers;
            state.canManage = state.job && state.job.canManage;
            renderMyJob();
            renderCoworkers();
            updateRosterTab();
            headerTitle.textContent = (state.job && state.job.label) || SwI18n.t('jobs.ui.header_title');
            break;

        case 'rosterData':
            state.roster = msg.roster || [];
            renderRoster();
            break;
    }
});

// Re-randare la schimbarea limbii (data-i18n e aplicat automat de SwI18n.apply)
document.addEventListener('sw:i18n', () => {
    if (state.job) {
        renderMyJob();
        renderCoworkers();
        renderRoster();
        headerTitle.textContent = (state.job && state.job.label) || SwI18n.t('jobs.ui.header_title');
    }
});

if (!isFiveM) {
    document.body.style.background = '#0a0e14';
    open({
        job: {
            name: 'police', label: 'Poliție', type: 'whitelisted',
            grade: 3, gradeLabel: 'Căpitan', salary: 5000,
            canManage: true, isOnDuty: true,
            permissions: ['arrest', 'armory', 'manage'],
        },
        grades: [
            { grade: 0, label: 'Ofițer',     can_manage: false },
            { grade: 1, label: 'Sergent',     can_manage: false },
            { grade: 2, label: 'Locotenent',  can_manage: false },
            { grade: 3, label: 'Căpitan',     can_manage: true  },
        ],
        coworkers: [
            { id: 2, first_name: 'Ion',   last_name: 'Popescu', grade_label: 'Sergent' },
            { id: 3, first_name: 'Maria', last_name: 'Ionescu', grade_label: 'Ofițer' },
        ],
        allJobs: [],
    });

    // Demo roster
    setTimeout(() => {
        window.dispatchEvent(new MessageEvent('message', { data: {
            action: 'rosterData',
            roster: [
                { id: 1, first_name: 'Alex',  last_name: 'Popescu', grade: 3, grade_label: 'Căpitan',    is_on_duty: true,  can_manage: true  },
                { id: 2, first_name: 'Ion',   last_name: 'Ionescu', grade: 2, grade_label: 'Locotenent', is_on_duty: false, can_manage: false },
                { id: 3, first_name: 'Maria', last_name: 'Dumitrescu', grade: 1, grade_label: 'Sergent', is_on_duty: true,  can_manage: false },
                { id: 4, first_name: 'Elena', last_name: 'Constantin',  grade: 0, grade_label: 'Ofițer', is_on_duty: false, can_manage: false },
            ],
            grades: [],
        }}));
    }, 300);
}
