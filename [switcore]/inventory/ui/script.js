let uiConfig = { MaxSlots: 40, HotbarSlots: 5 };
let itemsConfig = {};

let playerInventory = { id: null, slots: {}, maxWeight: 30.0 };
let keysInventory = { id: null, slots: {}, maxSlots: 100 };
let secondaryInventory = { id: null, slots: {}, maxWeight: 100.0 };

let draggedItem = null;
let ghostDrag = document.getElementById('ghost-drag');

function itemImageUrl(config, name) {
    if (config && config.image_url && String(config.image_url).trim() !== '') {
        return String(config.image_url);
    }
    return `img/items/${name}.png`;
}

let contextMenuTarget = null;

window.addEventListener('message', (event) => {
    let data = event.data;

    switch(data.action) {
        case "open":
            document.getElementById('inventory-container').classList.remove('hidden');
            break;
        case "close":
            document.getElementById('inventory-container').classList.add('hidden');
            closeContextMenu();
            closeSplitDialog();
            hideItemTooltip();
            break;
        case "setupConfig":
            uiConfig = data.config;
            itemsConfig = data.items;
            setupGrids();
            break;
        case "updateInventory":
            if (data.invId && data.invId.startsWith("keys:")) {
                keysInventory.id = data.invId;
                keysInventory.slots = (data.inventory && data.inventory.slots) || {};
                keysInventory.maxSlots = (data.inventory && data.inventory.maxSlots) || 100;
                renderKeys();
                break;
            }
            if (data.inventory && data.inventory.maxSlots && data.invId && data.invId.startsWith("char:") && data.inventory.maxSlots !== uiConfig.MaxSlots) {
                uiConfig.MaxSlots = data.inventory.maxSlots;
                setupGrids();
            }
            if (data.invId.startsWith("char:")) {
                if (playerInventory.id !== null && playerInventory.id !== data.invId) break;
                playerInventory.id = data.invId;
                playerInventory.slots = data.inventory.slots;
                playerInventory.maxWeight = data.inventory.maxWeight;
                renderInventory('player');
            } else if (secondaryInventory.id === data.invId) {
                secondaryInventory.slots = data.inventory.slots;
                secondaryInventory.maxWeight = data.inventory.maxWeight;
                renderInventory('secondary');
            } else {
                secondaryInventory.id = data.invId;
                secondaryInventory.slots = data.inventory.slots;
                secondaryInventory.maxWeight = data.inventory.maxWeight;
                updateSecondaryTitle(data.invId);
                renderInventory('secondary');
            }
            break;
        case "updateCash":
            renderCash(data.cash);
            break;
    }
});

function updateSecondaryTitle(invId) {
    const titleEl = document.getElementById('secondary-title');
    if (!titleEl) return;
    if (invId && invId.startsWith('glove:')) {
        titleEl.setAttribute('data-i18n', 'inventory.ui.glovebox_title');
        titleEl.textContent = SwI18n.t('inventory.ui.glovebox_title');
    } else {
        titleEl.setAttribute('data-i18n', 'inventory.ui.trunk_title');
        titleEl.textContent = SwI18n.t('inventory.ui.trunk_title');
    }
}

function formatCashAmount(n) {
    n = Number(n) || 0;
    return n.toLocaleString('en-US', { maximumFractionDigits: 2 });
}

function renderCash(cashList) {
    const el = document.getElementById('cash-display');
    if (!el) return;
    if (!cashList || cashList.length === 0) {
        el.textContent = '$0';
        return;
    }
    const nonZero = cashList.filter(c => Number(c.amount) > 0);
    if (nonZero.length === 0) {
        el.textContent = (cashList[0] && cashList[0].symbol ? cashList[0].symbol : '$') + '0';
        return;
    }
    el.innerHTML = nonZero
        .map(c => `<span class="cash-entry">${c.symbol || c.code || '$'}${formatCashAmount(c.amount)}</span>`)
        .join('');
}

function setupGrids() {
    const pGrid = document.getElementById('player-grid');
    const sGrid = document.getElementById('secondary-grid');

    pGrid.innerHTML = '';
    sGrid.innerHTML = '';

    for(let i=1; i<=uiConfig.MaxSlots; i++) {
        pGrid.appendChild(createSlotElement('player', i));
        sGrid.appendChild(createSlotElement('secondary', i));
    }
}

