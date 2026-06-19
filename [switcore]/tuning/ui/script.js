const isFiveM = typeof window.invokeNative !== 'undefined';

function nuiPost(action, data = {}) {
    if (isFiveM) {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(() => {});
    } else {
        console.log('[NUI]', action, data);
        handleDevNuiCallback(action, data);
    }
}

// Helper i18n cu fallback pe textul romanesc; SwI18n e injectat de core/ui/i18n.js
function T(key, fallback) {
    if (window.SwI18n) {
        const v = SwI18n.get(key);
        if (typeof v === 'string') return v;
    }
    return fallback !== undefined ? fallback : key;
}

function Tf(key, fallback) {
    const args = Array.prototype.slice.call(arguments, 2);
    let value = T(key, fallback);
    args.forEach(function(arg, i) {
        value = value.split('{' + (i + 1) + '}').join(String(arg));
    });
    return value;
}

// Eticheta tip jante din dict (fallback pe WHEEL_TYPE_LABELS), cu fallback generic "Tip {n}"
function wheelTypeLabel(typeIdx) {
    return T('tuning.wheel_type.' + typeIdx, WHEEL_TYPE_LABELS[typeIdx] || Tf('tuning.ui.type_generic', 'Tip ' + typeIdx, typeIdx));
}

const state = {
    vehicle:       null,
    config:        null,
    activeCatId:   null,
    cart:          {},
    payMethod:     'cash',
    originalMods:  {},
    previewMods:   {},
    colorPrimary:  '#FF0000',
    colorSecondary:'#000000',
    colorPearl:    0,
    wheelType:     null,
    wheelIndex:    -1,
    wheelCount:    0,
};

const PEARL_PALETTE = [
    { idx: 0,   name: 'Negru',         hex: '#0d1116' },
    { idx: 1,   name: 'Grafit',        hex: '#1c1d21' },
    { idx: 5,   name: 'Antracit',      hex: '#2e353b' },
    { idx: 6,   name: 'Argint Mat',    hex: '#7c8186' },
    { idx: 11,  name: 'Argint Pur',    hex: '#cfd0d4' },
    { idx: 27,  name: 'Roșu Sport',    hex: '#9e1b1b' },
    { idx: 28,  name: 'Roșu Lumânare', hex: '#7e0e1f' },
    { idx: 36,  name: 'Portocaliu',    hex: '#d36b00' },
    { idx: 38,  name: 'Auriu',         hex: '#b89968' },
    { idx: 49,  name: 'Verde Pădure',  hex: '#102f1d' },
    { idx: 51,  name: 'Verde Lime',    hex: '#a2c623' },
    { idx: 62,  name: 'Albastru Navy', hex: '#1a2a52' },
    { idx: 64,  name: 'Albastru Galaxy',hex:'#3a64a7' },
    { idx: 70,  name: 'Albastru Cer',  hex: '#4a8ad6' },
    { idx: 88,  name: 'Galben',        hex: '#f4c81a' },
    { idx: 89,  name: 'Galben Race',   hex: '#f7da57' },
    { idx: 111, name: 'Alb Cremă',     hex: '#ece6cf' },
    { idx: 112, name: 'Alb Pur',       hex: '#f2f2f2' },
    { idx: 132, name: 'Roz',           hex: '#d36a96' },
    { idx: 145, name: 'Violet',        hex: '#3d2c5d' },
];

const WHEEL_TYPE_LABELS = {
    0: 'Sport',
    1: 'Muscle',
    2: 'Lowrider',
    3: 'SUV',
    4: 'Offroad',
    5: 'Tuner',
    6: 'Bike',
    7: 'High-End',
};

const CATEGORY_ZONES = {
    engine:       'zone-engine',
    turbo:        'zone-engine',
    transmission: 'zone-transmission',
    brakes:       'zone-brakes',
    suspension:   'zone-suspension',
    armor:        'zone-armor',
    wheels:       'zone-wheels',
    xenon:        'zone-lights',
    color:        'zone-body',
    livery:       'zone-body',
};

const CAT_ICONS = {
    engine:       `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="10" rx="2"/><path d="M7 7V5m10 2V5M2 12h2m18 0h-2"/></svg>`,
    brakes:       `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/></svg>`,
    transmission: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="5" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="5" r="2"/><circle cx="19" cy="19" r="2"/><path d="M7 5h8M5 7v10M19 7v10"/></svg>`,
    turbo:        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2a10 10 0 1 0 10 10"/><path d="M12 6v6l4 2"/></svg>`,
    suspension:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="2" x2="12" y2="22"/><path d="M8 6h8M8 12h8M8 18h8"/></svg>`,
    armor:        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`,
    xenon:        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.22 4.22l1.42 1.42m12.72 12.72 1.42 1.42M2 12h2m16 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>`,
    wheels:       `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/><path d="M12 3v4M12 17v4M3 12h4m10 0h4"/></svg>`,
    color:        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 20h.01M7 20v-4a5 5 0 0 1 10 0v4m0 0h2m-2 0a2 2 0 0 1 4 0"/><circle cx="12" cy="8" r="3"/></svg>`,
    livery:       `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>`,
};

function fmt(amount, code) {
    code = code || 'USD';
    if (!amount && amount !== 0) return '-';
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: code, maximumFractionDigits: 0 }).format(amount);
}

function getMods() {
    if (!state.vehicle) return {};
    const raw = state.vehicle.modifications;
    if (!raw) return {};
    if (typeof raw === 'string') { try { return JSON.parse(raw); } catch (e) { return {}; } }
    return raw;
}

function getInstalledTier(catId) {
    const mods = getMods();
    const t = mods[catId];
    return (t !== undefined && t !== null) ? Number(t) : 0;
}

function isVipOnly(catId, tier) {
    const list = state.config && state.config.vipOnlyMods && state.config.vipOnlyMods[catId];
    return !!(list && list.includes(tier));
}

function calcCost(catId, tier) {
    const pt   = state.config && state.config.priceTable;
    const code = (state.config && state.config.currencyCode) || 'USD';
    if (!pt || !pt[catId]) return { raw: 0, display: T('tuning.ui.free', 'Gratuit') };

    const targetEntry  = pt[catId][tier];
    if (!targetEntry)  return { raw: 0, display: T('tuning.ui.free', 'Gratuit') };

    const currentTier  = getInstalledTier(catId);
    const currentEntry = pt[catId][currentTier];
    const currentPrice = (currentTier > 0 && currentEntry) ? (currentEntry.price || 0) : 0;
    let cost = Math.max(0, (targetEntry.price || 0) - currentPrice);

    if (cost > 0 && state.config && state.config.isVip) {
        cost = Math.floor(cost * (1.0 - (state.config.vipDiscount || 0)));
    }

    return { raw: cost, display: cost === 0 ? T('tuning.ui.free', 'Gratuit') : fmt(cost, code) };
}

