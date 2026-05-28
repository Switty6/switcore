
let bankAccounts = [];
let bankCash = 0;
let bankTransactions = [];
let banksList = [];
let currenciesList = [];
let loansList = [];

function bankShowView(viewName) {
    document.querySelectorAll('.bank-nav-item').forEach(v => v.classList.remove('active'));
    document.querySelectorAll('#bank-wrapper .bank-view').forEach(v => v.classList.remove('active'));
    
    document.querySelector(`.bank-nav-item[data-view="${viewName}"]`).classList.add('active');
    document.getElementById('bank-view-' + viewName).classList.add('active');
    
    if (viewName === 'transactions') {
        refreshTransactions();
    }
}

function bankOpTab(tabId, element) {
    document.querySelectorAll('.bank-op-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.bank-op-panel').forEach(p => p.classList.remove('active'));
    
    if (element) {
        element.classList.add('active');
    }
    document.getElementById(tabId).classList.add('active');
}

function updateBankAccounts(accounts) {
    bankAccounts = accounts;
    let totalBal = 0;
    accounts.forEach(a => totalBal += Number(a.balance));
    
    document.getElementById('bank-total-balance').textContent = formatMoney(totalBal);
    document.getElementById('bank-account-count').textContent = accounts.length;
    
    renderBankAccountsGrid(accounts);
    renderBankAccountsDashboard(accounts);
    populateBankSelects(accounts);
}

function updateBankCash(cash) {
    bankCash = cash;
    document.getElementById('bank-cash').textContent = formatMoney(cash);
    document.getElementById('bank-dep-cash').textContent = formatMoney(cash);
}

function renderBankAccountsGrid(accounts) {
    const grid = document.getElementById('bank-accounts-grid');
    if (!grid) return;
    
    if (accounts.length === 0) {
        grid.innerHTML = '<p style="color:rgba(232,244,255,0.4); padding:20px; font-size:13px;">Nu există conturi deschise.</p>';
        return;
    }
    
    grid.innerHTML = accounts.map(acc => `
        <div class="bank-account-card">
            <div class="bank-account-header">
                <span class="bank-account-bank">${acc.bankName}</span>
                <span class="bank-account-type">${acc.accountType}</span>
            </div>
            <div class="bank-account-balance">${formatMoney(acc.balance)}</div>
            <div class="bank-account-number">${acc.accountNumber}</div>
        </div>
    `).join('');
}

function renderBankAccountsDashboard(accounts) {
    const list = document.getElementById('bank-dashboard-accounts');
    if (!list) return;
    
    list.innerHTML = accounts.slice(0, 3).map(acc => `
        <div class="bank-transaction-item" style="border-radius: 12px; border: 1px solid rgba(0,180,255,0.1); margin-bottom: 8px;">
            <div class="bank-transaction-info">
                <div class="bank-transaction-icon" style="background:rgba(0,180,255,0.08); border:1px solid rgba(0,180,255,0.15); color:#00b4ff;">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/></svg>
                </div>
                <div class="bank-transaction-details">
                    <h4>${acc.bankName} - ${acc.accountType}</h4>
                    <p>${acc.accountNumber}</p>
                </div>
            </div>
            <div class="bank-transaction-amount positive">${formatMoney(acc.balance)}</div>
        </div>
    `).join('');

    if (accounts.length === 0) list.innerHTML = '<p style="color:rgba(232,244,255,0.4); padding:10px 0;">Nu există conturi. Creează unul din meniul Conturi.</p>';
}

function populateBankSelects(accounts) {
    const selects = ['bank-dep-account', 'bank-wit-account', 'bank-tr-from', 'bank-ex-account'];
    selects.forEach(id => {
        const select = document.getElementById(id);
        if (!select) return;
        select.innerHTML = '';
        accounts.forEach(acc => {
            const opt = document.createElement('option');
            opt.value = acc.id;
            opt.textContent = `${acc.bankName} - ${acc.accountNumber} (${formatMoney(acc.balance)})`;
            select.appendChild(opt);
        });
    });
}

function handleTransactionsData(data) {
    if (!data || !data.success) return;
    bankTransactions = data.transactions || [];
    renderTransactions(bankTransactions, 'bank-transactions-list');
    renderTransactions(bankTransactions.slice(0, 5), 'bank-dashboard-transactions');
}

