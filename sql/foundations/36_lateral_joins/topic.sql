-- ============================================================================
-- LATERAL joins & set-returning functions
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/36_lateral_joins/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (customer_id int PRIMARY KEY, name text NOT NULL);
CREATE TABLE orders (
    order_id int PRIMARY KEY, customer_id int NOT NULL, amount numeric NOT NULL, ordered_at date NOT NULL
);
INSERT INTO customers VALUES (1, 'Ana'), (2, 'Ben'), (3, 'Chidi');
INSERT INTO orders VALUES
    (100, 1, 40, DATE '2024-01-05'), (101, 1, 12, DATE '2024-02-01'), (102, 1, 90, DATE '2024-03-10'),
    (103, 2, 15, DATE '2024-01-20'), (104, 2, 55, DATE '2024-02-15'),
    (105, 3, 30, DATE '2024-03-01');

-- ==== Top-2 orders per customer =================================
SELECT c.name, o.order_id, o.amount
FROM customers c
CROSS JOIN LATERAL (
    SELECT order_id, amount FROM orders
    WHERE customer_id = c.customer_id
    ORDER BY amount DESC LIMIT 2
) o
ORDER BY c.name, o.amount DESC;
-- expect: Ana (90,40), Ben (55,15), Chidi (30)

-- ==== LEFT JOIN LATERAL keeps non-matching customers ============
SELECT c.name, o.order_id
FROM customers c
LEFT JOIN LATERAL (
    SELECT order_id FROM orders
    WHERE customer_id = c.customer_id AND amount > 100
    ORDER BY amount DESC LIMIT 1
) o ON true
ORDER BY c.name;
-- expect: 3 rows, all order_id NULL

-- ==== Per-row derived aggregate ================================
SELECT c.name, s.n_orders, s.total, s.last_order
FROM customers c
CROSS JOIN LATERAL (
    SELECT count(*) AS n_orders, sum(amount) AS total, max(ordered_at) AS last_order
    FROM orders WHERE customer_id = c.customer_id
) s
ORDER BY c.name;
-- expect: Ana 3/142, Ben 2/70, Chidi 1/30

-- ==== SRF in FROM ============================================
SELECT c.name, m::date AS month
FROM customers c
CROSS JOIN LATERAL generate_series(DATE '2024-01-01', DATE '2024-03-01', INTERVAL '1 month') AS m
WHERE c.customer_id = 1;
-- expect: 3 rows

-- ==== Most recent order per customer, nulls if none ============
SELECT c.name, o.order_id, o.ordered_at
FROM customers c
LEFT JOIN LATERAL (
    SELECT order_id, ordered_at FROM orders
    WHERE customer_id = c.customer_id ORDER BY ordered_at DESC LIMIT 1
) o ON true
ORDER BY c.name;

DROP SCHEMA sqlfp CASCADE;