function openUI(vehicle, config) {
    state.vehicle  = vehicle;
    state.config   = config;
    state.cart     = {};
    state.payMethod = 'cash';

    const mods = getMods();
    state.originalMods = Object.assign({}, mods);
    state.previewMods  = Object.assign({}, mods);

    document.getElementById('vehicleName').textContent  = vehicle.name  || vehicle.model || '-';
    document.getElementById('vehicleModel').textContent = vehicle.model || '-';

    const shopName = (config.shopCode || 'LS Customs').replace(/_/g, ' - ');
    document.getElementById('shopName').textContent     = shopName;
    document.getElementById('vehiclePlate').textContent = vehicle.plate || '-';

    const vipBadge = document.getElementById('vipBadge');
    if (config.isVip) vipBadge.classList.remove('hidden');
    else              vipBadge.classList.add('hidden');

    setPayMethod('cash');
    buildCatList();

    const firstCat = config.categories && config.categories[0];
    if (firstCat) selectCat(firstCat.id);

    renderCartBar();

    document.getElementById('app').classList.remove('hidden');

    if (!isFiveM) injectCarSvg();
}

function closeUI() {
    nuiPost('restoreAll', { mods: state.originalMods });
    document.getElementById('app').classList.add('hidden');
    state.vehicle     = null;
    state.config      = null;
    state.cart        = {};
    state.activeCatId = null;
    clearZoneHighlight();
    nuiPost('closeUI', {});
}

function buildCatList() {
    const nav  = document.getElementById('catList');
    nav.innerHTML = '';

    const cats = (state.config && state.config.categories) || [];
    cats.forEach(function(cat) {
        const div = document.createElement('div');
        div.className    = 'cat-item';
        div.dataset.catId = cat.id;

        const iconSvg = CAT_ICONS[cat.id] || '';
        const catLabel = T('tuning.category.' + cat.id, cat.label);
        div.innerHTML = `<span class="cat-icon">${iconSvg}</span><span class="cat-label">${catLabel}</span>`;
        div.addEventListener('click', function() { selectCat(cat.id); });
        nav.appendChild(div);
    });

    refreshCatBadges();
}

function refreshCatBadges() {
    const cats = (state.config && state.config.categories) || [];
    cats.forEach(function(cat) {
        const el = document.querySelector('.cat-item[data-cat-id="' + cat.id + '"]');
        if (!el) return;

        el.querySelectorAll('.cat-installed, .cat-in-cart').forEach(function(b) { b.remove(); });

        if (state.cart[cat.id]) {
            const b = document.createElement('span');
            b.className   = 'cat-in-cart';
            b.textContent = '•';
            el.appendChild(b);
        } else {
            const installed = getInstalledTier(cat.id);
            if (installed > 0) {
                const b = document.createElement('span');
                b.className   = 'cat-installed';
                b.textContent = 'T' + installed;
                el.appendChild(b);
            }
        }
    });
}

function selectCat(catId) {
    state.activeCatId = catId;

    document.querySelectorAll('.cat-item').forEach(function(el) {
        el.classList.toggle('active', el.dataset.catId === catId);
    });

    const cat = state.config && state.config.categories && state.config.categories.find(function(c) { return c.id === catId; });
    if (!cat) return;

    document.getElementById('modPanelTitle').textContent = T('tuning.category.' + cat.id, cat.label);
    document.getElementById('modPanelDesc').textContent  = '';

    highlightZone(catId);
    buildModList(cat);

    if (state.cart[catId] && cat.modType !== 'color') {
        nuiPost('previewMod', { category: catId, tier: state.cart[catId].tier });
    }
}

function highlightZone(catId) {
    clearZoneHighlight();
    const zoneId = CATEGORY_ZONES[catId];
    const label  = document.getElementById('zoneLabel');

    if (zoneId) {
        const zone = document.getElementById(zoneId);
        if (zone) zone.classList.add('active');
    }

    const cat = state.config && state.config.categories && state.config.categories.find(function(c) { return c.id === catId; });
    if (cat) {
        label.textContent = T('tuning.category.' + cat.id, cat.label);
        label.classList.add('visible');
    } else {
        label.classList.remove('visible');
    }
}

function clearZoneHighlight() {
    document.querySelectorAll('.car-zone').forEach(function(z) { z.classList.remove('active'); });
    const zl = document.getElementById('zoneLabel');
    if (zl) zl.classList.remove('visible');
}

function buildModList(cat) {
    const list = document.getElementById('modList');
    list.innerHTML = '';

    if (cat.modType === 'color') {
        buildColorPicker(list, cat);
    } else if (cat.modType === 'livery') {
        buildLiveryList(list, cat);
    } else if (cat.modType === 'wheel') {
        buildWheelPicker(list, cat);
    } else {
        buildTierList(list, cat);
    }
}

function buildTierList(container, cat) {
    const labels    = (state.config && state.config.tierLabels && state.config.tierLabels[cat.id]) || {};
    const maxTier   = cat.maxTier || 4;
    const cartItem  = state.cart[cat.id];
    const installed = getInstalledTier(cat.id);

    appendTierRow(container, cat, 0, {
        name:  T('tuning.tier.' + cat.id + '.0.label', (labels[0] && labels[0].label) || T('tuning.ui.stock', 'Stock')),
        desc:  T('tuning.tier.' + cat.id + '.0.desc',  (labels[0] && labels[0].desc)  || T('tuning.ui.stock_desc', 'Configurație originală')),
        cost:  { raw: 0, display: T('tuning.ui.free', 'Gratuit') },
        installed: installed,
        cartItem:  cartItem,
    });

    for (var tier = 1; tier <= maxTier; tier++) {
        var costObj = calcCost(cat.id, tier);
        appendTierRow(container, cat, tier, {
            name:  T('tuning.tier.' + cat.id + '.' + tier + '.label', (labels[tier] && labels[tier].label) || Tf('tuning.ui.tier_generic', 'Tier ' + tier, tier)),
            desc:  T('tuning.tier.' + cat.id + '.' + tier + '.desc',  (labels[tier] && labels[tier].desc)  || ''),
            cost:  costObj,
            installed: installed,
            cartItem:  cartItem,
        });
    }
}

