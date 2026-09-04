-- ============================================================================
-- Views & materialized views
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/31_views_and_materialized_views/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE orders (
    order_id bigint PRIMARY KEY,
    customer_id int NOT NULL,
    status   text NOT NULL,
    total    numeric NOT NULL,
    created_at date NOT NULL
);
INSERT INTO orders
SELECT g, (g % 1000) + 1,
       (ARRAY['paid', 'pending', 'cancelled'])[1 + (g % 3)],
       (g % 200) + 1,
       DATE '2024-01-01' + (g % 120)
FROM generate_series(1, 20000) g;
ANALYZE orders;

-- ==== A plain VIEW: always current ================================
CREATE VIEW paid_orders AS
SELECT order_id, customer_id, total, created_at FROM orders WHERE status = 'paid';

EXPLAIN SELECT sum(total) FROM paid_orders WHERE created_at >= DATE '2024-04-01';
SELECT count(*) AS n FROM paid_orders;
-- expect: ~6667

-- ==== A MATERIALIZED VIEW: fast but stale =========================
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT created_at AS day, sum(total) AS revenue, count(*) AS orders
FROM orders WHERE status = 'paid' GROUP BY created_at;
CREATE UNIQUE INDEX ON daily_revenue (day);

SELECT revenue FROM daily_revenue WHERE day = DATE '2024-01-02';
INSERT INTO orders VALUES (999999, 5, 'paid', 40, DATE '2024-01-02');
SELECT revenue AS still_stale FROM daily_revenue WHERE day = DATE '2024-01-02';

REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;
SELECT revenue AS refreshed FROM daily_revenue WHERE day = DATE '2024-01-02';

-- ==== Index a matview like a table ===============================
CREATE MATERIALIZED VIEW mv AS
SELECT customer_id, sum(total) AS spent FROM orders WHERE status = 'paid' GROUP BY customer_id;
CREATE INDEX ON mv (spent DESC);
EXPLAIN SELECT * FROM mv ORDER BY spent DESC LIMIT 10;

DROP SCHEMA sqlfp CASCADE;
