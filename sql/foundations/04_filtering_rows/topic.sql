-- ============================================================================
-- Filtering rows: WHERE, IN, BETWEEN, LIKE, CASE
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/04_filtering_rows/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE products (
    product_id int PRIMARY KEY,
    name       text NOT NULL,
    category   text NOT NULL,
    price      numeric NOT NULL,
    discontinued_on date
);

INSERT INTO products (product_id, name, category, price, discontinued_on) VALUES
    (10, 'Notebook',   'stationery',  6.00, NULL),
    (11, 'Pen pack',   'stationery',  4.50, DATE '2024-02-01'),
    (12, 'Desk lamp',  'home',       28.00, NULL),
    (13, 'Mug',        'home',        9.00, NULL),
    (14, 'Headphones', 'tech',       75.00, NULL),
    (15, 'USB cable',  'tech',        8.00, DATE '2023-11-15');

-- ==== The trace: three ANDed predicates =================================
SELECT product_id, name, category, price
FROM products
WHERE category IN ('home', 'tech')
  AND price BETWEEN 8 AND 30
  AND discontinued_on IS NULL
ORDER BY product_id;
-- expect: Desk lamp (28), Mug (9)

-- ==== LIKE and CASE as expressions =====================================
SELECT
    name,
    price,
    name LIKE '%e%' AS has_e,
    CASE WHEN price < 10 THEN 'cheap'
         WHEN price < 50 THEN 'mid'
         ELSE 'premium' END AS tier
FROM products
ORDER BY price;

-- ==== CASE inside WHERE ================================================
SELECT name, price FROM products
WHERE CASE WHEN category = 'tech' THEN price > 50 ELSE price > 5 END
ORDER BY name;
-- expect: Desk lamp, Headphones, Mug, Notebook

-- ==== BREAK: <> NULL drops the still-sold rows =========================
-- SELECT name FROM products
-- WHERE price < 10 AND discontinued_on <> DATE '1900-01-01';
--   returns only discontinued cheap products; the IS NULL rows vanish

-- ==== Fix ============================================================
SELECT name FROM products
WHERE price < 10 AND discontinued_on IS NULL
ORDER BY name;
-- expect: Mug, Notebook

DROP SCHEMA sqlfp CASCADE;
