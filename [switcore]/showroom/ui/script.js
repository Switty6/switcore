
const isFiveM = typeof window.invokeNative !== 'undefined';

// Traducere prin helperul standard SwI18n (core/ui/i18n.js); fallback pe cheie.
function t(key, ...args) {
    return SwI18n.t(`showroom.${key}`, ...args);
}

const app             = document.getElementById('app');
const dealerName      = document.getElementById('dealerName');
const categoryList    = document.getElementById('categoryList');
const vehicleList     = document.getElementById('vehicleList');
const closeBtn        = document.getElementById('closeBtn');
const priceDisplay    = document.getElementById('priceDisplay');
const overlayName     = document.getElementById('overlayName');
const overlayCat      = document.getElementById('overlayCat');
const colorSwatches   = document.getElementById('colorSwatches');
const selectedColorDot  = document.getElementById('selectedColorDot');
const selectedColorName = document.getElementById('selectedColorName');
const plateInput      = document.getElementById('plateInput');
const plateHint       = document.getElementById('plateHint');
const payTabs         = document.querySelectorAll('.pay-tab');
const buyBtn          = document.getElementById('buyBtn');
const testDriveBtn    = document.getElementById('testDriveBtn');
const tdBanner        = document.getElementById('tdBanner');
const tdVehicle       = document.getElementById('tdVehicle');
const tdTimer         = document.getElementById('tdTimer');
const tdReturn        = document.getElementById('tdReturn');
const termSlider      = document.getElementById('termSlider');
const termLabel       = document.getElementById('termLabel');

let state = {
    catalog:          [],
    selectedItem:     null,
    activeCategory:   'all',
    activeMethod:     'cash',
    selectedColor:    null,
    interestRate:     0.08,
    financeMinPrice:  5000,
    testDriveDuration: 5,
};

let timerInterval = null;

function postNUI(action, data = {}) {
    if (isFiveM) {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
    } else {
        console.log('[NUI]', action, data);
    }
}

// `r` is the GTA V paint index passed to SetVehicleColours
// `key` indexeaza showroom.colors.* in dictionar; numele e fallback.
const COLORS = [
    { key: 'arctic_white',   name: 'Alb Arctic',     hex: '#e8edf2', r: 0 },
    { key: 'pure_white',     name: 'Alb Pur',        hex: '#f8f8f8', r: 1 },
    { key: 'black',          name: 'Negru',          hex: '#111418', r: 12 },
    { key: 'anthracite',     name: 'Antracit',       hex: '#2a2e35', r: 147 },
    { key: 'graphite_gray',  name: 'Gri Grafit',     hex: '#4b5260', r: 68 },
    { key: 'silver_gray',    name: 'Gri Argintiu',   hex: '#8b939e', r: 4 },
    { key: 'classic_red',    name: 'Roșu Clasic',    hex: '#c0392b', r: 27 },
    { key: 'torino_red',     name: 'Roșu Torino',    hex: '#e53935', r: 28 },
    { key: 'wine_red',       name: 'Roșu Vin',       hex: '#7b1a2e', r: 30 },
    { key: 'orange',         name: 'Portocaliu',     hex: '#e65100', r: 38 },
    { key: 'race_yellow',    name: 'Galben Cursa',   hex: '#f9c20a', r: 88 },
    { key: 'gold',           name: 'Auriu',          hex: '#d4a017', r: 99 },
    { key: 'electric_green', name: 'Verde Electric', hex: '#1de73b', r: 53 },
    { key: 'army_green',     name: 'Verde Army',     hex: '#3a5940', r: 56 },
    { key: 'petrol_green',   name: 'Verde Petrol',   hex: '#0d5c4e', r: 62 },
    { key: 'cobalt_blue',    name: 'Albastru Cobalt',hex: '#0a3d91', r: 63 },
    { key: 'police_blue',    name: 'Albastru Police',hex: '#1565c0', r: 70 },
    { key: 'sky_blue',       name: 'Albastru Sky',   hex: '#0288d1', r: 71 },
    { key: 'neon_cyan',      name: 'Cyan Neon',      hex: '#00b4ff', r: 73 },
    { key: 'royal_purple',   name: 'Mov Royal',      hex: '#6a1b9a', r: 142 },
    { key: 'hot_pink',       name: 'Roz Hot',        hex: '#e91e8c', r: 135 },
    { key: 'wood_brown',     name: 'Maro Lemn',      hex: '#5d3a1a', r: 120 },
    { key: 'bronze',         name: 'Bronz',          hex: '#8b6914', r: 118 },
    { key: 'metal_silver',   name: 'Argintiu Metal', hex: '#b0b8c4', r: 5  },
    { key: 'champagne',      name: 'Champagne',      hex: '#d4c5a0', r: 104 },
];

