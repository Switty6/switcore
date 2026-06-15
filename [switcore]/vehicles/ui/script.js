
const isFiveM = typeof window.invokeNative !== 'undefined';

function postNUI(action, data = {}) {
    if (isFiveM) {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
    } else {
        console.log('[NUI →]', action, data);
    }
}

let state = {
    phase: null,
    pumpId: 1,
    pricePerLitre: 8,
    balance: 0,
    cash: 0,
    bank: 0,
    currentFuelPct: 0,
    holding: false,
    sym: '$',
};

const fillHud         = document.getElementById('fillHud');
const cableSnapEl     = document.getElementById('cableSnap');

const hudPumpId       = document.getElementById('hudPumpId');
const priceEl         = document.getElementById('pricePerLitre');
const balanceEl       = document.getElementById('playerBalance');
const cashEl          = document.getElementById('playerCash');
const bankEl          = document.getElementById('playerBank');
const gaugePct        = document.getElementById('gaugePct');
const gaugeFill       = document.getElementById('gaugeFill');
const gaugeNeedle     = document.getElementById('gaugeNeedle');

const hudStatus       = document.getElementById('hudStatus');
const holdIndicator   = document.getElementById('holdIndicator');
const holdCaption     = document.getElementById('holdCaption');
const hudProgressBar  = document.getElementById('hudProgressBar');
const hudLitres       = document.getElementById('hudLitres');
const hudCost         = document.getElementById('hudCost');
const hudTankLevel    = document.getElementById('hudTankLevel');
const hudFundsWarn    = document.getElementById('hudFundsWarn');
const cableBar        = document.getElementById('cableBar');
const cableStatus     = document.getElementById('cableStatus');

const paymentModal     = document.getElementById('paymentModal');
const paySummaryLitres = document.getElementById('paySummaryLitres');
const paySummaryCost   = document.getElementById('paySummaryCost');
const payCashBalance   = document.getElementById('payCashBalance');
const payCardBalance   = document.getElementById('payCardBalance');
const payCashBtn       = document.getElementById('payCashBtn');
const payCardBtn       = document.getElementById('payCardBtn');
const payError         = document.getElementById('payError');

const GAUGE_LEN = 283;

function fmt(n) {
    return (parseFloat(n) || 0).toLocaleString('ro-RO', { maximumFractionDigits: 0 });
}

// Coduri multi-litere (EUR, RON) sunt sufix cu spațiu; simbolurile mono-char ($, €, £) sunt prefix.
function money(value, sym = state.sym) {
    const s = sym || '$';
    const v = fmt(value);
    return /^[A-Za-z]{2,}$/.test(s) ? `${v} ${s}` : `${s}${v}`;
}

function setGauge(pct) {
    pct = Math.max(0, Math.min(100, pct));
    gaugeFill.style.strokeDashoffset = GAUGE_LEN - (GAUGE_LEN * pct / 100);
    gaugeFill.style.stroke = pct > 50 ? '#00e676' : pct > 25 ? '#ffab00' : '#ff3d3d';
    const angle = -90 + (pct / 100) * 180;
    gaugeNeedle.setAttribute('transform', `rotate(${angle})`);
    gaugePct.textContent = `${Math.round(pct)}%`;
}

function refreshBalanceUI() {
    priceEl.textContent   = `${money(state.pricePerLitre)}/L`;
    cashEl.textContent    = money(state.cash);
    bankEl.textContent    = money(state.bank);
    balanceEl.textContent = money(state.balance);
}

function openFillHud(data) {
    state.phase          = 'filling';
    state.pumpId         = data.pumpId        ?? state.pumpId;
    state.pricePerLitre  = data.pricePerLitre ?? state.pricePerLitre;
    state.balance        = data.balance       ?? state.balance;
    state.cash           = data.cash          ?? state.cash;
    state.bank           = data.bank          ?? state.bank;
    state.currentFuelPct = data.fuelPct       ?? state.currentFuelPct;
    if (data.currencySymbol) state.sym = data.currencySymbol;
    state.holding = false;

    hudPumpId.textContent      = String(state.pumpId).padStart(2, '0');
    hudStatus.textContent      = SwI18n.t('vehicles.ui_waiting');
    hudStatus.className        = 'hud-status';
    holdIndicator.className    = 'hold-indicator';
    holdCaption.className      = 'hold-caption';
    holdCaption.textContent    = SwI18n.t('vehicles.ui_hold_to_refuel');
    hudProgressBar.style.width = '0%';
    hudLitres.textContent      = '0.00L';
    hudCost.textContent        = money(0);
    hudTankLevel.textContent   = `${Math.round(state.currentFuelPct)}%`;
    hudFundsWarn.classList.add('hidden');

    setGauge(state.currentFuelPct);
    refreshBalanceUI();
    setCableDistance(0);

    fillHud.classList.remove('hidden');
}

function updateBalance(data) {
    if (data.pricePerLitre != null)  state.pricePerLitre = data.pricePerLitre;
    if (data.balance       != null)  state.balance       = data.balance;
    if (data.cash          != null)  state.cash          = data.cash;
    if (data.bank          != null)  state.bank          = data.bank;
    if (data.currencySymbol)         state.sym           = data.currencySymbol;
    refreshBalanceUI();
}

