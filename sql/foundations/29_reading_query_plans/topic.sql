-- ============================================================================
-- Reading query plans: EXPLAIN & EXPLAIN ANALYZE
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/29_reading_query_plans/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (customer_id int PRIMARY KEY, city text NOT NULL);
CREATE TABLE orders (
    order_id bigint PRIMARY KEY,
    customer_id int NOT NULL,
    amount numeric NOT NULL,
    created_at timestamptz NOT NULL
);
INSERT INTO customers SELECT g, (ARRAY['Berlin', 'Lagos', 'Toronto', 'Cairo'])[1 + (g % 4)]
FROM generate_series(1, 2000) g;
INSERT INTO orders
SELECT g, (g % 2000) + 1, (g % 100) + 1,
       TIMESTAMPTZ '2024-01-01' + (g || ' minutes')::interval
FROM generate_series(1, 60000) g;
ANALYZE customers;
ANALYZE orders;

-- ==== Plan only ===================================================
EXPLAIN
SELECT c.city, count(*)
FROM customers c JOIN orders o USING (customer_id)
WHERE o.amount > 95
GROUP BY c.city;

-- ==== Plan + actuals + buffers ===================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.city, count(*)
FROM customers c JOIN orders o USING (customer_id)
WHERE o.amount > 95
GROUP BY c.city;

-- ==== Selective query: Seq Scan -> Index Scan ====================
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
CREATE INDEX ix ON orders (customer_id);
ANALYZE orders;
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- ==== Misestimate from stale stats ==============================
INSERT INTO orders SELECT g, 1, 50, TIMESTAMPTZ '2025-01-01'
FROM generate_series(1000001, 1030000) g;
EXPLAIN SELECT * FROM orders WHERE customer_id = 1;   -- estimate stale
ANALYZE orders;
EXPLAIN SELECT * FROM orders WHERE customer_id = 1;   -- estimate refreshed

SELECT count(*) AS rows_for_cust_1 FROM orders WHERE customer_id = 1;
-- expect: ~30030

DROP SCHEMA sqlfp CASCADE;
