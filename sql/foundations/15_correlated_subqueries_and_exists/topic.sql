-- ============================================================================
-- Correlated subqueries & EXISTS
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/15_correlated_subqueries_and_exists/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (customer_id int PRIMARY KEY, name text NOT NULL, city text NOT NULL);
CREATE TABLE orders (
    order_id int PRIMARY KEY, customer_id int NOT NULL, amount numeric NOT NULL, ordered_at date NOT NULL
);
INSERT INTO customers VALUES (1,'Ana','Berlin'), (2,'Ben','Berlin'), (3,'Chidi','Lagos'), (4,'Dana','Lagos');
INSERT INTO orders VALUES
    (100,1,40,DATE '2024-01-10'),
    (101,1,90,DATE '2024-02-11'),
    (102,2,15,DATE '2024-01-15'),
    (103,3,120,DATE '2024-03-01');

-- ==== Correlated count / sum in the SELECT list ======================
SELECT c.name,
       (SELECT count(*)                FROM orders o WHERE o.customer_id = c.customer_id) AS n_orders,
       (SELECT coalesce(sum(amount),0) FROM orders o WHERE o.customer_id = c.customer_id) AS total
FROM customers c ORDER BY c.name;
-- expect: Ana 2/130, Ben 1/15, Chidi 1/120, Dana 0/0

-- ==== EXISTS: has an order over 50 ==================================
SELECT c.name FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.amount > 50)
ORDER BY c.name;
-- expect: Ana, Chidi

-- ==== Correlated in WHERE: each customer's biggest order =============
SELECT o.order_id, o.customer_id, o.amount
FROM orders o
WHERE o.amount = (SELECT max(o2.amount) FROM orders o2 WHERE o2.customer_id = o.customer_id)
ORDER BY o.customer_id;
-- expect: 101 (Ana 90), 102 (Ben 15), 103 (Chidi 120)

-- ==== Same as a LEFT JOIN to a grouped subquery =====================
SELECT c.name, coalesce(g.n, 0) AS n_orders
FROM customers c
LEFT JOIN (SELECT customer_id, count(*) AS n FROM orders GROUP BY customer_id) g
  ON g.customer_id = c.customer_id
ORDER BY c.name;

-- ==== NOT EXISTS: never ordered ===================================
SELECT c.name FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);
-- expect: Dana

DROP SCHEMA sqlfp CASCADE;
