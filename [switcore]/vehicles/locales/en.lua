return {
    vehicles = {
        -- Permissions and admin commands
        access_denied = 'Access denied',
        admin_vehicle_received = 'You received the vehicle {1} ({2})',

        -- Key item (vehicle_key usage)
        key_item_info = 'Key: {1} - {2}',

        -- General vehicle errors
        invalid_parameters = 'Invalid parameters',
        vehicle_not_found = 'Vehicle does not exist',
        vehicle_impounded = 'The vehicle is impounded',
        no_key_or_missing = 'You do not have a key for this vehicle or it does not exist',
        no_key_for_vehicle = 'You do not have a key for this vehicle',
        character_no_key = 'The character does not have a key for this vehicle',
        no_character = 'No character',

        -- Vehicle creation / plates
        custom_plate_min_length = 'The custom plate must have at least 3 characters',
        custom_plate_taken = 'The custom plate is already in use',
        vehicle_create_db_error = 'Error creating the vehicle in the database',
        plate_generation_failed = 'Could not generate a unique plate after 100 attempts',
        save_state_failed = 'Error saving the vehicle state',

        -- Impound
        vehicle_id_missing = 'vehicleId missing',
        impound_failed = 'Error impounding',
        release_failed = 'Error releasing from impound',

        -- Keys
        key_add_db_error = 'Error adding the key to the database',
        key_remove_failed = 'Error removing the key',
        not_owner = 'You are not the owner of this vehicle',
        ownership_transfer_failed = 'Error transferring ownership: {1}',

        -- Fuel / refueling
        fuel_tank_full = 'The tank is full',
        banking_unavailable = 'Banking system unavailable',
        no_bank_account = 'You do not have a bank account',
        insufficient_cash_fuel = 'Insufficient cash. Required: ${1}, you have: ${2}',
        insufficient_bank_fuel = 'Insufficient bank balance. Required: ${1}, you have: ${2}',
        insufficient_cash_amount = 'Insufficient cash: {1}{2} required.',
        insufficient_bank_amount = 'Insufficient bank balance: {1}{2} required.',
        auth_error = 'Authentication error.',
        refuel_failed = 'Refueling failed.',
        refueled_success = 'Refueled {1}L  -  {2}{3} paid by {4}',
        pay_method_card = 'card',
        pay_method_cash = 'cash',

        -- Engine (client)
        vehicle_locked_no_key = 'This vehicle is locked or you do not have the key!',
        engine_off = 'You turned off the engine.',
        engine_on = 'You started the engine.',
        no_vehicle_access = 'You do not have access to this vehicle.',
        keymap_toggle_engine = 'Start/Stop Engine',

        -- Critical fuel (client)
        fuel_critical = 'Critical fuel! Refuel immediately.',

        -- Fuel station (client)
        hose_snapped = 'The hose snapped!',
        pump_gone = 'The pump no longer exists.',
        nozzle_pickup_failed = 'Could not pick up the hose.',
        attach_hose_to_tank = 'Attach the hose to the tank',
        refuel_action = 'Refuel',
        press_alt_on_tank = 'Press ALT on the vehicle tank to refuel.',
        approach_vehicle = 'Get close to a vehicle and press ALT on it.',
        cannot_attach_hose = 'Cannot attach the hose to this vehicle.',
        tank_full_choose_payment = 'Tank full! Choose a payment method.',
        insufficient_funds_choose_payment = 'Insufficient funds, choose a payment method.',
        payment_failed = 'Payment failed',

        -- NUI - refuel HUD
        ui_pump = 'PUMP',
        ui_price_per_litre = 'PRICE / LITER',
        ui_cash = 'CASH',
        ui_bank = 'BANK',
        ui_total_available = 'TOTAL AVAILABLE',
        ui_hold_to_refuel = 'HOLD TO REFUEL',
        ui_waiting = 'WAITING',
        ui_litres = 'LITERS',
        ui_cost = 'COST',
        ui_tank = 'TANK',
        ui_insufficient_funds_stopped = 'Insufficient funds - refueling stopped',
        ui_hose = 'HOSE',
        ui_hose_snapped = 'HOSE SNAPPED!',
        ui_refuel_active = 'REFUELING ACTIVE - RELEASE TO STOP',
        ui_in_progress = 'IN PROGRESS',
        ui_cable_critical = 'CRITICAL - ABOUT TO SNAP',
        ui_cable_warning = 'WARNING - HOSE STRETCHED',
        ui_cable_ok = 'OK',
        ui_insufficient_funds = 'INSUFFICIENT FUNDS',

        -- NUI - payment modal
        ui_payment_method = 'PAYMENT METHOD',
        ui_refueled = 'Refueled',
        ui_to_pay = 'TO PAY',
        ui_card = 'CARD',
        ui_payment_footer = 'Click the desired method to complete the payment',
        ui_payment_failed = 'Payment failed',
    }
}
