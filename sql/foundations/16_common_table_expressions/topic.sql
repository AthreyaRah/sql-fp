-- ============================================================================
-- Common Table Expressions (WITH)
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/16_common_table_expressions/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE orders (
    order_id int PRIMARY KEY, customer_id int NOT NULL, status text NOT NULL, amount numeric NOT NULL
);
INSERT INTO orders VALUES
    (100,1,'paid',      40),
    (101,1,'paid',      12),
    (102,2,'paid',      75),
    (103,2,'pending',   10),
    (104,3,'paid',       9),
    (105,3,'paid',       8),
    (106,4,'cancelled', 50);

-- ==== Two-step CTE pipeline =========================================
WITH paid AS (
    SELECT customer_id, amount FROM orders WHERE status = 'paid'
),
totals AS (
    SELECT customer_id, sum(amount) AS total FROM paid GROUP BY customer_id
)
SELECT * FROM totals WHERE total > 20 ORDER BY customer_id;
-- expect: (1,52), (2,75)

-- ==== Reuse one CTE twice ==========================================
WITH totals AS (
    SELECT customer_id, sum(amount) AS total
    FROM orders WHERE status = 'paid' GROUP BY customer_id
)
SELECT t.customer_id, t.total,
       (SELECT round(avg(total), 2) FROM totals) AS avg_total
FROM totals t
ORDER BY t.total DESC;

-- ==== Materialization hints ========================================
EXPLAIN
WITH big AS NOT MATERIALIZED (SELECT * FROM orders WHERE amount > 10)
SELECT customer_id, count(*) FROM big GROUP BY customer_id;

EXPLAIN
WITH big AS MATERIALIZED (SELECT * FROM orders WHERE amount > 10)
SELECT customer_id, count(*) FROM big GROUP BY customer_id;

DROP SCHEMA sqlfp CASCADE;