function appendTierRow(container, cat, tier, opts) {
    var name = opts.name, desc = opts.desc, cost = opts.cost;
    var installed = opts.installed, cartItem = opts.cartItem;

    var inCart  = !!(cartItem && cartItem.tier === tier);
    var isCurr  = installed === tier;
    var vipOnly = isVipOnly(cat.id, tier);
    var locked  = vipOnly && !(state.config && state.config.isVip);

    var row = document.createElement('div');
    row.className = 'mod-row' + (isCurr ? ' is-current' : '') + (inCart ? ' in-cart' : '') + (locked ? ' locked' : '');
    row.dataset.tier = tier;

    var badges = [];
    if (isCurr)  badges.push('<span class="mod-badge badge-current">' + T('tuning.ui.badge_installed', 'Instalat') + '</span>');
    if (inCart)  badges.push('<span class="mod-badge badge-incart">' + T('tuning.ui.badge_in_cart', 'În coș') + '</span>');
    if (vipOnly) badges.push('<span class="mod-badge badge-vip">' + T('tuning.ui.badge_vip', 'VIP') + '</span>');

    var priceClass = '';
    if (tier === 0)         priceClass = 'owned';
    else if (cost.raw === 0) priceClass = 'free';

    var cartIconAdd = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';
    var cartIconRem = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/></svg>';

    row.innerHTML =
        '<div class="mod-tier-badge">' + (tier === 0 ? '○' : tier) + '</div>' +
        '<div class="mod-info">' +
            '<div class="mod-name">' + name + '</div>' +
            (desc ? '<div class="mod-desc">' + desc + '</div>' : '') +
            (badges.length ? '<div class="mod-badges">' + badges.join('') + '</div>' : '') +
        '</div>' +
        '<div class="mod-right">' +
            '<span class="mod-price ' + priceClass + '">' + cost.display + '</span>' +
            '<button class="btn-cart ' + (inCart ? 'in-cart' : '') + '" data-tier="' + tier + '"' +
                (locked ? ' disabled' : '') + '>' +
                (inCart ? cartIconRem : cartIconAdd) +
            '</button>' +
        '</div>';

    var catId = cat.id;
    var tierVal = tier;
    var costRaw = cost.raw;
    var nameVal = name;

    row.addEventListener('click', function(e) {
        if (e.target.closest('.btn-cart')) return;
        if (locked) return;
        previewTier(cat, tierVal);
    });

    row.querySelector('.btn-cart').addEventListener('click', function(e) {
        e.stopPropagation();
        if (locked) return;
        if (inCart) {
            removeFromCart(catId);
        } else {
            addToCart(catId, tierVal, nameVal, costRaw);
            previewTier(cat, tierVal);
        }
    });

    container.appendChild(row);
}

function buildColorPicker(container, cat) {
    var mods   = getMods();
    var code   = (state.config && state.config.currencyCode) || 'USD';
    var cost   = (state.config && state.config.colorCost) || 500;
    var inCart = !!state.cart['color'];

    state.colorPrimary   = mods['color_primary']   || '#FF0000';
    state.colorSecondary = mods['color_secondary'] || '#000000';
    state.colorPearl     = (mods['color_pearl'] !== undefined && mods['color_pearl'] !== null) ? Number(mods['color_pearl']) : 0;

    var pearlGrid = PEARL_PALETTE.map(function(p) {
        var sel = (state.colorPearl === p.idx) ? ' selected' : '';
        return '<button class="pearl-swatch' + sel + '" data-idx="' + p.idx +
               '" title="' + T('tuning.pearl.' + p.idx, p.name) + '" style="background:' + p.hex + '"></button>';
    }).join('');

    container.innerHTML =
        '<div class="mod-section-label">' + T('tuning.ui.color_primary_section', 'Culoare Primară') + '</div>' +
        '<div class="color-row">' +
            '<span class="color-row-label">' + T('tuning.ui.color_primary_label', 'Primară') + '</span>' +
            '<div class="color-swatch-wrap">' +
                '<div class="color-swatch" id="colorSwatchPrimary" style="background:' + state.colorPrimary + '"></div>' +
                '<input type="color" class="color-picker-input" id="pickerPrimary" value="' + state.colorPrimary + '">' +
            '</div>' +
            '<span class="color-hex-val" id="hexPrimary">' + state.colorPrimary.toUpperCase() + '</span>' +
        '</div>' +
        '<div class="mod-section-label">' + T('tuning.ui.color_secondary_section', 'Culoare Secundară') + '</div>' +
        '<div class="color-row">' +
            '<span class="color-row-label">' + T('tuning.ui.color_secondary_label', 'Secundară') + '</span>' +
            '<div class="color-swatch-wrap">' +
                '<div class="color-swatch" id="colorSwatchSecondary" style="background:' + state.colorSecondary + '"></div>' +
                '<input type="color" class="color-picker-input" id="pickerSecondary" value="' + state.colorSecondary + '">' +
            '</div>' +
            '<span class="color-hex-val" id="hexSecondary">' + state.colorSecondary.toUpperCase() + '</span>' +
        '</div>' +
        '<div class="mod-section-label">' + T('tuning.ui.pearl_section', 'Pearlescent') + ' <span style="font-weight:500;opacity:0.7;font-size:11px;">' + T('tuning.ui.pearl_hint', '(luciu suprapus peste vopsea)') + '</span></div>' +
        '<div class="pearl-grid" id="pearlGrid">' + pearlGrid + '</div>' +
        '<div class="color-row" style="border-top:1px solid var(--border);margin-top:8px;padding-top:12px;">' +
            '<span class="color-row-label" style="color:var(--text-1);font-weight:700;">' + T('tuning.ui.paint_cost', 'Cost vopsire') + '</span>' +
            '<span style="flex:1;font-size:13px;font-weight:900;color:var(--accent);">' + fmt(cost, code) + '</span>' +
            '<button class="btn-cart-color' + (inCart ? ' in-cart' : '') + '" id="btnCartColor">' +
                (inCart ? T('tuning.ui.remove_from_cart', 'Scoate din coș') : T('tuning.ui.add_to_cart', 'Adaugă în coș')) +
            '</button>' +
        '</div>';

    Array.prototype.forEach.call(document.querySelectorAll('#pearlGrid .pearl-swatch'), function(btn) {
        btn.addEventListener('click', function() {
            state.colorPearl = parseInt(btn.dataset.idx, 10) || 0;
            Array.prototype.forEach.call(document.querySelectorAll('#pearlGrid .pearl-swatch'), function(b) {
                b.classList.remove('selected');
            });
            btn.classList.add('selected');
            nuiPost('previewColor', {
                colorPrimary:   state.colorPrimary,
                colorSecondary: state.colorSecondary,
                colorPearl:     state.colorPearl,
            });
            if (state.cart['color']) {
                state.cart['color'].colorPearl = state.colorPearl;
            }
        });
    });

    document.getElementById('pickerPrimary').addEventListener('input', function(e) {
        state.colorPrimary = e.target.value;
        document.getElementById('colorSwatchPrimary').style.background = state.colorPrimary;
        document.getElementById('hexPrimary').textContent = state.colorPrimary.toUpperCase();
        nuiPost('previewColor', { colorPrimary: state.colorPrimary, colorSecondary: state.colorSecondary, colorPearl: state.colorPearl });
        if (state.cart['color']) {
            state.cart['color'].colorPrimary   = state.colorPrimary;
            state.cart['color'].colorSecondary = state.colorSecondary;
            state.cart['color'].colorPearl     = state.colorPearl;
        }
    });

    document.getElementById('pickerSecondary').addEventListener('input', function(e) {
        state.colorSecondary = e.target.value;
        document.getElementById('colorSwatchSecondary').style.background = state.colorSecondary;
        document.getElementById('hexSecondary').textContent = state.colorSecondary.toUpperCase();
        nuiPost('previewColor', { colorPrimary: state.colorPrimary, colorSecondary: state.colorSecondary, colorPearl: state.colorPearl });
        if (state.cart['color']) {
            state.cart['color'].colorPrimary   = state.colorPrimary;
            state.cart['color'].colorSecondary = state.colorSecondary;
            state.cart['color'].colorPearl     = state.colorPearl;
        }
    });

    var catRef = cat;
    var costVal = cost;
    document.getElementById('btnCartColor').addEventListener('click', function() {
        if (state.cart['color']) {
            removeFromCart('color');
        } else {
            addToCart('color', 0, T('tuning.ui.paint_label', 'Vopsire'), costVal, {
                colorPrimary:   state.colorPrimary,
                colorSecondary: state.colorSecondary,
                colorPearl:     state.colorPearl,
            });
        }
        buildColorPicker(container, catRef);
    });
}