function createSlotElement(invType, slotNumber) {
    const slot = document.createElement('div');
    slot.className = 'item-slot';
    slot.dataset.inv = invType;
    slot.dataset.slot = slotNumber;

    if (invType === 'player' && slotNumber <= uiConfig.HotbarSlots) {
        let hotbarLabel = document.createElement('div');
        hotbarLabel.className = 'hotbar-label';
        hotbarLabel.textContent = slotNumber;
        slot.appendChild(hotbarLabel);
    }

    slot.addEventListener('mousedown', handleSlotMouseDown);
    slot.addEventListener('contextmenu', handleContextMenu);
    slot.addEventListener('mouseenter', handleSlotMouseEnter);
    slot.addEventListener('mouseleave', handleSlotMouseLeave);

    return slot;
}

function getInventoryData(invType) {
    if (invType === 'keys')      return keysInventory;
    if (invType === 'secondary') return secondaryInventory;
    return playerInventory;
}

function renderKeys() {
    const grid    = document.getElementById('keys-grid');
    const emptyEl = document.getElementById('keys-empty');
    const countEl = document.getElementById('keys-count');
    if (!grid) return;

    Array.from(grid.querySelectorAll('.key-chip')).forEach(n => n.remove());

    const entries = [];
    if (keysInventory.slots) {
        for (const slotKey in keysInventory.slots) {
            const slot = parseInt(slotKey, 10);
            const item = keysInventory.slots[slotKey];
            if (item) entries.push({ slot, item });
        }
    }
    entries.sort((a, b) => a.slot - b.slot);

    if (countEl) countEl.textContent = entries.length;
    if (emptyEl) emptyEl.style.display = entries.length ? 'none' : '';

    for (const { slot, item } of entries) {
        const meta = item.metadata || {};
        const label = (meta.label) || (itemsConfig[item.name] && itemsConfig[item.name].label) || item.name;
        const plate = meta.plate ? `<span class="key-plate">${plate_esc(meta.plate)}</span>` : '';

        const chip = document.createElement('div');
        chip.className = 'key-chip';
        chip.dataset.slot = slot;
        chip.innerHTML = `<i class="fas fa-key"></i><span class="key-label">${plate_esc(label)}</span>${plate}`;
        chip.addEventListener('contextmenu', (e) => handleKeyContextMenu(e, slot, item));
        chip.addEventListener('click', (e) => handleKeyContextMenu(e, slot, item));
        grid.appendChild(chip);
    }
}

