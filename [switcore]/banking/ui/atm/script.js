
let atmAccounts = [];
let atmCash = 0;

function atmShowView(viewName) {
    document.querySelectorAll('#atm-wrapper .atm-view').forEach(v => v.classList.remove('active'));
    const view = document.getElementById('atm-view-' + viewName);
    if (view) view.classList.add('active');
}

function setAmount(inputId, amount) {
    document.getElementById(inputId).value = amount;
}

function populateATMSelects() {
    const selects = ['atm-withdraw-account', 'atm-deposit-account', 'atm-transfer-from'];
    selects.forEach(id => {
        const select = document.getElementById(id);
        if (!select) return;
        select.innerHTML = '';
        atmAccounts.forEach(acc => {
            const opt = document.createElement('option');
            opt.value = acc.id;
            opt.textContent = acc.accountNumber + ' (' + formatMoney(acc.balance) + ')';
            select.appendChild(opt);
        });
    });
}

function renderATMAccounts() {
    const list = document.getElementById('atm-accounts-list');
    if (!list) return;

    if (atmAccounts.length === 0) {
        list.innerHTML = '<div class="atm-account-item"><span class="atm-account-name" style="color: rgba(180,220,255,0.4);">Nu există conturi</span></div>';
        return;
    }

    list.innerHTML = atmAccounts.map(acc => `
        <div class="atm-account-item">
            <div>
                <div class="atm-account-name">${acc.bankName} - ${acc.accountType === 'current' ? 'Curent' : acc.accountType === 'savings' ? 'Economii' : 'Depozit'}</div>
                <div class="atm-account-number">${acc.accountNumber}</div>
            </div>
            <div class="atm-account-balance">${formatMoney(acc.balance)}</div>
        </div>
    `).join('');
}

function handleAccountsData(data) {
    if (!data || !data.success) return;

    atmAccounts = data.accounts || [];
    document.getElementById('atm-cash').textContent = formatMoney(atmCash);
    renderATMAccounts();
    populateATMSelects();

    if (typeof updateBankAccounts === 'function') {
        updateBankAccounts(data.accounts || []);
    }
}

function handleCashData(data) {
    if (!data || !data.success) return;
    atmCash = data.cash || 0;
    document.getElementById('atm-cash').textContent = formatMoney(atmCash);

    if (typeof updateBankCash === 'function') {
        updateBankCash(data.cash || 0);
    }
}

function atmWithdraw() {
    const accountId = document.getElementById('atm-withdraw-account').value;
    const amount = parseFloat(document.getElementById('atm-withdraw-amount').value);
    if (!accountId || !amount || amount <= 0) {
        showToast('Completează toate câmpurile', 'error');
        return;
    }
    fetch('https://banking/withdraw', {
        method: 'POST',
        body: JSON.stringify({ accountId: parseInt(accountId), amount: amount })
    });
    document.getElementById('atm-withdraw-amount').value = '';
}

function atmDeposit() {
    const accountId = document.getElementById('atm-deposit-account').value;
    const amount = parseFloat(document.getElementById('atm-deposit-amount').value);
    if (!accountId || !amount || amount <= 0) {
        showToast('Completează toate câmpurile', 'error');
        return;
    }
    fetch('https://banking/deposit', {
        method: 'POST',
        body: JSON.stringify({ accountId: parseInt(accountId), amount: amount })
    });
    document.getElementById('atm-deposit-amount').value = '';
}

function atmTransfer() {
    const fromAccountId = document.getElementById('atm-transfer-from').value;
    const toAccountNumber = document.getElementById('atm-transfer-to').value;
    const amount = parseFloat(document.getElementById('atm-transfer-amount').value);
    if (!fromAccountId || !toAccountNumber || !amount || amount <= 0) {
        showToast('Completează toate câmpurile', 'error');
        return;
    }
    fetch('https://banking/transfer', {
        method: 'POST',
        body: JSON.stringify({
            fromAccountId: parseInt(fromAccountId),
            toAccountNumber: toAccountNumber,
            amount: amount
        })
    });
    document.getElementById('atm-transfer-amount').value = '';
    document.getElementById('atm-transfer-to').value = '';
}
