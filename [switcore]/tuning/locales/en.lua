return {
    tuning = {
        -- Shop open messages (openShop)
        open_not_registered = 'This vehicle is not registered in the system.',
        open_no_key = 'You do not have a key for this vehicle.',
        open_impounded = 'The vehicle is impounded.',
        open_failed_generic = 'Could not open LS Customs.',
        open_need_vehicle = 'You must be in a vehicle to use LS Customs.',

        -- Success notifications to player
        mod_applied = 'Mod applied successfully!',
        color_applied = 'Color applied!',
        livery_applied = 'Livery applied!',
        mods_reset = 'Mods reset to stock!',
        cart_applied = 'Cart: {1} upgrade(s) applied!',

        -- Error notifications to player
        error_apply_mod = 'Error applying mod.',
        error_apply_color = 'Error applying paint.',
        error_apply_livery = 'Error applying livery.',
        error_reset = 'Error resetting.',
        error_cart_empty = 'The cart is empty.',
        error_cart_item = 'Cart: error at {1} - {2}',
        error_cart_unknown = 'unknown error',

        -- Errors from TuningManager (validation/payment/save)
        error_no_character = 'No active character',
        error_no_vehicle = 'Vehicle does not exist',
        error_no_key = 'You do not have a key for this vehicle',
        error_impounded = 'The vehicle is impounded',
        error_vip_required = 'Requires VIP subscription',
        error_invalid_category = 'Invalid category',
        error_invalid_tier = 'Invalid tier',
        error_currency_unavailable = 'Currency unavailable',
        error_insufficient_cash = 'Insufficient funds (cash)',
        error_insufficient_bank = 'Insufficient funds (bank account)',
        error_no_bank_account = 'No active bank account',
        error_save_mod = 'Error saving the modification; your money was refunded',
        error_save_color = 'Error saving the color; your money was refunded',
        error_save_livery = 'Error saving the livery; your money was refunded',
        error_save_reset = 'Error resetting the modifications; your money was refunded',

        -- Proximity / blip
        proximity_label = '{1}\nOpen LS Customs',
        default_shop_name = 'LS Customs',

        -- Modification categories (left panel label)
        category = {
            engine = 'Engine',
            brakes = 'Brakes',
            transmission = 'Transmission',
            turbo = 'Turbo',
            suspension = 'Suspension',
            armor = 'Armor',
            xenon = 'Xenon',
            wheels = 'Wheels',
            color = 'Color',
            livery = 'Livery',
        },

        -- Wheel types
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

        -- Tier labels per category (label + desc)
        tier = {
            engine = {
                ['1'] = { label = 'EMS Level I',    desc = '+4% engine power, +4% torque' },
                ['2'] = { label = 'EMS Level II',   desc = '+8% engine power, +8% torque' },
                ['3'] = { label = 'EMS Level III',  desc = '+12% engine power, +12% torque' },
                ['4'] = { label = 'EMS Level IV',   desc = '+16% engine power, +16% torque · VIP exclusive' },
            },
            brakes = {
                ['1'] = { label = 'Street Brakes', desc = 'Braking distance reduced by 10%' },
                ['2'] = { label = 'Sport Brakes',  desc = 'Braking distance reduced by 20%' },
                ['3'] = { label = 'Race Brakes',   desc = 'Braking distance reduced by 30%' },
            },
            transmission = {
                ['1'] = { label = 'Street Transmission', desc = 'Gear changes 5% faster' },
                ['2'] = { label = 'Sport Transmission',  desc = 'Gear changes 10% faster' },
                ['3'] = { label = 'Race Transmission',   desc = 'Gear changes 15% faster' },
            },
            turbo = {
                ['1'] = { label = 'Turbo Kit', desc = 'Significant boost at high RPM' },
            },
            suspension = {
                ['1'] = { label = 'Lowering',    desc = 'Lowered center of gravity' },
                ['2'] = { label = 'Street',      desc = 'Improved handling on tarmac' },
                ['3'] = { label = 'Sport',       desc = 'Increased stability in corners' },
                ['4'] = { label = 'Race',        desc = 'Maximized grip' },
                ['5'] = { label = 'Competition', desc = 'Professional circuit suspension' },
            },
            armor = {
                ['1'] = { label = 'Armor Level I',   desc = '+20% bullet resistance' },
                ['2'] = { label = 'Armor Level II',  desc = '+40% bullet resistance' },
                ['3'] = { label = 'Armor Level III', desc = '+60% bullet resistance' },
                ['4'] = { label = 'Armor Level IV',  desc = '+80% bullet resistance' },
                ['5'] = { label = 'Armor Level V',   desc = 'Full protection · VIP exclusive' },
            },
            xenon = {
                ['1'] = { label = 'Xenon Headlights', desc = 'High intensity, longer range' },
            },
            wheels = {
                ['0'] = { label = 'Sport',    desc = 'Lightweight sport rims' },
                ['1'] = { label = 'Muscle',   desc = 'Classic muscle rims' },
                ['2'] = { label = 'Lowrider', desc = 'Low-profile lowrider rims' },
                ['3'] = { label = 'SUV',      desc = 'Rugged SUV rims' },
                ['4'] = { label = 'Offroad',  desc = 'Rims for rough terrain' },
                ['5'] = { label = 'Tuner',    desc = 'Modern tuner rims' },
                ['6'] = { label = 'Bike',     desc = 'Motorcycle rims' },
                ['7'] = { label = 'High-End', desc = 'Premium luxury rims · VIP exclusive' },
            },
        },

        -- Pearlescent colors (palette)
        pearl = {
            ['0'] = 'Black',
            ['1'] = 'Graphite',
            ['5'] = 'Anthracite',
            ['6'] = 'Matte Silver',
            ['11'] = 'Pure Silver',
            ['27'] = 'Sport Red',
            ['28'] = 'Candy Red',
            ['36'] = 'Orange',
            ['38'] = 'Gold',
            ['49'] = 'Forest Green',
            ['51'] = 'Lime Green',
            ['62'] = 'Navy Blue',
            ['64'] = 'Galaxy Blue',
            ['70'] = 'Sky Blue',
            ['88'] = 'Yellow',
            ['89'] = 'Race Yellow',
            ['111'] = 'Cream White',
            ['112'] = 'Pure White',
            ['132'] = 'Pink',
            ['145'] = 'Purple',
        },

        -- NUI interface
        ui = {
            -- Static labels (data-i18n)
            shop_default = 'LS Customs',
            plate_placeholder = '- - -',
            vip = 'VIP',
            cart_empty = 'No upgrade selected · Add from the right panel',
            total = 'Total',
            pay_cash = 'Cash',
            pay_bank = 'Bank',
            buy_all = 'Buy All',
            reset_stock = 'Reset Stock',
            reset_stock_title = 'Reset Stock',
            modal_confirm_title = 'Confirm',
            modal_cancel = 'Cancel',
            modal_confirm = 'Confirm',
            panel_default_title = 'Engine',

            -- JS-generated strings
            free = 'Free',
            stock = 'Stock',
            stock_desc = 'Original configuration',
            tier_generic = 'Tier {1}',
            type_generic = 'Type {1}',
            badge_installed = 'Installed',
            badge_in_cart = 'In cart',
            badge_vip = 'VIP',

            color_primary_section = 'Primary Color',
            color_secondary_section = 'Secondary Color',
            color_primary_label = 'Primary',
            color_secondary_label = 'Secondary',
            pearl_section = 'Pearlescent',
            pearl_hint = '(gloss layered over the paint)',
            paint_cost = 'Paint cost',
            add_to_cart = 'Add to cart',
            remove_from_cart = 'Remove from cart',
            paint_label = 'Paint',

            wheel_type_hint = 'Type: {1} - pick a design.',
            wheel_pick_type = 'Pick a wheel type first.',
            wheel_design_header = 'Design {1}',
            wheel_no_design = 'No design available for this type.',
            wheel_design_line = '{1} · Design #{2}',
            wheel_cart_label = '{1} #{2}',
            wheels_fallback = 'Wheels',

            livery_cost_hint = 'Cost per livery: {1}',
            livery_none = 'No livery',
            livery_generic = 'Livery {1}',

            chip_remove = 'Remove',

            buy_modal_title = 'Confirm purchase',
            buy_modal_total = 'Total: {1}',
            buy_modal_line = '• {1} - {2}',
            reset_modal_title = 'Reset to Stock',
            reset_modal_body = 'All modifications will be removed.',
            reset_modal_cost = 'Cost: {1}',
        },
    },
}