function plate_esc(s) {
    return String(s ?? '')
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function handleKeyContextMenu(e, slot, item) {
    e.preventDefault();
    if (!keysInventory.id) return;

    contextMenuTarget = {
        invType: 'keys',
        invId:   keysInventory.id,
        slot:    slot,
        item:    item,
    };

    const menu = document.getElementById('context-menu');
    menu.style.left = `${e.clientX}px`;
    menu.style.top  = `${e.clientY}px`;
    menu.classList.remove('hidden');

    const config = itemsConfig[item.name];
    document.getElementById('ctx-use').style.display = (config && config.usable) ? 'flex' : 'none';
    document.getElementById('ctx-split').style.display = 'none';
}

function renderInventory(invType) {
    const invData = getInventoryData(invType);
    const gridId = invType === 'player' ? 'player-grid' : 'secondary-grid';
    const grid = document.getElementById(gridId);
    if (!grid) return;

    let currentWeight = 0.0;

    if (invType === 'secondary') {
        if (!invData.id) {
            document.getElementById('secondary-inventory').classList.add('hidden');
        } else {
            document.getElementById('secondary-inventory').classList.remove('hidden');
        }
    }

    for (let i = 1; i <= uiConfig.MaxSlots; i++) {
        let slotEl = grid.querySelector(`[data-slot="${i}"]`);
        if (!slotEl) continue;

        let itemData = invData.slots[i];

        Array.from(slotEl.children).forEach(child => {
            if (!child.classList.contains('hotbar-label')) {
                slotEl.removeChild(child);
            }
        });

        if (invType === 'player' && itemData && itemsConfig[itemData.name] && itemsConfig[itemData.name].type === 'key') {
            continue;
        }

        if (itemData && itemsConfig[itemData.name]) {
            let config = itemsConfig[itemData.name];
            currentWeight += (config.weight * itemData.amount);

            let img = document.createElement('div');
            img.className = 'item-img';
            img.style.backgroundImage = `url('${itemImageUrl(config, itemData.name).replace(/'/g, "\\'")}')`;

            let amount = document.createElement('div');
            amount.className = 'item-amount';
            amount.textContent = itemData.amount;

            let weight = document.createElement('div');
            weight.className = 'item-weight';
            let totalW = (config.weight * itemData.amount).toFixed(1);
            weight.textContent = `${totalW}kg`;

            let label = document.createElement('div');
            label.className = 'item-label';
            label.textContent = config.label;

            slotEl.appendChild(img);
            slotEl.appendChild(amount);
            slotEl.appendChild(weight);
            slotEl.appendChild(label);

            if (itemData.metadata && Object.keys(itemData.metadata).length > 0) {
                let metaIcon = document.createElement('div');
                metaIcon.className = 'item-meta-icon';
                metaIcon.innerHTML = `<i class="fas fa-star"></i>`;
                slotEl.appendChild(metaIcon);
            }
        }
    }

    if (invData.maxWeight) {
        let weightFill = document.getElementById(`${invType}-weight-fill`);
        let weightText = document.getElementById(`${invType}-weight-text`);
        let percentage = Math.min((currentWeight / invData.maxWeight) * 100, 100);

        weightFill.style.width = `${percentage}%`;
        weightText.textContent = `${currentWeight.toFixed(1)} / ${invData.maxWeight.toFixed(1)} kg`;

        if (percentage >= 90) weightFill.style.backgroundColor = '#ff4444';
        else weightFill.style.backgroundColor = '#00ff00';
    }
}

function handleSlotMouseDown(e) {
    if (e.button !== 0) return;

    closeContextMenu();
    closeSplitDialog();

    const slotEl = e.currentTarget;
    const invType = slotEl.dataset.inv;
    const slotNumber = parseInt(slotEl.dataset.slot);

    const invData = getInventoryData(invType);
    if (!invData.id || !invData.slots[slotNumber]) return;

    draggedItem = {
        invType: invType,
        invId: invData.id,
        slot: slotNumber,
        item: invData.slots[slotNumber],
        element: slotEl
    };

    let config = itemsConfig[draggedItem.item.name];
    const ghostUrl = itemImageUrl(config, draggedItem.item.name).replace(/'/g, "\\'");
    ghostDrag.innerHTML = `
        <div class="item-img" style="background-image: url('${ghostUrl}');"></div>
        <div class="item-amount">${draggedItem.item.amount}</div>
    `;
    ghostDrag.classList.remove('hidden');
    moveGhost(e);

    slotEl.classList.add('dragging');

    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
}

function handleMouseMove(e) {
    if (draggedItem) {
        moveGhost(e);
    }
}

function moveGhost(e) {
    ghostDrag.style.left = `${e.clientX - 35}px`;
    ghostDrag.style.top = `${e.clientY - 35}px`;
}

function handleMouseUp(e) {
    if (!draggedItem) return;

    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);

    ghostDrag.classList.add('hidden');
    if (draggedItem.element) {
        draggedItem.element.classList.remove('dragging');
    }

    ghostDrag.style.display = 'none';
    let target = document.elementFromPoint(e.clientX, e.clientY);
    ghostDrag.style.display = '';

    let dropSlot = target ? target.closest('.item-slot') : null;

    if (dropSlot) {
        const targetInvType = dropSlot.dataset.inv;
        const targetInvId = getInventoryData(targetInvType).id;
        const targetSlotNumber = parseInt(dropSlot.dataset.slot);

        if (targetInvId) {
            if (targetInvId !== draggedItem.invId || targetSlotNumber !== draggedItem.slot) {
                fetch(`https://inventory/moveItem`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        fromInv: draggedItem.invId,
                        toInv: targetInvId,
                        fromSlot: draggedItem.slot,
                        toSlot: targetSlotNumber,
                        amount: draggedItem.item.amount
                    })
                }).catch(err => console.log(err));
            }
        }
    } else {
        let panels = document.querySelectorAll('.inventory-panel');
        let droppedOnPanel = false;
        panels.forEach(p => {
            let rect = p.getBoundingClientRect();
            if (e.clientX >= rect.left && e.clientX <= rect.right &&
                e.clientY >= rect.top && e.clientY <= rect.bottom) {
                droppedOnPanel = true;
            }
        });

        if (!droppedOnPanel) {
            fetch(`https://inventory/dropItem`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    invId: draggedItem.invId,
                    slot: draggedItem.slot,
                    amount: draggedItem.item.amount
                })
            }).catch(err => console.log(err));
        }
    }

    draggedItem = null;
}

