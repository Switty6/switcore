
const ICONS = {
    interact: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/></svg>`,
    bag:      `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 00-2-2h-4a2 2 0 00-2 2v2"/></svg>`,
    terminal: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>`,
    bank:     `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/></svg>`,
    person:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`,
    chat:     `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>`,
    shield:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`,
    discord:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="12" r="1"/><circle cx="15" cy="12" r="1"/><path d="M7.5 7.5c2.5-1 6.5-1 9 0M7.5 16.5c2.5 1 6.5 1 9 0M5 5l1.5 9M19 5l-1.5 9M9 19l1 2 2-4 2 4 1-2"/></svg>`,
};

const TIPS = [
    { icon: 'interact', text: 'Apasă E pentru a interacționa cu lumea din jurul tău.' },
    { icon: 'bag',      text: 'Apasă TAB pentru a deschide inventarul.' },
    { icon: 'terminal', text: 'Folosește /help pentru a vedea comenzile disponibile.' },
    { icon: 'bank',     text: 'Accesează un ATM sau o bancă pentru a-ți gestiona fondurile.' },
    { icon: 'person',   text: 'Alege-ți cu grijă personajul - personalitatea contează!' },
    { icon: 'chat',     text: 'Comunicarea RP cu alți jucători îmbunătățește experiența tuturor.' },
    { icon: 'shield',   text: 'Respectă regulile serverului pentru o experiență plăcută.' },
    { icon: 'discord',  text: 'Găsești ajutor și actualizări pe Discord-ul comunității noastre.' },
];

const SEGMENT_COUNT = 32;

(function initVideo() {
    const video = document.getElementById('bg-video');
    if (!video) return;

    video.addEventListener('canplaythrough', function onReady() {
        video.removeEventListener('canplaythrough', onReady);
        video.classList.add('loaded');
        document.getElementById('particles').classList.add('video-active');
    });

    // Dacă video-ul nu se încarcă (fișier absent), rămânem pe particles
    video.addEventListener('error', function() {
        video.style.display = 'none';
    });
})();

(function initAudio() {
    const audio = document.getElementById('ambient');
    if (!audio) return;

    // Încearcă redarea - dacă fișierul nu există, ignoră silențios
    audio.volume = 0.18;
    const playPromise = audio.play();
    if (playPromise !== undefined) {
        playPromise.catch(() => { /* fișier absent sau autoplay blocat */ });
    }
})();

