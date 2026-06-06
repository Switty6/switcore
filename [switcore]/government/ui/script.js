'use strict';

const state = {
    data: null,
    selectedPartyId: null,
    selectedElectionId: null,
};

function nuiFetch(action, data = {}) {
    return fetch(`https://government/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

// Un tabel Lua gol se serializeaza ca {} (obiect), nu ca [] (lista). Fortam
// campurile-lista sa fie mereu array-uri ca render-ul (.slice/.map/.length) sa nu crape.
function asArray(v) {
    return Array.isArray(v) ? v : [];
}

function normalizeData(d) {
    if (!d || typeof d !== 'object') return d;
    ['proposals', 'laws', 'budgetLog', 'parties', 'elections', 'closedElections', 'officials'].forEach(k => {
        d[k] = asArray(d[k]);
    });
    d.elections.forEach(el => { if (el) el.candidates = asArray(el.candidates); });
    return d;
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'open') {
        state.data = normalizeData(msg.data);
        app.classList.remove('hidden');
        renderAll();
    } else if (msg.action === 'update') {
        state.data = normalizeData(msg.data);
        renderAll();
    } else if (msg.action === 'close') {
        app.classList.add('hidden');
    }
});

function closePanel() {
    app.classList.add('hidden');
    nuiFetch('close');
}

const app       = document.getElementById('app');
const navBtns   = document.querySelectorAll('.nav-btn');
const tabPanels = document.querySelectorAll('.tab-panel');

navBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        navBtns.forEach(b => b.classList.remove('active'));
        tabPanels.forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        const panel = document.getElementById('panel-' + btn.dataset.tab);
        if (panel) panel.classList.add('active');
    });
});

document.getElementById('btnClose').addEventListener('click', closePanel);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closePanel();
});

document.querySelectorAll('.sub-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const parent = btn.closest('.tab-panel');
        parent.querySelectorAll('.sub-btn').forEach(b => b.classList.remove('active'));
        parent.querySelectorAll('.sub-panel').forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        const panel = document.getElementById('sub-' + btn.dataset.sub);
        if (panel) panel.classList.add('active');
    });
});

function fmt(amount) {
    return new Intl.NumberFormat('ro-RO').format(Math.floor(amount || 0)) + ' RON';
}

function fmtDate(iso) {
    if (!iso) return '-';
    const d = new Date(iso);
    return d.toLocaleDateString('ro-RO') + ' ' + d.toLocaleTimeString('ro-RO', { hour: '2-digit', minute: '2-digit' });
}

function catBadge(cat) {
    const map = {
        'Penal': 'badge-danger', 'Rutier': 'badge-warn', 'Civil': 'badge-accent',
        'Fiscal': 'badge-success', 'Ordine Publica': 'badge-warn', 'Muncii': 'badge-gray',
    };
    return `<span class="badge ${map[cat] || 'badge-gray'}">${cat}</span>`;
}

function renderAll() {
    if (!state.data) return;
    const d = state.data;

    renderHeader(d);
    renderDashboard(d);
    renderLaws(d);
    renderBudget(d);
    renderParties(d);
    renderElections(d);
    applyPerms(d.perms);
    if (window.lucide) lucide.createIcons();
}

function renderHeader(d) {
    document.getElementById('hdr-balance').textContent   = 'Trezorerie: ' + fmt(d.balance);
    document.getElementById('hdr-laws').textContent      = 'Legi: ' + (d.laws || []).length;
    document.getElementById('hdr-officials').textContent = 'Funcționari: ' + (d.officials || []).length;
}

function renderDashboard(d) {
    document.getElementById('dash-balance').textContent   = fmt(d.balance);
    document.getElementById('dash-laws').textContent      = (d.laws || []).length;
    document.getElementById('dash-proposals').textContent = (d.proposals || []).length;
    document.getElementById('dash-officials').textContent = (d.officials || []).length;

    const offList = document.getElementById('officials-list');
    if ((d.officials || []).length === 0) {
        offList.innerHTML = '<span style="color:var(--text-dim);font-size:11px">Niciun funcționar online</span>';
    } else {
        offList.innerHTML = d.officials.map(o =>
            `<span class="official-chip">${o.name}</span>`
        ).join('');
    }

    const recentLog = document.getElementById('dash-recent-tx');
    const recent = (d.budgetLog || []).slice(0, 5);
    if (recent.length === 0) {
        recentLog.innerHTML = '<span style="color:var(--text-dim);font-size:11px">Nicio tranzacție</span>';
    } else {
        recentLog.innerHTML = recent.map(tx => {
            const sign = tx.type === 'income' ? '+' : '-';
            const cls  = tx.type === 'income' ? 'tx-income' : 'tx-expense';
            return `<div class="recent-tx-item">
                <span class="${cls}">${sign}${fmt(tx.amount)}</span>
                <span class="tx-desc">${tx.description}</span>
                <span class="tx-date">${fmtDate(tx.created_at)}</span>
            </div>`;
        }).join('');
    }
}

const btnProposeLaw  = document.getElementById('btnProposeLaw');
const proposeForm    = document.getElementById('propose-form');
const btnCancelLaw   = document.getElementById('btnCancelLaw');
const btnSubmitLaw   = document.getElementById('btnSubmitLaw');
const proposeToolbar = document.getElementById('propose-toolbar');

btnProposeLaw.addEventListener('click', () => {
    proposeForm.classList.remove('hidden');
    proposeToolbar.classList.add('hidden');
});
btnCancelLaw.addEventListener('click', () => {
    proposeForm.classList.add('hidden');
    proposeToolbar.classList.remove('hidden');
    clearProposeForm();
});
btnSubmitLaw.addEventListener('click', () => {
    const data = {
        title:           document.getElementById('law-title').value.trim(),
        category:        document.getElementById('law-category').value,
        description:     document.getElementById('law-desc').value.trim(),
        penalty:         document.getElementById('law-penalty').value.trim(),
        fine_amount:     parseInt(document.getElementById('law-fine').value) || 0,
        duration_minutes: parseInt(document.getElementById('law-duration').value) || 1440,
    };
    if (!data.title || !data.category || !data.description) return;
    nuiFetch('proposeLaw', data);
    proposeForm.classList.add('hidden');
    proposeToolbar.classList.remove('hidden');
    clearProposeForm();
});

function clearProposeForm() {
    ['law-title','law-desc','law-penalty','law-fine'].forEach(id => {
        document.getElementById(id).value = '';
    });
    document.getElementById('law-category').value = '';
}

function renderLaws(d) {
    renderProposals(d);
    renderActiveLaws(d);
}

function renderProposals(d) {
    const list     = document.getElementById('proposals-list');
    const proposals = d.proposals || [];
    const quorum    = d.quorum || 3;
    const canVote   = d.perms && d.perms.laws;

    if (proposals.length === 0) {
        list.innerHTML = '<div class="empty-state">Nicio propunere în așteptare</div>';
        return;
    }

    list.innerHTML = proposals.map(p => {
        const yesVotes = p.yes_votes || 0;
        const noVotes  = p.no_votes  || 0;
        const tally = `<span class="vote-tally"><span class="vote-yes">${yesVotes}</span> Da · <span class="vote-no">${noVotes}</span> Nu · cvorum ${quorum}</span>`;
        const footer = canVote ? `
            <div class="proposal-vote">
                <button class="vote-btn vote-btn-yes" data-id="${p.id}" data-vote="yes">Da</button>
                <button class="vote-btn vote-btn-no"  data-id="${p.id}" data-vote="no">Nu</button>
            </div>
            ${tally}
        ` : tally;

        return `<div class="proposal-card">
            <div class="proposal-header">
                <span class="proposal-title">${p.title}</span>
                ${catBadge(p.category)}
            </div>
            <div class="proposal-sub">
                <span>Propus de ${p.proposed_by_name || '-'}</span>
                <span>${fmtDate(p.created_at)}</span>
                ${p.voting_ends_at ? `<span>Termen vot: ${fmtDate(p.voting_ends_at)}</span>` : ''}
            </div>
            <div class="proposal-desc">${p.description}</div>
            ${(p.penalty || p.fine_amount) ? `<div class="proposal-penalty">${p.penalty || ''}${p.fine_amount ? (p.penalty ? ' · ' : '') + 'Amendă: ' + fmt(p.fine_amount) : ''}</div>` : ''}
            <div class="proposal-footer">${footer}</div>
        </div>`;
    }).join('');

    list.querySelectorAll('.vote-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            nuiFetch('voteLaw', { proposalId: parseInt(btn.dataset.id), vote: btn.dataset.vote });
        });
    });
}

function renderActiveLaws(d) {
    const list  = document.getElementById('laws-list');
    const laws  = d.laws || [];
    const canRepeal = d.perms && d.perms.laws;

    if (laws.length === 0) {
        list.innerHTML = '<div class="empty-state">Nicio lege activă</div>';
        return;
    }

    list.innerHTML = laws.map(l => `
        <div class="law-card">
            <div class="law-header">
                <span class="law-title">${l.title}</span>
                ${catBadge(l.category)}
                <span class="badge badge-success">Activă</span>
            </div>
            <div class="law-meta">Adoptată de ${l.created_by_name || '-'} · ${fmtDate(l.created_at)}</div>
            <div class="law-desc">${l.description}</div>
            ${l.penalty ? `<div class="law-penalty"><i data-lucide="alert-triangle"></i> ${l.penalty}${l.fine_amount ? ' · Amendă: ' + fmt(l.fine_amount) : ''}</div>` : ''}
            ${canRepeal ? `<div class="law-actions"><button class="btn-danger repeal-btn" data-id="${l.id}">Abrogă</button></div>` : ''}
        </div>
    `).join('');

    list.querySelectorAll('.repeal-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            nuiFetch('repealLaw', { lawId: parseInt(btn.dataset.id) });
        });
    });
}

const btnAddTx    = document.getElementById('btnAddTx');
const txForm      = document.getElementById('tx-form');
const btnCancelTx = document.getElementById('btnCancelTx');
const btnSubmitTx = document.getElementById('btnSubmitTx');

btnAddTx.addEventListener('click', () => txForm.classList.remove('hidden'));
btnCancelTx.addEventListener('click', () => {
    txForm.classList.add('hidden');
    document.getElementById('tx-amount').value = '';
    document.getElementById('tx-desc').value   = '';
});
btnSubmitTx.addEventListener('click', () => {
    const data = {
        type:        document.getElementById('tx-type').value,
        category:    document.getElementById('tx-category').value,
        amount:      parseInt(document.getElementById('tx-amount').value) || 0,
        description: document.getElementById('tx-desc').value.trim(),
    };
    if (!data.description || data.amount < 1) return;
    nuiFetch('addTransaction', data);
    txForm.classList.add('hidden');
    document.getElementById('tx-amount').value = '';
    document.getElementById('tx-desc').value   = '';
});

function renderBudget(d) {
    document.getElementById('budget-balance').textContent = fmt(d.balance);

    const log = document.getElementById('budget-log');
    const txs = d.budgetLog || [];

    if (txs.length === 0) {
        log.innerHTML = '<div class="empty-state">Nicio tranzacție înregistrată</div>';
        return;
    }

    log.innerHTML = txs.map(tx => {
        const sign = tx.type === 'income' ? '+' : '-';
        const cls  = tx.type === 'income' ? 'tx-income' : 'tx-expense';
        const desc = tx.description || (tx.type === 'income' ? 'Venit' : 'Cheltuială');
        return `<div class="tx-row tx-row-${tx.type === 'income' ? 'income' : 'expense'}">
            <div class="tx-main">
                <span class="badge badge-gray">${tx.category || 'Altele'}</span>
                <span class="tx-desc-full">${desc}</span>
            </div>
            <div class="tx-side">
                <span class="tx-amount ${cls}">${sign}${fmt(tx.amount)}</span>
                <span class="tx-meta">${tx.created_by_name || 'Auto'} · ${fmtDate(tx.created_at)}</span>
            </div>
        </div>`;
    }).join('');
}

const btnCreateParty  = document.getElementById('btnCreateParty');
const btnLeaveParty   = document.getElementById('btnLeaveParty');
const createPartyForm = document.getElementById('create-party-form');
const btnCancelParty  = document.getElementById('btnCancelParty');
const btnSubmitParty  = document.getElementById('btnSubmitParty');

btnCreateParty.addEventListener('click', () => createPartyForm.classList.remove('hidden'));
btnCancelParty.addEventListener('click', () => {
    createPartyForm.classList.add('hidden');
    document.getElementById('party-name').value  = '';
    document.getElementById('party-color').value = '#00b4ff';
});
btnSubmitParty.addEventListener('click', () => {
    const name  = document.getElementById('party-name').value.trim();
    const color = document.getElementById('party-color').value;
    if (!name) return;
    nuiFetch('createParty', { name, color });
    createPartyForm.classList.add('hidden');
    document.getElementById('party-name').value = '';
});
btnLeaveParty.addEventListener('click', () => {
    nuiFetch('leaveParty');
});

function renderParties(d) {
    const parties   = d.parties || [];
    const partyList = document.getElementById('parties-list');

    if (parties.length === 0) {
        partyList.innerHTML = '<div class="empty-state">Niciun partid înființat</div>';
    } else {
        partyList.innerHTML = parties.map(p => `
            <div class="party-item ${state.selectedPartyId === p.id ? 'selected' : ''}" data-id="${p.id}">
                <span class="party-dot" style="background:${p.color}"></span>
                <span class="party-name">${p.name}</span>
                <span class="party-members">${p.member_count} m.</span>
            </div>
        `).join('');

        partyList.querySelectorAll('.party-item').forEach(item => {
            item.addEventListener('click', () => {
                state.selectedPartyId = parseInt(item.dataset.id);
                renderParties(d);
            });
        });
    }

    const detail = document.getElementById('party-detail');
    const party  = parties.find(p => p.id === state.selectedPartyId);

    if (!party) {
        detail.innerHTML = '<div class="empty-state">Selectează un partid</div>';
        return;
    }

    const manifesto = party.manifesto || '<em style="color:var(--text-dim)">Niciun manifest înregistrat.</em>';

    detail.innerHTML = `
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px">
            <span class="party-dot" style="background:${party.color};width:14px;height:14px"></span>
            <span class="party-detail-name">${party.name}</span>
        </div>
        <div class="party-detail-meta">Lider: ${party.leader_name || '-'} · ${party.member_count} membri</div>
        <div class="section-title">Manifest</div>
        <div class="party-manifesto">${manifesto}</div>
        <div class="section-title">Acțiuni</div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
            <button class="btn-primary" id="btn-join-party" data-id="${party.id}">Alătură-te</button>
            <button class="btn-secondary" id="btn-edit-manifesto" data-id="${party.id}">Editează manifest</button>
        </div>
        <div id="manifesto-edit-form" class="hidden" style="margin-top:10px">
            <textarea id="manifesto-text" rows="5" placeholder="Manifestul partidului..." maxlength="5000">${party.manifesto || ''}</textarea>
            <div style="display:flex;gap:6px;margin-top:6px;justify-content:flex-end">
                <button class="btn-secondary" id="btn-cancel-manifesto">Anulează</button>
                <button class="btn-primary" id="btn-save-manifesto">Salvează</button>
            </div>
        </div>
    `;

    document.getElementById('btn-join-party').addEventListener('click', () => {
        nuiFetch('joinParty', { partyId: party.id });
    });

    const editForm = document.getElementById('manifesto-edit-form');
    document.getElementById('btn-edit-manifesto').addEventListener('click', () => {
        editForm.classList.remove('hidden');
    });
    document.getElementById('btn-cancel-manifesto').addEventListener('click', () => {
        editForm.classList.add('hidden');
    });
    document.getElementById('btn-save-manifesto').addEventListener('click', () => {
        const text = document.getElementById('manifesto-text').value;
        nuiFetch('updateManifesto', { manifesto: text });
        editForm.classList.add('hidden');
    });
}

const btnStartElection   = document.getElementById('btnStartElection');
const startElectionForm  = document.getElementById('start-election-form');
const btnCancelElection  = document.getElementById('btnCancelElection');
const btnSubmitElection  = document.getElementById('btnSubmitElection');

btnStartElection.addEventListener('click', () => startElectionForm.classList.remove('hidden'));
btnCancelElection.addEventListener('click', () => {
    startElectionForm.classList.add('hidden');
    document.getElementById('el-position').value = '';
    document.getElementById('el-desc').value     = '';
});
btnSubmitElection.addEventListener('click', () => {
    const position    = document.getElementById('el-position').value.trim();
    const description = document.getElementById('el-desc').value.trim();
    if (!position) return;
    nuiFetch('startElection', { position, description });
    startElectionForm.classList.add('hidden');
    document.getElementById('el-position').value = '';
    document.getElementById('el-desc').value     = '';
});

function renderElections(d) {
    const elections     = d.elections || [];
    const closedEl      = d.closedElections || [];
    const canManageEl   = d.perms && d.perms.elections;
    const list          = document.getElementById('elections-list');
    const closedList    = document.getElementById('closed-elections-list');

    if (elections.length === 0) {
        list.innerHTML = '<div class="empty-state">Nicio alegere activă</div>';
    } else {
        list.innerHTML = elections.map(el => {
            const candidates = el.candidates || [];
            const candRows = candidates.length === 0
                ? '<div style="color:var(--text-dim);font-size:11px">Niciun candidat</div>'
                : candidates.map(c => `
                    <div class="candidate-row">
                        <span class="candidate-name">${c.char_name}</span>
                        ${c.party_name ? `<span class="candidate-party" style="color:${c.party_color||'var(--text-dim)'}">● ${c.party_name}</span>` : ''}
                        <span class="candidate-votes">${c.votes} vot${c.votes !== 1 ? 'uri' : ''}</span>
                        <button class="btn-primary vote-cand" style="padding:3px 8px;font-size:11px" data-eid="${el.id}" data-cid="${c.id}">Votează</button>
                    </div>
                `).join('');

            return `<div class="election-card">
                <div class="election-header">
                    <span class="election-position">${el.position}</span>
                    <span class="badge badge-success">Activ</span>
                </div>
                ${el.description ? `<div class="election-desc">${el.description}</div>` : ''}
                <div class="candidates-grid">${candRows}</div>
                <div class="election-actions">
                    <button class="btn-secondary candidate-btn" data-id="${el.id}">Candidează</button>
                    ${canManageEl ? `<button class="btn-danger close-el-btn" data-id="${el.id}">Închide alegerile</button>` : ''}
                </div>
            </div>`;
        }).join('');

        list.querySelectorAll('.vote-cand').forEach(btn => {
            btn.addEventListener('click', () => {
                nuiFetch('voteElection', { electionId: parseInt(btn.dataset.eid), candidateId: parseInt(btn.dataset.cid) });
            });
        });
        list.querySelectorAll('.candidate-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                nuiFetch('candidateElection', { electionId: parseInt(btn.dataset.id) });
            });
        });
        list.querySelectorAll('.close-el-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                nuiFetch('closeElection', { electionId: parseInt(btn.dataset.id) });
            });
        });
    }

    if (closedEl.length === 0) {
        closedList.innerHTML = '<div class="empty-state" style="height:40px">Nicio alegere închisă</div>';
    } else {
        closedList.innerHTML = closedEl.map(el => `
            <div class="closed-election-row">
                <span class="closed-pos">${el.position}</span>
                <span class="closed-winner"><i data-lucide="trophy"></i> ${el.winner_name || '-'}</span>
                <span class="closed-date">${fmtDate(el.ended_at)}</span>
            </div>
        `).join('');
    }
}

(function () {
    const lawsPub      = document.getElementById('laws-public');
    const lawsPubList  = document.getElementById('laws-pub-list');
    const lawsPubCount = document.getElementById('laws-pub-count');
    let allLaws        = [];
    let activeFilter   = '';

    const catColors = {
        'Penal': 'badge-danger', 'Rutier': 'badge-warn', 'Civil': 'badge-accent',
        'Fiscal': 'badge-success', 'Ordine Publica': 'badge-gray', 'Muncii': 'badge-gray',
    };

    function renderPublicLaws() {
        const filtered = activeFilter
            ? allLaws.filter(l => l.category === activeFilter)
            : allLaws;

        lawsPubCount.textContent = filtered.length + ' lege' + (filtered.length !== 1 ? 'i' : '') + ' în vigoare';

        if (filtered.length === 0) {
            lawsPubList.innerHTML = `<div class="laws-pub-empty">
                <span class="laws-pub-empty-icon"><i data-lucide="scale"></i></span>
                <span>Nicio lege în această categorie</span>
            </div>`;
            return;
        }

        lawsPubList.innerHTML = filtered.map((l, i) => `
            <div class="laws-pub-card" data-cat="${l.category}">
                <div class="laws-pub-card-header">
                    <span class="laws-pub-card-title">Art. ${i + 1}. ${l.title}</span>
                    <span class="badge ${catColors[l.category] || 'badge-gray'}">${l.category}</span>
                </div>
                <div class="laws-pub-card-desc">${l.description}</div>
                ${l.penalty || l.fine_amount ? `<span class="laws-pub-card-penalty">
                    <i data-lucide="alert-triangle"></i> ${l.penalty || ''}${l.fine_amount ? (l.penalty ? ' · ' : '') + 'Amendă: ' + new Intl.NumberFormat('ro-RO').format(l.fine_amount) + ' RON' : ''}
                </span>` : ''}
            </div>
        `).join('');
        if (window.lucide) lucide.createIcons();
    }

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (msg.action === 'openLaws') {
            allLaws = msg.laws || [];
            activeFilter = '';
            document.querySelectorAll('.law-filter').forEach(b => b.classList.toggle('active', b.dataset.cat === ''));
            lawsPub.classList.remove('hidden');
            renderPublicLaws();
        } else if (msg.action === 'closeLaws') {
            lawsPub.classList.add('hidden');
        }
    });

    document.getElementById('btnCloseLaws').addEventListener('click', () => {
        lawsPub.classList.add('hidden');
        nuiFetch('closeLaws');
    });

    document.querySelectorAll('.law-filter').forEach(btn => {
        btn.addEventListener('click', () => {
            activeFilter = btn.dataset.cat;
            document.querySelectorAll('.law-filter').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            renderPublicLaws();
        });
    });

    document.querySelector('.laws-pub-overlay').addEventListener('click', () => {
        lawsPub.classList.add('hidden');
        nuiFetch('closeLaws');
    });
})();

// Vot public la alegeri (comanda /vot) - orice cetatean poate vota, fara restul panoului.
(function () {
    const votePub     = document.getElementById('vote-public');
    const votePubList = document.getElementById('vote-pub-list');

    function renderVote(elections) {
        const list = Array.isArray(elections) ? elections : [];
        if (list.length === 0) {
            votePubList.innerHTML = '<div class="empty-state">Nicio alegere activă în acest moment</div>';
            return;
        }
        votePubList.innerHTML = list.map(el => {
            const candidates = Array.isArray(el.candidates) ? el.candidates : [];
            const candRows = candidates.length === 0
                ? '<div style="color:var(--text-dim);font-size:11px">Niciun candidat înscris</div>'
                : candidates.map(c => `
                    <div class="candidate-row">
                        <span class="candidate-name">${c.char_name}</span>
                        ${c.party_name ? `<span class="candidate-party" style="color:${c.party_color || 'var(--text-dim)'}">● ${c.party_name}</span>` : ''}
                        <span class="candidate-votes">${c.votes} vot${c.votes !== 1 ? 'uri' : ''}</span>
                        <button class="btn-primary vote-cand" style="padding:3px 8px;font-size:11px" data-eid="${el.id}" data-cid="${c.id}">Votează</button>
                    </div>
                `).join('');
            return `<div class="election-card">
                <div class="election-header">
                    <span class="election-position">${el.position}</span>
                    <span class="badge badge-success">Activ</span>
                </div>
                ${el.description ? `<div class="election-desc">${el.description}</div>` : ''}
                <div class="candidates-grid">${candRows}</div>
            </div>`;
        }).join('');

        votePubList.querySelectorAll('.vote-cand').forEach(btn => {
            btn.addEventListener('click', () => {
                nuiFetch('voteElection', { electionId: parseInt(btn.dataset.eid), candidateId: parseInt(btn.dataset.cid), fromVote: true });
            });
        });
        if (window.lucide) lucide.createIcons();
    }

    function close() {
        votePub.classList.add('hidden');
        nuiFetch('closeVote');
    }

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (msg.action === 'openVote') {
            votePub.classList.remove('hidden');
            renderVote(msg.elections);
        } else if (msg.action === 'closeVote') {
            votePub.classList.add('hidden');
        }
    });

    document.getElementById('btnCloseVote').addEventListener('click', close);
    document.getElementById('vote-pub-overlay').addEventListener('click', close);
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !votePub.classList.contains('hidden')) close();
    });
})();

function applyPerms(perms) {
    if (!perms) return;

    const propToolbar = document.getElementById('propose-toolbar');
    if (propToolbar) propToolbar.style.display = perms.laws ? '' : 'none';

    if (btnAddTx) btnAddTx.style.display = perms.budget ? '' : 'none';

    if (btnCreateParty) btnCreateParty.style.display = perms.parties ? '' : 'none';
    if (btnLeaveParty)  btnLeaveParty.classList.remove('hidden');

    if (btnStartElection) {
        if (perms.elections) {
            btnStartElection.classList.remove('hidden');
        } else {
            btnStartElection.classList.add('hidden');
        }
    }
}
