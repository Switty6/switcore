
const root    = document.getElementById('hud-root');
const elTime  = document.getElementById('time-value');
const speedo  = document.getElementById('speedometer');
const speedVal= document.getElementById('speed-value');
const canvas  = document.getElementById('speed-canvas');
const ctx     = canvas.getContext('2d');
const elGearEl= document.getElementById('speed-gear');

const state = {
    health: 100, armor: 0, hunger: 100, thirst: 100,
    speed: 0, inVehicle: false,
    hour: 0, minute: 0
};

function setBar(id, pct) {
    const el = document.getElementById(id);
    if (!el) return;
    el.style.width = Math.max(0, Math.min(100, pct)) + '%';

    // Auto-hide stamina/oxygen cand sunt pline (100%)
    if (id === 'bar-stamina' || id === 'bar-oxygen') {
        const row = el.closest('.stat-row');
        if (row) {
            if (pct >= 100) {
                row.classList.add('stat-hide');
            } else {
                row.classList.remove('stat-hide');
            }
        }
    }
}

function updateHealthStyle(pct) {
    const row = document.getElementById('stat-health');
    row.classList.toggle('medium', pct <= 60 && pct > 25);
    row.classList.toggle('low',    pct <= 25);
}

function updateLowStyle(id, pct) {
    document.getElementById(id).classList.toggle('low', pct <= 25);
}

function setTime(h, m) {
    state.hour   = h;
    state.minute = m;
    elTime.textContent = String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0');
}

const MAX_SPEED   = 240;
const START_ANGLE = Math.PI * 0.75;   // 135°
const SWEEP       = Math.PI * 1.5;    // 270°

let speedTarget  = 0;
let speedCurrent = 0;
let speedRafId   = null;

function speedColor(spd) {
    if (spd >= 180) return '#ff4757';
    if (spd >= 120) return '#ffa502';
    return null; // null = gradient (gestionat in draw)
}

