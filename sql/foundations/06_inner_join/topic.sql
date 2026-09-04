-- ============================================================================
-- INNER JOIN: the cross-product-and-filter model
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/06_inner_join/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (
    customer_id int PRIMARY KEY,
    name        text NOT NULL
);
CREATE TABLE orders (
    order_id    int PRIMARY KEY,
    customer_id int,
    amount      numeric NOT NULL
);
CREATE TABLE order_items (order_id int, product text, qty int);

INSERT INTO customers VALUES (1, 'Ana'), (2, 'Ben'), (3, 'Chidi');
INSERT INTO orders VALUES
    (100, 1, 40),
    (101, 1, 12),
    (102, 2, 75),
    (103, NULL, 9);
INSERT INTO order_items VALUES
    (100, 'lamp', 1), (100, 'mug', 1), (100, 'cable', 1),
    (101, 'notebook', 2),
    (102, 'headphones', 1);

-- ==== The inner join ===================================================
SELECT c.name, o.order_id, o.amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.name, o.order_id;
-- expect: 3 rows (Ana x2, Ben x1). Chidi and order 103 (NULL) are gone.

-- ==== Joins multiply rows ============================================
SELECT c.name, count(*) AS order_rows, sum(o.amount) AS total
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.name ORDER BY c.name;
-- expect: Ana 2 rows total 52; Ben 1 row total 75

-- ==== The Cartesian product ==========================================
SELECT count(*) AS pairs FROM customers CROSS JOIN orders;
-- expect: 12

-- ==== BREAK: a second join inflates the SUM ==========================
SELECT c.name, sum(o.amount) AS total
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
GROUP BY c.name ORDER BY c.name;
-- expect: Ana 144 (inflated!), Ben 75

-- ==== Fix: pre-aggregate at the order grain in a CTE =================
WITH per_customer AS (
    SELECT customer_id, sum(amount) AS order_total
    FROM orders GROUP BY customer_id
)
SELECT c.name, pc.order_total
FROM customers c JOIN per_customer pc ON pc.customer_id = c.customer_id
ORDER BY c.name;
-- expect: Ana 52, Ben 75

DROP SCHEMA sqlfp CASCADE;