// numele tradus al unei culori, cu fallback pe numele RO din COLORS
function colorName(c) {
    const translated = SwI18n.t(`showroom.colors.${c.key}`);
    return translated === `showroom.colors.${c.key}` ? c.name : translated;
}

function buildColorSwatches() {
    colorSwatches.innerHTML = '';
    COLORS.forEach((c, i) => {
        const sw = document.createElement('button');
        sw.className = 'swatch' + (i === 0 ? ' active' : '');
        sw.style.background = c.hex;
        sw.title = colorName(c);
        sw.dataset.idx = String(i);
        sw.addEventListener('click', () => selectColor(i));
        colorSwatches.appendChild(sw);
    });
    selectColor(0);
}

function selectColor(idx) {
    state.selectedColor = COLORS[idx];
    colorSwatches.querySelectorAll('.swatch').forEach((s, i) => {
        s.classList.toggle('active', i === idx);
    });
    selectedColorDot.style.background = COLORS[idx].hex;
    selectedColorName.textContent = colorName(COLORS[idx]);

    postNUI('previewColor', { colorIndex: COLORS[idx].r });
}

plateInput.addEventListener('input', () => {
    plateInput.value = plateInput.value.toUpperCase().replace(/[^A-Z0-9-]/g, '');
    validatePlate();
});

function validatePlate() {
    const val = plateInput.value.trim();
    if (val.length === 0) {
        plateHint.textContent = '';
        return true;
    }
    if (val.length < 3) {
        plateHint.textContent = t('ui.plate_hint_min');
        return false;
    }
    plateHint.textContent = '';
    return true;
}

function getPlate() {
    return plateInput.value.trim() || null;
}

function buildCategories() {
    const allLabel = t('ui.category_all');
    const cats = ['all', ...new Set(state.catalog.map(c => c.category))];
    categoryList.innerHTML = '';
    cats.forEach(cat => {
        const isAll = cat === 'all';
        const btn = document.createElement('button');
        btn.className = 'cat-btn' + (isAll ? ' active' : '');
        btn.textContent = isAll ? allLabel : cat;
        btn.dataset.cat = cat;
        btn.addEventListener('click', () => {
            document.querySelectorAll('.cat-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.activeCategory = btn.dataset.cat;
            renderVehicleList();
        });
        categoryList.appendChild(btn);
    });
}

function renderVehicleList() {
    const items = state.catalog.filter(c =>
        state.activeCategory === 'all' || c.category === state.activeCategory
    );

    vehicleList.innerHTML = '';

    if (items.length === 0) {
        vehicleList.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-3);font-size:12px;">${esc(t('ui.no_vehicle_available'))}</div>`;
        return;
    }

    items.forEach(item => {
        const el = document.createElement('div');
        el.className = 'vehicle-item' + (state.selectedItem?.id === item.id ? ' active' : '');
        el.innerHTML = `
            <div class="vi-left">
                <div class="vi-label">${esc(item.label)}</div>
                <div class="vi-cat">${esc(item.category)} · ${esc(item.model)}</div>
            </div>
            <div class="vi-right">
                <div class="vi-price">$${fmt(item.price)}</div>
                ${item.vip_only ? `<div class="vi-badge">${esc(t('ui.vip_badge'))}</div>` : ''}
            </div>
        `;
        el.addEventListener('click', () => selectVehicle(item));
        vehicleList.appendChild(el);
    });
}

function selectVehicle(item) {
    state.selectedItem = item;
    renderVehicleList();

    overlayName.textContent = item.label;
    overlayCat.textContent  = item.category;

    priceDisplay.textContent = '$' + fmt(item.price);
    document.getElementById('cashTotal').textContent = '$' + fmt(item.price);
    document.getElementById('bankTotal').textContent = '$' + fmt(item.price);
    document.getElementById('financeTotal').textContent = '$' + fmt(item.price);
    updateFinance();

    const unavail = document.getElementById('financeUnavail');
    const finBody  = document.getElementById('financeBody');
    const ineligible = !item.finance_eligible || parseFloat(item.price) < state.financeMinPrice;
    unavail.classList.toggle('hidden', !ineligible);
    finBody.classList.toggle('hidden', ineligible);

    if (!plateInput.value) {
        plateInput.placeholder = 'SWC-' + String(item.id).padStart(5, '0');
    }

    postNUI('selectVehicle', {
        model:      item.model,
        colorIndex: state.selectedColor?.r ?? 0,
    });
}

