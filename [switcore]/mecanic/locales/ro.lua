return {
    mecanic = {
        -- Erori si acces
        err_generic = 'Eroare',
        err_internal = 'Eroare interna',
        err_no_mechanic = 'Nu esti mecanic.',
        err_access_denied = 'Acces interzis',
        err_no_roadside_perm = 'Nu ai permisiunea de asistenta rutiera.',
        err_no_service_perm = 'Nu ai permisiunea pentru acest serviciu.',
        err_only_manager_parts = 'Doar managerul poate cumpara piese.',

        -- Plata si fonduri
        ron_currency_missing = 'Valuta RON nu a fost gasita.',
        payment_failed = 'Plata esecata',
        client_no_funds = 'Clientul nu are fonduri suficiente.',
        insufficient_funds = 'Fonduri insuficiente',
        client_insufficient_funds = 'Nu ai destui bani pentru acest serviciu.',
        money_refunded = 'Banii au fost restituiti clientului.',
        firm_no_funds = 'Firma nu are suficienti bani.',

        -- Serviciu finalizat / plata
        service_paid_title = 'Plata serviciu',
        service_paid_msg = 'Ai platit {1} RON pentru {2}.',
        service_done_title = 'Serviciu finalizat',
        service_bonus_msg = 'Ai primit bonus {1} RON ({2}%).',

        -- Cereri de serviciu (server)
        call_create_failed = 'Nu s-a putut crea cererea de serviciu.',
        mechanic_called_title = 'Mecanic chemat',
        mechanic_called_msg = 'Cererea a fost trimisa. Asteapta un mecanic disponibil.',
        call_invalid_title = 'Cerere invalida',
        call_unavailable = 'Cererea nu mai este disponibila.',
        call_accept_failed = 'Nu s-a putut accepta cererea.',
        call_accepted_title = 'Cerere acceptata',
        call_accepted_msg = 'Deplaseaza-te la locatia clientului.',
        mechanic_enroute_title = 'Mecanic in drum',
        mechanic_enroute_msg = 'Mecanicul {1} {2} se deplaseaza catre tine.',
        call_cancelled_title = 'Cerere anulata',
        call_cancelled_msg = 'Cererea de mecanic a fost anulata.',

        -- Service / vehicul (server)
        client_disconnected = 'Clientul nu mai este conectat.',
        vehicle_not_found = 'Vehiculul nu a fost gasit.',
        part_missing_title = 'Piesa lipsa',
        part_missing_msg = 'Ai nevoie de {1}x {2} pentru acest serviciu.',
        vehicle_towed_title = 'Vehicul tractat',
        vehicle_towed_msg = 'Vehiculul tau a fost dus la service. Il poti ridica din garaj.',
        parts_bought_title = 'Piese cumparate',
        parts_bought_msg = 'Ai cumparat {1}x {2} ({3} RON din contul firmei).',
        vehicle_not_registered_title = 'Vehicul negasit',
        vehicle_not_registered_msg = 'Vehiculul cu placa {1} nu e inregistrat.',

        -- Denumiri servicii (folosite la notificari si log)
        service = {
            inspect = 'Diagnoza',
            oil_change = 'Schimb ulei',
            brakes = 'Schimb placute frana',
            battery = 'Inlocuire baterie',
            tire = 'Schimb anvelope ({1} buc)',
            suspension = 'Reparatie suspensie',
            engine = 'Reparatie motor',
            bodywork = 'Reparatie caroserie',
            roadside_engine = 'Urgenta motor (rutier)',
            roadside_tire = 'Schimb anvelopa (rutier)',
            roadside_battery = 'Jump start baterie',
            roadside_tow = 'Tractare la atelier',
        },
        -- Etichete tranzactii banca org
        tx_service = 'Serviciu: {1}',
        tx_bonus = 'Bonus mecanic',
        tx_buy_parts = 'Cumparare piese: {1} x{2}',

        -- Client (notificari client)
        notify = {
            service_failed_title = 'Esuat',
            minigame_failed = 'Minijoc esuat. Incearca din nou.',
            service_done_title = 'Serviciu finalizat',
            service_done_msg = 'Serviciul a fost efectuat cu succes!',
            service_active_title = 'Serviciu activ',
            service_active_msg = 'Mergi la zona marcata si interactioneaza.',
            busy_title = 'Ocupat',
            busy_msg = 'Esti deja in mijlocul unui serviciu.',
        },

        -- Avertizari componente (client)
        warn = {
            oil_low_title = 'Ulei Motor',
            oil_low_msg = 'Nivelul de ulei este scazut! Mergi la mecanic.',
            oil_crit_title = 'URGENT - Ulei Motor!',
            oil_crit_msg = 'Motorul pierde ulei! Mergi IMEDIAT la mecanic!',
            battery_low_title = 'Baterie Slaba',
            battery_low_msg = 'Bateria masinii este descarcata. Mergi la mecanic.',
            brakes_title = 'Placute Frana',
            brakes_msg = 'Placutele de frana sunt uzate. Mergi la mecanic.',
            tire_flat_title = 'Roata Sparta!',
            tire_flat_msg = 'Roata {1} este sparta! Suna un mecanic.',
            vehicle_repaired_title = 'Vehicul reparat',
            vehicle_repaired_msg = 'Reparatia a fost efectuata cu succes.',
        },

        -- Roadside (client)
        roadside = {
            call_title = 'Cerere Mecanic!',
            call_msg = '{1} are o problema: {2}',
            blip_call_name = 'Cerere: {1}',
            blip_client_name = 'Client in nevoie',
            arrived_title = 'Ai ajuns!',
            arrived_msg = 'Apasa E langa vehiculul clientului pentru servicii.',
            tow_done_title = 'Tractare finalizata',
            tow_done_msg = 'Vehiculul clientului a fost dus la service.',
        },

        -- Etichete probleme (client + UI)
        problem = {
            engine = 'Motor avariat',
            tire = 'Roata sparta',
            battery = 'Baterie descarcata',
            tow = 'Tractare necesara',
            tow_short = 'Tractare',
        },

        -- Harta / proximity / blip
        blip_workshop = 'Service Auto',
        prox_open_tablet = 'Service Auto - Deschide Tableta',
        prox_vehicle_services = 'Servicii Vehicul [{1}]',

        -- Etichete tinte serviciu (markere lume)
        target = {
            inspect = 'Diagnosticare auto',
            oil_change = 'Schimb ulei motor',
            brakes = 'Schimb placute frana',
            tire_pos = 'Anvelopa {1}',
            tire_generic = 'Schimb anvelopa',
            suspension_right = 'Suspensie dreapta',
            suspension_left = 'Suspensie stanga',
            battery = 'Inlocuire baterie',
            engine = 'Reparatie motor',
            bodywork = 'Reparatie caroserie',
        },
        wheel = {
            fl = 'Stanga-fata',
            fr = 'Dreapta-fata',
            rl = 'Stanga-spate',
            rr = 'Dreapta-spate',
        },

        -- Etichete minijoc (label trimis la NUI)
        minigame = {
            inspect = 'Diagnosticare vehicul...',
            oil_change = 'Schimb ulei motor...',
            brakes = 'Schimb placute frana...',
            tire = 'Schimb anvelopa...',
            suspension = 'Reparatie suspensie...',
            battery = 'Inlocuire baterie...',
            engine = 'Reparatie motor...',
            bodywork = 'Reparatie caroserie...',
            roadside_engine = 'Urgenta motor...',
            roadside_tire = 'Schimb anvelopa pe drum...',
            roadside_battery = 'Jump start baterie...',
            roadside_tow = 'Pregatire tractare...',
        },

        -- NUI
        ui = {
            title = 'Service Auto',
            tab_dashboard = 'Dashboard',
            tab_services = 'Servicii',
            tab_calls = 'Cereri',
            tab_log = 'Istoric',

            stat_today = 'Servicii azi',
            stat_bonus = 'Bonus total',
            stat_total = 'Total servicii',
            stat_revenue = 'Venituri firma',

            prices_title = 'Preturi servicii',

            workshop_empty = 'Apropie-te de un vehicul la atelier<br>pentru a vedea serviciile disponibile.',
            vehicle_health = 'Sanatate vehicul',
            health_engine = 'Motor',
            health_body = 'Caroserie',
            components = 'Componente',
            services_available = 'Servicii disponibile',

            calls_active = 'Cereri active',
            refresh = 'Actualizeaza',
            no_calls = 'Nicio cerere activa momentan.',
            no_log = 'Niciun serviciu in istoric.',

            mg_active = 'Serviciu activ...',
            mg_timing_hint_pre = 'Apasa',
            mg_timing_hint_post = 'sau click cand esti in zona verde',
            mg_sequence_hint = 'Apasa tastele in ordinea indicata',
            mg_hammer_hint_pre = 'Apasa',
            mg_hammer_hint_post = 'sau click cat mai rapid!',

            -- Generat din JS
            client = 'Client',
            plate_label = 'Placa:',
            no_permission = 'fara permisiune',
            execute = 'Executa',
            accept = 'Accept',
            time_now = 'acum',
            time_min_ago = '{1}m ago',
            time_hour_ago = '{1}h ago',
            time_day_ago = '{1}z ago',
            bonus_suffix = '+{1} bonus',

            -- Preturi (dashboard)
            price = {
                inspect_name = 'Diagnoza',
                inspect_req = '-',
                oil_change_name = 'Schimb Ulei',
                oil_change_req = '1x Ulei Motor',
                brakes_name = 'Placute Frana',
                brakes_req = '1x Placute',
                tire_name = 'Anvelopa',
                tire_req = '1x/buc',
                suspension_name = 'Suspensie',
                suspension_req = '1x Piesa/ax',
                battery_name = 'Baterie',
                battery_req = '1x Baterie',
                engine_name = 'Reparatie Motor',
                engine_req = '1x Piesa Motor',
                bodywork_name = 'Reparatie Caroserie',
                bodywork_req = '1x Piesa Car.',
            },

            -- Componente (workshop)
            comp = {
                oil = 'Ulei Motor',
                battery = 'Baterie',
                brakes = 'Placute Frana',
                exhaust = 'Esapament',
                tires = 'Anvelope',
                suspension = 'Suspensie',
            },

            -- Servicii (workshop, generat din JS)
            svc = {
                inspect_name = 'Diagnoza completa',
                inspect_req = '- fara piese',
                oil_change_name = 'Schimb Ulei',
                oil_change_req = '1x Ulei Motor',
                brakes_name = 'Schimb Placute Frana',
                brakes_req = '1x Placute Frana',
                tire_name = 'Schimb Anvelope (toate)',
                tire_req = '4x Anvelopa',
                suspension_name = 'Reparatie Suspensie',
                suspension_req = '2x Piesa Suspensie',
                battery_name = 'Inlocuire Baterie',
                battery_req = '1x Baterie Auto',
                engine_name = 'Reparatie Motor',
                engine_req = '1x Piesa Motor',
                bodywork_name = 'Reparatie Caroserie',
                bodywork_req = '1x Piesa Caroserie',
            },

            -- Rezultat minijoc
            mg_success = 'Serviciu finalizat cu succes!',
            mg_fail = 'Minijoc esuat!',
        },
    }
}
