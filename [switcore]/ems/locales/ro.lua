return {
    ems = {
        -- Notificari catre jucatorul resuscitat / transportat
        revived = 'Ai fost resuscitat de EMS!',
        revived_short = 'Ai fost resuscitat de EMS.',
        transported_hospital = 'Ai fost transportat la spital. Cost: 5000 RON.',
        cured_by_doctor = 'Ai fost tratat de medic. Bolile sunt vindecate.',
        iv_received = 'Medicul ti-a administrat {1}.',

        -- Carry / targa
        carrying_patient = 'Cara pacientul. Apasa E pe el pentru a-l depune.',

        -- Apel 112
        call_usage = 'Folosire: /911 [mesaj]',
        call_too_short = 'Mesajul este prea scurt.',
        call_sent = 'Apelul tau 112 a fost trimis. Asteapta EMS.',
        call_accepted = 'EMS a acceptat apelul tau! Se indreapta spre tine.',

        -- Pacient inconstient (broadcast EMS)
        patient_unconscious = '🏥 Pacient inconstient: {1}',
        patient_unknown = 'Necunoscut',

        -- Resuscitare / tratamente (catre EMS)
        no_revive_permission = 'Nu ai permisiunea de resuscitare.',
        no_permission = 'Nu ai permisiunea necesara.',
        patient_not_unconscious = 'Pacientul nu este inconstient.',
        injury_not_found = 'Rana nu a fost gasita.',
        injury_treated = 'Rana tratata cu succes.',
        patient_revived = 'Pacient resuscitat cu succes.',
        all_conditions_cured = 'Toate bolile pacientului au fost tratate.',
        iv_invalid = 'Tratament IV invalid.',
        iv_insufficient_stock = 'Stoc insuficient in ambulanta.',
        iv_administered = '{1} administrat cu succes.',
        diagnosis_saved = 'Diagnostic salvat in dosar.',

        -- Respawn la spital
        respawn_remaining = 'Mai ai {1}s pana la optiunea de respawn.',

        -- Targa / transport pacient
        patient_already_carried = 'Pacientul este deja transportat.',
        not_carrying_patient = 'Nu transporti acest pacient.',

        -- Inventar ambulanta
        ambulance_inv_interaction = 'Inventar Ambulanta',
        ambulance_stock_insufficient = 'Stoc insuficient in ambulanta.',
        item_taken = '{1}x {2} luat din ambulanta.',

        -- Interactiuni proximitate pacient
        examine_patient = 'Examineaza Pacient',
        lift_patient = 'Ridica Pacient (Targa)',

        -- Blip
        blip_patient = 'Pacient - {1}',

        ui = {
            -- Overlay inconstient
            unconscious_title = 'Ești inconștient...',
            unconscious_sub = 'Așteaptă EMS sau respawn la expirarea timpului',
            respawn_hospital = 'Respawn la Spital',
            respawn_cost = '(5000 RON)',

            -- Meniu pacient
            patient = 'Pacient',
            badge_unconscious = 'INCONȘTIENT',
            timer_remaining = '⏳ {1} ramas',
            section_conditions = 'Condiții Medicale',
            section_injuries = 'Răni Active',
            section_actions = 'Acțiuni',
            btn_revive = 'Resuscitare',
            btn_cure_all = 'Vindeca Boli',
            btn_administer_iv = 'Administreaza IV',
            diag_placeholder = 'Note diagnostic...',
            btn_log_diagnosis = 'Log în Dosar',
            no_conditions = 'Nicio boala activa.',
            no_injuries = 'Nicio rană activă.',
            condition_stage = 'Stadiu {1}',
            btn_treat = 'Tratează',

            -- Etichete rani
            injury_gunshot_leg = 'Împușcătură picior',
            injury_gunshot_chest = 'Împușcătură piept',
            injury_bruise = 'Vânătăi',
            injury_broken_bone = 'Os rupt',
            injury_stab = 'Înjunghiat',

            -- Severitate rani
            sev_minor = 'Minor',
            sev_moderate = 'Moderat',
            sev_severe = 'Sever',

            -- Inventar ambulanta
            ambulance_inventory = 'Inventar Ambulantă',
            empty_inventory = 'Inventar gol.',
            btn_take_one = 'Ia 1',
        },
    }
}
