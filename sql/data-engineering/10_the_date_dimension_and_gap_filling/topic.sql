-- ============================================================================
-- The date dimension & filling time-series gaps
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/10_the_date_dimension_and_gap_filling/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE fact_sales (d date NOT NULL, region text NOT NULL, revenue numeric NOT NULL);
INSERT INTO fact_sales VALUES
    (DATE '2024-03-01', 'EU', 100),
    (DATE '2024-03-01', 'US', 200),
    (DATE '2024-03-03', 'EU', 140),
    (DATE '2024-03-05', 'US', 260);

-- ==== Build dim_date ==========================================
CREATE TABLE dim_date AS
SELECT to_char(d, 'YYYYMMDD')::int          AS date_key,
       d::date                              AS d,
       extract(year from d)::int            AS year,
       extract(quarter from d)::int         AS quarter,
       extract(month from d)::int           AS month,
       to_char(d, 'Mon')                    AS month_name,
       extract(isodow from d)::int          AS iso_dow,
       (extract(isodow from d) >= 6)        AS is_weekend
FROM generate_series(DATE '2024-01-01', DATE '2024-12-31', INTERVAL '1 day') AS g (d);
ALTER TABLE dim_date ADD PRIMARY KEY (date_key);

SELECT count(*) AS days_2024 FROM dim_date;
-- expect: 366 (leap year)

-- ==== Gap fill: EU, every day 03-01..03-05 ====================
SELECT gs.d::date AS d, coalesce(sum(f.revenue), 0) AS revenue
FROM generate_series(DATE '2024-03-01', DATE '2024-03-05', INTERVAL '1 day') AS gs (d)
LEFT JOIN fact_sales f ON f.d = gs.d::date AND f.region = 'EU'
GROUP BY gs.d ORDER BY gs.d;
-- expect: 100, 0, 140, 0, 0

-- ==== Per-group gap fill: every (day, region) ================
WITH days AS (SELECT d::date FROM generate_series(DATE '2024-03-01', DATE '2024-03-05', INTERVAL '1 day') g (d)),
     regions AS (SELECT DISTINCT region FROM fact_sales)
SELECT d, region, coalesce(sum(f.revenue), 0) AS revenue
FROM days CROSS JOIN regions
LEFT JOIN fact_sales f USING (d, region)
GROUP BY d, region ORDER BY d, region;
-- expect: 10 rows (5 days x 2 regions), zeros on quiet (day, region) pairs

-- ==== Report via dim_date, no date functions in the query ======
SELECT dd.month_name, sum(f.revenue) AS revenue
FROM fact_sales f JOIN dim_date dd USING (d)
WHERE dd.iso_dow <= 5
GROUP BY dd.month_name;
-- expect: Mar -> (weekday revenue only)

DROP SCHEMA sqlfp CASCADE;