function setHoldState(active) {
    state.holding = active;
    if (active) {
        holdIndicator.classList.add('active');
        holdCaption.classList.add('active');
        holdCaption.textContent = SwI18n.t('vehicles.ui_refuel_active');
        hudStatus.textContent   = SwI18n.t('vehicles.ui_in_progress');
        hudStatus.className     = 'hud-status active';
    } else {
        holdIndicator.classList.remove('active');
        holdCaption.classList.remove('active');
        holdCaption.textContent = SwI18n.t('vehicles.ui_hold_to_refuel');
        hudStatus.textContent   = SwI18n.t('vehicles.ui_waiting');
        hudStatus.className     = 'hud-status';
    }
}

function updateFill(data) {
    const filledL = data.filledLitres || 0;
    const fuelPct = data.fuelPct      ?? state.currentFuelPct;
    if (data.currencySymbol) state.sym = data.currencySymbol;

    hudProgressBar.style.width = `${Math.min(100, fuelPct)}%`;
    hudLitres.textContent      = `${filledL.toFixed(2)}L`;
    hudCost.textContent        = money(data.totalCost || 0);
    hudTankLevel.textContent   = `${Math.round(fuelPct)}%`;

    setGauge(fuelPct);
    setCableDistance(data.cableDistance || 0, data.maxCable || 6);
}

function setCableDistance(dist, maxDist = 6) {
    const pct = Math.min(100, (dist / maxDist) * 100);
    cableBar.style.width = `${pct}%`;
    if (pct >= 90) {
        cableBar.className      = 'cable-bar-fill crit';
        cableStatus.className   = 'cable-status crit';
        cableStatus.textContent = SwI18n.t('vehicles.ui_cable_critical');
    } else if (pct >= 65) {
        cableBar.className      = 'cable-bar-fill warn';
        cableStatus.className   = 'cable-status warn';
        cableStatus.textContent = SwI18n.t('vehicles.ui_cable_warning');
    } else {
        cableBar.className      = 'cable-bar-fill';
        cableStatus.className   = 'cable-status';
        cableStatus.textContent = SwI18n.t('vehicles.ui_cable_ok');
    }
}

function showInsufficientFunds() {
    hudFundsWarn.classList.remove('hidden');
    setHoldState(false);
    hudStatus.textContent = SwI18n.t('vehicles.ui_insufficient_funds');
    hudStatus.className   = 'hud-status warn';
}

function showCableSnap() {
    cableSnapEl.classList.remove('hidden');
    setTimeout(() => cableSnapEl.classList.add('hidden'), 2500);
}

function closeFillHud() {
    fillHud.classList.add('hidden');
    state.phase = null;
}

let lastPayCost = 0;

function openPayment(data) {
    const litres = data.litres || 0;
    const cost   = data.cost   || 0;
    const cash   = data.cash   || 0;
    const bank   = data.bank   || 0;
    if (data.currencySymbol) state.sym = data.currencySymbol;
    lastPayCost  = cost;

    paySummaryLitres.textContent = `${litres.toFixed(2)} L`;
    paySummaryCost.textContent   = money(cost);
    payCashBalance.textContent   = money(cash);
    payCardBalance.textContent   = money(bank);

    payCashBtn.classList.toggle('disabled', cash < cost);
    payCardBtn.classList.toggle('disabled', bank < cost);

    payError.classList.add('hidden');
    paymentModal.classList.remove('hidden');
    state.phase = 'payment';
}

function closePayment() {
    paymentModal.classList.add('hidden');
}

function paymentError(data) {
    payError.textContent = data.error || SwI18n.t('vehicles.ui_payment_failed');
    payError.classList.remove('hidden');
}

payCashBtn.addEventListener('click', () => {
    if (payCashBtn.classList.contains('disabled')) return;
    payError.classList.add('hidden');
    postNUI('fuel:pay', { method: 'cash' });
});
payCardBtn.addEventListener('click', () => {
    if (payCardBtn.classList.contains('disabled')) return;
    payError.classList.add('hidden');
    postNUI('fuel:pay', { method: 'card' });
});

// Re-randare stringuri generate din JS la schimbarea dictionarului (sw:i18n).
document.addEventListener('sw:i18n', () => {
    if (state.phase === 'filling') {
        setHoldState(state.holding);
    }
});

window.addEventListener('message', e => {
    const msg = e.data;
    if (!msg || !msg.action) return;

    switch (msg.action) {
        case 'fuel:openFillHud':       openFillHud(msg);          break;
        case 'fuel:updateBalance':     updateBalance(msg);        break;
        case 'fuel:holdState':         setHoldState(msg.active);  break;
        case 'fuel:updateFill':        updateFill(msg);           break;
        case 'fuel:insufficientFunds': showInsufficientFunds();   break;
        case 'fuel:cableSnap':
            showCableSnap();
            closeFillHud();
            break;
        case 'fuel:openPayment':
            closeFillHud();
            openPayment(msg);
            break;
        case 'fuel:paymentError':
            paymentError(msg);
            break;
        case 'fuel:complete':
        case 'fuel:close':
            closeFillHud();
            closePayment();
            break;
    }
});

if (!isFiveM) {
    document.body.style.background = '#0a0e14';
    state.sym = 'EUR';

    openFillHud({
        pumpId: 1,
        pricePerLitre: 3.5,
        balance: 45518940,
        cash: 45518940,
        bank: 0,
        fuelPct: 42,
        currencySymbol: 'EUR',
    });
}
