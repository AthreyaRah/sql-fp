-- ============================================================================
-- Logical query processing order
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/03_logical_query_processing_order/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE orders (
    order_id    int PRIMARY KEY,
    customer_id int NOT NULL,
    status      text NOT NULL,
    amount      numeric NOT NULL
);

INSERT INTO orders (order_id, customer_id, status, amount) VALUES
    (100, 1, 'paid',      40),
    (101, 1, 'paid',      12),
    (102, 2, 'pending',   75),
    (103, 3, 'paid',       9),
    (104, 3, 'cancelled', 28),
    (106, 1, 'paid',      75),
    (107, 5, 'pending',    6);

-- ==== The full pipeline ==================================================
SELECT customer_id, sum(amount) AS total
FROM orders
WHERE status = 'paid'
GROUP BY customer_id
HAVING sum(amount) > 20
ORDER BY total DESC;
-- expect: 1 row -> customer_id 1, total 127

-- ==== ORDER BY can see the alias 'total' ================================
SELECT customer_id, sum(amount) AS total
FROM orders
GROUP BY customer_id
ORDER BY total DESC;
-- expect: 4 rows, customer 1 first (127)

-- ==== BREAK: WHERE cannot see the alias or the aggregate ================
-- SELECT customer_id, sum(amount) AS total FROM orders
-- WHERE status = 'paid' AND total > 20 GROUP BY customer_id;
--   ERROR: column "total" does not exist
-- SELECT customer_id, sum(amount) FROM orders WHERE sum(amount) > 20 GROUP BY customer_id;
--   ERROR: aggregate functions are not allowed in WHERE

-- ==== ORDER BY a column that is not selected ============================
SELECT order_id FROM orders ORDER BY amount DESC LIMIT 3;
-- expect: 102, 106, 100  (sorted by a column not in the SELECT list)

DROP SCHEMA sqlfp CASCADE;
