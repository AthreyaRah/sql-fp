-- ============================================================================
-- Reading EXPLAIN plans & query optimization (a worked case)
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/02_reading_explain_plans_and_query_optimization/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (
    customer_id int PRIMARY KEY,
    country     text NOT NULL,
    created_at  timestamptz NOT NULL
);
CREATE TABLE orders (
    order_id    bigint PRIMARY KEY,
    customer_id int NOT NULL,
    status      text NOT NULL,
    total       numeric NOT NULL,
    created_at  timestamptz NOT NULL
);
INSERT INTO customers
SELECT g, (ARRAY['DE', 'NG', 'CA', 'EG', 'BR'])[1 + (g % 5)],
       TIMESTAMPTZ '2023-01-01' + (g || ' minutes')::interval
FROM generate_series(1, 30000) g;
INSERT INTO orders
SELECT g, (g % 30000) + 1,
       (ARRAY['paid', 'pending', 'cancelled', 'refunded'])[1 + (g % 4)],
       (g % 900) + 1,
       TIMESTAMPTZ '2024-01-01' + ((g * 10) || ' minutes')::interval
FROM generate_series(1, 50000) g;
ANALYZE customers;
ANALYZE orders;

-- ==== 1 · the slow plan (Seq Scan on orders, then Sort) ============
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, o.total, o.created_at
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id = 12345
  AND o.status = 'paid'
  AND o.created_at >= TIMESTAMPTZ '2024-01-01'
ORDER BY o.created_at DESC
LIMIT 20;

-- ==== 2 · add the composite index in the right column order ========
CREATE INDEX idx_orders_cust_status_created
  ON orders (customer_id, status, created_at DESC);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, o.total, o.created_at
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id = 12345
  AND o.status = 'paid'
  AND o.created_at >= TIMESTAMPTZ '2024-01-01'
ORDER BY o.created_at DESC
LIMIT 20;
-- expect: Index Scan using idx_orders_cust_status_created, no Sort node

-- ==== 3 · wrong column order does not help =========================
CREATE INDEX bad ON orders (created_at, status, customer_id);
ANALYZE orders;
EXPLAIN
SELECT order_id FROM orders
WHERE customer_id = 12345 AND status = 'paid' AND created_at >= TIMESTAMPTZ '2024-01-01'
ORDER BY created_at DESC LIMIT 20;

-- ==== 4 · covering index -> Index Only Scan ========================
CREATE INDEX idx_cov
  ON orders (customer_id, status, created_at DESC) INCLUDE (order_id, total);
ANALYZE orders;
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, total, created_at FROM orders
WHERE customer_id = 12345 AND status = 'paid' AND created_at >= TIMESTAMPTZ '2024-01-01'
ORDER BY created_at DESC LIMIT 20;

DROP SCHEMA sqlfp CASCADE;
