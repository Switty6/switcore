let shopData = null;
let selectedItem = null;
let cashBalance = 0;
let accounts = [];

function closeShop() {
    fetch(`https://${GetParentResourceName()}/closeShop`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    document.getElementById('shop-overlay').classList.add('hidden');
    resetState();
}

function resetState() {
    shopData = null;
    selectedItem = null;
    document.getElementById('purchase-empty').classList.remove('hidden');
    document.getElementById('purchase-form').classList.add('hidden');
    document.getElementById('buy-error').classList.add('hidden');
    document.getElementById('items-grid').innerHTML = '';
    document.getElementById('qty-input').value = 1;
}

function renderItems(items) {
    const grid = document.getElementById('items-grid');
    grid.innerHTML = '';

    if (!items || items.length === 0) {
        grid.innerHTML = '<div class="no-items">Niciun produs disponibil</div>';
        return;
    }

    items.forEach(item => {
        const card = document.createElement('div');
        card.className = 'item-card';
        card.dataset.name = item.item_name;
        card.onclick = () => selectItem(item);

        const symbol = item.currency_code === 'USD' ? '$' : item.currency_code;
        card.innerHTML = `
            <div class="item-card-img" style="background-image:url('nui://inventory/ui/img/items/${item.item_name}.png')"></div>
            <div class="item-card-label">${item.label}</div>
            <div class="item-card-price">${symbol}${parseFloat(item.price).toFixed(2)}</div>
        `;
        grid.appendChild(card);
    });
}

function selectItem(item) {
    selectedItem = item;

    document.querySelectorAll('.item-card').forEach(c => c.classList.remove('selected'));
    const card = document.querySelector(`.item-card[data-name="${item.item_name}"]`);
    if (card) card.classList.add('selected');

    document.getElementById('purchase-empty').classList.add('hidden');
    document.getElementById('purchase-form').classList.remove('hidden');
    document.getElementById('buy-error').classList.add('hidden');

    const symbol = item.currency_code === 'USD' ? '$' : item.currency_code;
    document.getElementById('item-preview-img').style.backgroundImage =
        `url('nui://inventory/ui/img/items/${item.item_name}.png')`;
    document.getElementById('item-preview-label').textContent = item.label;
    document.getElementById('item-preview-price').textContent = `${symbol}${parseFloat(item.price).toFixed(2)} / buc.`;

    document.getElementById('qty-input').value = 1;
    updateTotal();
    updateBalanceDisplay();
}

function changeQty(delta) {
    const input = document.getElementById('qty-input');
    let val = parseInt(input.value) + delta;
    val = Math.max(1, Math.min(99, val));
    input.value = val;
    updateTotal();
}

document.getElementById('qty-input').addEventListener('input', updateTotal);

function updateTotal() {
    if (!selectedItem) return;
    const qty = parseInt(document.getElementById('qty-input').value) || 1;
    const total = qty * parseFloat(selectedItem.price);
    const symbol = selectedItem.currency_code === 'USD' ? '$' : selectedItem.currency_code;
    document.getElementById('total-value').textContent = `${symbol}${total.toFixed(2)}`;
}

function updateBalanceDisplay() {
    const method = document.getElementById('payment-select').value;
    const symbol = selectedItem && selectedItem.currency_code === 'USD' ? '$' : (selectedItem ? selectedItem.currency_code : '$');
    let balance = 0;

    if (method === 'cash') {
        balance = cashBalance;
    } else {
        const accountId = parseInt(method);
        const acc = accounts.find(a => a.id === accountId);
        balance = acc ? acc.balance : 0;
    }

    document.getElementById('balance-value').textContent = `${symbol}${parseFloat(balance).toFixed(2)}`;
}

document.getElementById('payment-select').addEventListener('change', updateBalanceDisplay);

function buildPaymentOptions() {
    const select = document.getElementById('payment-select');
    select.innerHTML = `<option value="cash">Cash - $${parseFloat(cashBalance).toFixed(2)}</option>`;
    accounts.forEach(acc => {
        const opt = document.createElement('option');
        opt.value = acc.id;
        opt.textContent = `${acc.bankName} (${acc.accountNumber}) - $${parseFloat(acc.balance).toFixed(2)}`;
        select.appendChild(opt);
    });
}

function confirmBuy() {
    if (!selectedItem || !shopData) return;

    const qty = parseInt(document.getElementById('qty-input').value) || 1;
    const method = document.getElementById('payment-select').value;
    const isAccount = method !== 'cash';

    document.getElementById('buy-error').classList.add('hidden');
    document.getElementById('btn-buy').disabled = true;

    fetch(`https://${GetParentResourceName()}/buyItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            shopName: shopData.name,
            itemName: selectedItem.item_name,
            quantity: qty,
            paymentMethod: isAccount ? 'account' : 'cash',
            accountId: isAccount ? parseInt(method) : null
        })
    }).then(() => {
        document.getElementById('btn-buy').disabled = false;
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'open':
            resetState();
            shopData = data.shop;
            cashBalance = data.cash || 0;
            accounts = data.accounts || [];

            document.getElementById('shop-overlay').classList.remove('hidden');
            document.getElementById('shop-name').textContent = data.shop.label;
            const icons = { gun: 'crosshair', pharmacy: 'pill', general: 'shopping-cart' };
            document.getElementById('shop-icon').innerHTML = `<i data-lucide="${icons[data.shop.type] || 'shopping-cart'}"></i>`;
            if (window.lucide) lucide.createIcons();

            renderItems(data.items);
            buildPaymentOptions();
            break;

        case 'close':
            document.getElementById('shop-overlay').classList.add('hidden');
            resetState();
            break;

        case 'buySuccess':
            document.getElementById('btn-buy').disabled = false;
            if (data.currencyCode === 'USD') {
                cashBalance = Math.max(0, cashBalance - data.totalCost);
            }
            buildPaymentOptions();
            updateBalanceDisplay();
            const errEl = document.getElementById('buy-error');
            errEl.innerHTML = '<i data-lucide="check"></i> Cumpărătură reușită!';
            if (window.lucide) lucide.createIcons();
            errEl.className = 'buy-success';
            errEl.classList.remove('hidden');
            setTimeout(() => errEl.classList.add('hidden'), 2500);
            break;

        case 'buyError':
            document.getElementById('btn-buy').disabled = false;
            const errDiv = document.getElementById('buy-error');
            errDiv.textContent = data.error || 'Eroare necunoscută';
            errDiv.className = 'buy-error-msg';
            errDiv.classList.remove('hidden');
            break;
    }
});

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'shops';
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeShop();
});
