'use strict';

document.addEventListener('DOMContentLoaded', () => {
    if (window.lucide) lucide.createIcons();
});

const state = {
    items:        [],
    ownedItems:   {},
    equippedMap:  {},
    selectedItem: null,
    currentTexture: 0,
    activeCategory: 'all',
    outfits:      [],
    isAutoRotating: false,
};

const COMPONENT_META = {
    component_1:  { label: 'Mască',          icon: 'drama',        bg: 'icon-bg-mask'    },
    component_3:  { label: 'Torso',          icon: 'shirt',        bg: 'icon-bg-torso'   },
    component_4:  { label: 'Pantaloni',      icon: 'square',       bg: 'icon-bg-legs'    },
    component_5:  { label: 'Geantă/Rucsac',  icon: 'backpack',     bg: 'icon-bg-bag'     },
    component_6:  { label: 'Încălțăminte',   icon: 'footprints',   bg: 'icon-bg-feet'    },
    component_7:  { label: 'Accesoriu',      icon: 'gem',          bg: 'icon-bg-acc'     },
    component_8:  { label: 'Tricou',         icon: 'shirt',        bg: 'icon-bg-shirt'   },
    component_9:  { label: 'Vestă/Armură',   icon: 'shield',       bg: 'icon-bg-torso'   },
    component_10: { label: 'Decal',          icon: 'tag',          bg: 'icon-bg-acc'     },
    component_11: { label: 'Jachetă',        icon: 'shirt',        bg: 'icon-bg-jacket'  },
    prop_0:       { label: 'Pălărie',        icon: 'crown',        bg: 'icon-bg-hat'     },
    prop_1:       { label: 'Ochelari',       icon: 'glasses',      bg: 'icon-bg-glasses' },
    prop_2:       { label: 'Cercei',         icon: 'gem',          bg: 'icon-bg-acc'     },
    prop_6:       { label: 'Ceas',           icon: 'watch',        bg: 'icon-bg-acc'     },
    prop_7:       { label: 'Brățară',        icon: 'circle-dot',   bg: 'icon-bg-acc'     },
};

function getCompMeta(item) {
    const key = `${item.component_type}_${item.component_id}`;
    return COMPONENT_META[key] || { label: 'Haine', icon: 'shirt', bg: 'icon-bg-jacket' };
}

function formatPrice(price) {
    return Number(price).toLocaleString('ro-RO') + ' RON';
}

function formatBonus(slots, weight) {
    const parts = [];
    if (slots  > 0) parts.push(`+${slots} sloturi`);
    if (weight > 0) parts.push(`+${weight}kg`);
    return parts.join('  ');
}

function getItemKey(item) {
    return `${item.component_type}_${item.component_id}`;
}