function renderTransactions(transactions, containerId) {
    const list = document.getElementById(containerId);
    if (!list) return;
    
    if (transactions.length === 0) {
        list.innerHTML = '<p style="padding:20px; color:rgba(232,244,255,0.4); text-align:center; font-size:13px; letter-spacing:0.5px;">Nu există tranzacții recente.</p>';
        return;
    }
    
    list.innerHTML = transactions.map(tx => {
        let isIn = tx.transaction_type === 'deposit' || (tx.transaction_type === 'transfer' && tx.to_account_id);
        if(tx.transaction_type === 'transfer') {
             isIn = tx.amount > 0;
        }
        
        const isOut = tx.transaction_type === 'withdrawal' || tx.transaction_type === 'fee' || tx.transaction_type === 'loan_payment';
        if(isOut) isIn = false;

        const icon = isIn ? '↓' : '↑';
        const colorClass = isIn ? 'in' : 'out';
        const amountClass = isIn ? 'positive' : 'negative';
        const sign = isIn ? '+' : '-';
        
        let txDesc = tx.description || tx.transaction_type;
        const date = new Date(tx.created_at).toLocaleString('ro-RO', {hour: '2-digit', minute:'2-digit', day:'numeric', month:'short'});
        
        return `
            <div class="bank-transaction-item">
                <div class="bank-transaction-info">
                    <div class="bank-transaction-icon ${colorClass}">${icon}</div>
                    <div class="bank-transaction-details">
                        <h4>${txDesc}</h4>
                        <p>${date}</p>
                    </div>
                </div>
                <div class="bank-transaction-amount ${amountClass}">${sign}${formatMoney(tx.amount)}</div>
            </div>
        `;
    }).join('');
}

function refreshTransactions() {
    fetch('https://banking/getTransactions', { method: 'POST', body: JSON.stringify({ limit: 50 }) });
}

function handleBanksData(data) {
    if (!data.success) return;
    banksList = data.banks || [];
    
    const selects = ['modal-bank', 'modal-loan-bank'];
    selects.forEach(id => {
        const sel = document.getElementById(id);
        if(sel) {
            sel.innerHTML = banksList.map(b => `<option value="${b.code}">${b.name}</option>`).join('');
        }
    });
}

function handleCurrenciesData(data) {
    if (!data.success) return;
    currenciesList = data.currencies || [];
    
    const selects = ['bank-ex-from', 'bank-ex-to'];
    selects.forEach(id => {
        const sel = document.getElementById(id);
        if(sel) {
            sel.innerHTML = currenciesList.map(c => `<option value="${c.id}">${c.name} (${c.code})</option>`).join('');
        }
    });
}

function handleLoansData(data) {
    if(!data.success) return;
    loansList = data.loans || [];
    document.getElementById('bank-total-debt').textContent = formatMoney(data.totalDebt);
    document.getElementById('bank-loans-total-debt').textContent = formatMoney(data.totalDebt);
    
    const list = document.getElementById('bank-loans-list');
    if(!list) return;
    
    if(loansList.length === 0) {
        list.innerHTML = '<div style="background:rgba(255,255,255,0.03); padding:20px; border-radius:14px; border:1px solid rgba(0,180,255,0.1); text-align:center; color:rgba(232,244,255,0.4);">Nu ai niciun credit activ.</div>';
        return;
    }

    list.innerHTML = loansList.map(loan => `
        <div class="bank-account-card" style="margin-bottom:12px;">
            <div class="bank-account-header">
                <span class="bank-account-bank">Credit ${loan.loan_type}</span>
                <span class="bank-account-type">Rata: ${loan.interest_rate}%</span>
            </div>
            <div style="display:flex; justify-content:space-between; align-items:flex-end;">
                <div>
                    <div style="font-size:11px; color:rgba(232,244,255,0.4); margin-bottom:4px; text-transform:uppercase; letter-spacing:1px;">De plată (Total)</div>
                    <div class="bank-account-balance" style="color:#ff4d6a; text-shadow:0 0 15px rgba(255,77,106,0.3);">${formatMoney(loan.remaining_amount)}</div>
                </div>
                <button class="bank-btn bank-btn-secondary" style="padding:8px 14px;" onclick="showPayLoanModal(${loan.id}, ${loan.remaining_amount})">Plătește Rate</button>
            </div>
            <div style="margin-top:12px; background:rgba(0,0,0,0.2); padding:10px 12px; border-radius:8px; border:1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; font-size:11px; color:rgba(232,244,255,0.5); letter-spacing:0.5px;">
                <span>Principal: ${formatMoney(loan.principal_amount)}</span>
                <span>Termen: ${loan.term_months} luni</span>
            </div>
        </div>
    `).join('');
}

