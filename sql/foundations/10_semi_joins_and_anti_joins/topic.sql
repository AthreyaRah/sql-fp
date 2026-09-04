-- ============================================================================
-- Semi-joins & anti-joins (EXISTS, NOT IN trap)
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/10_semi_joins_and_anti_joins/topic.sql
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
    (900, NULL, 5);

-- ==== Semi-join: EXISTS ==============================================
SELECT c.name FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
ORDER BY c.name;
-- expect: Ana, Ben (once each)

-- ==== Semi-join: IN =================================================
SELECT name FROM customers
WHERE customer_id IN (SELECT customer_id FROM orders)
ORDER BY name;
-- expect: Ana, Ben

-- ==== Anti-join: NOT EXISTS (correct) ===============================
SELECT name FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
ORDER BY name;
-- expect: Chidi, Dana

-- ==== Anti-join: NOT IN with a NULL in the subquery -> 0 rows ========
SELECT name FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM orders);
-- expect: 0 rows (the NULL from order 900 poisons NOT IN)

-- ==== Anti-join via LEFT JOIN ... IS NULL ===========================
SELECT c.name FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.name;
-- expect: Chidi, Dana

-- ==== Safe NOT IN: exclude NULLs from the subquery ==================
SELECT name FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM orders WHERE customer_id IS NOT NULL)
ORDER BY name;
-- expect: Chidi, Dana

DROP SCHEMA sqlfp CASCADE;
