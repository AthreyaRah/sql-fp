-- ============================================================================
-- HAVING vs WHERE
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/12_having_vs_where/topic.sql
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
INSERT INTO orders VALUES
    (100, 1, 'paid',      40),
    (101, 1, 'paid',      12),
    (102, 1, 'cancelled', 90),
    (103, 2, 'paid',      75),
    (104, 3, 'paid',       9),
    (105, 3, 'paid',       8);

-- ==== The trace: WHERE (rows) then HAVING (groups) ====================
SELECT customer_id, sum(amount) AS paid_total
FROM orders
WHERE status = 'paid'
GROUP BY customer_id
HAVING sum(amount) > 20
ORDER BY customer_id;
-- expect: (1, 52), (2, 75) -- cust 3's 17 dropped; cust 1's cancelled 90 never counted

-- ==== HAVING with count(*) and multiple aggregates ==================
SELECT customer_id, count(*) AS n, sum(amount) AS total
FROM orders
GROUP BY customer_id
HAVING count(*) >= 2 AND sum(amount) > 40
ORDER BY customer_id;
-- expect: (1, 3, 142)

-- ==== Find duplicates: HAVING count(*) > 1 ==========================
SELECT customer_id, count(*) FROM orders GROUP BY customer_id HAVING count(*) > 1
ORDER BY customer_id;
-- expect: cust 1 (3), cust 3 (2)

-- ==== BREAK: aggregate in WHERE ====================================
-- SELECT customer_id, count(*) FROM orders
-- WHERE status = 'paid' AND count(*) >= 2 GROUP BY customer_id;
--   ERROR: aggregate functions are not allowed in WHERE

DROP SCHEMA sqlfp CASCADE;