function handleSlotMouseEnter(e) {
    if (draggedItem) {
        e.currentTarget.classList.add('drag-hover');
        return;
    }
    showItemTooltipFor(e.currentTarget, e.clientX, e.clientY);
}

function handleSlotMouseLeave(e) {
    e.currentTarget.classList.remove('drag-hover');
    hideItemTooltip();
}

function escapeHtml(s) {
    return String(s ?? '')
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function showItemTooltipFor(slotEl, x, y) {
    const tt = document.getElementById('item-tooltip');
    if (!tt) return;
    const invType = slotEl.dataset.inv;
    const slotNumber = parseInt(slotEl.dataset.slot);
    const invData = getInventoryData(invType);
    if (!invData) return;
    const itemData = invData.slots && invData.slots[slotNumber];
    if (!itemData) { hideItemTooltip(); return; }
    const cfg = itemsConfig[itemData.name];
    if (!cfg) { hideItemTooltip(); return; }

    const totalW = (Number(cfg.weight || 0) * Number(itemData.amount || 0)).toFixed(2);
    const parts = [];
    parts.push(`<div class="tt-label">${escapeHtml(cfg.label || itemData.name)}</div>`);
    parts.push(`<div class="tt-sub">${escapeHtml(itemData.name)} · ${escapeHtml(cfg.type || 'misc')}</div>`);
    if (cfg.description) parts.push(`<div class="tt-desc">${escapeHtml(cfg.description)}</div>`);
    parts.push(`<div class="tt-stats">
        <span>x${itemData.amount}</span>
        <span>${Number(cfg.weight || 0).toFixed(2)} kg/buc</span>
        <span>total ${totalW} kg</span>
    </div>`);
    if (cfg.usable)    parts.push(`<div class="tt-tag tt-usable">${escapeHtml(SwI18n.t('inventory.ui.tag_usable'))}</div>`);
    if (!cfg.stackable) parts.push(`<div class="tt-tag tt-unique">${escapeHtml(SwI18n.t('inventory.ui.tag_unique'))}</div>`);

    tt.innerHTML = parts.join('');
    tt.classList.remove('hidden');
    positionTooltip(tt, x, y);
}

function positionTooltip(tt, x, y) {
    const margin = 16;
    const w = tt.offsetWidth;
    const h = tt.offsetHeight;
    let left = x + 18;
    let top  = y + 18;
    if (left + w + margin > window.innerWidth)  left = window.innerWidth  - w - margin;
    if (top  + h + margin > window.innerHeight) top  = window.innerHeight - h - margin;
    if (left < margin) left = margin;
    if (top  < margin) top  = margin;
    tt.style.left = `${left}px`;
    tt.style.top  = `${top}px`;
}

function hideItemTooltip() {
    const tt = document.getElementById('item-tooltip');
    if (tt) tt.classList.add('hidden');
}

document.addEventListener('mousemove', (e) => {
    const tt = document.getElementById('item-tooltip');
    if (tt && !tt.classList.contains('hidden')) {
        positionTooltip(tt, e.clientX, e.clientY);
    }
});

function handleContextMenu(e) {
    e.preventDefault();
    if (draggedItem) return;

    const slotEl = e.currentTarget;
    const invType = slotEl.dataset.inv;
    const slotNumber = parseInt(slotEl.dataset.slot);
    const invData = getInventoryData(invType);
    const itemData = invData.slots[slotNumber];

    if (!invData.id || !itemData) {
        closeContextMenu();
        return;
    }

    contextMenuTarget = {
        invType: invType,
        invId: invData.id,
        slot: slotNumber,
        item: itemData
    };

    const menu = document.getElementById('context-menu');
    menu.style.left = `${e.clientX}px`;
    menu.style.top = `${e.clientY}px`;
    menu.classList.remove('hidden');

    const config = itemsConfig[itemData.name];
    if (config && config.usable) {
        document.getElementById('ctx-use').style.display = 'flex';
    } else {
        document.getElementById('ctx-use').style.display = 'none';
    }
    document.getElementById('ctx-split').style.display = 'flex';
}

function closeContextMenu() {
    document.getElementById('context-menu').classList.add('hidden');
    contextMenuTarget = null;
}

document.addEventListener('click', (e) => {
    if (!e.target.closest('#context-menu')) {
        closeContextMenu();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'Tab') {
        document.getElementById('inventory-container').classList.add('hidden');
        closeContextMenu();
        closeSplitDialog();

        fetch(`https://inventory/close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(err => console.log(err));
    }
});

document.getElementById('ctx-use').addEventListener('click', () => {
    if (contextMenuTarget) {
        fetch(`https://inventory/useItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                invId: contextMenuTarget.invId,
                slot: contextMenuTarget.slot
            })
        }).catch(err => console.log(err));
        closeContextMenu();
    }
});

