CREATE TABLE IF NOT EXISTS shops (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    label VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'general',
    coords JSONB NOT NULL,
    blip_sprite INT DEFAULT 52,
    blip_color INT DEFAULT 2,
    is_open BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS shop_items (
    id SERIAL PRIMARY KEY,
    shop_name VARCHAR(50) NOT NULL REFERENCES shops(name) ON DELETE CASCADE,
    item_name VARCHAR(50) NOT NULL REFERENCES items(name),
    price NUMERIC(10, 2) NOT NULL,
    currency_code VARCHAR(10) NOT NULL DEFAULT 'USD',
    is_available BOOLEAN DEFAULT true,
    UNIQUE(shop_name, item_name)
);
