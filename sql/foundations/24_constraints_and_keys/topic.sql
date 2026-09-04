-- ============================================================================
-- Constraints & keys: PK, FK, UNIQUE, CHECK
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/24_constraints_and_keys/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (
    customer_id int PRIMARY KEY,
    email       text NOT NULL UNIQUE,
    country     text NOT NULL
);
CREATE TABLE orders (
    order_id    int PRIMARY KEY,
    customer_id int NOT NULL REFERENCES customers (customer_id),
    status      text NOT NULL CHECK (status IN ('pending', 'paid', 'cancelled')),
    amount      numeric NOT NULL CHECK (amount >= 0)
);
INSERT INTO customers VALUES (1, 'ana@x.com', 'DE'), (2, 'ben@x.com', 'NG');
INSERT INTO orders VALUES (100, 1, 'paid', 40), (101, 2, 'pending', 10);

-- ==== Constraints reject bad writes (caught so the script continues) ====
DO $$ BEGIN
    BEGIN INSERT INTO orders VALUES (102, 3, 'paid', 5);
    EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'FK rejected order 102'; END;
    BEGIN INSERT INTO customers VALUES (3, 'ana@x.com', 'FR');
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'UNIQUE rejected duplicate email'; END;
    BEGIN UPDATE orders SET status = 'refunded' WHERE order_id = 100;
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'CHECK rejected status refunded'; END;
    BEGIN INSERT INTO orders VALUES (103, 1, 'paid', -1);
    EXCEPTION WHEN check_violation THEN RAISE NOTICE 'CHECK rejected negative amount'; END;
END $$;

-- ==== The valid path ==============================================
INSERT INTO customers VALUES (3, 'cid@x.com', 'FR');
INSERT INTO orders VALUES (102, 3, 'paid', 5);
SELECT count(*) AS orders FROM orders;
-- expect: 3

-- ==== UNIQUE allows multiple NULLs ================================
CREATE TEMP TABLE t (id int, code text UNIQUE);
INSERT INTO t VALUES (1, NULL), (2, NULL), (3, 'x');
SELECT count(*) AS rows FROM t;
-- expect: 3

-- ==== Partial unique index: at most one primary per customer ======
CREATE TABLE addresses (customer_id int, line text, is_primary boolean NOT NULL DEFAULT false);
CREATE UNIQUE INDEX one_primary_addr ON addresses (customer_id) WHERE is_primary;
INSERT INTO addresses VALUES (1, 'A st', true), (1, 'B rd', false);
DO $$ BEGIN
    INSERT INTO addresses VALUES (1, 'C ave', true);
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'second primary address rejected'; END $$;

-- ==== NOT VALID then VALIDATE ====================================
ALTER TABLE orders ADD CONSTRAINT amount_cap CHECK (amount <= 100000) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT amount_cap;
SELECT conname FROM pg_constraint WHERE conrelid = 'sqlfp.orders'::regclass ORDER BY conname;

DROP SCHEMA sqlfp CASCADE;