function drawSpeedo(spd) {
    const W  = canvas.width;
    const H  = canvas.height;
    const cx = W / 2;
    const cy = H / 2 + 10;
    const R  = 55;

    ctx.clearRect(0, 0, W, H);

    const zone2Start = START_ANGLE + SWEEP * (120 / MAX_SPEED);
    const zone3Start = START_ANGLE + SWEEP * (180 / MAX_SPEED);
    const arcEnd     = START_ANGLE + SWEEP;

    ctx.beginPath();
    ctx.arc(cx, cy, R + 10, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.03)';
    ctx.lineWidth = 1;
    ctx.stroke();

    ctx.lineCap = 'butt';

    ctx.beginPath();
    ctx.arc(cx, cy, R, START_ANGLE, zone2Start);
    ctx.strokeStyle = 'rgba(0,180,255,0.09)';
    ctx.lineWidth = 8;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(cx, cy, R, zone2Start, zone3Start);
    ctx.strokeStyle = 'rgba(255,165,2,0.14)';
    ctx.lineWidth = 8;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(cx, cy, R, zone3Start, arcEnd);
    ctx.strokeStyle = 'rgba(255,71,87,0.2)';
    ctx.lineWidth = 8;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(cx, cy, R, START_ANGLE, arcEnd);
    ctx.strokeStyle = 'rgba(255,255,255,0.05)';
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    ctx.stroke();

    for (let kmh = 0; kmh <= MAX_SPEED; kmh += 20) {
        const angle    = START_ANGLE + SWEEP * (kmh / MAX_SPEED);
        const isMajor  = (kmh % 40 === 0);
        const rOuter   = R + 8;
        const rInner   = isMajor ? R + 1 : R + 4;

        let tickColor;
        if (kmh >= 180)      tickColor = 'rgba(255,71,87,0.65)';
        else if (kmh >= 120) tickColor = 'rgba(255,165,2,0.6)';
        else                 tickColor = 'rgba(232,244,255,0.22)';

        ctx.beginPath();
        ctx.moveTo(cx + rOuter * Math.cos(angle), cy + rOuter * Math.sin(angle));
        ctx.lineTo(cx + rInner * Math.cos(angle), cy + rInner * Math.sin(angle));
        ctx.strokeStyle = tickColor;
        ctx.lineWidth   = isMajor ? 1.5 : 1;
        ctx.lineCap     = 'round';
        ctx.stroke();

        if (isMajor) {
            const labelR = rOuter + 10;
            ctx.save();
            ctx.font = '600 7px Inter, sans-serif';
            if (kmh >= 180)      ctx.fillStyle = 'rgba(255,71,87,0.55)';
            else if (kmh >= 120) ctx.fillStyle = 'rgba(255,165,2,0.5)';
            else                 ctx.fillStyle = 'rgba(232,244,255,0.28)';
            ctx.textAlign    = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(kmh, cx + labelR * Math.cos(angle), cy + labelR * Math.sin(angle));
            ctx.restore();
        }
    }

    ctx.beginPath();
    ctx.arc(cx, cy, 18, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.04)';
    ctx.lineWidth = 1;
    ctx.stroke();

    const progress = Math.min(spd / MAX_SPEED, 1);
    const endAngle = START_ANGLE + SWEEP * progress;
    const col      = speedColor(spd);

    if (spd > 0) {
        ctx.beginPath();
        ctx.arc(cx, cy, R, START_ANGLE, endAngle);

        if (col) {
            ctx.strokeStyle = col;
        } else {
            const grad = ctx.createLinearGradient(cx - R, cy, cx + R, cy);
            grad.addColorStop(0,   '#00b4ff');
            grad.addColorStop(0.5, '#00c97a');
            grad.addColorStop(1,   '#00b4ff');
            ctx.strokeStyle = grad;
        }
        ctx.lineWidth = 4;
        ctx.lineCap   = 'round';
        ctx.stroke();

        const tipX = cx + R * Math.cos(endAngle);
        const tipY = cy + R * Math.sin(endAngle);
        ctx.beginPath();
        ctx.arc(tipX, tipY, 4.5, 0, Math.PI * 2);
        ctx.fillStyle  = col || '#00c97a';
        ctx.shadowColor = col || '#00b4ff';
        ctx.shadowBlur  = 14;
        ctx.fill();
        ctx.shadowBlur = 0;
    }

    speedVal.textContent = Math.round(spd);

    if (spd >= 180) {
        speedVal.style.color      = '#ff4757';
        speedVal.style.textShadow = '0 0 20px rgba(255,71,87,0.6)';
    } else if (spd >= 120) {
        speedVal.style.color      = '#ffa502';
        speedVal.style.textShadow = '0 0 20px rgba(255,165,2,0.5)';
    } else {
        speedVal.style.color      = '';
        speedVal.style.textShadow = '';
    }
}

function animateSpeedo() {
    const diff = speedTarget - speedCurrent;
    if (Math.abs(diff) < 0.5) {
        speedCurrent = speedTarget;
        drawSpeedo(speedCurrent);
        speedRafId = null;
        return;
    }
    speedCurrent += diff * 0.18;
    drawSpeedo(speedCurrent);
    speedRafId = requestAnimationFrame(animateSpeedo);
}

function setSpeed(spd) {
    speedTarget = spd;
    if (!speedRafId) speedRafId = requestAnimationFrame(animateSpeedo);
}

function setGear(g) {
    let label, color;
    if (g < 0) { label = 'R'; color = '#ff4757'; }
    else if (g === 0) { label = 'N'; color = '#ffa502'; }
    else { label = String(g); color = '#00b4ff'; }
    elGearEl.textContent = label;
    elGearEl.style.color = color;
    elGearEl.style.textShadow = `0 0 18px ${color}99`;
}

function setFuel(pct) {
    pct = Math.max(0, Math.min(100, pct));
    const bar = document.getElementById('bar-fuel');
    const lbl = document.getElementById('fuel-pct');
    if (bar) { bar.style.width = pct + '%'; bar.classList.toggle('low', pct <= 20); }
    if (lbl) { lbl.textContent = Math.round(pct) + '%'; lbl.classList.toggle('low', pct <= 20); }
}

function setMileage(km) {
    const lbl = document.getElementById('odo-value');
    if (!lbl) return;
    if (km == null || km < 0) {
        lbl.textContent = '- km';
        return;
    }
    if (km >= 1000) {
        lbl.textContent = Math.floor(km).toLocaleString() + ' km';
    } else {
        lbl.textContent = km.toFixed(1) + ' km';
    }
}