(function initParticles() {
    const canvas = document.getElementById('particles');
    const ctx    = canvas.getContext('2d');

    function resize() {
        canvas.width  = window.innerWidth;
        canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    const COUNT = 90;
    const pts = Array.from({ length: COUNT }, () => ({
        x:  Math.random() * canvas.width,
        y:  Math.random() * canvas.height,
        r:  Math.random() * 1.3 + 0.3,
        vx: (Math.random() - 0.5) * 0.22,
        vy: (Math.random() - 0.5) * 0.22,
        a:  Math.random() * 0.3 + 0.07
    }));

    function draw() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Connection lines
        for (let i = 0; i < pts.length; i++) {
            for (let j = i + 1; j < pts.length; j++) {
                const dx = pts[i].x - pts[j].x;
                const dy = pts[i].y - pts[j].y;
                const d  = Math.sqrt(dx * dx + dy * dy);
                if (d < 110) {
                    ctx.beginPath();
                    ctx.moveTo(pts[i].x, pts[i].y);
                    ctx.lineTo(pts[j].x, pts[j].y);
                    ctx.strokeStyle = `rgba(0,180,255,${0.06 * (1 - d / 110)})`;
                    ctx.lineWidth   = 0.5;
                    ctx.stroke();
                }
            }
        }

        // Dots
        pts.forEach(p => {
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(0,180,255,${p.a})`;
            ctx.fill();

            p.x += p.vx;
            p.y += p.vy;
            if (p.x < 0) p.x = canvas.width;
            if (p.x > canvas.width)  p.x = 0;
            if (p.y < 0) p.y = canvas.height;
            if (p.y > canvas.height) p.y = 0;
        });

        requestAnimationFrame(draw);
    }
    draw();
})();

const segContainer = document.getElementById('segments');
const segs = [];

for (let i = 0; i < SEGMENT_COUNT; i++) {
    const el = document.createElement('div');
    el.className = 'seg';
    segContainer.appendChild(el);
    segs.push(el);
}

let activeSegs = 0;
let leadingEl  = null;

function setSegments(count) {
    const target = Math.min(Math.max(0, count), SEGMENT_COUNT);

    if (leadingEl) { leadingEl.classList.remove('leading'); leadingEl = null; }

    if (target > activeSegs) {
        // Avansează segmentele
        for (let i = activeSegs; i < target; i++) {
            segs[i].classList.add('active');
            if (i === target - 1) {
                segs[i].classList.add('fresh');
                setTimeout(() => segs[i].classList.remove('fresh'), 500);
            }
        }
    } else if (target < activeSegs) {
        // Resetează segmentele (când progresul real < fake)
        for (let i = target; i < activeSegs; i++) {
            segs[i].classList.remove('active', 'fresh', 'leading');
        }
    }

    activeSegs = target;

    if (activeSegs > 0 && activeSegs < SEGMENT_COUNT) {
        leadingEl = segs[activeSegs - 1];
        if (leadingEl) leadingEl.classList.add('leading');
    }
}

const elStatus   = document.getElementById('prog-status');
const elPct      = document.getElementById('prog-pct');
const elResource = document.getElementById('resource-line');

const elTip     = document.getElementById('tip-text');
const elIcon    = document.getElementById('tip-icon');
let tipIndex    = Math.floor(Math.random() * TIPS.length);
let typeTimer   = null;

function setIcon(key) {
    elIcon.innerHTML = ICONS[key] || ICONS['interact'];
}

function typeWrite(text, speed = 32) {
    clearInterval(typeTimer);
    elTip.textContent = '';
    let i = 0;
    typeTimer = setInterval(() => {
        elTip.textContent += text[i++];
        if (i >= text.length) clearInterval(typeTimer);
    }, speed);
}

function rotateTip() {
    clearInterval(typeTimer);
    elTip.textContent = '';
    tipIndex = (tipIndex + 1) % TIPS.length;
    setTimeout(() => {
        setIcon(TIPS[tipIndex].icon);
        typeWrite(TIPS[tipIndex].text);
    }, 300);
}

setIcon(TIPS[tipIndex].icon);
typeWrite(TIPS[tipIndex].text);
setInterval(rotateTip, 6000);

// Evenimentele oficiale FiveM pentru loadscreen:
// - loadProgress      → loadFraction (0.0–1.0) - progresul principal
// - initFunctionInvoking → name - ce resursă/funcție se inițializează
// - onLogLine         → message - linii de log
// Ref: https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/

window.addEventListener('message', function (e) {
    const d = e.data;
    if (!d) return;

    // ── Progres principal (0.0 → 1.0) ──────────────────────────────────
    if (d.eventName === 'loadProgress') {
        const fraction = typeof d.loadFraction === 'number' ? d.loadFraction : 0;
        if (!realProgressStarted && fraction > 0) {
            realProgressStarted = true;
            fakeRunning = false;
        }
        const pct    = Math.min(100, Math.round(fraction * 100));
        const segAmt = Math.round((pct / 100) * SEGMENT_COUNT);
        elPct.textContent = pct + '%';
        setSegments(segAmt);

        if      (pct < 25)  elStatus.textContent = 'Se inițializează...';
        else if (pct < 60)  elStatus.textContent = 'Se încarcă resursele...';
        else if (pct < 90)  elStatus.textContent = 'Aproape gata...';
        else if (pct < 100) elStatus.textContent = 'Finalizare...';
        else                elStatus.textContent = 'Gata!';
    }

    // ── Numele funcției/resursei curente ────────────────────────────────
    if (d.eventName === 'initFunctionInvoking' && d.name) {
        elResource.textContent = d.name;
    }

    // ── Linii de log suplimentare ───────────────────────────────────────
    if (d.eventName === 'onLogLine' && d.message) {
        elResource.textContent = d.message;
    }
});

// loadProgress vine de la FiveM de la 0 cu date reale - nu mai e nevoie de fake crawl.
let fakeRunning = false;
let realProgressStarted = false;
