-- ============================================================================
-- GROUPING SETS, ROLLUP, CUBE
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/13_grouping_sets_rollup_cube/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE sales (region text NOT NULL, category text NOT NULL, amount numeric NOT NULL);
INSERT INTO sales (region, category, amount) VALUES
    ('EU', 'tech', 100),
    ('EU', 'tech',  40),
    ('EU', 'home',  30),
    ('US', 'tech', 200),
    ('US', 'home',  60),
    ('US', 'home',  20);

-- ==== ROLLUP: detail + region subtotals + grand total ================
SELECT region, category, sum(amount) AS total
FROM sales
GROUP BY ROLLUP(region, category)
ORDER BY region NULLS LAST, category NULLS LAST;
-- expect: 7 rows; (EU,NULL,170) (US,NULL,280) (NULL,NULL,450)

-- ==== GROUPING() to label subtotal rows =============================
SELECT
    CASE WHEN GROUPING(region)   = 1 THEN 'ALL' ELSE region   END AS region,
    CASE WHEN GROUPING(category) = 1 THEN 'all' ELSE category END AS category,
    sum(amount) AS total
FROM sales
GROUP BY ROLLUP(region, category)
ORDER BY GROUPING(region), region, GROUPING(category), category;

-- ==== CUBE: every combination ======================================
SELECT region, category, sum(amount) AS total
FROM sales
GROUP BY CUBE(region, category)
ORDER BY region NULLS LAST, category NULLS LAST;
-- expect: 9 rows (adds per-category totals home=110, tech=340)

-- ==== Explicit GROUPING SETS =======================================
SELECT region, category, sum(amount) AS total
FROM sales
GROUP BY GROUPING SETS ((region), (category), ())
ORDER BY region NULLS LAST, category NULLS LAST;
-- expect: 5 rows

-- ==== Hide the grand total with GROUPING() =========================
SELECT region, category, sum(amount) AS total
FROM sales
GROUP BY ROLLUP(region, category)
HAVING GROUPING(region) = 0
ORDER BY region, category NULLS LAST;

DROP SCHEMA sqlfp CASCADE;