function buildWheelPicker(container, cat) {
    container.innerHTML = '';

    var labels    = (state.config && state.config.tierLabels && state.config.tierLabels[cat.id]) || {};
    var maxTier   = cat.maxTier || 7;
    var installed = getInstalledTier(cat.id);
    var installedIdx = getMods()['wheels_index'];
    if (installedIdx === undefined || installedIdx === null) installedIdx = -1;
    installedIdx = Number(installedIdx);

    var cartItem = state.cart['wheels'];
    var selectedType = (cartItem && cartItem.tier !== undefined) ? cartItem.tier
                     : (state.wheelType !== null ? state.wheelType : installed);

    document.getElementById('modPanelDesc').textContent =
        selectedType !== null && selectedType !== undefined
            ? Tf('tuning.ui.wheel_type_hint', 'Tip: {1} - alege un design.', wheelTypeLabel(selectedType))
            : T('tuning.ui.wheel_pick_type', 'Alege întâi un tip de jantă.');

    /* Step 1: type grid */
    var typeGrid = document.createElement('div');
    typeGrid.className = 'wheel-type-grid';

    for (var t = 0; t <= maxTier; t++) {
        (function(typeIdx) {
            var vipOnly = isVipOnly('wheels', typeIdx);
            var locked  = vipOnly && !(state.config && state.config.isVip);
            var lbl     = T('tuning.tier.wheels.' + typeIdx + '.label', (labels[typeIdx] && labels[typeIdx].label) || wheelTypeLabel(typeIdx));
            var cost    = calcCost('wheels', typeIdx);
            var isSel   = selectedType === typeIdx;
            var isInst  = installed === typeIdx;

            var card = document.createElement('button');
            card.className = 'wheel-type-card' +
                             (isSel  ? ' selected'  : '') +
                             (isInst ? ' installed' : '') +
                             (locked ? ' locked'    : '');
            card.disabled = !!locked;
            card.innerHTML =
                '<div class="wheel-type-icon">' +
                    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
                        '<circle cx="12" cy="12" r="9"/>' +
                        '<circle cx="12" cy="12" r="3"/>' +
                        '<path d="M12 3v4M12 17v4M3 12h4m10 0h4"/>' +
                    '</svg>' +
                '</div>' +
                '<div class="wheel-type-name">' + lbl + '</div>' +
                '<div class="wheel-type-price">' + cost.display + '</div>' +
                (vipOnly ? '<div class="wheel-type-vip">' + T('tuning.ui.badge_vip', 'VIP') + '</div>' : '') +
                (isInst ? '<div class="wheel-type-installed-badge">' + T('tuning.ui.badge_installed', 'Instalat') + '</div>' : '');

            card.addEventListener('click', function() {
                if (locked) return;
                state.wheelType  = typeIdx;
                state.wheelIndex = (isInst && installedIdx >= 0) ? installedIdx : 0;
                buildWheelPicker(container, cat);
                nuiPost('previewMod', { category: 'wheels', tier: typeIdx, subIndex: state.wheelIndex });
            });
            typeGrid.appendChild(card);
        })(t);
    }

    container.appendChild(typeGrid);

    if (selectedType === null || selectedType === undefined) return;

    var designHeader = document.createElement('div');
    designHeader.className = 'mod-section-label';
    designHeader.style.marginTop = '12px';
    designHeader.textContent = Tf('tuning.ui.wheel_design_header', 'Design ' + wheelTypeLabel(selectedType), wheelTypeLabel(selectedType));
    container.appendChild(designHeader);

    var designWrap = document.createElement('div');
    designWrap.className = 'wheel-design-grid';
    designWrap.id = 'wheelDesignGrid';
    container.appendChild(designWrap);

    var costObj = calcCost('wheels', selectedType);
    state.wheelCount = 0;

    if (isFiveM) {
        fetch(`https://${GetParentResourceName()}/getWheelDesignCount`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ wheelType: selectedType }),
        }).then(function(r) { return r.json(); }).then(function(res) {
            state.wheelCount = (res && res.count) ? res.count : 0;
            renderWheelDesigns(designWrap, cat, selectedType, installed, installedIdx, costObj);
        }).catch(function() {
            state.wheelCount = 20;
            renderWheelDesigns(designWrap, cat, selectedType, installed, installedIdx, costObj);
        });
    } else {
        state.wheelCount = 20;
        renderWheelDesigns(designWrap, cat, selectedType, installed, installedIdx, costObj);
    }

    var inCart = !!state.cart['wheels'] && state.cart['wheels'].tier === selectedType;
    var cartRow = document.createElement('div');
    cartRow.className = 'color-row';
    cartRow.style.cssText = 'border-top:1px solid var(--border);margin-top:12px;padding-top:12px;';
    cartRow.innerHTML =
        '<span class="color-row-label" style="color:var(--text-1);font-weight:700;">' +
            Tf('tuning.ui.wheel_design_line', wheelTypeLabel(selectedType) + ' · Design #' + (state.wheelIndex >= 0 ? state.wheelIndex : '-'),
               wheelTypeLabel(selectedType), (state.wheelIndex >= 0 ? state.wheelIndex : '-')) +
        '</span>' +
        '<span style="flex:1;font-size:13px;font-weight:900;color:var(--accent);">' + costObj.display + '</span>' +
        '<button class="btn-cart-color' + (inCart ? ' in-cart' : '') + '" id="btnCartWheels">' +
            (inCart ? T('tuning.ui.remove_from_cart', 'Scoate din coș') : T('tuning.ui.add_to_cart', 'Adaugă în coș')) +
        '</button>';
    container.appendChild(cartRow);

    document.getElementById('btnCartWheels').addEventListener('click', function() {
        if (state.cart['wheels']) {
            removeFromCart('wheels');
        } else {
            addToCart('wheels', selectedType,
                Tf('tuning.ui.wheel_cart_label', (WHEEL_TYPE_LABELS[selectedType] || T('tuning.ui.wheels_fallback', 'Roți')) + ' #' + state.wheelIndex,
                   wheelTypeLabel(selectedType), state.wheelIndex),
                costObj.raw,
                { subIndex: state.wheelIndex });
        }
        buildWheelPicker(container, cat);
    });
}

