-- ============================================================================
-- OLTP vs OLAP; row stores vs column stores
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/03_oltp_vs_olap_and_columnar/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE fact_sales (
    sale_id      bigint,
    date_key     int,
    product_key  int,
    customer_key int,
    qty          int,
    revenue      numeric(12, 2)
);
INSERT INTO fact_sales
SELECT g,
       20240100 + (g % 90) + 1,
       (g % 40) + 1,
       (g % 500) + 1,
       (g % 5) + 1,
       ((g % 200) + 1)::numeric
FROM generate_series(1, 50000) g;
ANALYZE fact_sales;

-- ==== OLAP-shaped: wide aggregation ============================
EXPLAIN (ANALYZE, BUFFERS) SELECT sum(revenue) FROM fact_sales;

-- ==== OLTP-shaped: one row, the row store's sweet spot =========
CREATE INDEX ON fact_sales (sale_id);
ANALYZE fact_sales;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM fact_sales WHERE sale_id = 42000;

-- ==== revenue is highly compressible (few distinct values) ======
SELECT count(DISTINCT revenue) AS distinct_revenue, count(*) AS rows FROM fact_sales;
-- expect: 200, 50000
SELECT pg_size_pretty(pg_relation_size('sqlfp.fact_sales')) AS row_store_size;

-- ==== Pre-aggregate: 50k row reads -> 90 =======================
CREATE TABLE daily_revenue AS
SELECT date_key, sum(revenue) AS revenue, sum(qty) AS qty
FROM fact_sales GROUP BY date_key;
CREATE UNIQUE INDEX ON daily_revenue (date_key);
ANALYZE daily_revenue;

SELECT count(*) AS days FROM daily_revenue;
-- expect: 90
EXPLAIN SELECT sum(revenue) FROM daily_revenue;

SELECT sum(revenue) = (SELECT sum(revenue) FROM fact_sales) AS totals_match FROM daily_revenue;
-- expect: true

DROP SCHEMA sqlfp CASCADE;
