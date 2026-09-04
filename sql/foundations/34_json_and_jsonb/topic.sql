-- ============================================================================
-- JSON & JSONB
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/34_json_and_jsonb/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE products (id int PRIMARY KEY, name text NOT NULL, attrs jsonb NOT NULL);
INSERT INTO products (id, name, attrs) VALUES
    (1, 'Desk lamp',  '{"category":"home","price":28,"tags":["light","office"],"dims":{"w":12,"h":40}}'),
    (2, 'Notebook',   '{"category":"stationery","price":6,"tags":["paper"],"ruled":true}'),
    (3, 'Headphones', '{"category":"tech","price":75,"tags":["audio","office"],"wireless":true}'),
    (4, 'Mug',        '{"category":"home","price":9,"tags":["kitchen"]}');

-- ==== The operators ============================================
SELECT name,
       attrs -> 'price'              AS price_jsonb,
       attrs ->> 'price'             AS price_text,
       (attrs ->> 'price')::numeric  AS price_num,
       attrs #>> '{dims,h}'          AS height,
       attrs ? 'wireless'            AS has_wireless
FROM products ORDER BY id;

-- ==== The trace: containment + cast ===========================
SELECT name, (attrs ->> 'price')::numeric AS price
FROM products
WHERE attrs @> '{"category":"home"}'
  AND (attrs ->> 'price')::numeric < 20
ORDER BY name;
-- expect: Mug (9)

-- ==== GIN index for @> and ? ==================================
CREATE INDEX idx_attrs ON products USING GIN (attrs);
SELECT name FROM products WHERE attrs @> '{"tags":["office"]}' ORDER BY name;
-- expect: Desk lamp, Headphones
EXPLAIN SELECT name FROM products WHERE attrs @> '{"category":"tech"}';

-- ==== Explode arrays / objects into rows ======================
SELECT p.name, t AS tag
FROM products p, jsonb_array_elements_text(p.attrs -> 'tags') AS t
ORDER BY p.name, tag;

-- ==== Modify a document ======================================
UPDATE products
SET attrs = jsonb_set(attrs, '{price}', to_jsonb((attrs ->> 'price')::numeric * 1.1))
WHERE id = 1
RETURNING name, attrs ->> 'price' AS new_price;
-- expect: 30.8

UPDATE products SET attrs = attrs || '{"clearance": true}' WHERE id = 4;
SELECT attrs ? 'clearance' AS tagged FROM products WHERE id = 4;
-- expect: true

-- ==== Expression index for one hot path =======================
CREATE INDEX idx_price ON products (((attrs ->> 'price')::numeric));
EXPLAIN SELECT name FROM products WHERE (attrs ->> 'price')::numeric > 50;

DROP SCHEMA sqlfp CASCADE;