function renderWheelDesigns(wrap, cat, wheelType, installedType, installedIdx, costObj) {
    wrap.innerHTML = '';
    var count = state.wheelCount || 0;

    if (count === 0) {
        wrap.innerHTML = '<div style="grid-column:1/-1;opacity:0.6;font-size:12px;padding:8px;">' + T('tuning.ui.wheel_no_design', 'Niciun design disponibil pentru acest tip.') + '</div>';
        return;
    }

    for (var i = 0; i < count; i++) {
        (function(designIdx) {
            var isSelected = (state.wheelIndex === designIdx);
            var isInstalled = (installedType === wheelType && installedIdx === designIdx);
            var cell = document.createElement('button');
            cell.className = 'wheel-design-cell' +
                             (isSelected  ? ' selected' : '') +
                             (isInstalled ? ' installed' : '');
            cell.innerHTML = '<span class="wheel-design-num">#' + designIdx + '</span>' +
                             (isInstalled ? '<span class="wheel-design-mark"><svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span>' : '');
            cell.addEventListener('click', function() {
                state.wheelIndex = designIdx;
                wrap.querySelectorAll('.wheel-design-cell').forEach(function(c) { c.classList.remove('selected'); });
                cell.classList.add('selected');
                nuiPost('previewMod', { category: 'wheels', tier: wheelType, subIndex: designIdx });
                if (state.cart['wheels']) {
                    state.cart['wheels'].subIndex = designIdx;
                    state.cart['wheels'].label   = Tf('tuning.ui.wheel_cart_label', (WHEEL_TYPE_LABELS[wheelType] || T('tuning.ui.wheels_fallback', 'Roți')) + ' #' + designIdx, wheelTypeLabel(wheelType), designIdx);
                    renderCartBar();
                }
                var headerLabel = document.querySelector('.color-row .color-row-label');
                if (headerLabel) {
                    headerLabel.textContent = Tf('tuning.ui.wheel_design_line', wheelTypeLabel(wheelType) + ' · Design #' + designIdx, wheelTypeLabel(wheelType), designIdx);
                }
            });
            wrap.appendChild(cell);
        })(i);
    }
}

function buildLiveryList(container, cat) {
    var code      = (state.config && state.config.currencyCode) || 'USD';
    var cost      = (state.config && state.config.liveryCost) || 1000;
    var maxTier   = cat.maxTier || 8;
    var labels    = (state.config && state.config.tierLabels && state.config.tierLabels['livery']) || {};
    var installed = getInstalledTier('livery');
    var cartItem  = state.cart['livery'];

    document.getElementById('modPanelDesc').textContent = Tf('tuning.ui.livery_cost_hint', 'Cost per liverie: ' + fmt(cost, code), fmt(cost, code));

    for (var i = 0; i <= maxTier; i++) {
        (function(idx) {
            var inCart = !!(cartItem && cartItem.tier === idx);
            var isCurr = installed === idx;
            var name   = T('tuning.tier.livery.' + idx + '.label',
                           (labels[idx] && labels[idx].label) ||
                           (idx === 0 ? T('tuning.ui.livery_none', 'Fără liverie') : Tf('tuning.ui.livery_generic', 'Liverie ' + idx, idx)));

            var cartIconAdd = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';
            var cartIconRem = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/></svg>';

            var row = document.createElement('div');
            row.className    = 'mod-row' + (isCurr ? ' is-current' : '') + (inCart ? ' in-cart' : '');
            row.dataset.tier = idx;

            var badges = [];
            if (isCurr) badges.push('<span class="mod-badge badge-current">' + T('tuning.ui.badge_installed', 'Instalat') + '</span>');
            if (inCart) badges.push('<span class="mod-badge badge-incart">' + T('tuning.ui.badge_in_cart', 'În coș') + '</span>');

            row.innerHTML =
                '<div class="mod-tier-badge">' + (idx === 0 ? '○' : idx) + '</div>' +
                '<div class="mod-info">' +
                    '<div class="mod-name">' + name + '</div>' +
                    (badges.length ? '<div class="mod-badges">' + badges.join('') + '</div>' : '') +
                '</div>' +
                '<div class="mod-right">' +
                    '<span class="mod-price' + (idx === 0 ? ' owned' : '') + '">' + (idx === 0 ? T('tuning.ui.free', 'Gratuit') : fmt(cost, code)) + '</span>' +
                    '<button class="btn-cart ' + (inCart ? 'in-cart' : '') + '" data-tier="' + idx + '">' +
                        (inCart ? cartIconRem : cartIconAdd) +
                    '</button>' +
                '</div>';

            row.addEventListener('click', function(e) {
                if (e.target.closest('.btn-cart')) return;
                nuiPost('previewMod', { category: 'livery', tier: idx });
                container.querySelectorAll('.mod-row').forEach(function(r) { r.classList.remove('previewing'); });
                row.classList.add('previewing');
            });

            row.querySelector('.btn-cart').addEventListener('click', function(e) {
                e.stopPropagation();
                if (inCart) {
                    removeFromCart('livery');
                } else {
                    addToCart('livery', idx, name, idx === 0 ? 0 : cost);
                    nuiPost('previewMod', { category: 'livery', tier: idx });
                }
                buildLiveryList(container, cat);
            });

            container.appendChild(row);
        })(i);
    }
}