function bankDeposit() {
    const accountId = document.getElementById('bank-dep-account').value;
    const amount = parseFloat(document.getElementById('bank-dep-amount').value);
    if (!accountId || !amount) return showToast('Validează câmpurile', 'error');
    fetch('https://banking/deposit', { method: 'POST', body: JSON.stringify({ accountId: parseInt(accountId), amount }) });
    document.getElementById('bank-dep-amount').value = '';
}

function bankWithdraw() {
    const accountId = document.getElementById('bank-wit-account').value;
    const amount = parseFloat(document.getElementById('bank-wit-amount').value);
    if (!accountId || !amount) return showToast('Validează câmpurile', 'error');
    fetch('https://banking/withdraw', { method: 'POST', body: JSON.stringify({ accountId: parseInt(accountId), amount }) });
    document.getElementById('bank-wit-amount').value = '';
}

function bankTransfer() {
    const fromId = document.getElementById('bank-tr-from').value;
    const toAcc = document.getElementById('bank-tr-to').value;
    const amount = parseFloat(document.getElementById('bank-tr-amount').value);
    if (!fromId || !toAcc || !amount) return showToast('Validează câmpurile', 'error');
    fetch('https://banking/transfer', { method: 'POST', body: JSON.stringify({ fromAccountId: parseInt(fromId), toAccountNumber: toAcc, amount }) });
    document.getElementById('bank-tr-to').value = '';
    document.getElementById('bank-tr-amount').value = '';
}

function bankExchange() {
    const accountId = document.getElementById('bank-ex-account').value;
    const fromId = document.getElementById('bank-ex-from').value;
    const toId = document.getElementById('bank-ex-to').value;
    const amount = parseFloat(document.getElementById('bank-ex-amount').value);
    if (!accountId || !fromId || !toId || !amount) return showToast('Validează câmpurile', 'error');
    fetch('https://banking/exchangeCurrency', { method: 'POST', body: JSON.stringify({ accountId: parseInt(accountId), amount, currencyFromId: parseInt(fromId), currencyToId: parseInt(toId) }) });
    document.getElementById('bank-ex-amount').value = '';
}

function showCreateAccountModal() {
    document.getElementById('create-account-modal').classList.add('active');
}

function createAccount() {
    const bankCode = document.getElementById('modal-bank').value;
    const type = document.getElementById('modal-account-type').value;
    fetch('https://banking/createAccount', { method: 'POST', body: JSON.stringify({ bankCode, accountType: type }) });
}

function showCreateLoanModal() {
    document.getElementById('create-loan-modal').classList.add('active');
}

function createLoan() {
    const bankCode = document.getElementById('modal-loan-bank').value;
    const type = document.getElementById('modal-loan-type').value;
    const amount = parseFloat(document.getElementById('modal-loan-amount').value);
    const term = parseInt(document.getElementById('modal-loan-term').value);
    if (!amount || !term) return showToast('Validează câmpurile', 'error');
    fetch('https://banking/createLoan', { method: 'POST', body: JSON.stringify({ bankCode, loanType: type, amount, termMonths: term }) });
}

function showPayLoanModal(loanId, maxAmount) {
    document.getElementById('modal-pay-loan-id').value = loanId;
    document.getElementById('modal-pay-loan-amount').value = maxAmount;
    document.getElementById('pay-loan-modal').classList.add('active');
}

function payLoan() {
    const loanId = document.getElementById('modal-pay-loan-id').value;
    const amount = parseFloat(document.getElementById('modal-pay-loan-amount').value);
    if (!loanId || !amount) return;
    fetch('https://banking/payLoan', { method: 'POST', body: JSON.stringify({ loanId: parseInt(loanId), amount }) });
}
