-- ============================================================================
-- Pivot & unpivot
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/09_pivot_and_unpivot/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE sales_long (region text NOT NULL, month text NOT NULL, revenue numeric NOT NULL);
INSERT INTO sales_long VALUES
    ('EU', 'Jan', 100), ('EU', 'Feb', 120), ('EU', 'Mar', 90),
    ('US', 'Jan', 200), ('US', 'Feb', 210), ('US', 'Mar', 260);

CREATE TABLE sales_wide (region text PRIMARY KEY, jan numeric, feb numeric, mar numeric);
INSERT INTO sales_wide VALUES ('EU', 100, 120, 90), ('US', 200, 210, 260);

-- ==== Pivot: FILTER aggregation ================================
SELECT region,
       sum(revenue) FILTER (WHERE month = 'Jan') AS jan,
       sum(revenue) FILTER (WHERE month = 'Feb') AS feb,
       sum(revenue) FILTER (WHERE month = 'Mar') AS mar,
       sum(revenue)                              AS total
FROM sales_long GROUP BY region ORDER BY region;
-- expect: EU 100/120/90/310, US 200/210/260/670

-- ==== Unpivot: LATERAL VALUES =================================
SELECT w.region, m.month, m.revenue
FROM sales_wide w
CROSS JOIN LATERAL (VALUES ('Jan', w.jan), ('Feb', w.feb), ('Mar', w.mar)) AS m(month, revenue)
ORDER BY w.region, m.month;
-- expect: 6 rows, same as sales_long

-- ==== Dynamic pivot -> jsonb =================================
SELECT region, jsonb_object_agg(month, revenue ORDER BY month) AS by_month
FROM sales_long GROUP BY region ORDER BY region;
-- expect: EU -> {"Feb":120,"Jan":100,"Mar":90}

-- ==== Pivot a count (contingency table) =====================
CREATE TABLE tickets (id int, team text, priority text);
INSERT INTO tickets VALUES (1,'infra','high'),(2,'infra','low'),(3,'infra','high'),(4,'app','low'),(5,'app','high');
SELECT team,
       count(*) FILTER (WHERE priority = 'high') AS high,
       count(*) FILTER (WHERE priority = 'low')  AS low
FROM tickets GROUP BY team ORDER BY team;
-- expect: app 1/1, infra 2/1

-- ==== round-trip: long -> wide -> long matches ==============
WITH wide AS (
    SELECT region,
           sum(revenue) FILTER (WHERE month = 'Jan') AS jan,
           sum(revenue) FILTER (WHERE month = 'Feb') AS feb,
           sum(revenue) FILTER (WHERE month = 'Mar') AS mar
    FROM sales_long GROUP BY region
),
back AS (
    SELECT region, m.month, m.revenue
    FROM wide CROSS JOIN LATERAL (VALUES ('Jan', jan), ('Feb', feb), ('Mar', mar)) AS m(month, revenue)
)
SELECT count(*) AS matched
FROM back JOIN sales_long USING (region, month, revenue);
-- expect: 6

DROP SCHEMA sqlfp CASCADE;
