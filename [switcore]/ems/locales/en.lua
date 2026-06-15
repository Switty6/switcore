return {
    ems = {
        -- Notifications to the revived / transported player
        revived = 'You were revived by EMS!',
        revived_short = 'You were revived by EMS.',
        transported_hospital = 'You were transported to the hospital. Cost: 5000 RON.',
        cured_by_doctor = 'You were treated by a doctor. Your conditions are cured.',
        iv_received = 'The doctor administered {1} to you.',

        -- Carry / stretcher
        carrying_patient = 'Carrying the patient. Press E on them to put them down.',

        -- 112 call
        call_usage = 'Usage: /911 [message]',
        call_too_short = 'The message is too short.',
        call_sent = 'Your 112 call has been sent. Wait for EMS.',
        call_accepted = 'EMS accepted your call! They are on their way to you.',

        -- Unconscious patient (EMS broadcast)
        patient_unconscious = '🏥 Unconscious patient: {1}',
        patient_unknown = 'Unknown',

        -- Revive / treatments (to EMS)
        no_revive_permission = 'You do not have the revive permission.',
        no_permission = 'You do not have the required permission.',
        patient_not_unconscious = 'The patient is not unconscious.',
        injury_not_found = 'Injury not found.',
        injury_treated = 'Injury treated successfully.',
        patient_revived = 'Patient revived successfully.',
        all_conditions_cured = 'All of the patient\'s conditions have been treated.',
        iv_invalid = 'Invalid IV treatment.',
        iv_insufficient_stock = 'Insufficient stock in the ambulance.',
        iv_administered = '{1} administered successfully.',
        diagnosis_saved = 'Diagnosis saved to the record.',

        -- Hospital respawn
        respawn_remaining = 'You have {1}s left until the respawn option.',

        -- Stretcher / patient transport
        patient_already_carried = 'The patient is already being carried.',
        not_carrying_patient = 'You are not carrying this patient.',

        -- Ambulance inventory
        ambulance_inv_interaction = 'Ambulance Inventory',
        ambulance_stock_insufficient = 'Insufficient stock in the ambulance.',
        item_taken = '{1}x {2} taken from the ambulance.',

        -- Patient proximity interactions
        examine_patient = 'Examine Patient',
        lift_patient = 'Lift Patient (Stretcher)',

        -- Blip
        blip_patient = 'Patient - {1}',

        ui = {
            -- Unconscious overlay
            unconscious_title = 'You are unconscious...',
            unconscious_sub = 'Wait for EMS or respawn when the timer expires',
            respawn_hospital = 'Respawn at Hospital',
            respawn_cost = '(5000 RON)',

            -- Patient menu
            patient = 'Patient',
            badge_unconscious = 'UNCONSCIOUS',
            timer_remaining = '⏳ {1} left',
            section_conditions = 'Medical Conditions',
            section_injuries = 'Active Injuries',
            section_actions = 'Actions',
            btn_revive = 'Revive',
            btn_cure_all = 'Cure Conditions',
            btn_administer_iv = 'Administer IV',
            diag_placeholder = 'Diagnosis notes...',
            btn_log_diagnosis = 'Log to Record',
            no_conditions = 'No active conditions.',
            no_injuries = 'No active injuries.',
            condition_stage = 'Stage {1}',
            btn_treat = 'Treat',

            -- Injury labels
            injury_gunshot_leg = 'Gunshot leg',
            injury_gunshot_chest = 'Gunshot chest',
            injury_bruise = 'Bruises',
            injury_broken_bone = 'Broken bone',
            injury_stab = 'Stabbed',

            -- Injury severity
            sev_minor = 'Minor',
            sev_moderate = 'Moderate',
            sev_severe = 'Severe',

            -- Ambulance inventory
            ambulance_inventory = 'Ambulance Inventory',
            empty_inventory = 'Empty inventory.',
            btn_take_one = 'Take 1',
        },
    }
}
