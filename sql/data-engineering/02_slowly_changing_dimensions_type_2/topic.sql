-- ============================================================================
-- Slowly Changing Dimensions - Type 2
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/02_slowly_changing_dimensions_type_2/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE stg_customers (
    customer_id int PRIMARY KEY,
    name        text NOT NULL,
    city        text NOT NULL,
    tier        text NOT NULL
);
INSERT INTO stg_customers VALUES
    (1, 'Ana', 'Berlin', 'gold'),
    (2, 'Ben', 'Lagos', 'silver'),
    (3, 'Chidi', 'Cairo', 'bronze');

CREATE TABLE dim_customer (
    customer_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  int  NOT NULL,
    name         text NOT NULL,
    city         text NOT NULL,
    tier         text NOT NULL,
    valid_from   date NOT NULL,
    valid_to     date NOT NULL DEFAULT DATE '9999-12-31',
    is_current   boolean NOT NULL DEFAULT true,
    CHECK (valid_from < valid_to)
);
CREATE UNIQUE INDEX dim_customer_current ON dim_customer (customer_id) WHERE is_current;

-- ==== Load 1 (2024-01-01): seed ====================================
INSERT INTO dim_customer (customer_id, name, city, tier, valid_from)
SELECT customer_id, name, city, tier, DATE '2024-01-01' FROM stg_customers;

SELECT count(*) AS after_load_1 FROM dim_customer;
-- expect: 3

-- ==== Source changes, then Load 2 (2024-03-01) =====================
UPDATE stg_customers SET city = 'Munich' WHERE customer_id = 1;
UPDATE stg_customers SET tier = 'gold'   WHERE customer_id = 2;

-- reusable load procedure
CREATE PROCEDURE scd2_load(load_date date) LANGUAGE plpgsql AS $$
BEGIN
    UPDATE dim_customer d
    SET valid_to = load_date, is_current = false
    FROM stg_customers s
    WHERE d.customer_id = s.customer_id
      AND d.is_current
      AND (d.name, d.city, d.tier) IS DISTINCT FROM (s.name, s.city, s.tier);

    INSERT INTO dim_customer (customer_id, name, city, tier, valid_from)
    SELECT s.customer_id, s.name, s.city, s.tier, load_date
    FROM stg_customers s
    LEFT JOIN dim_customer d ON d.customer_id = s.customer_id AND d.is_current
    WHERE d.customer_id IS NULL;
END $$;

CALL scd2_load(DATE '2024-03-01');

SELECT customer_id, city, tier, valid_from, valid_to, is_current
FROM dim_customer ORDER BY customer_id, valid_from;
-- expect: cust 1 -> Berlin(closed), Munich(current); cust 2 -> Lagos silver(closed), Lagos gold(current); cust 3 -> unchanged

SELECT count(*) AS after_load_2 FROM dim_customer;
-- expect: 5

-- ==== Idempotency: re-run with no source changes ===================
CALL scd2_load(DATE '2024-03-01');
CALL scd2_load(DATE '2024-03-01');
SELECT count(*) AS after_reruns FROM dim_customer;
-- expect: still 5

-- ==== Point-in-time lookup ========================================
SELECT d.d AS as_of, dc.city
FROM (VALUES (DATE '2024-02-01'), (DATE '2024-03-15'), (DATE '2024-06-01')) d (d)
JOIN dim_customer dc
  ON dc.customer_id = 1 AND d.d >= dc.valid_from AND d.d < dc.valid_to
ORDER BY as_of;
-- expect: 2024-02-01 -> Berlin; 2024-03-15 -> Munich; 2024-06-01 -> Munich

-- ==== Exactly one current row per customer ========================
SELECT customer_id, count(*) FILTER (WHERE is_current) AS current_rows
FROM dim_customer GROUP BY customer_id ORDER BY customer_id;
-- expect: all 1

DROP SCHEMA sqlfp CASCADE;