document.getElementById('ctx-give').addEventListener('click', () => {
    if (contextMenuTarget) {
        fetch(`https://inventory/giveItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                invId: contextMenuTarget.invId,
                slot:  contextMenuTarget.slot,
                amount: contextMenuTarget.item.amount,
            })
        }).catch(err => console.log(err));
        closeContextMenu();
    }
});

document.getElementById('ctx-drop').addEventListener('click', () => {
    if (contextMenuTarget) {
        fetch(`https://inventory/dropItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                invId: contextMenuTarget.invId,
                slot: contextMenuTarget.slot,
                amount: contextMenuTarget.item.amount
            })
        }).catch(err => console.log(err));
        closeContextMenu();
    }
});

document.getElementById('ctx-split').addEventListener('click', () => {
    if (contextMenuTarget) {
        if (contextMenuTarget.item.amount <= 1) {
            closeContextMenu();
            return;
        }

        const dialog = document.getElementById('split-dialog');
        const input = document.getElementById('split-amount');
        input.max = contextMenuTarget.item.amount - 1;
        input.value = Math.floor(contextMenuTarget.item.amount / 2);

        dialog.classList.remove('hidden');
        closeContextMenu();
    }
});

function closeSplitDialog() {
    document.getElementById('split-dialog').classList.add('hidden');
}

document.getElementById('split-cancel').addEventListener('click', closeSplitDialog);

document.getElementById('split-confirm').addEventListener('click', () => {
    if (!contextMenuTarget) return;

    let amountStr = document.getElementById('split-amount').value;
    let splitAmount = parseInt(amountStr);

    if (splitAmount > 0 && splitAmount < contextMenuTarget.item.amount) {
        const invData = getInventoryData(contextMenuTarget.invType);
        let emptySlot = null;
        for (let i = 1; i <= uiConfig.MaxSlots; i++) {
            if (!invData.slots[i]) {
                emptySlot = i;
                break;
            }
        }

        if (emptySlot) {
            fetch(`https://inventory/moveItem`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    fromInv: contextMenuTarget.invId,
                    toInv: contextMenuTarget.invId,
                    fromSlot: contextMenuTarget.slot,
                    toSlot: emptySlot,
                    amount: splitAmount
                })
            }).catch(err => console.log(err));
        }
    }
    closeSplitDialog();
});

document.querySelectorAll('.cloth-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        let type = btn.dataset.type;
        fetch(`https://inventory/ToggleClothing`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type: type })
        }).catch((err) => console.log(err));
    });
});

if (uiConfig && uiConfig.MaxSlots > 0) {
    setupGrids();
}
