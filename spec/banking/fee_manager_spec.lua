local FivemEnv = dofile('spec/support/fivem_env.lua')

describe('FeeManager.calculateFee', function()
    local FeeManager

    before_each(function()
        FivemEnv.install()
        -- CurrencyManager e referit doar pe calea cu conversie valutara;
        -- il punem ca stub gol si adaugam getExchangeRate in testele care au nevoie.
        _G.CurrencyManager = {}
        FeeManager = dofile('[switcore]/banking/server/fee_manager.lua')
    end)

    it('nu percepe comision pentru transfer in aceeasi banca', function()
        assert.equals(0.0, FeeManager.calculateFee(1, 'transfer_same_bank', 100, 1))
    end)

    it('returneaza 0 pentru parametri invalizi', function()
        assert.equals(0.0, FeeManager.calculateFee(nil, 'withdrawal', 100, 1))
        assert.equals(0.0, FeeManager.calculateFee(1, 'withdrawal', 0, 1))
        assert.equals(0.0, FeeManager.calculateFee(1, 'withdrawal', -5, 1))
    end)

    it('returneaza 0 cand comisionul e inactiv', function()
        FeeManager.getBankFee = function() return { is_active = false } end
        assert.equals(0.0, FeeManager.calculateFee(1, 'withdrawal', 100, 1))
    end)

    it('calculeaza un comision procentual in aceeasi valuta', function()
        FeeManager.getBankFee = function()
            return { is_active = true, fee_type_value = 'percentage', fee_amount = 2.5, currency_id = 1 }
        end
        -- 100 * 2.5% = 2.5
        assert.equals(2.5, FeeManager.calculateFee(1, 'withdrawal', 100, 1))
    end)

    it('calculeaza un comision fix in aceeasi valuta', function()
        FeeManager.getBankFee = function()
            return { is_active = true, fee_type_value = 'fixed', fee_amount = 15, currency_id = 1 }
        end
        assert.equals(15, FeeManager.calculateFee(1, 'withdrawal', 100, 1))
    end)

    it('converteste un comision fix in valuta ceruta', function()
        FeeManager.getBankFee = function()
            return { is_active = true, fee_type_value = 'fixed', fee_amount = 10, currency_id = 2 }
        end
        CurrencyManager.getExchangeRate = function() return 4.5 end
        -- 10 (valuta 2) * 4.5 = 45 in valuta 1
        assert.equals(45, FeeManager.calculateFee(1, 'withdrawal', 100, 1))
    end)

    it('converteste un comision procentual in valuta ceruta', function()
        FeeManager.getBankFee = function()
            return { is_active = true, fee_type_value = 'percentage', fee_amount = 10, currency_id = 2 }
        end
        CurrencyManager.getExchangeRate = function() return 2.0 end
        -- 100 * 10% = 10, apoi * 2.0 = 20
        assert.equals(20, FeeManager.calculateFee(1, 'withdrawal', 100, 1))
    end)

    it('returneaza 0 daca lipseste cursul de schimb pentru conversie', function()
        FeeManager.getBankFee = function()
            return { is_active = true, fee_type_value = 'fixed', fee_amount = 10, currency_id = 2 }
        end
        CurrencyManager.getExchangeRate = function() return nil end
        assert.equals(0.0, FeeManager.calculateFee(1, 'withdrawal', 100, 1))
    end)
end)