payTabs.forEach(tab => {
    tab.addEventListener('click', () => {
        payTabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        state.activeMethod = tab.dataset.method;

        ['cash','bank','finance'].forEach(m => {
            document.getElementById('payBody-' + m).classList.toggle('hidden', m !== state.activeMethod);
        });
    });
});

termSlider.addEventListener('input', updateFinance);

function updateFinance() {
    if (!state.selectedItem) return;
    const price  = parseFloat(state.selectedItem.price);
    const months = parseInt(termSlider.value);
    termLabel.textContent = t('ui.term_months', months);

    const mr = state.interestRate / 12;
    const monthly = mr === 0
        ? price / months
        : price * (mr * Math.pow(1 + mr, months)) / (Math.pow(1 + mr, months) - 1);

    const total = monthly * months;

    document.getElementById('monthlyRate').textContent  = t('ui.monthly_rate_value', fmt(Math.ceil(monthly)));
    document.getElementById('totalRepay').textContent   = '$' + fmt(Math.round(total));
    document.getElementById('interestLabel').textContent = t('ui.interest_percent', Math.round(state.interestRate * 100));
}

buyBtn.addEventListener('click', () => {
    if (!state.selectedItem) return;
    if (!validatePlate()) return;

    buyBtn.disabled = true;
    // Plasa de siguranta: daca serverul nu raspunde (eroare neasteptata), reactivam
    // butonul ca sa nu ramana blocat permanent.
    clearTimeout(buyBtn._safetyTimer);
    buyBtn._safetyTimer = setTimeout(function() { buyBtn.disabled = false; }, 8000);
    postNUI('purchaseVehicle', {
        catalogId:     state.selectedItem.id,
        paymentMethod: state.activeMethod,
        termMonths:    parseInt(termSlider.value),
        customPlate:   getPlate(),
        colorIndex:    state.selectedColor?.r ?? 0,
    });
});

testDriveBtn.addEventListener('click', () => {
    if (!state.selectedItem) return;
    postNUI('startTestDrive', { catalogId: state.selectedItem.id });
    closeUI();
});

closeBtn.addEventListener('click', closeUI);
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeUI(); });

function closeUI() {
    app.classList.add('hidden');
    postNUI('close');
}

function startBanner(label, durationSecs) {
    tdVehicle.textContent = label;
    tdBanner.classList.remove('hidden');
    if (timerInterval) clearInterval(timerInterval);
    const end = Date.now() + durationSecs * 1000;
    timerInterval = setInterval(() => {
        const rem = Math.max(0, Math.floor((end - Date.now()) / 1000));
        const m = String(Math.floor(rem / 60)).padStart(2, '0');
        const s = String(rem % 60).padStart(2, '0');
        tdTimer.textContent = `${m}:${s}`;
        tdTimer.classList.toggle('urgent', rem <= 60);
        if (rem === 0) clearInterval(timerInterval);
    }, 1000);
}

function stopBanner() {
    if (timerInterval) clearInterval(timerInterval);
    tdBanner.classList.add('hidden');
}

tdReturn.addEventListener('click', () => {
    postNUI('endTestDrive');
    stopBanner();
});

function open(data) {
    Object.assign(state, {
        catalog:           data.catalog || [],
        financeMinPrice:   data.financeMinPrice  || 5000,
        testDriveDuration: data.testDriveDuration || 5,
        interestRate:      0.08,
        selectedItem:      null,
        activeCategory:    'all',
        activeMethod:      'cash',
    });

    dealerName.textContent = data.dealership?.name || t('ui.showroom_fallback');
    plateInput.value = '';
    plateHint.textContent = '';
    overlayName.textContent = '-';
    overlayCat.textContent  = '-';
    priceDisplay.textContent = '-';

    buildColorSwatches();
    buildCategories();
    renderVehicleList();

    payTabs.forEach(t => t.classList.toggle('active', t.dataset.method === 'cash'));
    ['cash','bank','finance'].forEach(m => {
        document.getElementById('payBody-' + m).classList.toggle('hidden', m !== 'cash');
    });

    buyBtn.disabled = false;

    if (data.activeDrive) {
        const expMs = new Date(data.activeDrive.expires_at).getTime();
        const remSecs = Math.max(0, Math.floor((expMs - Date.now()) / 1000));
        startBanner(data.activeDrive.label, remSecs);
    }

    app.classList.remove('hidden');

    if (state.catalog.length > 0) selectVehicle(state.catalog[0]);
}

