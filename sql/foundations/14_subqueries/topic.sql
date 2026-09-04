-- ============================================================================
-- Subqueries: scalar, row, table
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/14_subqueries/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE products (
    product_id int PRIMARY KEY,
    name       text NOT NULL,
    category   text NOT NULL,
    price      numeric NOT NULL
);
INSERT INTO products VALUES
    (10, 'Notebook',   'stationery',  6),
    (11, 'Pen pack',   'stationery',  4),
    (12, 'Desk lamp',  'home',       28),
    (13, 'Mug',        'home',        9),
    (14, 'Headphones', 'tech',       75),
    (15, 'USB cable',  'tech',        8);

-- ==== Scalar subquery in WHERE (avg = 21.67) =========================
SELECT name, price FROM products
WHERE price > (SELECT avg(price) FROM products)
ORDER BY price;
-- expect: Desk lamp (28), Headphones (75)

-- ==== Scalar subquery in the SELECT list ============================
SELECT name, price, price - (SELECT avg(price) FROM products) AS vs_avg
FROM products ORDER BY vs_avg;

-- ==== Table subquery in FROM =======================================
SELECT t.category, t.avg_price
FROM (SELECT category, avg(price) AS avg_price FROM products GROUP BY category) AS t
WHERE t.avg_price > 10
ORDER BY t.avg_price DESC;
-- expect: tech (41.5), home (18.5)

-- ==== Table subquery with IN ======================================
SELECT name, category FROM products
WHERE category IN (SELECT category FROM products GROUP BY category HAVING count(*) >= 2)
ORDER BY category, name;
-- expect: all 6 (each category has 2)

-- ==== Row subquery ================================================
SELECT name, category, price FROM products
WHERE (category, price) = (
    SELECT category, max(price) FROM products WHERE category = 'tech' GROUP BY category
);
-- expect: Headphones, tech, 75

-- ==== BREAK: scalar context fed multiple rows ======================
-- SELECT name FROM products
-- WHERE price = (SELECT max(price) FROM products GROUP BY category);
--   ERROR: more than one row returned by a subquery used as an expression

-- ==== Fix: correlated ============================================
SELECT name FROM products p
WHERE price = (SELECT max(p2.price) FROM products p2 WHERE p2.category = p.category)
ORDER BY name;
-- expect: Desk lamp, Headphones, Notebook

DROP SCHEMA sqlfp CASCADE;
