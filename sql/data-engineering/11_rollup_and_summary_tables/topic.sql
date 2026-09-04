-- ============================================================================
-- Rollup & summary tables
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/11_rollup_and_summary_tables/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE fact_order_line (
    order_id int, line_no int, d date NOT NULL, region text NOT NULL, product text NOT NULL,
    qty int NOT NULL, revenue numeric(12, 2) NOT NULL
);
INSERT INTO fact_order_line
SELECT (g / 3) + 1, (g % 3) + 1,
       DATE '2024-03-01' + (g % 10),
       (ARRAY['EU', 'US'])[1 + (g % 2)],
       (ARRAY['lamp', 'mug', 'cable'])[1 + (g % 3)],
       (g % 4) + 1,
       (((g % 4) + 1) * (ARRAY[28, 9, 8])[1 + (g % 3)])::numeric
FROM generate_series(0, 599) g;

-- ==== Build the summary =======================================
CREATE TABLE agg_daily_region (
    d date, region text, revenue numeric, qty int, order_lines int, orders int,
    PRIMARY KEY (d, region)
);
INSERT INTO agg_daily_region
SELECT d, region, sum(revenue), sum(qty), count(*), count(DISTINCT order_id)
FROM fact_order_line GROUP BY d, region;

SELECT count(*) AS summary_rows FROM agg_daily_region;
-- expect: 20 (10 days x 2 regions), vs 600 fact rows

-- ==== Ratios at read time ====================================
SELECT region,
       sum(revenue) AS revenue, sum(qty) AS qty,
       round(sum(revenue) / sum(qty), 2)          AS avg_unit_price,
       round(sum(revenue) / sum(order_lines), 2)  AS avg_line_value
FROM agg_daily_region GROUP BY region ORDER BY region;

-- ==== Incremental refresh: only the changed day ==============
INSERT INTO fact_order_line VALUES (999, 1, DATE '2024-03-11', 'EU', 'lamp', 2, 56);

INSERT INTO agg_daily_region (d, region, revenue, qty, order_lines, orders)
SELECT d, region, sum(revenue), sum(qty), count(*), count(DISTINCT order_id)
FROM fact_order_line WHERE d = DATE '2024-03-11'
GROUP BY d, region
ON CONFLICT (d, region) DO UPDATE
    SET revenue = EXCLUDED.revenue, qty = EXCLUDED.qty,
        order_lines = EXCLUDED.order_lines, orders = EXCLUDED.orders;

SELECT revenue FROM agg_daily_region WHERE d = DATE '2024-03-11' AND region = 'EU';
-- expect: 56

-- ==== Reconcile ============================================
SELECT
    (SELECT sum(revenue) FROM agg_daily_region)   AS summary_total,
    (SELECT sum(revenue) FROM fact_order_line)    AS fact_total,
    (SELECT sum(revenue) FROM agg_daily_region)
        = (SELECT sum(revenue) FROM fact_order_line) AS reconciles;
-- expect: reconciles = true

-- ==== Layer: daily -> monthly ==============================
CREATE TABLE agg_monthly_region AS
SELECT to_char(d, 'YYYY-MM') AS ym, region, sum(revenue) AS revenue, sum(qty) AS qty
FROM agg_daily_region GROUP BY 1, 2;
SELECT sum(revenue) = (SELECT sum(revenue) FROM fact_order_line) AS monthly_reconciles
FROM agg_monthly_region;
-- expect: true

DROP SCHEMA sqlfp CASCADE;
