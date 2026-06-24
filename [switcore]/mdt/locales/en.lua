return {
    mdt = {
        -- Server notifications (title / message)
        notify = {
            access_denied_title = 'Access denied',
            access_denied_records = 'You do not have access to MDT records.',
            access_denied_citations = 'You do not have permission to issue citations.',
            access_denied_bolos = 'You do not have permission to issue BOLOs.',
            access_denied_incidents = 'You do not have permission to create incidents.',
            access_denied_impounds = 'You do not have permission to impound vehicles.',
            citation_title = 'Citation',
            citation_emitted_title = 'Citation issued',
            citation_emitted = 'A fine of ${1} has been issued.',
            citation_marked_paid = 'Citation marked as paid.',
            citation_already_paid = 'The citation was already paid.',
            bolo_emitted_title = 'BOLO issued',
            bolo_emitted = 'BOLO for {1} has been issued.',
            bolo_title = 'BOLO',
            bolo_closed = 'BOLO closed.',
            incident_title = 'Incident',
            incident_saved = 'Incident report saved.',
            impound_title = 'Impound',
            impound_done = 'Vehicle {1} has been impounded.',
            impound_released = 'Vehicle released from impound.',
            waypoint_set = 'Waypoint set to the call location.',
            must_be_on_duty_title = 'MDT',
            must_be_on_duty = 'You must be on duty to open the MDT.',
        },

        -- Command / keymapping
        keymap_open = 'Open MDT',

        -- Panel header
        header = {
            badge_police = 'POL',
            badge_ems = 'EMS',
            title_police = 'MDT - Police',
            title_ems = 'MDT - Medical EMS',
        },

        -- Police tabs
        tab = {
            warrants = 'Warrants',
            search = 'Search',
            criminal = 'Criminal Record',
            citations = 'Citations',
            bolos = 'BOLO',
            incidents = 'Incidents',
            impounds = 'Impound',
            officers = 'Officers',
            management = 'Management',
            -- EMS tabs
            calls = '112 Calls',
            patient = 'Find Patient',
            medical = 'Medical Record',
            team = 'Team',
            unavailable = 'Tab unavailable.',
        },

        -- Common buttons
        common = {
            refresh = '↻ Refresh',
            close = 'Close',
            release = 'Release',
            cancel = 'Cancel',
            emit = 'Issue',
            save = 'Save',
            add = 'Add',
            delete = 'Delete',
            no_results = 'No results.',
            data_unavailable = 'Data unavailable.',
        },

        -- Warrants
        warrants = {
            add_btn = '+ Issue Warrant',
            col_name = 'Name',
            col_charges = 'Charges',
            col_bail = 'Bail',
            col_date = 'Date',
            empty = 'No active warrants',
            close_btn = 'Close',
        },

        -- Search
        search = {
            placeholder = 'Search by name...',
            age_suffix = '{1} yrs',
            badge_warrant = 'Active warrant',
            badge_jailed = 'Jailed',
            emit_warrant = 'Issue Warrant',
            release = 'Release',
            criminal_record = 'Criminal Record',
            confirm_unjail = 'Are you sure you want to release this character?',
        },

        -- Criminal record
        criminal = {
            search_placeholder = 'Search person...',
            select_prompt = 'Select a person to view the criminal record.',
            loading = 'Loading record for {1}...',
            badge_warrant = 'W',
            badge_jailed = 'J',
            section_arrests = 'Arrests ({1})',
            section_warrants = 'Warrants ({1})',
            section_citations = 'Citations ({1})',
            no_arrests = 'No arrests.',
            no_warrants = 'No warrants.',
            no_citations = 'No citations.',
            badge_arrest = 'Arrest',
            arrest_detail = '{1} min | Bail: ${2}',
            warrant_active = 'Active',
            warrant_closed = 'Closed',
            citation_paid = 'Paid',
            citation_unpaid = 'Unpaid',
            citation_fine = 'Fine: ${1}',
        },

        -- Citations
        citations = {
            add_btn = '+ Issue Citation',
            col_suspect = 'Suspect',
            col_offense = 'Offense',
            col_fine = 'Fine',
            col_status = 'Status',
            col_date = 'Date',
            empty = 'No active citations.',
            status_paid = 'Paid',
            status_unpaid = 'Unpaid',
            mark_paid = 'Mark as paid',
        },

        -- BOLO
        bolos = {
            add_btn = '+ Issue BOLO',
            col_subject = 'Subject',
            col_description = 'Description',
            col_vehicle = 'Vehicle',
            col_date = 'Date',
            empty = 'No active BOLOs.',
            close_btn = 'Close',
        },

        -- Incidents
        incidents = {
            add_btn = '+ Incident Report',
            col_title = 'Title',
            col_description = 'Description',
            col_date = 'Date',
            empty = 'No incidents recorded.',
        },

        -- Impound
        impounds = {
            add_btn = '+ Impound Vehicle',
            col_plate = 'Plate',
            col_model = 'Model',
            col_reason = 'Reason',
            col_fee = 'Fee',
            col_status = 'Status',
            col_date = 'Date',
            empty = 'No impounded vehicles.',
            status_retrieved = 'Retrieved',
            status_impounded = 'Impounded',
            release_btn = 'Release',
        },

        -- Officers
        officers = {
            empty = 'No active officers.',
        },

        -- Management
        management = {
            sub_budget = 'Budget',
            sub_fleet = 'Fleet',
            sub_armory = 'Armory',
            budget_available = 'Available budget',
            tx_col_type = 'Type',
            tx_col_amount = 'Amount',
            tx_col_description = 'Description',
            tx_col_date = 'Date',
            tx_empty = 'No transactions.',
            fleet_current = 'Current Fleet',
            fleet_purchase = 'Purchase Vehicle',
            fleet_empty = 'No vehicles in the fleet.',
            fleet_free = 'Free',
            fleet_in_use = 'In use',
            fleet_sell = 'Sell ${1}',
            models_empty = 'No models configured.',
            buy_btn = 'Purchase',
            confirm_buy = 'Purchase "{1}"?',
            confirm_sell = 'Sell {1} ({2}) for ${3}?',
            armory_weapons = 'Configured Weapons',
            armory_equipment = 'Configured Equipment',
            add_weapon = 'Add Weapon',
            add_equipment = 'Add Equipment',
            ph_item_name = 'itemName',
            ph_display_name = 'Display name',
            ph_ammo_item = 'Ammo item (optional)',
            ph_ammo_amount = 'Ammo amount',
            ph_amount = 'Amount',
            weapons_empty = 'No weapons configured.',
            equipment_empty = 'No equipment configured.',
            delete_btn = 'Delete',
            confirm_delete_weapon = 'Delete weapon "{1}"?',
            confirm_delete_equipment = 'Delete equipment "{1}"?',
        },

        -- EMS 112 calls
        calls = {
            col_caller = 'Caller',
            col_message = 'Message',
            col_time = 'Time',
            col_status = 'Status',
            col_actions = 'Actions',
            empty = 'No active calls.',
            status_pending = 'Pending',
            status_active = 'Active',
            accept = 'Accept',
            resolve = 'Resolve',
        },

        -- EMS patient
        patient = {
            search_placeholder = 'Search patient by name...',
            select_prompt = 'Select a patient to view the medical history.',
            loading = 'Loading history for {1}...',
            empty = 'No medical records.',
            ems_system = 'System',
        },

        -- EMS medical record
        medical = {
            search_placeholder = 'Search by name...',
        },

        -- EMS team
        team = {
            empty = 'No active EMS.',
            col_name = 'Name',
            col_grade = 'Grade',
            col_status = 'Status',
            on_duty = 'On Duty',
            off_duty = 'Off Duty',
        },

        -- Modals
        modal = {
            warrant_title = 'Issue Warrant',
            citation_title = 'Issue Citation',
            bolo_title = 'Issue BOLO',
            incident_title = 'Incident Report',
            impound_title = 'Impound Vehicle',

            search_suspect = 'Search Suspect',
            ph_name_search = 'First or Last name...',
            label_charges = 'Charges',
            ph_charges = 'Charges...',
            label_bail = 'Bail ($)',
            label_offense = 'Offense',
            ph_offense = 'Ex: Speeding...',
            label_fine = 'Fine ($)',

            label_subject = 'Subject / Suspect Name',
            ph_subject = 'Name or Unidentified...',
            label_description = 'Description',
            ph_bolo_description = 'Suspect description, behavior...',
            label_vehicle_info = 'Vehicle Info (optional)',
            ph_vehicle_info = 'Make, model, color, plate...',

            label_title = 'Title',
            ph_title = 'Incident title...',
            ph_incident_desc = 'Detailed description...',
            label_involved = 'People involved (IDs separated by comma)',
            ph_involved = 'Ex: 12, 45, 78',

            label_plate = 'License Plate',
            ph_plate = 'Ex: AB12 CDE',
            label_model = 'Vehicle Model',
            ph_model = 'Ex: Adder, Sultan...',
            label_reason = 'Impound Reason',
            ph_reason = 'Reason for impound...',
            label_fee = 'Retrieval Fee ($)',

            cancel = 'Cancel',
            emit = 'Issue',
            save = 'Save',
            impound = 'Impound',
            suspect_prefix = 'Suspect: {1}',
        },

        -- JS validations / alerts
        alert = {
            fill_all = 'Fill in all fields.',
            fill_subject_desc = 'Fill in the subject and description.',
            fill_title_desc = 'Fill in the title and description.',
            fill_plate_reason = 'Fill in the license plate and reason.',
            fill_item_label = 'Fill in itemName and label.',
        },
    }
}