function setSignal(side, on) {
    const el = document.getElementById('sig-' + side);
    if (el) el.classList.toggle('active', on);
}

function setLights(on) {
    const el = document.getElementById('headlight');
    if (el) el.classList.toggle('on', on);
}

function setHighBeam(on) {
    const el = document.getElementById('highbeam');
    if (el) el.classList.toggle('on', on);
}

const cluster = document.getElementById('stat-cluster');

function setVehicle(inVeh) {
    if (inVeh === state.inVehicle) return;
    state.inVehicle = inVeh;
    speedo.classList.toggle('speed-hidden', !inVeh);
    cluster.classList.toggle('veh-on', inVeh);
    if (!inVeh) setSpeed(0);
}

window.addEventListener('message', function (e) {
    const d = e.data;
    if (!d || !d.action) return;

    switch (d.action) {

        case 'show':
            root.classList.remove('hidden');
            drawSpeedo(0);
            break;

        case 'hide':
            root.classList.add('hidden');
            break;

        case 'init':
            setBar('bar-hunger', d.hunger ?? 100);
            setBar('bar-thirst', d.thirst ?? 100);
            updateLowStyle('stat-hunger', d.hunger ?? 100);
            updateLowStyle('stat-thirst', d.thirst ?? 100);
            break;

        case 'updateGame':
            state.health = d.health ?? state.health;
            state.armor  = d.armor  ?? state.armor;

            setBar('bar-health', state.health);
            setBar('bar-armor',  state.armor);
            updateHealthStyle(state.health);
            setVehicle(!!d.inVehicle);
            if (d.inVehicle) {
                setSpeed(d.speed || 0);
                if (d.gear        !== undefined) setGear(d.gear);
                if (d.fuel        !== undefined) setFuel(d.fuel);
                if (d.mileage     !== undefined) setMileage(d.mileage);
                if (d.signalLeft  !== undefined) setSignal('left',  d.signalLeft);
                if (d.signalRight !== undefined) setSignal('right', d.signalRight);
                if (d.lights      !== undefined) setLights(d.lights);
                if (d.highBeam    !== undefined) setHighBeam(d.highBeam);
            }

            if (d.stamina !== undefined) setBar('bar-stamina', d.stamina);
            if (d.oxygen  !== undefined) setBar('bar-oxygen',  d.oxygen);
            break;

        case 'updateNeeds':
            setBar('bar-hunger', d.hunger ?? 100);
            setBar('bar-thirst', d.thirst ?? 100);
            updateLowStyle('stat-hunger', d.hunger ?? 100);
            updateLowStyle('stat-thirst', d.thirst ?? 100);
            break;

        case 'updateTime':
            setTime(d.hour || 0, d.minute || 0);
            break;

        case 'updateJob':
            setJobInfo(d.name, d.gradeLabel, d.type, d.isOnDuty);
            break;

        case 'setComponent':
            if (d.component === 'hunger') { setBar('bar-hunger', d.value); updateLowStyle('stat-hunger', d.value); }
            if (d.component === 'thirst') { setBar('bar-thirst', d.value); updateLowStyle('stat-thirst', d.value); }
            if (d.component === 'health') { setBar('bar-health', d.value); updateHealthStyle(d.value); }
            if (d.component === 'armor')  { setBar('bar-armor',  d.value); }
            if (d.component === 'time')   { setTime(d.hour, d.minute); }
            break;
    }
});

const jobBadgeEl   = document.getElementById('job-badge');
const jobDutyDot   = document.getElementById('job-duty-dot');
const jobBadgeText = document.getElementById('job-badge-text');

function setJobInfo(name, gradeLabel, type, isOnDuty) {
    if (!name || name === 'unemployed') {
        jobBadgeEl.classList.add('hidden');
        return;
    }
    jobBadgeEl.classList.remove('hidden');
    jobBadgeText.textContent = gradeLabel ? (name + ' · ' + gradeLabel) : name;
    jobDutyDot.classList.toggle('on', isOnDuty && type !== 'illegal');
}

drawSpeedo(0);
