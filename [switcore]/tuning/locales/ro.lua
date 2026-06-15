return {
    tuning = {
        -- Mesaje de deschidere shop (openShop)
        open_not_registered = 'Vehiculul nu este înregistrat în sistem.',
        open_no_key = 'Nu ai cheie pentru acest vehicul.',
        open_impounded = 'Vehiculul este sechestrat.',
        open_failed_generic = 'Nu s-a putut deschide LS Customs.',
        open_need_vehicle = 'Trebuie să fii în vehicul pentru a folosi LS Customs.',

        -- Notificari succes catre jucator
        mod_applied = 'Mod aplicat cu succes!',
        color_applied = 'Culoare aplicată!',
        livery_applied = 'Liverie aplicată!',
        mods_reset = 'Mods resetate la stock!',
        cart_applied = 'Coș: {1} upgrade(uri) aplicate!',

        -- Notificari eroare catre jucator
        error_apply_mod = 'Eroare la aplicare mod.',
        error_apply_color = 'Eroare la vopsire.',
        error_apply_livery = 'Eroare la liverie.',
        error_reset = 'Eroare la resetare.',
        error_cart_empty = 'Coșul este gol.',
        error_cart_item = 'Coș: eroare la {1} - {2}',
        error_cart_unknown = 'eroare necunoscută',

        -- Erori din TuningManager (validare/plata/salvare)
        error_no_character = 'Niciun personaj activ',
        error_no_vehicle = 'Vehicul inexistent',
        error_no_key = 'Nu ai cheie pentru acest vehicul',
        error_impounded = 'Vehiculul este sechestrat',
        error_vip_required = 'Necesită abonament VIP',
        error_invalid_category = 'Categorie invalidă',
        error_invalid_tier = 'Tier invalid',
        error_currency_unavailable = 'Monedă indisponibilă',
        error_insufficient_cash = 'Fonduri insuficiente (cash)',
        error_insufficient_bank = 'Fonduri insuficiente (cont bancar)',
        error_no_bank_account = 'Niciun cont bancar activ',
        error_save_mod = 'Eroare la salvarea modificării; banii au fost rambursați',
        error_save_color = 'Eroare la salvarea culorii; banii au fost rambursați',
        error_save_livery = 'Eroare la salvarea livery-ului; banii au fost rambursați',
        error_save_reset = 'Eroare la resetarea modificărilor; banii au fost rambursați',

        -- Proximity / blip
        proximity_label = '{1}\nDeschide LS Customs',
        default_shop_name = 'LS Customs',

        -- Categorii de modificari (label panou stanga)
        category = {
            engine = 'Motor',
            brakes = 'Frâne',
            transmission = 'Transmisie',
            turbo = 'Turbo',
            suspension = 'Suspensie',
            armor = 'Blindaj',
            xenon = 'Xenon',
            wheels = 'Roți',
            color = 'Culoare',
            livery = 'Liverie',
        },

        -- Tipuri de jante
        wheel_type = {
            ['0'] = 'Sport',
            ['1'] = 'Muscle',
            ['2'] = 'Lowrider',
            ['3'] = 'SUV',
            ['4'] = 'Offroad',
            ['5'] = 'Tuner',
            ['6'] = 'Bike',
            ['7'] = 'High-End',
        },

        -- Etichete tier per categorie (label + desc)
        tier = {
            engine = {
                ['1'] = { label = 'EMS Nivel I',    desc = '+4% putere motor, +4% cuplu' },
                ['2'] = { label = 'EMS Nivel II',   desc = '+8% putere motor, +8% cuplu' },
                ['3'] = { label = 'EMS Nivel III',  desc = '+12% putere motor, +12% cuplu' },
                ['4'] = { label = 'EMS Nivel IV',   desc = '+16% putere motor, +16% cuplu · Exclusiv VIP' },
            },
            brakes = {
                ['1'] = { label = 'Frâne Stradă', desc = 'Distanță frânare redusă cu 10%' },
                ['2'] = { label = 'Frâne Sport',  desc = 'Distanță frânare redusă cu 20%' },
                ['3'] = { label = 'Frâne Cursă',  desc = 'Distanță frânare redusă cu 30%' },
            },
            transmission = {
                ['1'] = { label = 'Transmisie Stradă', desc = 'Schimbare viteze cu 5% mai rapidă' },
                ['2'] = { label = 'Transmisie Sport',  desc = 'Schimbare viteze cu 10% mai rapidă' },
                ['3'] = { label = 'Transmisie Cursă',  desc = 'Schimbare viteze cu 15% mai rapidă' },
            },
            turbo = {
                ['1'] = { label = 'Turbo Kit', desc = 'Boost semnificativ la turații înalte' },
            },
            suspension = {
                ['1'] = { label = 'Lowering',   desc = 'Centru de greutate coborât' },
                ['2'] = { label = 'Stradă',     desc = 'Handling îmbunătățit pe asfalt' },
                ['3'] = { label = 'Sport',      desc = 'Stabilitate sporită în curbe' },
                ['4'] = { label = 'Cursă',      desc = 'Aderență maximizată' },
                ['5'] = { label = 'Competiție', desc = 'Suspensie de circuit profesional' },
            },
            armor = {
                ['1'] = { label = 'Blindaj Nivel I',   desc = '+20% rezistență la proiectile' },
                ['2'] = { label = 'Blindaj Nivel II',  desc = '+40% rezistență la proiectile' },
                ['3'] = { label = 'Blindaj Nivel III', desc = '+60% rezistență la proiectile' },
                ['4'] = { label = 'Blindaj Nivel IV',  desc = '+80% rezistență la proiectile' },
                ['5'] = { label = 'Blindaj Nivel V',   desc = 'Protecție completă · Exclusiv VIP' },
            },
            xenon = {
                ['1'] = { label = 'Faruri Xenon', desc = 'Intensitate ridicată, rază mai mare' },
            },
            wheels = {
                ['0'] = { label = 'Sport',    desc = 'Jante sport ușoare' },
                ['1'] = { label = 'Muscle',   desc = 'Jante musculare clasice' },
                ['2'] = { label = 'Lowrider', desc = 'Jante lowrider cu profil scăzut' },
                ['3'] = { label = 'SUV',      desc = 'Jante SUV robuste' },
                ['4'] = { label = 'Offroad',  desc = 'Jante pentru teren accidentat' },
                ['5'] = { label = 'Tuner',    desc = 'Jante tuner moderne' },
                ['6'] = { label = 'Bike',     desc = 'Jante pentru motociclete' },
                ['7'] = { label = 'High-End', desc = 'Jante premium de lux · Exclusiv VIP' },
            },
        },

        -- Culori pearlescent (palette)
        pearl = {
            ['0'] = 'Negru',
            ['1'] = 'Grafit',
            ['5'] = 'Antracit',
            ['6'] = 'Argint Mat',
            ['11'] = 'Argint Pur',
            ['27'] = 'Roșu Sport',
            ['28'] = 'Roșu Lumânare',
            ['36'] = 'Portocaliu',
            ['38'] = 'Auriu',
            ['49'] = 'Verde Pădure',
            ['51'] = 'Verde Lime',
            ['62'] = 'Albastru Navy',
            ['64'] = 'Albastru Galaxy',
            ['70'] = 'Albastru Cer',
            ['88'] = 'Galben',
            ['89'] = 'Galben Race',
            ['111'] = 'Alb Cremă',
            ['112'] = 'Alb Pur',
            ['132'] = 'Roz',
            ['145'] = 'Violet',
        },

        -- Interfata NUI
        ui = {
            -- Etichete statice (data-i18n)
            shop_default = 'LS Customs',
            plate_placeholder = '- - -',
            vip = 'VIP',
            cart_empty = 'Niciun upgrade selectat · Adaugă din panoul din dreapta',
            total = 'Total',
            pay_cash = 'Cash',
            pay_bank = 'Bancă',
            buy_all = 'Cumpără Tot',
            reset_stock = 'Reset Stock',
            reset_stock_title = 'Reset Stock',
            modal_confirm_title = 'Confirmă',
            modal_cancel = 'Anulează',
            modal_confirm = 'Confirmă',
            panel_default_title = 'Motor',

            -- Stringuri generate din JS
            free = 'Gratuit',
            stock = 'Stock',
            stock_desc = 'Configurație originală',
            tier_generic = 'Tier {1}',
            type_generic = 'Tip {1}',
            badge_installed = 'Instalat',
            badge_in_cart = 'În coș',
            badge_vip = 'VIP',

            color_primary_section = 'Culoare Primară',
            color_secondary_section = 'Culoare Secundară',
            color_primary_label = 'Primară',
            color_secondary_label = 'Secundară',
            pearl_section = 'Pearlescent',
            pearl_hint = '(luciu suprapus peste vopsea)',
            paint_cost = 'Cost vopsire',
            add_to_cart = 'Adaugă în coș',
            remove_from_cart = 'Scoate din coș',
            paint_label = 'Vopsire',

            wheel_type_hint = 'Tip: {1} - alege un design.',
            wheel_pick_type = 'Alege întâi un tip de jantă.',
            wheel_design_header = 'Design {1}',
            wheel_no_design = 'Niciun design disponibil pentru acest tip.',
            wheel_design_line = '{1} · Design #{2}',
            wheel_cart_label = '{1} #{2}',
            wheels_fallback = 'Roți',

            livery_cost_hint = 'Cost per liverie: {1}',
            livery_none = 'Fără liverie',
            livery_generic = 'Liverie {1}',

            chip_remove = 'Scoate',

            buy_modal_title = 'Confirmă achiziția',
            buy_modal_total = 'Total: {1}',
            buy_modal_line = '• {1} - {2}',
            reset_modal_title = 'Reset la Stock',
            reset_modal_body = 'Toate modificările vor fi eliminate.',
            reset_modal_cost = 'Cost: {1}',
        },
    },
}
