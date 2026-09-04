-- ============================================================================
-- EXISTS vs IN vs JOIN for existence checks
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/09_exists_vs_in_vs_join/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE products (id int PRIMARY KEY, name text NOT NULL, price numeric NOT NULL);
CREATE TABLE reviews (
    id int PRIMARY KEY, product_id int, rating int NOT NULL CHECK (rating BETWEEN 1 AND 5)
);
INSERT INTO products VALUES (1, 'Lamp', 28), (2, 'Mug', 9), (3, 'Cable', 8), (4, 'Notebook', 6);
INSERT INTO reviews VALUES (10, 1, 5), (11, 1, 4), (12, 1, 3), (13, 2, 5), (14, NULL, 2);

-- ==== Three ways, same rows ====================================
SELECT name FROM products p
WHERE EXISTS (SELECT 1 FROM reviews r WHERE r.product_id = p.id) ORDER BY name;
-- expect: Lamp, Mug

SELECT name FROM products WHERE id IN (SELECT product_id FROM reviews) ORDER BY name;
-- expect: Lamp, Mug

SELECT DISTINCT p.name FROM products p JOIN reviews r ON r.product_id = p.id ORDER BY p.name;
-- expect: Lamp, Mug

-- ==== The fan-out bug ==========================================
SELECT count(*) AS inflated_count FROM products p JOIN reviews r ON r.product_id = p.id;
-- expect: 4 (not 2 -- Lamp counted 3x)
SELECT sum(p.price) AS inflated_sum FROM products p JOIN reviews r ON r.product_id = p.id;
-- expect: 28*3 + 9 = 93 (not 37)

-- ==== When you want child data: JOIN + GROUP BY =================
SELECT p.name, count(r.id) AS n_reviews, round(avg(r.rating), 2) AS avg_rating
FROM products p LEFT JOIN reviews r ON r.product_id = p.id
GROUP BY p.name ORDER BY p.name;

-- ==== NOT: the asymmetry ======================================
SELECT name FROM products p
WHERE NOT EXISTS (SELECT 1 FROM reviews r WHERE r.product_id = p.id) ORDER BY name;
-- expect: Cable, Notebook

SELECT count(*) AS not_in_rows FROM products WHERE id NOT IN (SELECT product_id FROM reviews);
-- expect: 0 (NULL in the subquery poisons NOT IN)

-- ==== EXISTS plans as a semi-join =============================
CREATE INDEX ON reviews (product_id);
ANALYZE reviews;
EXPLAIN SELECT name FROM products p
WHERE EXISTS (SELECT 1 FROM reviews r WHERE r.product_id = p.id);

DROP SCHEMA sqlfp CASCADE;
