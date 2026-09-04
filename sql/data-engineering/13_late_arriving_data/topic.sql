-- ============================================================================
-- Late-arriving dimensions & facts
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/13_late_arriving_data/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE dim_customer (
    customer_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  int NOT NULL,
    name text, city text,
    valid_from date NOT NULL, valid_to date NOT NULL DEFAULT DATE '9999-12-31',
    is_current boolean NOT NULL DEFAULT true,
    is_inferred boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX ON dim_customer (customer_id) WHERE is_current;
INSERT INTO dim_customer (customer_id, name, city, valid_from)
VALUES (1, 'Ana', 'Berlin', DATE '2024-01-01');

CREATE TABLE fact_order (
    order_id int PRIMARY KEY,
    customer_key bigint NOT NULL REFERENCES dim_customer (customer_key),
    ordered_on date NOT NULL,
    amount numeric NOT NULL
);

-- ==== Late fact: inferred dimension member =====================
INSERT INTO dim_customer (customer_id, name, city, valid_from, is_inferred)
SELECT 2, '(Unknown)', '(Unknown)', DATE '2024-03-01', true
WHERE NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_id = 2 AND is_current);

INSERT INTO fact_order (order_id, customer_key, ordered_on, amount)
SELECT 500, dc.customer_key, DATE '2024-03-01', 40
FROM dim_customer dc WHERE dc.customer_id = 2 AND dc.is_current;

SELECT c.name, c.is_inferred FROM fact_order o JOIN dim_customer c USING (customer_key) WHERE o.order_id = 500;
-- expect: (Unknown), true

-- real customer arrives: update the placeholder IN PLACE
UPDATE dim_customer SET name = 'Ben', city = 'Lagos', is_inferred = false
WHERE customer_id = 2 AND is_current AND is_inferred;

SELECT c.name, c.is_inferred FROM fact_order o JOIN dim_customer c USING (customer_key) WHERE o.order_id = 500;
-- expect: Ben, false  (same customer_key)
SELECT count(*) AS dim_rows_for_cust_2 FROM dim_customer WHERE customer_id = 2;
-- expect: 1

-- ==== Late Type-2 change: split the interval + re-point facts ===
-- naive June load already split Ana at 2024-06-01
UPDATE dim_customer SET valid_to = DATE '2024-06-01', is_current = false WHERE customer_id = 1 AND city = 'Berlin';
INSERT INTO dim_customer (customer_id, name, city, valid_from) VALUES (1, 'Ana', 'Munich', DATE '2024-06-01');

-- correction: move was effective 2024-04-01
UPDATE dim_customer SET valid_to = DATE '2024-04-01' WHERE customer_id = 1 AND city = 'Berlin';
UPDATE dim_customer SET valid_from = DATE '2024-04-01' WHERE customer_id = 1 AND city = 'Munich';

-- a May order was loaded against the Berlin key
INSERT INTO fact_order
SELECT 600, customer_key, DATE '2024-05-15', 90 FROM dim_customer WHERE customer_id = 1 AND city = 'Berlin';

-- re-point every fact to the version valid on its own date
UPDATE fact_order f
SET customer_key = dc.customer_key
FROM dim_customer dc
WHERE dc.customer_id = 1
  AND f.ordered_on >= dc.valid_from AND f.ordered_on < dc.valid_to
  AND f.customer_key <> dc.customer_key;

SELECT f.order_id, f.ordered_on, c.city
FROM fact_order f JOIN dim_customer c USING (customer_key)
WHERE f.order_id = 600;
-- expect: order 600 (2024-05-15) -> Munich

DROP SCHEMA sqlfp CASCADE;
