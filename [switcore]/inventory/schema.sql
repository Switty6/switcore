CREATE TABLE IF NOT EXISTS items (
    name VARCHAR(50) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    weight DECIMAL(5, 2) NOT NULL DEFAULT 0.0,
    type VARCHAR(50) NOT NULL DEFAULT 'misc',
    usable BOOLEAN DEFAULT FALSE,
    stackable BOOLEAN DEFAULT TRUE,
    description TEXT
);

ALTER TABLE items ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT NULL;
ALTER TABLE items ADD COLUMN IF NOT EXISTS drop_prop VARCHAR(100) DEFAULT NULL;
ALTER TABLE items ADD COLUMN IF NOT EXISTS drop_anim_dict VARCHAR(100) DEFAULT NULL;
ALTER TABLE items ADD COLUMN IF NOT EXISTS drop_anim_name VARCHAR(100) DEFAULT NULL;

CREATE TABLE IF NOT EXISTS inventory_items (
    id SERIAL PRIMARY KEY,
    inventory_id VARCHAR(50) NOT NULL,
    item_name VARCHAR(50) NOT NULL REFERENCES items(name) ON DELETE RESTRICT,
    amount INT NOT NULL DEFAULT 1,
    slot INT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_inventory_items_inventory_id ON inventory_items(inventory_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_item_name ON inventory_items(item_name);

CREATE TABLE IF NOT EXISTS inventory_bonuses (
    character_id INT PRIMARY KEY,
    bonus_slots INT NOT NULL DEFAULT 0,
    bonus_weight DECIMAL(5,2) NOT NULL DEFAULT 0.0
);

-- Default item seeds
INSERT INTO items (name, label, weight, type, usable, stackable, description) VALUES
('water', 'Sticlă cu Apă', 0.5, 'consumable', TRUE, TRUE, 'O sticlă cu apă plată pentru hidratare.'),
('bread', 'Pâine', 0.2, 'consumable', TRUE, TRUE, 'O felie de pâine proaspătă.'),
('weapon_pistol', 'Pistol 9mm', 1.5, 'weapon', TRUE, FALSE, 'O armă de foc de calibru mic. Necesită muniție.'),
('ammo_9mm', 'Muniție 9mm', 0.01, 'ammo', FALSE, TRUE, 'Cutie de cartușe 9mm pentru pistoale.'),
('money', 'Bani', 0.0, 'money', FALSE, TRUE, 'Bancnote folosite în San Andreas.'),
('bandage', 'Bandaj', 0.1, 'medical', TRUE, TRUE, 'Bandaj steril pentru oprirea sângerărilor minore.'),
('medkit', 'Trusă Medicală', 0.8, 'medical', TRUE, FALSE, 'Trusă completă de prim ajutor. Restaurează sănătate semnificativ.'),
('painkillers', 'Analgezice', 0.05, 'medical', TRUE, TRUE, 'Pastile pentru durere. Efect moderat de refacere.'),
('vitamins', 'Vitamine', 0.05, 'medical', TRUE, TRUE, 'Supliment zilnic de vitamine. Efect minor de refacere.'),
('antidepressants', 'Antidepresante', 0.05, 'medical', TRUE, TRUE, 'Tratament psihiatric prescris.')
ON CONFLICT (name) DO NOTHING;