// re-randare a stringurilor generate din JS la schimbarea dictionarului
document.addEventListener('sw:i18n', () => {
    if (state.catalog.length > 0) {
        buildCategories();
        renderVehicleList();
        if (state.selectedItem) updateFinance();
    }
    // actualizeaza titlurile swatch-urilor si numele culorii selectate
    if (state.selectedColor) {
        colorSwatches.querySelectorAll('.swatch').forEach((s, i) => {
            if (COLORS[i]) s.title = colorName(COLORS[i]);
        });
        selectedColorName.textContent = colorName(state.selectedColor);
    }
});

window.addEventListener('message', e => {
    const msg = e.data;
    if (!msg?.action) return;
    switch (msg.action) {
        case 'open':           open(msg); break;
        case 'purchaseError':  clearTimeout(buyBtn._safetyTimer); buyBtn.disabled = false; break;
        case 'close':          closeUI(); break;
        case 'testDriveStarted':
            startBanner(msg.label, msg.durationSecs);
            break;
        case 'testDriveEnded':
            stopBanner();
            break;
    }
});

function esc(s) {
    return String(s || '')
        .replace(/&/g,'&amp;').replace(/</g,'&lt;')
        .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
function fmt(n) {
    return (parseFloat(n) || 0).toLocaleString('ro-RO', { maximumFractionDigits: 0 });
}

if (!isFiveM) {
    const center = document.querySelector('.center-area');
    const ph = document.createElement('div');
    ph.className = 'center-placeholder';
    ph.innerHTML = `<svg class="car-silhouette" viewBox="0 0 800 300" fill="white" xmlns="http://www.w3.org/2000/svg">
        <path d="M80 200 L120 200 L140 160 L200 120 L340 100 L460 100 L560 130 L660 160 L700 200 L720 200 L720 220 L80 220 Z"/>
        <ellipse cx="180" cy="222" rx="40" ry="40"/>
        <ellipse cx="600" cy="222" rx="40" ry="40"/>
        <path d="M210 140 L250 110 L380 105 L450 105 L530 130 L520 140 Z" fill="rgba(0,180,255,0.15)"/>
    </svg>`;
    center.insertBefore(ph, center.firstChild);

    open({
        dealership: { id: 1, name: 'Premium Deluxe Motorsport', code: 'PDM' },
        catalog: [
            { id:1,  model:'sultan',   label:'Karin Sultan RS',      category:'Sport',  price:35000,  finance_eligible:true,  vip_only:false },
            { id:2,  model:'jester',   label:'Dinka Jester Classic', category:'Sport',  price:42000,  finance_eligible:true,  vip_only:false },
            { id:3,  model:'elegy2',   label:'Annis Elegy RH8',      category:'Sport',  price:58000,  finance_eligible:true,  vip_only:false },
            { id:4,  model:'adder',    label:'Truffade Adder',       category:'Super',  price:150000, finance_eligible:true,  vip_only:false },
            { id:5,  model:'t20',      label:'Progen T20',           category:'Super',  price:220000, finance_eligible:true,  vip_only:true  },
            { id:6,  model:'zentorno', label:'Pegassi Zentorno',     category:'Super',  price:185000, finance_eligible:true,  vip_only:false },
            { id:7,  model:'jackal',   label:'Obey Jackal',          category:'Sedan',  price:25000,  finance_eligible:true,  vip_only:false },
            { id:8,  model:'granger',  label:'Declasse Granger',     category:'SUV',    price:32000,  finance_eligible:true,  vip_only:false },
            { id:9,  model:'bf400',    label:'BF400',                category:'Moto',   price:14000,  finance_eligible:false, vip_only:false },
            { id:10, model:'phantom',  label:'Jobuilt Phantom',      category:'Camion', price:62000,  finance_eligible:true,  vip_only:false },
        ],
        activeDrive:       null,
        financeMinPrice:   5000,
        testDriveDuration: 5,
    });
}
