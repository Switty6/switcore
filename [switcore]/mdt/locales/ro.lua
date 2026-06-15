return {
    mdt = {
        -- Notificari server (titlu / mesaj)
        notify = {
            access_denied_title = 'Acces refuzat',
            access_denied_records = 'Nu ai acces la dosarele MDT.',
            access_denied_citations = 'Nu ai permisiunea sa emiti citatii.',
            access_denied_bolos = 'Nu ai permisiunea sa emiti BOLO.',
            access_denied_incidents = 'Nu ai permisiunea sa creezi incidente.',
            access_denied_impounds = 'Nu ai permisiunea sa sechestrezi vehicule.',
            citation_title = 'Citatie',
            citation_emitted_title = 'Citatie emisa',
            citation_emitted = 'Amenda de ${1} a fost emisa.',
            citation_marked_paid = 'Citatie marcata ca platita.',
            citation_already_paid = 'Citatia era deja platita.',
            bolo_emitted_title = 'BOLO emis',
            bolo_emitted = 'BOLO pentru {1} a fost emis.',
            bolo_title = 'BOLO',
            bolo_closed = 'BOLO inchis.',
            incident_title = 'Incident',
            incident_saved = 'Raport de incident salvat.',
            impound_title = 'Sechestru',
            impound_done = 'Vehiculul {1} a fost sechestrat.',
            impound_released = 'Vehicul eliberat din sechestru.',
            waypoint_set = 'Waypoint setat la locatia apelului.',
        },

        -- Comanda / keymapping
        keymap_open = 'Deschide MDT',

        -- Antet panou
        header = {
            badge_police = 'POL',
            badge_ems = 'EMS',
            title_police = 'MDT - Politie',
            title_ems = 'MDT - Medical EMS',
        },

        -- Taburi politie
        tab = {
            warrants = 'Mandate',
            search = 'Cautare',
            criminal = 'Dosar Penal',
            citations = 'Citatii',
            bolos = 'BOLO',
            incidents = 'Incidente',
            impounds = 'Sechestru',
            officers = 'Ofiteri',
            management = 'Management',
            -- Taburi EMS
            calls = 'Apeluri 112',
            patient = 'Cauta Pacient',
            medical = 'Dosar Medical',
            team = 'Echipa',
            unavailable = 'Tab nedisponibil.',
        },

        -- Butoane comune
        common = {
            refresh = '↻ Actualizeaza',
            close = 'Inchide',
            release = 'Elibereaza',
            cancel = 'Anuleaza',
            emit = 'Emite',
            save = 'Salveaza',
            add = 'Adauga',
            delete = 'Sterge',
            no_results = 'Niciun rezultat.',
            data_unavailable = 'Date indisponibile.',
        },

        -- Mandate
        warrants = {
            add_btn = '+ Emite Mandat',
            col_name = 'Nume',
            col_charges = 'Acuzatii',
            col_bail = 'Cautiune',
            col_date = 'Data',
            empty = 'Niciun mandat activ',
            close_btn = 'Inchide',
        },

        -- Cautare
        search = {
            placeholder = 'Cauta dupa nume...',
            age_suffix = '{1} ani',
            badge_warrant = 'Mandat activ',
            badge_jailed = 'Inchis',
            emit_warrant = 'Emite Mandat',
            release = 'Elibereaza',
            criminal_record = 'Dosar Penal',
            confirm_unjail = 'Esti sigur ca vrei sa eliberezi acest personaj?',
        },

        -- Dosar penal
        criminal = {
            search_placeholder = 'Cauta persoana...',
            select_prompt = 'Selecteaza o persoana pentru a vedea dosarul penal.',
            loading = 'Se incarca dosarul pentru {1}...',
            badge_warrant = 'M',
            badge_jailed = 'I',
            section_arrests = 'Arestari ({1})',
            section_warrants = 'Mandate ({1})',
            section_citations = 'Citatii ({1})',
            no_arrests = 'Nicio arestare.',
            no_warrants = 'Niciun mandat.',
            no_citations = 'Nicio citatie.',
            badge_arrest = 'Arest',
            arrest_detail = '{1} min | Cautiune: ${2}',
            warrant_active = 'Activ',
            warrant_closed = 'Inchis',
            citation_paid = 'Platita',
            citation_unpaid = 'Neplatita',
            citation_fine = 'Amenda: ${1}',
        },

        -- Citatii
        citations = {
            add_btn = '+ Emite Citatie',
            col_suspect = 'Suspect',
            col_offense = 'Infractiune',
            col_fine = 'Amenda',
            col_status = 'Status',
            col_date = 'Data',
            empty = 'Nicio citatie activa.',
            status_paid = 'Platita',
            status_unpaid = 'Neplatita',
            mark_paid = 'Marcheaza platita',
        },

        -- BOLO
        bolos = {
            add_btn = '+ Emite BOLO',
            col_subject = 'Subiect',
            col_description = 'Descriere',
            col_vehicle = 'Vehicul',
            col_date = 'Data',
            empty = 'Niciun BOLO activ.',
            close_btn = 'Inchide',
        },

        -- Incidente
        incidents = {
            add_btn = '+ Raport Incident',
            col_title = 'Titlu',
            col_description = 'Descriere',
            col_date = 'Data',
            empty = 'Niciun incident inregistrat.',
        },

        -- Sechestru
        impounds = {
            add_btn = '+ Sechestru Vehicul',
            col_plate = 'Numar',
            col_model = 'Model',
            col_reason = 'Motiv',
            col_fee = 'Taxa',
            col_status = 'Status',
            col_date = 'Data',
            empty = 'Niciun vehicul sechestrat.',
            status_retrieved = 'Recuperat',
            status_impounded = 'Sechestrat',
            release_btn = 'Elibereaza',
        },

        -- Ofiteri
        officers = {
            empty = 'Niciun ofiter activ.',
        },

        -- Management
        management = {
            sub_budget = 'Buget',
            sub_fleet = 'Flota',
            sub_armory = 'Armament',
            budget_available = 'Buget disponibil',
            tx_col_type = 'Tip',
            tx_col_amount = 'Suma',
            tx_col_description = 'Descriere',
            tx_col_date = 'Data',
            tx_empty = 'Nicio tranzactie.',
            fleet_current = 'Flota Curenta',
            fleet_purchase = 'Achizitioneaza Vehicul',
            fleet_empty = 'Niciun vehicul in flota.',
            fleet_free = 'Liber',
            fleet_in_use = 'In uz',
            fleet_sell = 'Vinde ${1}',
            models_empty = 'Niciun model configurat.',
            buy_btn = 'Achizitioneaza',
            confirm_buy = 'Achizitionezi "{1}"?',
            confirm_sell = 'Vinzi {1} ({2}) pentru ${3}?',
            armory_weapons = 'Arme Configurate',
            armory_equipment = 'Echipamente Configurate',
            add_weapon = 'Adauga Arma',
            add_equipment = 'Adauga Echipament',
            ph_item_name = 'itemName',
            ph_display_name = 'Nume afisat',
            ph_ammo_item = 'Ammo item (optional)',
            ph_ammo_amount = 'Cantitate ammo',
            ph_amount = 'Cantitate',
            weapons_empty = 'Nicio arma configurata.',
            equipment_empty = 'Niciun echipament configurat.',
            delete_btn = 'Sterge',
            confirm_delete_weapon = 'Stergi arma "{1}"?',
            confirm_delete_equipment = 'Stergi echipamentul "{1}"?',
        },

        -- EMS apeluri 112
        calls = {
            col_caller = 'Apelant',
            col_message = 'Mesaj',
            col_time = 'Timp',
            col_status = 'Status',
            col_actions = 'Actiuni',
            empty = 'Niciun apel activ.',
            status_pending = 'Asteapta',
            status_active = 'Activ',
            accept = 'Accept',
            resolve = 'Rezolva',
        },

        -- EMS pacient
        patient = {
            search_placeholder = 'Cauta pacient dupa nume...',
            select_prompt = 'Selecteaza un pacient pentru a vedea istoricul medical.',
            loading = 'Se incarca istoricul pentru {1}...',
            empty = 'Niciun record medical.',
            ems_system = 'Sistem',
        },

        -- EMS dosar medical
        medical = {
            search_placeholder = 'Cauta dupa nume...',
        },

        -- EMS echipa
        team = {
            empty = 'Niciun EMS activ.',
            col_name = 'Nume',
            col_grade = 'Grad',
            col_status = 'Status',
            on_duty = 'On Duty',
            off_duty = 'Off Duty',
        },

        -- Modale
        modal = {
            warrant_title = 'Emite Mandat',
            citation_title = 'Emite Citatie',
            bolo_title = 'Emite BOLO',
            incident_title = 'Raport Incident',
            impound_title = 'Sechestru Vehicul',

            search_suspect = 'Cautare Suspect',
            ph_name_search = 'Prenume sau Nume...',
            label_charges = 'Acuzatii',
            ph_charges = 'Acuzatii...',
            label_bail = 'Cautiune ($)',
            label_offense = 'Infractiune',
            ph_offense = 'Ex: Depasire viteza...',
            label_fine = 'Amenda ($)',

            label_subject = 'Subiect / Nume Suspect',
            ph_subject = 'Nume sau Neidentificat...',
            label_description = 'Descriere',
            ph_bolo_description = 'Descriere suspect, comportament...',
            label_vehicle_info = 'Informatii Vehicul (optional)',
            ph_vehicle_info = 'Marca, model, culoare, numar...',

            label_title = 'Titlu',
            ph_title = 'Titlu incident...',
            ph_incident_desc = 'Descriere detaliata...',
            label_involved = 'Persoane implicate (ID-uri separate prin virgula)',
            ph_involved = 'Ex: 12, 45, 78',

            label_plate = 'Numar Inmatriculare',
            ph_plate = 'Ex: AB12 CDE',
            label_model = 'Model Vehicul',
            ph_model = 'Ex: Adder, Sultan...',
            label_reason = 'Motiv Sechestru',
            ph_reason = 'Motivul sechestrului...',
            label_fee = 'Taxa Recuperare ($)',

            cancel = 'Anuleaza',
            emit = 'Emite',
            save = 'Salveaza',
            impound = 'Sechestru',
            suspect_prefix = 'Suspect: {1}',
        },

        -- Validari / alerturi JS
        alert = {
            fill_all = 'Completeaza toate campurile.',
            fill_subject_desc = 'Completeaza subiectul si descrierea.',
            fill_title_desc = 'Completeaza titlul si descrierea.',
            fill_plate_reason = 'Completeaza numarul de inmatriculare si motivul.',
            fill_item_label = 'Completeaza itemName si label.',
        },
    }
}
