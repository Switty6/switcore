let state = {
    job:       null,
    stats:     null,
    recent:    [],
    calls:     [],
    prices:    {},
    workshop:  null,
    clientSrc: null,
};

// Traducere prin helperul standard SwI18n (core/ui/i18n.js); fallback pe cheie.
function t(key, ...args) {
    return SwI18n.t(`mecanic.${key}`, ...args);
}

// Re-randare a stringurilor generate din JS la schimbarea dictionarului.
document.addEventListener('sw:i18n', () => {
    const emptyText = document.getElementById('workshopEmptyText');
    if (emptyText) emptyText.innerHTML = t('ui.workshop_empty');
    renderDashboard();
    renderCalls();
    renderLog();
    if (state.workshop) renderWorkshop(state.workshop);
    updateCallsBadge((state.calls || []).length);
});

window.addEventListener('message', function(event) {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'hidePanel':
            document.getElementById('app').classList.add('hidden');
            break;

        case 'startMinigame':
            MG.start(data.gameType, data.rounds, data.difficulty, data.label);
            break;

        case 'open':
            state.job    = data.job;
            state.stats  = data.stats;
            state.recent = data.recent || [];
            state.calls  = data.calls  || [];
            state.prices = data.prices || {};
            show();
            renderDashboard();
            renderCalls();
            renderLog();
            break;

        case 'openWorkshop':
            state.workshop  = data;
            state.clientSrc = data.clientSrc;
            switchTab('workshop', document.querySelector('[data-tab="workshop"]'));
            renderWorkshop(data);
            break;

        case 'inspectResult':
            state.workshop = data.data;
            renderWorkshop(data.data);
            break;

        case 'updateCalls':
            state.calls = data.calls || [];
            renderCalls();
            updateCallsBadge(state.calls.length);
            break;

        case 'newCall':
            state.calls.unshift(data.call);
            renderCalls();
            updateCallsBadge(state.calls.length);
            break;
    }
});

