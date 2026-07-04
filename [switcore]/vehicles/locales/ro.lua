return {
    vehicles = {
        -- Permisiuni si comenzi admin
        access_denied = 'Acces refuzat',
        admin_vehicle_received = 'Ai primit vehiculul {1} ({2})',

        -- Chei item (folosire vehicle_key)
        key_item_info = 'Cheie: {1} - {2}',

        -- Erori generale vehicul
        invalid_parameters = 'Parametri invalizi',
        vehicle_not_found = 'Vehicul inexistent',
        vehicle_impounded = 'Vehiculul este sechestrat',
        no_key_or_missing = 'Nu ai cheie pentru acest vehicul sau este inexistent',
        no_key_for_vehicle = 'Nu ai cheie pentru acest vehicul',
        character_no_key = 'Personajul nu are cheie pentru acest vehicul',
        already_out = 'Vehiculul este deja scos din garaj',
        no_character = 'No character',

        -- Creare vehicul / placute
        custom_plate_min_length = 'Plăcuța custom trebuie să aibă minim 3 caractere',
        custom_plate_taken = 'Plăcuța custom este deja folosită',
        vehicle_create_db_error = 'Eroare la crearea vehiculului în baza de date',
        plate_generation_failed = 'Nu am putut genera o plăcuță unică după 100 încercări',
        save_state_failed = 'Eroare la salvarea stării vehiculului',

        -- Sechestru
        vehicle_id_missing = 'vehicleId lipsă',
        impound_failed = 'Eroare la sechestrare',
        release_failed = 'Eroare la eliberare din sechestru',

        -- Chei
        key_add_db_error = 'Eroare la adăugarea cheii în baza de date',
        key_remove_failed = 'Eroare la ștergerea cheii',
        not_owner = 'Nu ești proprietarul acestui vehicul',
        ownership_transfer_failed = 'Eroare la transferul proprietății: {1}',

        -- Combustibil / alimentare
        fuel_tank_full = 'Rezervorul este plin',
        banking_unavailable = 'Sistem banking indisponibil',
        no_bank_account = 'Nu ai cont bancar',
        insufficient_cash_fuel = 'Cash insuficient. Necesar: ${1}, ai: ${2}',
        insufficient_bank_fuel = 'Sold bancar insuficient. Necesar: ${1}, ai: ${2}',
        insufficient_cash_amount = 'Cash insuficient: {1}{2} necesar.',
        insufficient_bank_amount = 'Sold bancar insuficient: {1}{2} necesar.',
        auth_error = 'Eroare autentificare.',
        refuel_failed = 'Alimentare eșuată.',
        refueled_success = 'Alimentat {1}L  -  {2}{3} plătit cu {4}',
        pay_method_card = 'cardul',
        pay_method_cash = 'cash',

        -- Motor (client)
        vehicle_locked_no_key = 'Acest vehicul este încuiat sau nu ai cheia!',
        vehicle_locked_no_key_lockpick = 'Acest vehicul este încuiat. Dacă ai o rangă, apasă [G] pentru a forța broasca.',
        engine_off = 'Ai oprit motorul.',
        engine_on = 'Ai pornit motorul.',
        no_vehicle_access = 'Nu ai acces la acest vehicul.',
        keymap_toggle_engine = 'Porneste/Opreste Motorul',
        keymap_lockpick = 'Forteaza broasca vehiculului (lockpick)',

        -- Lockpick (client + server)
        lockpick_start = 'Ai început să forțezi broasca...',
        lockpick_success = 'Ai reușit să forțezi broasca!',
        lockpick_failed = 'Nu ai reușit să forțezi broasca.',
        lockpick_broken = 'Ranga s-a rupt în timpul încercării.',
        no_lockpick = 'Nu ai o rangă pentru a forța broasca.',

        -- Combustibil critic (client)
        fuel_critical = 'Combustibil critic! Alimentați imediat.',

        -- Statie de alimentare (client)
        hose_snapped = 'Furtunul s-a rupt!',
        pump_gone = 'Pompa nu mai există.',
        nozzle_pickup_failed = 'Nu am putut prelua furtunul.',
        attach_hose_to_tank = 'Atașează furtunul la rezervor',
        refuel_action = 'Alimentează',
        press_alt_on_tank = 'Apasă ALT pe rezervorul vehiculului pentru a alimenta.',
        approach_vehicle = 'Apropie-te de un vehicul și apasă ALT pe el.',
        cannot_attach_hose = 'Nu pot ataşa furtunul la acest vehicul.',
        tank_full_choose_payment = 'Rezervor plin! Alege metoda de plată.',
        insufficient_funds_choose_payment = 'Fonduri insuficiente, alege metoda de plată.',
        payment_failed = 'Plată eșuată',

        -- NUI - HUD alimentare
        ui_pump = 'POMPA',
        ui_price_per_litre = 'PREȚ / LITRU',
        ui_cash = 'CASH',
        ui_bank = 'BANCĂ',
        ui_total_available = 'TOTAL DISPONIBIL',
        ui_hold_to_refuel = 'ȚINE APĂSAT [E] PENTRU A ALIMENTA',
        ui_waiting = 'ÎN AȘTEPTARE',
        ui_litres = 'LITRI',
        ui_cost = 'COST',
        ui_tank = 'REZERVOR',
        ui_insufficient_funds_stopped = 'Fonduri insuficiente - alimentare oprită',
        ui_hose = 'FURTUN',
        ui_hose_snapped = 'FURTUN RUPT!',
        ui_refuel_active = 'ALIMENTARE ACTIVĂ - ELIBEREAZĂ PENTRU A OPRI',
        ui_in_progress = 'ÎN CURS',
        ui_cable_critical = 'CRITIC - APROAPE DE RUPERE',
        ui_cable_warning = 'AVERTISMENT - FURTUN ÎNTINS',
        ui_cable_ok = 'OK',
        ui_insufficient_funds = 'FONDURI INSUFICIENTE',

        -- NUI - modal plata
        ui_payment_method = 'METODĂ DE PLATĂ',
        ui_refueled = 'Alimentat',
        ui_to_pay = 'DE PLATĂ',
        ui_card = 'CARD',
        ui_payment_footer = 'Apasă pe metoda dorită pentru a finaliza plata',
        ui_payment_failed = 'Plată eșuată',
    }
}
