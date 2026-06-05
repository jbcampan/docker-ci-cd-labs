-- Initialisation script executed once on first DB startup
CREATE TABLE IF NOT EXISTS items (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Seed data
INSERT INTO items (name) VALUES
    ('first item'),
    ('second item'),
    ('third item');