function previewTier(cat, tier) {
    nuiPost('previewMod', { category: cat.id, tier: tier });
    state.previewMods[cat.id] = tier;

    document.querySelectorAll('.mod-row').forEach(function(r) { r.classList.remove('previewing'); });
    var row = document.querySelector('.mod-row[data-tier="' + tier + '"]');
    if (row) row.classList.add('previewing');
}

function addToCart(catId, tier, label, cost, extra) {
    extra = extra || {};
    state.cart[catId] = Object.assign({ category: catId, tier: tier, label: label, cost: cost }, extra);
    refreshCatBadges();
    renderCartBar();
    refreshModListSelection(catId);
}

function removeFromCart(catId) {
    delete state.cart[catId];
    nuiPost('restorePreview', { category: catId, tier: state.originalMods[catId] !== undefined ? state.originalMods[catId] : 0 });
    refreshCatBadges();
    renderCartBar();
    refreshModListSelection(catId);
}

function refreshModListSelection(catId) {
    if (state.activeCatId !== catId) return;
    var cat = state.config && state.config.categories && state.config.categories.find(function(c) { return c.id === catId; });
    if (cat) buildModList(cat);
}

function renderCartBar() {
    var scrollArea = document.getElementById('cartScrollArea');
    var emptyMsg   = document.getElementById('cartEmptyMsg');
    var totalEl    = document.getElementById('cartTotal');
    var btnBuy     = document.getElementById('btnBuy');
    var code       = (state.config && state.config.currencyCode) || 'USD';

    var items = Object.values(state.cart);

    scrollArea.querySelectorAll('.cart-chip').forEach(function(c) { c.remove(); });

    var total = 0;
    items.forEach(function(item) {
        total += item.cost || 0;

        var chip = document.createElement('div');
        chip.className   = 'cart-chip';
        chip.dataset.cat = item.category;

        var shortLabel = item.label.length > 18 ? item.label.slice(0, 16) + '…' : item.label;
        chip.innerHTML =
            '<span class="cart-chip-label">' + shortLabel + '</span>' +
            '<span class="cart-chip-price">' + (item.cost > 0 ? fmt(item.cost, code) : T('tuning.ui.free', 'Gratuit')) + '</span>' +
            '<button class="cart-chip-remove" title="' + T('tuning.ui.chip_remove', 'Scoate') + '">' +
                '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">' +
                    '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>' +
                '</svg>' +
            '</button>';

        var catId = item.category;
        chip.querySelector('.cart-chip-remove').addEventListener('click', function() { removeFromCart(catId); });
        scrollArea.insertBefore(chip, emptyMsg);
    });

    if (items.length === 0) emptyMsg.classList.remove('hidden');
    else                    emptyMsg.classList.add('hidden');

    totalEl.textContent = fmt(total, code);
    btnBuy.disabled     = items.length === 0;
}

function setPayMethod(method) {
    state.payMethod = method;
    document.getElementById('payCash').classList.toggle('active', method === 'cash');
    document.getElementById('payBank').classList.toggle('active', method === 'bank');
}

function buyCart() {
    var items = Object.values(state.cart);
    if (!items.length) return;

    var code  = (state.config && state.config.currencyCode) || 'USD';
    var total = items.reduce(function(s, i) { return s + (i.cost || 0); }, 0);
    var names = items.map(function(i) {
        return Tf('tuning.ui.buy_modal_line', '• ' + i.label + ' - ' + (i.cost > 0 ? fmt(i.cost, code) : T('tuning.ui.free', 'Gratuit')),
                  i.label, (i.cost > 0 ? fmt(i.cost, code) : T('tuning.ui.free', 'Gratuit')));
    }).join('\n');

    var payLabel = state.payMethod === 'cash' ? T('tuning.ui.pay_cash', 'Cash') : T('tuning.ui.pay_bank', 'Bancă');

    showModal(
        T('tuning.ui.buy_modal_title', 'Confirmă achiziția'),
        '<strong>' + Tf('tuning.ui.buy_modal_total', 'Total: ' + fmt(total, code), fmt(total, code)) + '</strong> (' + payLabel + ')\n\n' + names,
        function() {
            nuiPost('applyCart', { items: items, paymentMethod: state.payMethod });
            document.getElementById('btnBuy').disabled = true;
        }
    );
}

function resetStock() {
    var code = (state.config && state.config.currencyCode) || 'USD';
    var cost = (state.config && state.config.resetCost) || 1500;

    var payLabel = state.payMethod === 'cash' ? T('tuning.ui.pay_cash', 'Cash') : T('tuning.ui.pay_bank', 'Bancă');

    showModal(
        T('tuning.ui.reset_modal_title', 'Reset la Stock'),
        T('tuning.ui.reset_modal_body', 'Toate modificările vor fi eliminate.') + '\n\n' +
            Tf('tuning.ui.reset_modal_cost', 'Cost: ' + fmt(cost, code), fmt(cost, code)) + ' (' + payLabel + ')',
        function() {
            nuiPost('resetMods', { paymentMethod: state.payMethod });
        }
    );
}

var _modalConfirmCb = null;

function showModal(title, body, onConfirm) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML    = body.replace(/\n/g, '<br>');
    _modalConfirmCb = onConfirm;
    document.getElementById('modalOverlay').classList.remove('hidden');
}

function hideModal() {
    document.getElementById('modalOverlay').classList.add('hidden');
    _modalConfirmCb = null;
}

function onCartApplied(results, finalMods) {
    if (finalMods && state.vehicle) {
        state.vehicle.modifications = finalMods;
        state.originalMods = Object.assign({}, finalMods);
        state.previewMods  = Object.assign({}, finalMods);
    }

    results.forEach(function(r) {
        if (r.success) delete state.cart[r.category];
    });

    refreshCatBadges();
    renderCartBar();

    if (state.activeCatId) {
        var cat = state.config && state.config.categories && state.config.categories.find(function(c) { return c.id === state.activeCatId; });
        if (cat) buildModList(cat);
    }

    // Inchide automat panoul dupa o achizitie reusita (toate articolele aplicate).
    var allOk = results && results.length && results.every(function(r) { return r.success; });
    if (allOk) {
        setTimeout(closeUI, 700);
    }
}

function onModsReset(finalMods) {
    if (state.vehicle) {
        state.vehicle.modifications = finalMods || {};
        state.originalMods = {};
        state.previewMods  = {};
    }
    state.cart = {};
    refreshCatBadges();
    renderCartBar();
    if (state.activeCatId) {
        var cat = state.config && state.config.categories && state.config.categories.find(function(c) { return c.id === state.activeCatId; });
        if (cat) buildModList(cat);
    }
}

