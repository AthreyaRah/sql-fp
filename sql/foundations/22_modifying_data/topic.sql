-- ============================================================================
-- Modifying data: INSERT, UPDATE, DELETE, RETURNING
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/22_modifying_data/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE products (
    product_id int PRIMARY KEY,
    name       text NOT NULL,
    price      numeric NOT NULL,
    archived   boolean NOT NULL DEFAULT false
);
CREATE TABLE price_bumps (product_id int, pct numeric);
INSERT INTO products (product_id, name, price) VALUES
    (1, 'Notebook', 6), (2, 'Desk lamp', 28), (3, 'Mug', 9), (4, 'Cable', 8);
INSERT INTO price_bumps VALUES (1, 10), (2, 25);

-- ==== UPDATE ... FROM with RETURNING ================================
UPDATE products p
SET price = round(p.price * (1 + b.pct / 100.0), 2)
FROM price_bumps b
WHERE b.product_id = p.product_id
RETURNING p.product_id, p.name, p.price;
-- expect: (1, Notebook, 6.60), (2, Desk lamp, 35.00)

-- ==== INSERT ... SELECT ... RETURNING ==============================
INSERT INTO products (product_id, name, price)
SELECT product_id + 100, name || ' (copy)', price FROM products WHERE price < 10
RETURNING product_id, name;

-- ==== no-WHERE footgun, contained by a transaction =================
BEGIN;
UPDATE products SET archived = true;   -- ALL rows
SELECT count(*) FILTER (WHERE archived) AS archived_now FROM products;
ROLLBACK;
SELECT count(*) FILTER (WHERE archived) AS archived_after_rollback FROM products;
-- expect: archived_after_rollback = 0

-- ==== data-modifying CTE ==========================================
CREATE TEMP TABLE audit (msg text);
WITH archived AS (
    UPDATE products SET archived = true WHERE price < 9 RETURNING name
)
INSERT INTO audit (msg) SELECT 'archived ' || name FROM archived;
SELECT count(*) AS logged FROM audit;

DROP SCHEMA sqlfp CASCADE;
