local FivemEnv = dofile('spec/support/fivem_env.lua')

describe('LoanManager.createLoan', function()
    local LoanManager
    local captured

    before_each(function()
        FivemEnv.install()
        captured = nil

        -- Capturam argumentele cu care s-ar persista creditul, ca sa verificam
        -- aritmetica (rata lunara, totalul) fara o baza de date reala.
        -- Pozitii: 1 charId, 2 bankId, 3 type, 4 principal, 5 ratePct,
        --          6 remaining/total, 7 monthlyPayment, 8 term, 9 date, 10 currencyId
        BankingDatabase.createLoan = function(...)
            captured = { ... }
            return { id = 1 }
        end
        BankingDatabase.addCharacterCash = function() return true end
        BankingDatabase.createTransaction = function() return true end
        BankingManager.getCharacterAccounts = function() return {} end

        LoanManager = dofile('[switcore]/banking/server/loan_manager.lua')
    end)

    it('respinge tip de credit invalid', function()
        local ok, err = LoanManager.createLoan(1, 1, 'crypto', 10000, 12, 1)
        assert.is_false(ok)
        assert.equals('Tip credit invalid', err)
    end)

    it('respinge termen in afara intervalului permis', function()
        assert.is_false((LoanManager.createLoan(1, 1, 'personal', 10000, 1, 1)))
        assert.is_false((LoanManager.createLoan(1, 1, 'personal', 10000, 999, 1)))
    end)

    it('respinge principal <= 0', function()
        assert.is_false((LoanManager.createLoan(1, 1, 'personal', 0, 12, 1)))
    end)

    it('calculeaza rata lunara cu formula de anuitate', function()
        FivemEnv.setSetting('banking.loan_rate_personal', 12.0)

        local ok = LoanManager.createLoan(1, 1, 'personal', 10000, 12, 1)
        assert.is_true(ok)
        assert.is_not_nil(captured)

        -- 10000 la 12% pe an, 12 luni -> ~888.49 / luna
        local monthlyPayment = captured[7]
        assert.near(888.49, monthlyPayment, 1.0)

        -- Totalul de rambursat = rata lunara * numarul de luni
        local total = captured[6]
        assert.near(monthlyPayment * 12, total, 0.01)

        -- Rata persistata e procentuala (12.0), nu fractie
        assert.near(12.0, captured[5], 1e-9)
    end)

    it('imparte egal principalul cand dobanda e zero', function()
        FivemEnv.setSetting('banking.loan_rate_personal', 0.0)

        local ok = LoanManager.createLoan(1, 1, 'personal', 12000, 12, 1)
        assert.is_true(ok)
        -- 12000 / 12 = 1000, fara dobanda
        assert.near(1000.0, captured[7], 1e-9)
    end)
end)
