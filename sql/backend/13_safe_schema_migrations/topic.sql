-- ============================================================================
-- Safe schema migrations: locks, backfills, NOT VALID
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/13_safe_schema_migrations/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE orders (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    total  numeric NOT NULL,
    status text NOT NULL DEFAULT 'pending'
);
INSERT INTO orders (total) SELECT (g % 500) + 1 FROM generate_series(1, 5000) g;

SET lock_timeout = '2s';

-- ==== Online NOT NULL add ======================================
ALTER TABLE orders ADD COLUMN currency text;                          -- instant

UPDATE orders SET currency = 'EUR' WHERE currency IS NULL AND id BETWEEN 1 AND 2500;
UPDATE orders SET currency = 'EUR' WHERE currency IS NULL AND id BETWEEN 2501 AND 5000;

ALTER TABLE orders ADD CONSTRAINT currency_nn CHECK (currency IS NOT NULL) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT currency_nn;
ALTER TABLE orders ALTER COLUMN currency SET NOT NULL;

SELECT count(*) FILTER (WHERE currency IS NULL) AS nulls FROM orders;
-- expect: 0

-- ==== NOT VALID FK, validated separately =======================
CREATE TABLE customers (id int PRIMARY KEY);
INSERT INTO customers SELECT DISTINCT (total::int % 50) + 1 FROM orders;

ALTER TABLE orders ADD COLUMN customer_id int;
UPDATE orders SET customer_id = (total::int % 50) + 1;

ALTER TABLE orders ADD CONSTRAINT orders_customer_fk
    FOREIGN KEY (customer_id) REFERENCES customers (id) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT orders_customer_fk;

SELECT conname, convalidated FROM pg_constraint
WHERE conrelid = 'sqlfp.orders'::regclass AND contype = 'f';
-- expect: orders_customer_fk, true

-- ==== A constant default is free; a volatile one rewrites =======
ALTER TABLE orders ADD COLUMN region text NOT NULL DEFAULT 'EU';        -- instant (constant default)
SELECT DISTINCT region FROM orders;
-- ALTER TABLE orders ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();  -- would rewrite every row

DROP SCHEMA sqlfp CASCADE;
