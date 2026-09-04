-- ============================================================================
-- Outer joins: LEFT, RIGHT, FULL & NULL semantics
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/07_outer_joins/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (customer_id int PRIMARY KEY, name text NOT NULL);
CREATE TABLE orders (order_id int PRIMARY KEY, customer_id int, amount numeric NOT NULL);

INSERT INTO customers VALUES (1, 'Ana'), (2, 'Ben'), (3, 'Chidi'), (4, 'Dana');
INSERT INTO orders VALUES
    (100, 1, 40),
    (101, 1, 12),
    (102, 2, 75),
    (900, 99, 5);   -- orphan order

-- ==== LEFT JOIN: all customers, orders if any =========================
SELECT c.name, o.order_id, o.amount
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.name, o.order_id;
-- expect: 5 rows -- Ana x2, Ben x1, Chidi (NULLs), Dana (NULLs). Order 900 absent.

-- ==== count(*) vs count(col) =========================================
SELECT c.name,
       count(*)          AS star,
       count(o.order_id) AS real_orders,
       coalesce(sum(o.amount), 0) AS total
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.name ORDER BY c.name;
-- expect: Chidi/Dana -> star 1, real_orders 0, total 0

-- ==== Anti-join: customers with no orders ============================
SELECT c.name FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.name;
-- expect: Chidi, Dana

-- ==== FULL JOIN: the orphan order shows up ===========================
SELECT c.name, o.order_id, o.customer_id
FROM customers c
FULL JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.name NULLS LAST, o.order_id;
-- expect: 6 rows; last row (NULL, 900, 99)

-- ==== BREAK: WHERE on the right table collapses to inner join =========
-- SELECT c.name, count(o.order_id) FROM customers c
-- LEFT JOIN orders o ON o.customer_id = c.customer_id
-- WHERE o.amount > 20 GROUP BY c.name;   -- Chidi & Dana disappear

-- ==== Fix: filter in ON =============================================
SELECT c.name, count(o.order_id) AS big_orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.amount > 20
GROUP BY c.name ORDER BY c.name;
-- expect: Ana 1, Ben 1, Chidi 0, Dana 0

DROP SCHEMA sqlfp CASCADE;
