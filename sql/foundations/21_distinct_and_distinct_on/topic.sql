-- ============================================================================
-- DISTINCT & DISTINCT ON
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/21_distinct_and_distinct_on/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE price_history (product_id int NOT NULL, changed_at date NOT NULL, price numeric NOT NULL);
INSERT INTO price_history (product_id, changed_at, price) VALUES
    (1, DATE '2024-01-01', 10),
    (1, DATE '2024-02-01', 12),
    (1, DATE '2024-03-01', 11),
    (2, DATE '2024-01-15', 50),
    (2, DATE '2024-02-20', 55),
    (3, DATE '2024-01-05',  8);

-- ==== DISTINCT ON: latest price per product ==========================
SELECT DISTINCT ON (product_id) product_id, changed_at, price
FROM price_history
ORDER BY product_id, changed_at DESC;
-- expect: (1, 2024-03-01, 11), (2, 2024-02-20, 55), (3, 2024-01-05, 8)

-- ==== Plain DISTINCT dedupes the whole row ==========================
SELECT DISTINCT product_id FROM price_history ORDER BY product_id;          -- 1,2,3
SELECT DISTINCT product_id, price FROM price_history ORDER BY product_id;   -- 6 rows, not 3

-- ==== count(DISTINCT ...) ==========================================
SELECT count(*) AS rows,
       count(DISTINCT product_id) AS products,
       count(DISTINCT price)      AS distinct_prices
FROM price_history;
-- expect: 6, 3, 6

-- ==== Portable equivalent: row_number() = 1 ========================
SELECT product_id, changed_at, price FROM (
    SELECT *, row_number() OVER (PARTITION BY product_id ORDER BY changed_at DESC) AS rn
    FROM price_history
) s WHERE rn = 1
ORDER BY product_id;

-- ==== BREAK: DISTINCT ON without the ORDER BY prefix ================
-- SELECT DISTINCT ON (product_id) product_id, price FROM price_history ORDER BY changed_at DESC;
--   ERROR: SELECT DISTINCT ON expressions must match initial ORDER BY expressions

DROP SCHEMA sqlfp CASCADE;
