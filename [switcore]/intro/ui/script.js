
const TAGLINE_TEXT = 'Roleplay. Libertate. Comunitate.';
const HOLD_AFTER   = 2200;  // ms stat pe ecran după ce tagline-ul s-a scris complet
const TOTAL_AUTO   = 11000; // ms total înainte de ieșire automată

let autoTimer = null;
let typeTimer = null;
let isDone    = false;

(function initParticles() {
    const canvas = document.getElementById('particles');
    const ctx    = canvas.getContext('2d');

    function resize() {
        canvas.width  = window.innerWidth;
        canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    const COUNT = 70;
    const pts = Array.from({ length: COUNT }, () => ({
        x:  Math.random() * canvas.width,
        y:  Math.random() * canvas.height,
        r:  Math.random() * 1.2 + 0.3,
        vx: (Math.random() - 0.5) * 0.18,
        vy: (Math.random() - 0.5) * 0.18,
        a:  Math.random() * 0.25 + 0.05
    }));

    function draw() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        for (let i = 0; i < pts.length; i++) {
            for (let j = i + 1; j < pts.length; j++) {
                const dx = pts[i].x - pts[j].x;
                const dy = pts[i].y - pts[j].y;
                const d  = Math.sqrt(dx * dx + dy * dy);
                if (d < 120) {
                    ctx.beginPath();
                    ctx.moveTo(pts[i].x, pts[i].y);
                    ctx.lineTo(pts[j].x, pts[j].y);
                    ctx.strokeStyle = `rgba(0,180,255,${0.05 * (1 - d / 120)})`;
                    ctx.lineWidth   = 0.5;
                    ctx.stroke();
                }
            }
        }

        pts.forEach(p => {
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(0,180,255,${p.a})`;
            ctx.fill();

            p.x += p.vx; p.y += p.vy;
            if (p.x < 0) p.x = canvas.width;
            if (p.x > canvas.width)  p.x = 0;
            if (p.y < 0) p.y = canvas.height;
            if (p.y > canvas.height) p.y = 0;
        });

        requestAnimationFrame(draw);
    }
    draw();
})();

function typeWrite(el, text, speed, onDone) {
    clearInterval(typeTimer);
    el.textContent = '';
    el.classList.remove('done');
    let i = 0;
    typeTimer = setInterval(() => {
        el.textContent += text[i++];
        if (i >= text.length) {
            clearInterval(typeTimer);
            el.classList.add('done');
            if (onDone) onDone();
        }
    }, speed);
}

function playIntro() {
    const overlay = document.getElementById('intro-overlay');
    const center  = document.getElementById('intro-center');
    const name    = document.getElementById('server-name');
    const sep     = document.querySelector('.sep');
    const tagline = document.getElementById('tagline');

    overlay.classList.add('visible');

    setTimeout(() => center.classList.add('animate'), 50);
    setTimeout(() => name.classList.add('show'), 900);
    setTimeout(() => sep.classList.add('show'), 1400);

    setTimeout(() => {
        tagline.classList.add('show');
        typeWrite(tagline, TAGLINE_TEXT, 38, () => {
            autoTimer = setTimeout(done, HOLD_AFTER);
        });
    }, 1700);

    // Failsafe: forteaza exit daca typewriter-ul nu termina la timp
    autoTimer = setTimeout(done, TOTAL_AUTO);
}

function done() {
    if (isDone) return;
    isDone = true;

    clearTimeout(autoTimer);
    clearInterval(typeTimer);

    const overlay = document.getElementById('intro-overlay');
    overlay.classList.add('exit');

    setTimeout(() => {
        fetch('https://intro/introDone', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(() => {});
    }, 100);
}

window.addEventListener('message', function(e) {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'play') {
        isDone      = false;
        skipAllowed = false;
        playIntro();
    }

    if (d.type === 'hide') {
        const overlay = document.getElementById('intro-overlay');
        overlay.classList.remove('visible', 'exit', 'animate');
        document.getElementById('intro-center').classList.remove('animate');
        document.getElementById('server-name').classList.remove('show');
        document.querySelector('.sep').classList.remove('show');
        document.getElementById('tagline').classList.remove('show', 'done');
        isDone = false;
    }
});

// Demo mode in afara FiveM (CEF nu expune invokeNative in browser)
if (!window.invokeNative) {
    setTimeout(() => playIntro(), 500);
}