window.addEventListener('message', function(e) {
    var d = e.data || {};
    switch (d.action) {
        case 'openUI':
            openUI(d.vehicle, d.config);
            break;
        case 'closeUI':
            document.getElementById('app').classList.add('hidden');
            break;
        case 'cartApplied':
            onCartApplied(d.results, d.finalMods);
            break;
        case 'modsReset':
            onModsReset(d.finalMods);
            break;
    }
});

// Re-randare a stringurilor generate din JS la schimbarea dictionarului
document.addEventListener('sw:i18n', function() {
    if (!state.config) return;
    buildCatList();
    if (state.activeCatId) {
        var cat = state.config.categories && state.config.categories.find(function(c) { return c.id === state.activeCatId; });
        if (cat) {
            document.getElementById('modPanelTitle').textContent = T('tuning.category.' + cat.id, cat.label);
            buildModList(cat);
        }
    }
    renderCartBar();
});

document.getElementById('btnClose').addEventListener('click', closeUI);
document.getElementById('payCash').addEventListener('click', function() { setPayMethod('cash'); });
document.getElementById('payBank').addEventListener('click', function() { setPayMethod('bank'); });
document.getElementById('btnBuy').addEventListener('click', buyCart);
document.getElementById('btnReset').addEventListener('click', resetStock);
document.getElementById('modalCancel').addEventListener('click', hideModal);
document.getElementById('modalConfirm').addEventListener('click', function() {
    if (_modalConfirmCb) _modalConfirmCb();
    hideModal();
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        var overlay = document.getElementById('modalOverlay');
        if (!overlay.classList.contains('hidden')) hideModal();
        else closeUI();
    }
});

// Orbit camera: trage cu mouse-ul peste zona centrala pentru a roti masina,
// scroll pentru zoom. Delta-urile se trimit catre client.lua care misca camera.
(function setupCameraOrbit() {
    var carArea = document.getElementById('carArea');
    if (!carArea) return;

    var dragging = false, lastX = 0, lastY = 0, accDx = 0, accDy = 0, rafPending = false;

    function flush() {
        rafPending = false;
        if (accDx !== 0 || accDy !== 0) {
            nuiPost('orbitCamera', { dx: accDx, dy: accDy });
            accDx = 0; accDy = 0;
        }
    }

    carArea.addEventListener('mousedown', function(e) {
        if (e.button !== 0) return;
        if (e.target.closest('.close-btn')) return;
        dragging = true;
        lastX = e.clientX; lastY = e.clientY;
        carArea.classList.add('grabbing');
    });

    window.addEventListener('mousemove', function(e) {
        if (!dragging) return;
        accDx += e.clientX - lastX;
        accDy += e.clientY - lastY;
        lastX = e.clientX; lastY = e.clientY;
        if (!rafPending) { rafPending = true; requestAnimationFrame(flush); }
    });

    window.addEventListener('mouseup', function() {
        dragging = false;
        carArea.classList.remove('grabbing');
    });

    carArea.addEventListener('wheel', function(e) {
        e.preventDefault();
        nuiPost('zoomCamera', { delta: e.deltaY > 0 ? 0.5 : -0.5 });
    }, { passive: false });
})();

function injectCarSvg() {
    var carArea = document.getElementById('carArea');
    if (document.getElementById('carSvg')) return;

    var svgNS = 'http://www.w3.org/2000/svg';
    var svg   = document.createElementNS(svgNS, 'svg');
    svg.id = 'carSvg';
    svg.setAttribute('viewBox', '0 0 900 320');
    svg.setAttribute('xmlns', svgNS);
    svg.setAttribute('style', 'position:absolute;inset:0;width:100%;height:100%;opacity:0.5;pointer-events:none;');

    svg.innerHTML =
        '<g id="zone-body" class="car-zone"><ellipse cx="450" cy="258" rx="340" ry="26" fill="currentColor"/>' +
            '<rect x="110" y="145" width="680" height="113" rx="16"/>' +
            '<path d="M200 145 Q230 75 310 68 L590 68 Q670 75 700 145 Z"/></g>' +
        '<g id="zone-engine" class="car-zone"><path d="M560 100 L680 108 L700 145 L555 145 Z"/></g>' +
        '<g id="zone-transmission" class="car-zone"><rect x="400" y="213" width="100" height="36" rx="5"/></g>' +
        '<g id="zone-brakes" class="car-zone"><ellipse cx="225" cy="260" rx="52" ry="17"/><ellipse cx="675" cy="260" rx="52" ry="17"/></g>' +
        '<g id="zone-suspension" class="car-zone"><rect x="155" y="238" width="50" height="18" rx="4"/><rect x="695" y="238" width="50" height="18" rx="4"/></g>' +
        '<g id="zone-armor" class="car-zone"><rect x="240" y="148" width="160" height="106" rx="4"/><rect x="500" y="148" width="160" height="106" rx="4"/></g>' +
        '<g id="zone-wheels" class="car-zone"><circle cx="225" cy="260" r="50"/><circle cx="675" cy="260" r="50"/></g>' +
        '<g id="zone-lights" class="car-zone"><ellipse cx="128" cy="188" rx="22" ry="13"/><ellipse cx="772" cy="188" rx="22" ry="13"/></g>' +
        '<path d="M200 145 Q230 75 310 68 L590 68 Q670 75 700 145 L790 155 Q820 160 820 180 L820 233 Q820 258 800 260 ' +
            'L725 260 Q720 315 675 315 Q630 315 625 260 L275 260 Q270 315 225 315 Q180 315 175 260 ' +
            'L110 260 Q90 258 90 233 L90 180 Q90 160 120 155 Z" fill="none" stroke="#1e2a38" stroke-width="2"/>' +
        '<path d="M305 70 L260 142 L545 142 L540 70 Z" fill="rgba(0,180,255,0.05)" stroke="#1e2a38" stroke-width="1.5"/>' +
        '<path d="M595 70 L640 142 L720 142 L680 70 Z" fill="rgba(0,180,255,0.05)" stroke="#1e2a38" stroke-width="1.5"/>' +
        '<circle cx="225" cy="260" r="50" fill="#0d111a" stroke="#1e2a38" stroke-width="2"/>' +
        '<circle cx="225" cy="260" r="30" fill="#141b26" stroke="#2a3548" stroke-width="1.5"/>' +
        '<circle cx="675" cy="260" r="50" fill="#0d111a" stroke="#1e2a38" stroke-width="2"/>' +
        '<circle cx="675" cy="260" r="30" fill="#141b26" stroke="#2a3548" stroke-width="1.5"/>' +
        '<ellipse cx="128" cy="188" rx="22" ry="13" fill="rgba(255,220,100,0.07)" stroke="#1e2a38" stroke-width="1.5"/>' +
        '<ellipse cx="772" cy="188" rx="22" ry="13" fill="rgba(255,80,60,0.05)" stroke="#1e2a38" stroke-width="1.5"/>';

    carArea.insertBefore(svg, carArea.firstChild);
}

