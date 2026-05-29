local FivemEnv = dofile('spec/support/fivem_env.lua')

describe('BankingHelpers', function()
    local BankingHelpers

    before_each(function()
        FivemEnv.install()
        BankingHelpers = dofile('[switcore]/banking/server/banking_helpers.lua')
    end)

    describe('validateIds', function()
        it('accepta id-uri pozitive si le converteste la numere', function()
            local ok, err, characterId, accountId, currencyId =
                BankingHelpers.validateIds('5', '7', '2')

            assert.is_true(ok)
            assert.is_nil(err)
            assert.equals(5, characterId)
            assert.equals(7, accountId)
            assert.equals(2, currencyId)
        end)

        it('respinge id-uri zero sau negative', function()
            assert.is_false((BankingHelpers.validateIds(0, 1, 1)))
            assert.is_false((BankingHelpers.validateIds(1, -1, 1)))
            assert.is_false((BankingHelpers.validateIds(1, 1, 0)))
        end)

        it('respinge valori nenumerice', function()
            local ok, err = BankingHelpers.validateIds('abc', 1, 1)
            assert.is_false(ok)
            assert.equals('ID-uri invalide', err)
        end)
    end)

    describe('validateTransactionAmount', function()
        it('respinge sume <= 0 sau nil', function()
            assert.is_false((BankingHelpers.validateTransactionAmount(0)))
            assert.is_false((BankingHelpers.validateTransactionAmount(-10)))
            assert.is_false((BankingHelpers.validateTransactionAmount(nil)))
        end)

        it('respecta limitele min/max din settings', function()
            FivemEnv.setSetting('banking.min_transaction_amount', 10)
            FivemEnv.setSetting('banking.max_transaction_amount', 1000)

            assert.is_false((BankingHelpers.validateTransactionAmount(5)))
            assert.is_false((BankingHelpers.validateTransactionAmount(5000)))
            assert.is_true(BankingHelpers.validateTransactionAmount(500))
        end)

        it('foloseste implicitele cand settings lipsesc', function()
            assert.is_true(BankingHelpers.validateTransactionAmount(0.01))
            assert.is_true(BankingHelpers.validateTransactionAmount(1000))
        end)
    end)

    describe('validateAccountOwnership', function()
        it('respinge cont inexistent', function()
            local ok, err = BankingHelpers.validateAccountOwnership(nil, 1)
            assert.is_false(ok)
            assert.equals('Cont nu există', err)
        end)

        it('respinge contul altui caracter', function()
            local ok = BankingHelpers.validateAccountOwnership({ character_id = 2 }, 1)
            assert.is_false(ok)
        end)

        it('accepta proprietarul corect', function()
            assert.is_true(BankingHelpers.validateAccountOwnership({ character_id = 1 }, 1))
        end)
    end)

    describe('parseBalance', function()
        it('returneaza tabelul direct daca primeste deja un tabel', function()
            local balance = { usd = 100 }
            assert.equals(balance, BankingHelpers.parseBalance(balance))
        end)

        it('decodeaza un string JSON valid', function()
            _G.json.decode = function() return { usd = 50 } end
            local result = BankingHelpers.parseBalance('{"usd":50}')
            assert.equals(50, result.usd)
        end)

        it('returneaza tabel gol cand JSON-ul e invalid', function()
            _G.json.decode = function() error('invalid') end
            assert.same({}, BankingHelpers.parseBalance('nu e json'))
        end)

        it('returneaza tabel gol pentru nil', function()
            assert.same({}, BankingHelpers.parseBalance(nil))
        end)
    end)

    describe('lastDayOfMonth', function()
        it('returneaza zilele corecte pentru luni obisnuite', function()
            assert.equals(31, BankingHelpers.lastDayOfMonth(2026, 1))
            assert.equals(30, BankingHelpers.lastDayOfMonth(2026, 4))
            assert.equals(31, BankingHelpers.lastDayOfMonth(2026, 12))
        end)

        it('gestioneaza februarie in ani normali si bisecti', function()
            assert.equals(28, BankingHelpers.lastDayOfMonth(2026, 2))
            assert.equals(29, BankingHelpers.lastDayOfMonth(2024, 2))
            assert.equals(28, BankingHelpers.lastDayOfMonth(2100, 2)) -- divizibil cu 100, nu cu 400
            assert.equals(29, BankingHelpers.lastDayOfMonth(2000, 2)) -- divizibil cu 400
        end)
    end)

    describe('advanceOneMonth', function()
        it('avanseaza o luna pastrand ziua cand e valida', function()
            assert.equals('2026-02-15', BankingHelpers.advanceOneMonth('2026-01-15'))
        end)

        it('clampeaza ziua 31 la sfarsitul lunii scurte', function()
            -- bug-ul original: 2026-01-31 producea 2026-02-31, respins de DATE
            assert.equals('2026-02-28', BankingHelpers.advanceOneMonth('2026-01-31'))
            assert.equals('2026-04-30', BankingHelpers.advanceOneMonth('2026-03-31'))
        end)

        it('clampeaza la 29 februarie in an bisect', function()
            assert.equals('2024-02-29', BankingHelpers.advanceOneMonth('2024-01-31'))
        end)

        it('trece corect peste granita de an', function()
            assert.equals('2027-01-31', BankingHelpers.advanceOneMonth('2026-12-31'))
        end)
    end)
end)