function nuiPost(action, data = {}) {
    return fetch(`https://clothing/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => ({}));
}

window.addEventListener('message', (e) => {
    const { action } = e.data;

    if (action === 'openStore')        return onOpenStore(e.data);
    if (action === 'closeStore')       return onCloseStore();
    if (action === 'receiveOutfits')   return renderOutfits(e.data.outfits || []);
    if (action === 'autoRotateFinished') return onAutoRotateFinished();
    if (action === 'itemPurchased')    return onItemPurchased(e.data.itemId);
});

function onOpenStore(data) {
    state.items         = data.items       || [];
    state.ownedItems    = data.ownedItems  || {};
    state.equippedMap   = buildEquippedMap(data.equipped || {});
    state.selectedItem  = null;
    state.activeCategory = 'all';
    state.currentTexture = 0;

    const badge = document.getElementById('store-type-badge');
    badge.textContent = data.storeType || 'casual';
    badge.className   = data.storeType || 'casual';

    document.getElementById('store-title').textContent = data.storeLabel || 'Magazin';

    switchTab('items');
    filterCategory('all');
    document.getElementById('item-detail').classList.add('hidden');
    document.getElementById('app').classList.remove('hidden');
}

function buildEquippedMap(equipped) {
    const map = {};
    for (const [key, comp] of Object.entries(equipped)) {
        map[key] = comp;
    }
    return map;
}

function onCloseStore() {
    document.getElementById('app').classList.add('hidden');
    document.getElementById('fitting-room').classList.add('hidden');
    hideFittingRoom();
}

function closeStore() {
    nuiPost('closeStore');
}

function switchTab(name) {
    document.querySelectorAll('.tab').forEach(t => {
        t.classList.toggle('active', t.dataset.tab === name);
    });
    document.querySelectorAll('.tab-content').forEach(c => {
        c.classList.toggle('active', c.id === `tab-${name}`);
    });

    if (name === 'equipped') renderEquipped();
    if (name === 'outfits')  { nuiPost('getOutfits'); }
}

function filterCategory(cat) {
    state.activeCategory = cat;
    document.querySelectorAll('.cat-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.cat === cat);
    });
    renderItemGrid();
}

function renderItemGrid() {
    const grid = document.getElementById('item-grid');
    const filtered = cat => cat === 'all'
        ? state.items
        : state.items.filter(i => `${i.component_type}_${i.component_id}` === cat);

    const items = filtered(state.activeCategory);
    grid.innerHTML = items.length === 0
        ? `<div class="empty-state" style="grid-column:1/-1"><div><i data-lucide="shopping-bag"></i></div>Niciun articol în această categorie.</div>`
        : items.map(itemCardHTML).join('');
    if (window.lucide) lucide.createIcons({ nodes: grid.querySelectorAll('[data-lucide]') });
}

function itemCardHTML(item) {
    const meta      = getCompMeta(item);
    const isOwned   = !!state.ownedItems[String(item.id)];
    const compKey   = getItemKey(item);
    const isEquipped = state.equippedMap[compKey]?.clothing_item_id == item.id;
    const hasBonus  = (item.bonus_slots > 0 || item.bonus_weight > 0);
    const isSelected = state.selectedItem?.id == item.id;

    const classes = [
        'item-card',
        isOwned    ? 'owned'          : '',
        isEquipped ? 'equipped-badge' : '',
        isSelected ? 'selected'       : '',
    ].filter(Boolean).join(' ');

    return `
<div class="${classes}" onclick="selectItem(${item.id})">
    <div class="item-card-icon ${meta.bg}"><i data-lucide="${meta.icon}"></i></div>
    <div class="item-card-label">${item.label}</div>
    <div class="item-card-price">${formatPrice(item.price)}</div>
    ${hasBonus ? `<div class="item-card-bonus">+inv</div>` : ''}
</div>`;
}

function selectItem(itemId) {
    const item = state.items.find(i => i.id == itemId);
    if (!item) return;

    state.selectedItem   = item;
    state.currentTexture = item.default_texture || 0;

    renderItemGrid();
    renderDetail(item);
    document.getElementById('item-detail').classList.remove('hidden');
}

function renderDetail(item) {
    const meta     = getCompMeta(item);
    const isOwned  = !!state.ownedItems[String(item.id)];
    const compKey  = getItemKey(item);
    const isEquipped = state.equippedMap[compKey]?.clothing_item_id == item.id;
    const hasBonus = (item.bonus_slots > 0 || item.bonus_weight > 0);
    const texCount = Number(item.texture_count) || 1;

    document.getElementById('detail-icon-wrap').className = `icon-bg-jacket ${meta.bg}`;
    document.getElementById('detail-icon-inner').innerHTML = `<i data-lucide="${meta.icon}"></i>`;
    document.getElementById('detail-label').textContent = item.label;
    document.getElementById('detail-price').textContent = formatPrice(item.price);

    const bonusEl = document.getElementById('detail-bonus');
    if (hasBonus) {
        bonusEl.innerHTML = '<i data-lucide="package"></i> ' + formatBonus(item.bonus_slots, item.bonus_weight);
        bonusEl.classList.remove('hidden');
    } else {
        bonusEl.classList.add('hidden');
    }

    const texSection = document.getElementById('texture-section');
    if (texCount > 1) {
        texSection.classList.remove('hidden');
        updateTextureLabel();
    } else {
        texSection.classList.add('hidden');
    }

    const btnBuy   = document.getElementById('btn-buy');
    const btnEquip = document.getElementById('btn-equip');
    const btnOwned = document.getElementById('btn-owned-badge');

    if (isOwned) {
        btnBuy.classList.add('hidden');
        btnOwned.classList.remove('hidden');
        if (isEquipped) {
            btnEquip.innerHTML = '<i data-lucide="check"></i> Echipat';
            btnEquip.classList.remove('hidden');
        } else {
            btnEquip.textContent = 'Echipează';
            btnEquip.classList.remove('hidden');
        }
    } else {
        btnBuy.classList.remove('hidden');
        btnEquip.classList.add('hidden');
        btnOwned.classList.add('hidden');
    }
    if (window.lucide) lucide.createIcons({ nodes: document.getElementById('item-detail').querySelectorAll('[data-lucide]') });
}

function updateTextureLabel() {
    if (!state.selectedItem) return;
    const texCount = Number(state.selectedItem.texture_count) || 1;
    document.getElementById('texture-label').textContent =
        `${state.currentTexture + 1} / ${texCount}`;
}

function changeTextureBy(delta) {
    if (!state.selectedItem) return;
    const texCount = Number(state.selectedItem.texture_count) || 1;
    state.currentTexture = ((state.currentTexture + delta) % texCount + texCount) % texCount;
    updateTextureLabel();
    nuiPost('changeTexture', {
        componentType: state.selectedItem.component_type,
        componentId:   state.selectedItem.component_id,
        drawable:      state.selectedItem.drawable,
        texture:       state.currentTexture,
    });
}

function tryOnSelected() {
    if (!state.selectedItem) return;
    nuiPost('tryOn', {
        componentType: state.selectedItem.component_type,
        componentId:   state.selectedItem.component_id,
        drawable:      state.selectedItem.drawable,
        texture:       state.currentTexture,
    });
}

function buySelected() {
    if (!state.selectedItem) return;
    nuiPost('buyItem', {
        itemId:  state.selectedItem.id,
        texture: state.currentTexture,
    });
}

function onItemPurchased(itemId) {
    state.ownedItems[String(itemId)] = true;
    renderItemGrid();
    if (state.selectedItem?.id == itemId) {
        renderDetail(state.selectedItem);
    }
}

function equipSelected() {
    if (!state.selectedItem) return;
    nuiPost('equipItem', {
        itemId:  state.selectedItem.id,
        texture: state.currentTexture,
    });

    const compKey = getItemKey(state.selectedItem);
    state.equippedMap[compKey] = {
        clothing_item_id: state.selectedItem.id,
        ...state.selectedItem,
        texture: state.currentTexture,
    };

    renderItemGrid();
    renderDetail(state.selectedItem);
}

const SLOT_LABELS = {
    component_1:  'Mască',
    component_3:  'Torso',
    component_4:  'Pantaloni',
    component_5:  'Geantă',
    component_6:  'Încălțăminte',
    component_7:  'Accesoriu',
    component_8:  'Tricou interior',
    component_9:  'Vestă',
    component_10: 'Decal',
    component_11: 'Jachetă',
    prop_0:       'Pălărie',
    prop_1:       'Ochelari',
    prop_2:       'Cercei',
    prop_6:       'Ceas',
    prop_7:       'Brățară',
};

function renderEquipped() {
    const list = document.getElementById('equipped-list');
    const entries = Object.entries(state.equippedMap);

    if (entries.length === 0) {
        list.innerHTML = `<div class="empty-state"><div><i data-lucide="shirt"></i></div>Nu ai nicio haină echipată.</div>`;
        if (window.lucide) lucide.createIcons({ nodes: list.querySelectorAll('[data-lucide]') });
        return;
    }

    list.innerHTML = entries.map(([key, comp]) => {
        const meta     = COMPONENT_META[key] || { icon: 'shirt', bg: 'icon-bg-jacket' };
        const hasBonus = (comp.bonus_slots > 0 || comp.bonus_weight > 0);
        return `
<div class="equipped-row">
    <div class="equipped-row-icon"><i data-lucide="${meta.icon}"></i></div>
    <div class="equipped-row-info">
        <div class="equipped-row-label">${comp.label || 'Necunoscut'}</div>
        <div class="equipped-row-slot">${SLOT_LABELS[key] || key} - textură ${(comp.texture || 0) + 1}</div>
        ${hasBonus ? `<div class="equipped-row-bonus"><i data-lucide="package"></i> ${formatBonus(comp.bonus_slots, comp.bonus_weight)}</div>` : ''}
    </div>
    <button class="btn-danger" onclick="unequipSlot('${comp.component_type}', ${comp.component_id})">Dezechipează</button>
</div>`;
    }).join('');
    if (window.lucide) lucide.createIcons({ nodes: list.querySelectorAll('[data-lucide]') });
}

function unequipSlot(componentType, componentId) {
    nuiPost('unequipItem', { componentType, componentId });

    const key = `${componentType}_${componentId}`;
    delete state.equippedMap[key];
    renderEquipped();
    renderItemGrid();
    if (state.selectedItem) renderDetail(state.selectedItem);
}

function goToTryOnRoom() {
    nuiPost('goToTryOn').then(() => {
        document.getElementById('store-panel').classList.add('hidden');
        document.getElementById('fitting-room').classList.remove('hidden');
    });
}

function exitTryOnRoom() {
    nuiPost('exitTryOn').then(() => {
        hideFittingRoom();
    });
}

function hideFittingRoom() {
    document.getElementById('fitting-room').classList.add('hidden');
    document.getElementById('store-panel').classList.remove('hidden');
    state.isAutoRotating = false;
    document.getElementById('btn-auto-rotate').classList.remove('rotating');
    document.getElementById('btn-auto-rotate').innerHTML = '<i data-lucide="play"></i> 360° Auto';
    if (window.lucide) lucide.createIcons({ nodes: document.getElementById('btn-auto-rotate').querySelectorAll('[data-lucide]') });
}

function rotateView(direction) {
    nuiPost('rotateView', { direction });
}

function toggleAutoRotate() {
    if (state.isAutoRotating) {
        nuiPost('stopAutoRotate');
        state.isAutoRotating = false;
        const btn = document.getElementById('btn-auto-rotate');
        btn.classList.remove('rotating');
        btn.innerHTML = '<i data-lucide="play"></i> 360° Auto';
        if (window.lucide) lucide.createIcons({ nodes: btn.querySelectorAll('[data-lucide]') });
    } else {
        nuiPost('autoRotate').then(res => {
            if (res && res.ok) {
                state.isAutoRotating = true;
                const btn = document.getElementById('btn-auto-rotate');
                btn.classList.add('rotating');
                btn.innerHTML = '<i data-lucide="square"></i> Stop';
                if (window.lucide) lucide.createIcons({ nodes: btn.querySelectorAll('[data-lucide]') });
            }
        });
    }
}

function onAutoRotateFinished() {
    state.isAutoRotating = false;
    const btn = document.getElementById('btn-auto-rotate');
    btn.classList.remove('rotating');
    btn.innerHTML = '<i data-lucide="play"></i> 360° Auto';
    if (window.lucide) lucide.createIcons({ nodes: btn.querySelectorAll('[data-lucide]') });
}

function renderOutfits(outfits) {
    state.outfits = outfits;
    const list = document.getElementById('outfits-list');

    if (!outfits || outfits.length === 0) {
        list.innerHTML = `<div class="empty-state"><div><i data-lucide="shirt"></i></div>Nu ai outfit-uri salvate.</div>`;
        if (window.lucide) lucide.createIcons({ nodes: list.querySelectorAll('[data-lucide]') });
        return;
    }

    list.innerHTML = outfits.map(o => {
        const date = o.created_at
            ? new Date(o.created_at).toLocaleDateString('ro-RO', { day:'2-digit', month:'2-digit', year:'numeric' })
            : '';
        return `
<div class="outfit-row">
    <div class="outfit-row-name">${escapeHtml(o.name)}</div>
    <div class="outfit-row-date">${date}</div>
    <div class="outfit-row-actions">
        <button class="btn-primary" onclick="loadOutfit(${o.id})">Aplică</button>
        <button class="btn-danger"  onclick="deleteOutfit(${o.id})"><i data-lucide="x"></i></button>
    </div>
</div>`;
    }).join('');
    if (window.lucide) lucide.createIcons({ nodes: list.querySelectorAll('[data-lucide]') });
}

function saveOutfit() {
    const input = document.getElementById('outfit-name-input');
    const name  = input.value.trim();
    if (!name) return;

    nuiPost('saveOutfit', { name });
    input.value = '';
}

function loadOutfit(outfitId) {
    nuiPost('loadOutfit', { outfitId });
}

function deleteOutfit(outfitId) {
    nuiPost('deleteOutfit', { outfitId });
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}
