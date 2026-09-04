-- ============================================================================
-- Generated columns, domains & custom types
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/37_generated_columns_domains_and_types/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE order_lines (
    order_id   int NOT NULL,
    product    text NOT NULL,
    qty        int  NOT NULL CHECK (qty > 0),
    unit_price numeric(10, 2) NOT NULL CHECK (unit_price >= 0),
    line_total numeric(12, 2) GENERATED ALWAYS AS (qty * unit_price) STORED,
    PRIMARY KEY (order_id, product)
);
INSERT INTO order_lines (order_id, product, qty, unit_price) VALUES
    (100, 'lamp',  1, 28.00),
    (100, 'mug',   2,  9.00),
    (101, 'cable', 3,  8.00);

-- ==== Generated column maintained by the engine ================
SELECT * FROM order_lines ORDER BY order_id, product;
-- expect: line_total = 28.00, 18.00, 24.00

UPDATE order_lines SET qty = 4 WHERE order_id = 100 AND product = 'mug'
RETURNING product, qty, line_total;
-- expect: mug, 4, 36.00

DO $$ BEGIN
    UPDATE order_lines SET line_total = 999 WHERE product = 'mug';
EXCEPTION WHEN others THEN RAISE NOTICE 'cannot write a generated column: %', SQLERRM;
END $$;

-- ==== DOMAIN carries its CHECK ================================
CREATE DOMAIN email AS text CHECK (VALUE ~ '^[^@]+@[^@]+\.[^@]+$');
CREATE TABLE people (id int, contact email);
INSERT INTO people VALUES (1, 'ana@acme.io');
DO $$ BEGIN
    INSERT INTO people VALUES (2, 'not-an-email');
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'domain rejected bad email';
END $$;
SELECT count(*) AS people FROM people;
-- expect: 1

-- ==== ENUM: ordered + compact ================================
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'cancelled');
CREATE TABLE o (id int, status order_status NOT NULL);
INSERT INTO o VALUES (1, 'paid'), (2, 'pending'), (3, 'cancelled');
SELECT id, status FROM o WHERE status < 'cancelled' ORDER BY status;
-- expect: pending, paid  (declaration order)
SELECT pg_column_size('paid'::order_status) AS bytes;
-- expect: 4

-- ==== Generated tsvector column =============================
CREATE TABLE docs (
    id int PRIMARY KEY,
    body text NOT NULL,
    search tsvector GENERATED ALWAYS AS (to_tsvector('english', body)) STORED
);
CREATE INDEX ON docs USING GIN (search);
INSERT INTO docs (id, body) VALUES (1, 'PostgreSQL indexing and query tuning');
SELECT id FROM docs WHERE search @@ plainto_tsquery('english', 'index tuning');
-- expect: 1

DROP SCHEMA sqlfp CASCADE;
