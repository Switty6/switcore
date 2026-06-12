const CONFIG = {
    maxNotifications: 5,
    defaultDuration: 5000,
    position: 'right-middle'
};

const TYPE_META = {
    'success':     { icon: '<i data-lucide="check"></i>',          key: 'notifications.types.success',     title: 'Succes' },
    'error':       { icon: '<i data-lucide="x"></i>',              key: 'notifications.types.error',       title: 'Eroare' },
    'info':        { icon: 'i',                                     key: 'notifications.types.info',        title: 'Informație' },
    'warning':     { icon: '!',                                     key: 'notifications.types.warning',     title: 'Atenție' },
    'cash-add':    { icon: '+',                                     key: 'notifications.types.cash_add',    title: 'Fonduri primite' },
    'cash-remove': { icon: '−',                                     key: 'notifications.types.cash_remove', title: 'Fonduri deduse' }
};

let notifId = 0;
const container = document.getElementById('notifications-container');

// Traducere cu fallback pe textul romanesc, pana soseste dictionarul sw:i18n
function t(key, fallback) {
    if (window.SwI18n) {
        const value = SwI18n.t(key);
        if (value !== key) return value;
    }
    return fallback;
}

function escapeHtml(str) {
    const d = document.createElement('div');
    d.textContent = String(str);
    return d.innerHTML;
}

function formatAmount(num) {
    return Number(num).toLocaleString('ro-RO');
}

function setPosition(pos) {
    container.className = 'notifications-container position-' + pos;
}

function removeNotif(el) {
    if (el.dataset.leaving) return;
    el.dataset.leaving = '1';

    clearTimeout(Number(el.dataset.timer));
    el.classList.remove('entering');
    el.classList.add('leaving');
    el.addEventListener('animationend', () => el.remove(), { once: true });

    // Fallback: daca animationend nu se declanseaza (tab hidden, GPU stuck), garanteaza remove
    setTimeout(() => el.remove(), 400);
}

function createNotif(type, message, duration) {
    const dur = duration || CONFIG.defaultDuration;
    const meta = TYPE_META[type] || TYPE_META['info'];

    const visible = container.querySelectorAll('.notification:not([data-leaving])');
    if (visible.length >= CONFIG.maxNotifications) {
        removeNotif(visible[visible.length - 1]);
    }

    const id = ++notifId;
    const el = document.createElement('div');
    el.className = 'notification entering';
    el.dataset.type = type;
    el.dataset.id = id;

    el.innerHTML = `
        <div class="notif-accent"></div>
        <div class="notif-body">
            <div class="notif-icon">${meta.icon}</div>
            <div class="notif-content">
                <div class="notif-title" data-i18n="${meta.key}">${t(meta.key, meta.title)}</div>
                <div class="notif-message">${escapeHtml(message)}</div>
            </div>
            <button class="notif-close" aria-label="${t('notifications.close', 'Închide')}"><i data-lucide="x"></i></button>
        </div>
        <div class="notif-progress">
            <div class="notif-progress-bar"></div>
        </div>`;

    container.prepend(el);
    if (window.lucide) lucide.createIcons({ nodes: el.querySelectorAll('[data-lucide]') });

    // Dublu rAF: prima frame planteaza starea initiala 100%, a doua porneste tranzitia spre 0
    requestAnimationFrame(() => {
        requestAnimationFrame(() => {
            const bar = el.querySelector('.notif-progress-bar');
            bar.style.transition = `transform ${dur}ms linear`;
            bar.style.transform  = 'scaleX(0)';
        });
    });

    const timer = setTimeout(() => removeNotif(el), dur);
    el.dataset.timer = timer;

    el.querySelector('.notif-close').addEventListener('click', () => removeNotif(el));
}

function createCashNotif(amount, currency, isAdd, duration) {
    const dur  = duration || CONFIG.defaultDuration;
    const type = isAdd ? 'cash-add' : 'cash-remove';
    const sign = isAdd ? '+' : '−';
    const meta = TYPE_META[type];

    const visible = container.querySelectorAll('.notification:not([data-leaving])');
    if (visible.length >= CONFIG.maxNotifications) {
        removeNotif(visible[visible.length - 1]);
    }

    const id = ++notifId;
    const el = document.createElement('div');
    el.className = 'notification entering';
    el.dataset.type = type;
    el.dataset.id = id;

    el.innerHTML = `
        <div class="notif-accent"></div>
        <div class="notif-body">
            <div class="notif-icon">${sign}</div>
            <div class="notif-content">
                <div class="notif-cash-amount">${sign}${escapeHtml(currency)}${formatAmount(amount)}</div>
                <div class="notif-cash-label" data-i18n="${meta.key}">${t(meta.key, meta.title)}</div>
            </div>
            <button class="notif-close" aria-label="${t('notifications.close', 'Închide')}"><i data-lucide="x"></i></button>
        </div>
        <div class="notif-progress">
            <div class="notif-progress-bar"></div>
        </div>`;

    container.prepend(el);
    if (window.lucide) lucide.createIcons({ nodes: el.querySelectorAll('[data-lucide]') });

    requestAnimationFrame(() => {
        requestAnimationFrame(() => {
            const bar = el.querySelector('.notif-progress-bar');
            bar.style.transition = `transform ${dur}ms linear`;
            bar.style.transform  = 'scaleX(0)';
        });
    });

    const timer = setTimeout(() => removeNotif(el), dur);
    el.dataset.timer = timer;

    el.querySelector('.notif-close').addEventListener('click', () => removeNotif(el));
}

window.addEventListener('message', function (e) {
    const data = e.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'notify':
            createNotif(data.type, data.message, data.duration);
            break;

        case 'notifyCash':
            createCashNotif(data.amount, data.currency, data.isAdd, data.duration);
            break;

        case 'config':
            if (data.maxNotifications) CONFIG.maxNotifications = data.maxNotifications;
            if (data.defaultDuration)  CONFIG.defaultDuration  = data.defaultDuration;
            if (data.position)         setPosition(data.position);
            break;
    }
});
