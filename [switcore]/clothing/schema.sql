CREATE TABLE IF NOT EXISTS clothing_stores (
    name        VARCHAR(50)  PRIMARY KEY,
    label       VARCHAR(100) NOT NULL,
    type        VARCHAR(20)  NOT NULL DEFAULT 'casual', -- casual | sport | luxury
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    shop_coords JSONB        NOT NULL,   -- {x, y, z, heading}
    tryon_coords JSONB       NOT NULL    -- {x, y, z, heading} - fitting room spot
);

CREATE TABLE IF NOT EXISTS clothing_items (
    id             SERIAL       PRIMARY KEY,
    store_name     VARCHAR(50)  NOT NULL REFERENCES clothing_stores(name) ON DELETE CASCADE,
    item_name      VARCHAR(50)  NOT NULL,   -- maps to inventory items table
    label          VARCHAR(100) NOT NULL,
    component_type VARCHAR(10)  NOT NULL DEFAULT 'component', -- 'component' | 'prop'
    component_id   INT          NOT NULL,
    drawable       INT          NOT NULL,
    default_texture INT         NOT NULL DEFAULT 0,
    texture_count  INT          NOT NULL DEFAULT 1,
    gender         INT          NOT NULL DEFAULT -1,  -- -1 = ambele, 0 = masculin, 1 = feminin
    price          INT          NOT NULL DEFAULT 100,
    bonus_slots    INT          NOT NULL DEFAULT 0,
    bonus_weight   DECIMAL(5,2) NOT NULL DEFAULT 0.0,
    UNIQUE(store_name, component_type, component_id, drawable)
);

CREATE TABLE IF NOT EXISTS character_equipped_clothing (
    character_id INT  PRIMARY KEY,
    components   JSONB NOT NULL DEFAULT '{}'::jsonb
    -- Format: {"component_11": {component_type, component_id, drawable, texture, item_name, bonus_slots, bonus_weight, label}, ...}
);

CREATE TABLE IF NOT EXISTS character_outfits (
    id           SERIAL       PRIMARY KEY,
    character_id INT          NOT NULL,
    name         VARCHAR(50)  NOT NULL,
    components   JSONB        NOT NULL DEFAULT '{}'::jsonb,
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    UNIQUE(character_id, name)
);

CREATE INDEX IF NOT EXISTS idx_clothing_items_store    ON clothing_items(store_name);
CREATE INDEX IF NOT EXISTS idx_character_outfits_char  ON character_outfits(character_id);
