return {
    mecanic = {
        -- Errors and access
        err_generic = 'Error',
        err_internal = 'Internal error',
        err_no_mechanic = 'You are not a mechanic.',
        err_access_denied = 'Access denied',
        err_no_roadside_perm = 'You do not have the roadside assistance permission.',
        err_no_service_perm = 'You do not have permission for this service.',
        err_only_manager_parts = 'Only the manager can buy parts.',

        -- Payment and funds
        ron_currency_missing = 'RON currency was not found.',
        payment_failed = 'Payment failed',
        client_no_funds = 'The client does not have enough funds.',
        insufficient_funds = 'Insufficient funds',
        client_insufficient_funds = 'You do not have enough money for this service.',
        money_refunded = 'The money was refunded to the client.',
        firm_no_funds = 'The company does not have enough money.',

        -- Service completed / payment
        service_paid_title = 'Service payment',
        service_paid_msg = 'You paid {1} RON for {2}.',
        service_done_title = 'Service completed',
        service_bonus_msg = 'You received a bonus of {1} RON ({2}%).',

        -- Service calls (server)
        call_create_failed = 'The service request could not be created.',
        mechanic_called_title = 'Mechanic called',
        mechanic_called_msg = 'The request has been sent. Wait for an available mechanic.',
        call_invalid_title = 'Invalid request',
        call_unavailable = 'The request is no longer available.',
        call_accept_failed = 'The request could not be accepted.',
        call_accepted_title = 'Request accepted',
        call_accepted_msg = 'Head to the client location.',
        mechanic_enroute_title = 'Mechanic on the way',
        mechanic_enroute_msg = 'Mechanic {1} {2} is heading toward you.',
        call_cancelled_title = 'Request cancelled',
        call_cancelled_msg = 'The mechanic request has been cancelled.',

        -- Service / vehicle (server)
        client_disconnected = 'The client is no longer connected.',
        vehicle_not_found = 'The vehicle was not found.',
        part_missing_title = 'Missing part',
        part_missing_msg = 'You need {1}x {2} for this service.',
        vehicle_towed_title = 'Vehicle towed',
        vehicle_towed_msg = 'Your vehicle was taken to the workshop. You can retrieve it from the garage.',
        parts_bought_title = 'Parts bought',
        parts_bought_msg = 'You bought {1}x {2} ({3} RON from the company account).',
        vehicle_not_registered_title = 'Vehicle not found',
        vehicle_not_registered_msg = 'The vehicle with plate {1} is not registered.',

        -- Service names (used in notifications and log)
        service = {
            inspect = 'Diagnostic',
            oil_change = 'Oil change',
            brakes = 'Brake pad replacement',
            battery = 'Battery replacement',
            tire = 'Tire change ({1} pcs)',
            suspension = 'Suspension repair',
            engine = 'Engine repair',
            bodywork = 'Bodywork repair',
            roadside_engine = 'Engine emergency (roadside)',
            roadside_tire = 'Tire change (roadside)',
            roadside_battery = 'Battery jump start',
            roadside_tow = 'Tow to workshop',
        },
        -- Org bank transaction labels
        tx_service = 'Service: {1}',
        tx_bonus = 'Mechanic bonus',
        tx_buy_parts = 'Buy parts: {1} x{2}',

        -- Client (client notifications)
        notify = {
            service_failed_title = 'Failed',
            minigame_failed = 'Minigame failed. Try again.',
            service_done_title = 'Service completed',
            service_done_msg = 'The service was carried out successfully!',
            service_active_title = 'Service active',
            service_active_msg = 'Go to the marked area and interact.',
            busy_title = 'Busy',
            busy_msg = 'You are already in the middle of a service.',
        },

        -- Component warnings (client)
        warn = {
            oil_low_title = 'Engine Oil',
            oil_low_msg = 'The oil level is low! Go to a mechanic.',
            oil_crit_title = 'URGENT - Engine Oil!',
            oil_crit_msg = 'The engine is losing oil! Go to a mechanic IMMEDIATELY!',
            battery_low_title = 'Low Battery',
            battery_low_msg = 'The car battery is drained. Go to a mechanic.',
            brakes_title = 'Brake Pads',
            brakes_msg = 'The brake pads are worn. Go to a mechanic.',
            tire_flat_title = 'Flat Tire!',
            tire_flat_msg = 'The {1} tire is flat! Call a mechanic.',
            vehicle_repaired_title = 'Vehicle repaired',
            vehicle_repaired_msg = 'The repair was carried out successfully.',
        },

        -- Roadside (client)
        roadside = {
            call_title = 'Mechanic Request!',
            call_msg = '{1} has a problem: {2}',
            blip_call_name = 'Request: {1}',
            blip_client_name = 'Client in need',
            arrived_title = 'You arrived!',
            arrived_msg = 'Press E next to the client vehicle for services.',
            tow_done_title = 'Tow completed',
            tow_done_msg = 'The client vehicle was taken to the workshop.',
        },

        -- Problem labels (client + UI)
        problem = {
            engine = 'Damaged engine',
            tire = 'Flat tire',
            battery = 'Dead battery',
            tow = 'Tow needed',
            tow_short = 'Tow',
        },

        -- Map / proximity / blip
        blip_workshop = 'Auto Service',
        prox_open_tablet = 'Auto Service - Open Tablet',
        prox_vehicle_services = 'Vehicle Services [{1}]',

        -- Service target labels (world markers)
        target = {
            inspect = 'Vehicle diagnostic',
            oil_change = 'Engine oil change',
            brakes = 'Brake pad replacement',
            tire_pos = 'Tire {1}',
            tire_generic = 'Tire change',
            suspension_right = 'Right suspension',
            suspension_left = 'Left suspension',
            battery = 'Battery replacement',
            engine = 'Engine repair',
            bodywork = 'Bodywork repair',
        },
        wheel = {
            fl = 'Front-left',
            fr = 'Front-right',
            rl = 'Rear-left',
            rr = 'Rear-right',
        },

        -- Minigame labels (label sent to NUI)
        minigame = {
            inspect = 'Diagnosing vehicle...',
            oil_change = 'Changing engine oil...',
            brakes = 'Replacing brake pads...',
            tire = 'Changing tire...',
            suspension = 'Repairing suspension...',
            battery = 'Replacing battery...',
            engine = 'Repairing engine...',
            bodywork = 'Repairing bodywork...',
            roadside_engine = 'Engine emergency...',
            roadside_tire = 'Changing tire on the road...',
            roadside_battery = 'Battery jump start...',
            roadside_tow = 'Preparing tow...',
        },

        -- NUI
        ui = {
            title = 'Auto Service',
            tab_dashboard = 'Dashboard',
            tab_services = 'Services',
            tab_calls = 'Requests',
            tab_log = 'History',

            stat_today = 'Services today',
            stat_bonus = 'Total bonus',
            stat_total = 'Total services',
            stat_revenue = 'Company revenue',

            prices_title = 'Service prices',

            workshop_empty = 'Approach a vehicle at the workshop<br>to see the available services.',
            vehicle_health = 'Vehicle health',
            health_engine = 'Engine',
            health_body = 'Bodywork',
            components = 'Components',
            services_available = 'Available services',

            calls_active = 'Active requests',
            refresh = 'Refresh',
            no_calls = 'No active requests at the moment.',
            no_log = 'No services in history.',

            mg_active = 'Service active...',
            mg_timing_hint_pre = 'Press',
            mg_timing_hint_post = 'or click when you are in the green zone',
            mg_sequence_hint = 'Press the keys in the indicated order',
            mg_hammer_hint_pre = 'Press',
            mg_hammer_hint_post = 'or click as fast as possible!',

            -- Generated from JS
            client = 'Client',
            plate_label = 'Plate:',
            no_permission = 'no permission',
            execute = 'Execute',
            accept = 'Accept',
            time_now = 'now',
            time_min_ago = '{1}m ago',
            time_hour_ago = '{1}h ago',
            time_day_ago = '{1}d ago',
            bonus_suffix = '+{1} bonus',

            -- Prices (dashboard)
            price = {
                inspect_name = 'Diagnostic',
                inspect_req = '-',
                oil_change_name = 'Oil Change',
                oil_change_req = '1x Engine Oil',
                brakes_name = 'Brake Pads',
                brakes_req = '1x Pads',
                tire_name = 'Tire',
                tire_req = '1x/pc',
                suspension_name = 'Suspension',
                suspension_req = '1x Part/axle',
                battery_name = 'Battery',
                battery_req = '1x Battery',
                engine_name = 'Engine Repair',
                engine_req = '1x Engine Part',
                bodywork_name = 'Bodywork Repair',
                bodywork_req = '1x Body Part',
            },

            -- Components (workshop)
            comp = {
                oil = 'Engine Oil',
                battery = 'Battery',
                brakes = 'Brake Pads',
                exhaust = 'Exhaust',
                tires = 'Tires',
                suspension = 'Suspension',
            },

            -- Services (workshop, generated from JS)
            svc = {
                inspect_name = 'Full diagnostic',
                inspect_req = '- no parts',
                oil_change_name = 'Oil Change',
                oil_change_req = '1x Engine Oil',
                brakes_name = 'Brake Pad Replacement',
                brakes_req = '1x Brake Pads',
                tire_name = 'Tire Change (all)',
                tire_req = '4x Tire',
                suspension_name = 'Suspension Repair',
                suspension_req = '2x Suspension Part',
                battery_name = 'Battery Replacement',
                battery_req = '1x Car Battery',
                engine_name = 'Engine Repair',
                engine_req = '1x Engine Part',
                bodywork_name = 'Bodywork Repair',
                bodywork_req = '1x Body Part',
            },

            -- Minigame result
            mg_success = 'Service completed successfully!',
            mg_fail = 'Minigame failed!',
        },
    }
}