function handleDevNuiCallback(action, data) {
    if (action === 'applyCart') {
        var results = (data.items || []).map(function(i) { return { category: i.category, tier: i.tier, success: true }; });
        var finalMods = Object.assign({}, getMods());
        (data.items || []).forEach(function(i) {
            if (i.category === 'color') {
                finalMods['color_primary']   = i.colorPrimary;
                finalMods['color_secondary'] = i.colorSecondary;
                if (i.colorPearl !== undefined) finalMods['color_pearl'] = i.colorPearl;
            } else if (i.category === 'wheels') {
                finalMods['wheels'] = i.tier;
                if (i.subIndex !== undefined) finalMods['wheels_index'] = i.subIndex;
            } else {
                finalMods[i.category] = i.tier;
            }
        });
        setTimeout(function() { onCartApplied(results, finalMods); }, 400);
    } else if (action === 'getWheelDesignCount') {
        return Promise.resolve({ count: 12 });
    } else if (action === 'resetMods') {
        setTimeout(function() { onModsReset({}); }, 400);
    }
}

if (!isFiveM) {
    document.body.style.background = 'linear-gradient(135deg, #070b12 0%, #0b1018 100%)';
    openUI(
        {
            id:    1,
            plate: 'SWT001',
            name:  'Dewbauchee Vagner',
            model: 'vagner',
            modifications: {
                engine: 1, brakes: 0, transmission: 2, turbo: 0,
                suspension: 0, armor: 0, xenon: 0,
                wheels: 0, wheels_index: -1,
                color_primary: '#1a3a6e', color_secondary: '#c0c0c0', color_pearl: 0,
                livery: -1,
            }
        },
        {
            shopCode:     'LSC_BURTON',
            isVip:        true,
            currencyCode: 'USD',
            resetCost:    1500,
            colorCost:    500,
            liveryCost:   1000,
            vipDiscount:  0.15,
            priceTable: {
                engine:       { 1:{price:5000},  2:{price:12000}, 3:{price:24000}, 4:{price:45000} },
                brakes:       { 1:{price:3000},  2:{price:7500},  3:{price:15000} },
                transmission: { 1:{price:4000},  2:{price:10000}, 3:{price:20000} },
                turbo:        { 1:{price:8000} },
                suspension:   { 1:{price:2000},  2:{price:4500},  3:{price:8000}, 4:{price:13000}, 5:{price:20000} },
                armor:        { 1:{price:5000},  2:{price:12000}, 3:{price:22000},4:{price:35000}, 5:{price:50000} },
                xenon:        { 1:{price:2500} },
                wheels:       { 1:{price:3000},  2:{price:6000},  3:{price:10000},4:{price:15000}, 5:{price:22000}, 6:{price:30000}, 7:{price:40000} },
            },
            categories: [
                { id:'engine',       label:'Motor',      nativeType:11, modType:'index',  maxTier:4 },
                { id:'brakes',       label:'Frâne',      nativeType:12, modType:'index',  maxTier:3 },
                { id:'transmission', label:'Transmisie', nativeType:13, modType:'index',  maxTier:3 },
                { id:'turbo',        label:'Turbo',      nativeType:18, modType:'toggle', maxTier:1 },
                { id:'suspension',   label:'Suspensie',  nativeType:15, modType:'index',  maxTier:5 },
                { id:'armor',        label:'Blindaj',    nativeType:16, modType:'index',  maxTier:5 },
                { id:'xenon',        label:'Xenon',      nativeType:22, modType:'toggle', maxTier:1 },
                { id:'wheels',       label:'Roți',       nativeType:-1, modType:'wheel',  maxTier:7 },
                { id:'color',        label:'Culoare',    nativeType:-2, modType:'color',  maxTier:0 },
                { id:'livery',       label:'Liverie',    nativeType:48, modType:'livery', maxTier:6 },
            ],
            tierLabels: {
                engine: {
                    0:{label:'Stock',     desc:'Motor original al producătorului'},
                    1:{label:'Sport',     desc:'Filtru aer sport, carburator îmbunătățit'},
                    2:{label:'Sport+',    desc:'Chiuloasă portată, pistoane forjate'},
                    3:{label:'Race',      desc:'Injecție directă, camă de cursă'},
                    4:{label:'Race+',     desc:'Motor complet reconstruit pentru pistă'},
                },
                brakes: {
                    0:{label:'Stock'}, 1:{label:'Sport',desc:'Discuri ventilate'},
                    2:{label:'Sport+',desc:'Sistem Brembo'}, 3:{label:'Race',desc:'Carbon-ceramice'},
                },
                transmission: {
                    0:{label:'Stock'}, 1:{label:'Sport',desc:'Schimburi mai rapide'},
                    2:{label:'Sport+',desc:'Close-ratio'}, 3:{label:'Race',desc:'Secvențială'},
                },
                turbo:      { 0:{label:'Fără'}, 1:{label:'Turbo',desc:'Kit complet'} },
                suspension: { 0:{label:'Stock'}, 1:{label:'Lowered'}, 2:{label:'Street'}, 3:{label:'Track'}, 4:{label:'Drift'}, 5:{label:'Race'} },
                armor:      { 0:{label:'Fără'}, 1:{label:'20%'}, 2:{label:'40%'}, 3:{label:'60%'}, 4:{label:'80%'}, 5:{label:'100%'} },
                xenon:      { 0:{label:'Faruri normale'}, 1:{label:'Xenon',desc:'Lumini HID'} },
                wheels:     { 0:{label:'Stock'}, 1:{label:'Sport 17"'}, 2:{label:'Sport 18"'}, 3:{label:'Race 19"'}, 4:{label:'Race 20"'}, 5:{label:'Custom 21"'}, 6:{label:'Forjate 22"'}, 7:{label:'Motorsport'} },
                livery:     { 0:{label:'Fără liverie'}, 1:{label:'Liverie 1'}, 2:{label:'Liverie 2'}, 3:{label:'Liverie 3'}, 4:{label:'Liverie 4'}, 5:{label:'Liverie 5'}, 6:{label:'Liverie 6'} },
            },
            vipOnlyMods: { engine:[4], armor:[5], wheels:[7] },
        }
    );
}