function post(event, data) {
    const resource = (typeof GetParentResourceName === 'function' && GetParentResourceName !== post)
        ? GetParentResourceName()
        : 'mecanic';
    fetch(`https://${resource}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

function show() {
    document.getElementById('app').classList.remove('hidden');
}

function closeUI() {
    document.getElementById('app').classList.add('hidden');
    post('close');
}

function switchTab(tabName, btn) {
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    const pane = document.getElementById('tab-' + tabName);
    if (pane) pane.classList.add('active');
    if (btn)  btn.classList.add('active');
}

function updateCallsBadge(count) {
    const badge = document.getElementById('callsBadge');
    badge.textContent = count;
    badge.className = 'badge' + (count === 0 ? ' zero' : '');
}

function healthColor(pct) {
    if (pct >= 70) return '#22c55e';
    if (pct >= 40) return '#f97316';
    return '#ef4444';
}

function compColor(val) {
    if (val >= 60) return '#22c55e';
    if (val >= 30) return '#f97316';
    return '#ef4444';
}

function timeSince(dateStr) {
    if (!dateStr) return '';
    const diff = Math.floor((Date.now() - new Date(dateStr)) / 1000);
    if (diff < 60)   return t('ui.time_now');
    if (diff < 3600) return t('ui.time_min_ago', Math.floor(diff/60));
    if (diff < 86400) return t('ui.time_hour_ago', Math.floor(diff/3600));
    return t('ui.time_day_ago', Math.floor(diff/86400));
}

function problemLabel(type) {
    const valid = { engine:true, tire:true, battery:true, tow:true };
    return valid[type] ? t(type === 'tow' ? 'problem.tow_short' : `problem.${type}`) : type;
}

function renderDashboard() {
    const s = state.stats || {};
    document.getElementById('statToday').textContent   = s.today_services || 0;
    document.getElementById('statBonus').textContent   = fmt(s.total_bonus) + ' RON';
    document.getElementById('statTotal').textContent   = s.total_services || 0;
    document.getElementById('statRevenue').textContent = fmt(s.total_revenue) + ' RON';

    renderPrices();
}

function fmt(n) {
    return Number(n || 0).toLocaleString('ro-RO');
}

function renderPrices() {
    const p = state.prices;
    const list = document.getElementById('priceList');
    const rows = [
        { name: t('ui.price.inspect_name'),    req: t('ui.price.inspect_req'),    key: 'inspect' },
        { name: t('ui.price.oil_change_name'), req: t('ui.price.oil_change_req'), key: 'oil_change' },
        { name: t('ui.price.brakes_name'),     req: t('ui.price.brakes_req'),     key: 'brakes' },
        { name: t('ui.price.tire_name'),       req: t('ui.price.tire_req'),       key: 'tire' },
        { name: t('ui.price.suspension_name'), req: t('ui.price.suspension_req'), key: 'suspension' },
        { name: t('ui.price.battery_name'),    req: t('ui.price.battery_req'),    key: 'battery' },
        { name: t('ui.price.engine_name'),     req: t('ui.price.engine_req'),     key: 'engine' },
        { name: t('ui.price.bodywork_name'),   req: t('ui.price.bodywork_req'),   key: 'bodywork' },
    ];
    list.innerHTML = rows.map(r => `
        <div class="price-row">
            <div>
                <div class="price-name">${r.name}</div>
                <div class="price-req">${r.req}</div>
            </div>
            <div class="price-val">${fmt(p[r.key] || 0)} RON</div>
        </div>
    `).join('');
}

function renderWorkshop(data) {
    if (!data) return;
    document.getElementById('workshopEmpty').classList.add('hidden');
    document.getElementById('workshopPanel').classList.remove('hidden');

    document.getElementById('vehPlate').textContent   = data.plate  || '-';
    document.getElementById('vehModel').textContent   = data.model  || '-';
    document.getElementById('vehMileage').textContent = Math.floor(data.mileage || 0).toLocaleString('ro-RO') + ' km';

    const engPct = Math.round((data.engineHealth || 1000) / 10);
    const bodPct = Math.round((data.bodyHealth   || 1000) / 10);

    setBar('engineBar', 'enginePct', engPct);
    setBar('bodyBar',   'bodyPct',   bodPct);

    renderComponents(data.components);
    renderServices(data);
}

function setBar(barId, pctId, pct) {
    const bar = document.getElementById(barId);
    const lbl = document.getElementById(pctId);
    bar.style.width = pct + '%';
    bar.style.background = healthColor(pct);
    lbl.textContent = pct + '%';
    lbl.style.color = healthColor(pct);
}

function renderComponents(comps) {
    if (!comps) return;
    const grid = document.getElementById('componentsGrid');

    const simpleComps = [
        { key: 'oil',     label: t('ui.comp.oil') },
        { key: 'battery', label: t('ui.comp.battery') },
        { key: 'brakes',  label: t('ui.comp.brakes') },
        { key: 'exhaust', label: t('ui.comp.exhaust') },
    ];

    let html = simpleComps.map(c => {
        const val = comps[c.key] !== undefined ? comps[c.key] : 100;
        const color = compColor(val);
        return `
            <div class="comp-card">
                <div class="comp-name">${c.label}</div>
                <div class="comp-bar-wrap"><div class="comp-bar" style="width:${val}%;background:${color}"></div></div>
                <div class="comp-val" style="color:${color}">${val}%</div>
            </div>
        `;
    }).join('');

    const tires = comps.tires || { fl:100, fr:100, rl:100, rr:100 };
    html += wheelCard(t('ui.comp.tires'), tires);

    const susp = comps.suspension || { fl:100, fr:100, rl:100, rr:100 };
    html += wheelCard(t('ui.comp.suspension'), susp);

    grid.innerHTML = html;
}

function wheelCard(label, wheels) {
    const positions = ['fl','fr','rl','rr'];
    const posLabel  = { fl:'FL', fr:'FR', rl:'RL', rr:'RR' };
    const items = positions.map(pos => {
        const val   = wheels[pos] !== undefined ? wheels[pos] : 100;
        const color = compColor(val);
        return `
            <div class="comp-wheel-item">
                <div class="comp-wheel-label">${posLabel[pos]}</div>
                <div class="comp-wheel-bar-wrap"><div class="comp-wheel-bar" style="width:${val}%;background:${color}"></div></div>
                <div class="comp-wheel-val" style="color:${color}">${val}%</div>
            </div>
        `;
    }).join('');

    return `
        <div class="comp-card comp-card-wide">
            <div class="comp-name">${label}</div>
            <div class="comp-wheels">${items}</div>
        </div>
    `;
}

function renderServices(data) {
    const comps   = data.components || {};
    const tires   = comps.tires     || {};
    const susp    = comps.suspension || {};
    const perms   = state.job && state.job.permissions ? state.job.permissions : [];
    const hasPerm = (p) => perms.includes(p);
    const p       = state.prices;
    const list    = document.getElementById('servicesList');

    const services = [
        {
            type: 'inspect', perm: 'inspect',
            name: t('ui.svc.inspect_name'),
            req:  t('ui.svc.inspect_req'),
            price: p.inspect || 200,
        },
        {
            type: 'oil_change', perm: 'oil_change',
            name: t('ui.svc.oil_change_name'),
            req:  t('ui.svc.oil_change_req'),
            price: p.oil_change || 400,
            disabled: (comps.oil || 0) >= 100,
        },
        {
            type: 'brakes', perm: 'brakes',
            name: t('ui.svc.brakes_name'),
            req:  t('ui.svc.brakes_req'),
            price: p.brakes || 500,
            disabled: (comps.brakes || 0) >= 100,
        },
        {
            type: 'tire', perm: 'tires',
            name: t('ui.svc.tire_name'),
            req:  t('ui.svc.tire_req'),
            price: (p.tire || 300) * 4,
            tirePositions: ['fl','fr','rl','rr'],
        },
        {
            type: 'suspension', perm: 'suspension',
            name: t('ui.svc.suspension_name'),
            req:  t('ui.svc.suspension_req'),
            price: (p.suspension || 800) * 2,
            suspensionPositions: ['fl','fr','rl','rr'],
        },
        {
            type: 'battery', perm: 'battery',
            name: t('ui.svc.battery_name'),
            req:  t('ui.svc.battery_req'),
            price: p.battery || 600,
            disabled: (comps.battery || 0) >= 100,
        },
        {
            type: 'engine', perm: 'engine',
            name: t('ui.svc.engine_name'),
            req:  t('ui.svc.engine_req'),
            price: p.engine || 1500,
            disabled: (data.engineHealth || 1000) >= 1000,
        },
        {
            type: 'bodywork', perm: 'bodywork',
            name: t('ui.svc.bodywork_name'),
            req:  t('ui.svc.bodywork_req'),
            price: p.bodywork || 800,
            disabled: (data.bodyHealth || 1000) >= 1000,
        },
    ];

    list.innerHTML = services.map(svc => {
        const allowed = hasPerm(svc.perm);
        const isDisabled = !allowed || svc.disabled;
        return `
            <div class="service-item">
                <div class="service-info">
                    <div class="service-name">${svc.name}</div>
                    <div class="service-req">${svc.req}${!allowed ? ` · <span style="color:var(--red)">${t('ui.no_permission')}</span>` : ''}</div>
                </div>
                <span class="service-price">${fmt(svc.price)} RON</span>
                <button class="btn-service" ${isDisabled ? 'disabled style="opacity:.4;cursor:not-allowed"' : ''}
                    onclick='performService(${JSON.stringify(svc)})'>
                    ${t('ui.execute')}
                </button>
            </div>
        `;
    }).join('');
}

function performService(svc) {
    if (!state.workshop) return;
    const payload = {
        serviceType: svc.type,
        vehicleId:   state.workshop.vehicleId,
        clientSrc:   state.clientSrc,
    };

    // Tire service: serverul are nevoie de pozitiile damaged ca sa stie unde sa puna markere
    if (svc.type === 'tire') {
        const tires = (state.workshop.components || {}).tires || {};
        payload.damagedTires = Object.keys(tires).filter(k => (tires[k] ?? 100) < 100);
        if (payload.damagedTires.length === 0) {
            payload.damagedTires = ['fl','fr','rl','rr'];
        }
    }

    if (svc.tirePositions)       payload.tirePositions       = svc.tirePositions;
    if (svc.suspensionPositions) payload.suspensionPositions = svc.suspensionPositions;
    post('performService', payload);
}

function renderCalls() {
    const list = document.getElementById('callsList');
    if (!state.calls || state.calls.length === 0) {
        list.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12"/>
                </svg>
                <p>${t('ui.no_calls')}</p>
            </div>`;
        return;
    }

    list.innerHTML = state.calls.map(call => {
        const loc = typeof call.location === 'string' ? JSON.parse(call.location) : call.location;
        return `
            <div class="call-card">
                <div class="call-top">
                    <div class="call-client">${call.client_name || call.clientName || t('ui.client')}</div>
                    <span class="call-type ${call.problem_type || call.problemType}">${problemLabel(call.problem_type || call.problemType)}</span>
                </div>
                <div class="call-meta">
                    ${call.plate ? t('ui.plate_label') + ' <strong>' + call.plate + '</strong> · ' : ''}
                    ${call.model || ''}
                    ${timeSince(call.created_at) ? ' · ' + timeSince(call.created_at) : ''}
                </div>
                <div class="call-actions">
                    <button class="btn btn-accept btn-sm" onclick="acceptCall(${call.id})">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <polyline points="20 6 9 17 4 12"/>
                        </svg>
                        ${t('ui.accept')}
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

function acceptCall(callId) {
    post('acceptCall', { callId });
    state.calls = state.calls.filter(c => c.id !== callId);
    renderCalls();
    updateCallsBadge(state.calls.length);
}

function refreshCalls() {
    post('refreshCalls');
}

function renderLog() {
    const list = document.getElementById('logList');
    if (!state.recent || state.recent.length === 0) {
        list.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                </svg>
                <p>${t('ui.no_log')}</p>
            </div>`;
        return;
    }

    list.innerHTML = state.recent.map(r => `
        <div class="log-item">
            <div>
                <div class="log-service">${r.service_type}</div>
                <div class="log-client">${r.client_name || t('ui.client')} · ${r.plate || '-'}</div>
            </div>
            <div class="log-right">
                <div class="log-price">${fmt(r.price)} RON</div>
                <div class="log-bonus">${t('ui.bonus_suffix', fmt(r.bonus_paid))}</div>
                <div class="log-time">${timeSince(r.completed_at)}</div>
            </div>
        </div>
    `).join('');
}

const MG = {
    active: false,
    raf:    null,
    clean:  null,

    start(gameType, rounds, difficulty, label) {
        if (this.active) return;
        this.active = true;

        document.getElementById('mg-label').textContent = label || t('ui.mg_active');
        document.getElementById('mg-result').classList.add('hidden');
        document.querySelectorAll('.mg-game').forEach(g => g.classList.add('hidden'));

        const overlay = document.getElementById('mg-overlay');
        overlay.classList.remove('hidden');

        if      (gameType === 'timing')    this._timing(rounds, difficulty);
        else if (gameType === 'sequence')  this._sequence(rounds, difficulty);
        else if (gameType === 'hammering') this._hammering(rounds, difficulty);
        else                               this._timing(rounds, difficulty);
    },

    _finish(success) {
        if (this.raf)   { cancelAnimationFrame(this.raf); this.raf = null; }
        if (this.clean) { this.clean(); this.clean = null; }

        document.querySelectorAll('.mg-game').forEach(g => g.classList.add('hidden'));

        const res  = document.getElementById('mg-result');
        const icon = document.getElementById('mg-result-icon');
        const text = document.getElementById('mg-result-text');
        icon.innerHTML = success ? '<i data-lucide="check"></i>' : '<i data-lucide="x"></i>';
        if (window.lucide) lucide.createIcons({ nodes: icon.querySelectorAll('[data-lucide]') });
        text.textContent = success ? t('ui.mg_success') : t('ui.mg_fail');
        text.className   = 'mg-result-text ' + (success ? 'success' : 'fail');
        res.classList.remove('hidden');

        setTimeout(() => {
            document.getElementById('mg-overlay').classList.add('hidden');
            this.active = false;
            post('minigameResult', { result: success ? 'success' : 'fail' });
        }, 900);
    },

    _dots(total, current) {
        const wrap = document.getElementById('mg-rounds-wrap');
        wrap.innerHTML = Array.from({ length: total }, (_, i) => {
            const cls = i < current ? 'done' : i === current ? 'current' : '';
            return `<div class="mg-round-dot ${cls}" id="mg-dot-${i}"></div>`;
        }).join('');
    },

    _dotDone(idx) {
        const el = document.getElementById('mg-dot-' + idx);
        if (el) el.className = 'mg-round-dot done';
    },

    _timing(totalRounds, difficulty) {
        const panel = document.getElementById('mg-timing');
        panel.classList.remove('hidden');

        const cfg = { easy: { speed:0.50, zone:0.30 }, medium: { speed:0.85, zone:0.20 }, hard: { speed:1.30, zone:0.13 } }[difficulty] || { speed:0.85, zone:0.20 };
        const MAX_STRIKES = 3;

        let round = 0, strikes = 0;
        let pos = 0.05, vel = cfg.speed;
        let zoneL = 0.35, blocked = false;
        let lastTs = null;

        const needle = document.getElementById('mg-needle');
        const zone   = document.getElementById('mg-zone');

        document.getElementById('mg-strikes').innerHTML =
            Array.from({ length: MAX_STRIKES }, (_, i) => `<div class="mg-strike" id="ms${i}"></div>`).join('');

        const placeZone = () => {
            zoneL = 0.08 + Math.random() * (0.84 - cfg.zone);
            zone.style.left  = (zoneL * 100) + '%';
            zone.style.width = (cfg.zone * 100) + '%';
        };

        const newRound = () => {
            placeZone();
            blocked = false;
            this._dots(totalRounds, round);
        };
        newRound();

        const loop = (ts) => {
            const dt = lastTs ? Math.min((ts - lastTs) / 1000, 0.1) : 0;
            lastTs = ts;
            pos += vel * dt;
            if (pos >= 1) { pos = 1; vel = -Math.abs(vel); }
            if (pos <= 0) { pos = 0; vel =  Math.abs(vel); }
            const inZone = pos >= zoneL && pos <= zoneL + cfg.zone;
            needle.style.left = (pos * 100) + '%';
            needle.classList.toggle('in-zone', inZone);
            this.raf = requestAnimationFrame(loop);
        };
        this.raf = requestAnimationFrame(loop);

        const hit = () => {
            if (blocked) return;
            blocked = true;
            const inZone = pos >= zoneL && pos <= zoneL + cfg.zone;

            needle.classList.remove('flash-success', 'flash-fail');
            void needle.offsetWidth; // forteaza reflow ca animatia sa porneasca din nou
            needle.classList.add(inZone ? 'flash-success' : 'flash-fail');

            if (inZone) {
                this._dotDone(round);
                round++;
                if (round >= totalRounds) { setTimeout(() => this._finish(true), 450); return; }
                setTimeout(newRound, 550);
            } else {
                strikes++;
                const s = document.getElementById('ms' + (strikes - 1));
                if (s) s.classList.add('used');
                if (strikes >= MAX_STRIKES) { setTimeout(() => this._finish(false), 450); return; }
                setTimeout(() => { blocked = false; }, 500);
            }
        };

        const onKey   = (e) => { if (e.code === 'Space') { e.preventDefault(); hit(); } };
        const onClick = () => hit();
        document.addEventListener('keydown', onKey);
        panel.addEventListener('click', onClick);
        this.clean = () => { document.removeEventListener('keydown', onKey); panel.removeEventListener('click', onClick); };
    },

    _sequence(totalRounds, difficulty) {
        const panel = document.getElementById('mg-sequence');
        panel.classList.remove('hidden');

        const cfg = { easy: { len:4, time:7 }, medium: { len:5, time:5 }, hard: { len:6, time:4 } }[difficulty] || { len:5, time:5 };
        const POOL = ['E','R','F','T','G','X'];
        const MAX_TRIES = 2;

        let round = 0, tries = 0, idx = 0;
        let seq = [], timerRaf = null, tStart = 0, timerRunning = false, locked = false;

        const genSeq = () => {
            seq = [];
            for (let i = 0; i < cfg.len; i++) {
                let k;
                do { k = POOL[Math.floor(Math.random() * POOL.length)]; } while (seq[seq.length-1] === k);
                seq.push(k);
            }
        };

        const renderSeq = () => {
            document.getElementById('mg-seq-keys').innerHTML = seq.map((k, i) => {
                const cls = i < idx ? 'done' : i === idx ? 'active' : '';
                return `<div class="mg-key ${cls}" id="sk${i}">${k}</div>`;
            }).join('');
        };

        const startTimer = () => {
            tStart = performance.now();
            timerRunning = true;
            const bar = document.getElementById('mg-seq-timer-bar');
            const tick = (ts) => {
                if (!timerRunning) return;
                const pct = Math.max(0, (1 - (ts - tStart) / (cfg.time * 1000)) * 100);
                bar.style.width = pct + '%';
                bar.style.background = pct > 35 ? 'var(--orange)' : 'var(--red)';
                if (pct > 0) { timerRaf = requestAnimationFrame(tick); }
                else         { timerRunning = false; onFail(); }
            };
            timerRaf = requestAnimationFrame(tick);
        };

        const stopTimer = () => {
            timerRunning = false;
            if (timerRaf) { cancelAnimationFrame(timerRaf); timerRaf = null; }
        };

        const onFail = () => {
            if (locked) return;
            locked = true;
            stopTimer();
            for (let i = idx; i < seq.length; i++) {
                const el = document.getElementById('sk' + i);
                if (el) el.className = 'mg-key wrong';
            }
            tries++;
            if (tries >= MAX_TRIES) { setTimeout(() => this._finish(false), 700); return; }
            setTimeout(() => { idx = 0; locked = false; renderSeq(); startTimer(); }, 900);
        };

        const newRound = () => {
            genSeq(); idx = 0; locked = false;
            this._dots(totalRounds, round);
            renderSeq();
            stopTimer();
            startTimer();
        };
        newRound();

        const onKey = (e) => {
            if (locked) return;
            const k = e.key.toUpperCase();
            if (!POOL.includes(k)) return;
            if (k === seq[idx]) {
                const el = document.getElementById('sk' + idx);
                if (el) el.className = 'mg-key done';
                idx++;
                if (idx >= seq.length) {
                    stopTimer();
                    this._dotDone(round);
                    round++;
                    if (round >= totalRounds) { setTimeout(() => this._finish(true), 450); return; }
                    setTimeout(newRound, 650);
                }
            } else {
                const el = document.getElementById('sk' + idx);
                if (el) {
                    el.classList.add('wrong');
                    setTimeout(() => { if (el) el.className = 'mg-key active'; }, 320);
                }
                onFail();
            }
        };

        document.addEventListener('keydown', onKey);
        this.clean = () => { document.removeEventListener('keydown', onKey); stopTimer(); };
    },

    _hammering(totalRounds, difficulty) {
        const panel = document.getElementById('mg-hammering');
        panel.classList.remove('hidden');

        const cfg = { easy: { gain:13, decay:4,  time:9 }, medium: { gain:10, decay:9,  time:7 }, hard: { gain:8, decay:15, time:6 } }[difficulty] || { gain:10, decay:9, time:7 };

        let round = 0, fill = 0, timeLeft = cfg.time, lastTs = null;

        this._dots(totalRounds, 0);

        const barEl   = document.getElementById('mg-hammer-bar');
        const pctEl   = document.getElementById('mg-hammer-pct');
        const timerEl = document.getElementById('mg-hammer-timer');

        const reset = () => {
            fill = 0; timeLeft = cfg.time; lastTs = null;
            this._dots(totalRounds, round);
        };
        reset();

        const loop = (ts) => {
            const dt = lastTs ? Math.min((ts - lastTs) / 1000, 0.1) : 0;
            lastTs = ts;

            fill     = Math.max(0, fill - cfg.decay * dt);
            timeLeft = Math.max(0, timeLeft - dt);

            barEl.style.width    = fill + '%';
            pctEl.textContent    = Math.round(fill) + '%';
            timerEl.style.width  = ((timeLeft / cfg.time) * 100) + '%';

            if (fill >= 100) {
                this._dotDone(round);
                round++;
                if (round >= totalRounds) { cancelAnimationFrame(this.raf); this.raf = null; setTimeout(() => this._finish(true), 400); return; }
                reset();
            } else if (timeLeft <= 0) {
                cancelAnimationFrame(this.raf); this.raf = null;
                setTimeout(() => this._finish(false), 400);
                return;
            }
            this.raf = requestAnimationFrame(loop);
        };
        this.raf = requestAnimationFrame(loop);

        const doHit = () => { fill = Math.min(100, fill + cfg.gain); };
        const onKey   = (e) => { if (e.code === 'KeyE') { e.preventDefault(); doHit(); } };
        const onClick = () => doHit();

        document.addEventListener('keydown', onKey);
        document.getElementById('mg-hammer-bar-wrap').addEventListener('click', onClick);
        this.clean = () => {
            document.removeEventListener('keydown', onKey);
            const el = document.getElementById('mg-hammer-bar-wrap');
            if (el) el.removeEventListener('click', onClick);
        };
    },
};

document.addEventListener('DOMContentLoaded', () => {});

// Dev preview: ruleaza doar daca pagina e deschisa direct in browser (in joc protocolul e nui://)
if (window.location.protocol === 'http:' || window.location.protocol === 'https:') {
    state.job = { name:'mecanic_auto', grade:2, permissions:['inspect','oil_change','brakes','tires','battery','bodywork','engine','suspension','roadside'] };
    state.stats = { today_services:4, total_bonus:1240, total_services:87, total_revenue:42000 };
    state.prices = { inspect:200, oil_change:400, brakes:500, tire:300, suspension:800, battery:600, engine:1500, bodywork:800 };
    state.recent = [
        { service_type:'Schimb Ulei', client_name:'Ion Popescu', plate:'SWC-001', price:400, bonus_paid:48, completed_at:new Date(Date.now()-3600000).toISOString() },
        { service_type:'Reparatie Motor', client_name:'Maria Ionescu', plate:'SWC-042', price:1500, bonus_paid:180, completed_at:new Date(Date.now()-7200000).toISOString() },
    ];
    state.calls = [
        { id:1, client_name:'Andrei Popa', plate:'SWC-007', model:'Sultan', problem_type:'engine', location:{x:0,y:0,z:0}, created_at:new Date().toISOString() },
        { id:2, client_name:'Elena Dumitrescu', plate:'SWC-088', model:'Kuruma', problem_type:'tire', location:{x:0,y:0,z:0}, created_at:new Date(Date.now()-120000).toISOString() },
    ];
    show();
    renderDashboard();
    renderCalls();
    renderLog();
    updateCallsBadge(state.calls.length);

    setTimeout(() => {
        renderWorkshop({
            vehicleId:1, plate:'SWC-042', model:'Sultan RS',
            engineHealth:420, bodyHealth:780, mileage:12450, clientSrc:1,
            components:{
                oil:15, battery:82, brakes:28, exhaust:55,
                tires:{ fl:100, fr:45, rl:0, rr:88 },
                suspension:{ fl:92, fr:90, rl:35, rr:40 },
            }
        });
        state.workshop = { vehicleId:1, plate:'SWC-042', model:'Sultan RS', engineHealth:420, bodyHealth:780, mileage:12450 };
    }, 300);
}
