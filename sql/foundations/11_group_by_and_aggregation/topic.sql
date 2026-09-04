-- ============================================================================
-- Aggregation & GROUP BY
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/11_group_by_and_aggregation/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE orders (
    order_id    int PRIMARY KEY,
    customer_id int NOT NULL,
    status      text NOT NULL,
    amount      numeric,
    ordered_at  date NOT NULL
);
INSERT INTO orders (order_id, customer_id, status, amount, ordered_at) VALUES
    (100, 1, 'paid',      40,   DATE '2024-01-05'),
    (101, 1, 'paid',      12,   DATE '2024-01-20'),
    (102, 2, 'paid',      75,   DATE '2024-01-22'),
    (103, 2, 'pending',   NULL, DATE '2024-02-01'),
    (104, 3, 'paid',      NULL, DATE '2024-02-03'),
    (105, 1, 'cancelled', 28,   DATE '2024-02-10');

-- ==== The trace ======================================================
SELECT customer_id, count(*) AS orders, sum(amount) AS total
FROM orders GROUP BY customer_id ORDER BY customer_id;
-- expect: (1,3,80) (2,2,75) (3,1,NULL)

-- ==== count variants + FILTER =======================================
SELECT
    customer_id,
    count(*)                                   AS all_orders,
    count(amount)                              AS with_amount,
    count(*) FILTER (WHERE status = 'paid')    AS paid_orders,
    sum(amount) FILTER (WHERE status = 'paid') AS paid_total
FROM orders GROUP BY customer_id ORDER BY customer_id;

-- ==== Whole table = one group =======================================
SELECT count(*) AS rows, count(DISTINCT customer_id) AS customers,
       min(ordered_at) AS first_order, max(ordered_at) AS last_order
FROM orders;
-- expect: 6, 3, 2024-01-05, 2024-02-10

-- ==== string_agg ===================================================
SELECT customer_id, string_agg(status, ', ' ORDER BY order_id) AS statuses
FROM orders GROUP BY customer_id ORDER BY customer_id;

-- ==== BREAK: non-grouped, non-aggregated column ====================
-- SELECT customer_id, status, sum(amount) FROM orders GROUP BY customer_id;
--   ERROR: column "orders.status" must appear in the GROUP BY clause...

-- ==== Fix: group by both ==========================================
SELECT customer_id, status, sum(amount) AS total
FROM orders GROUP BY customer_id, status ORDER BY customer_id, status;

DROP SCHEMA sqlfp CASCADE;
