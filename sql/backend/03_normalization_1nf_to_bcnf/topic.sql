-- ============================================================================
-- Normalization: 1NF to BCNF (and when to stop)
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/03_normalization_1nf_to_bcnf/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE orders_flat (
    order_id      int,
    customer_id   int,
    customer_name text,
    customer_city text,
    product_ids   text,
    product_names text,
    status_code   int,
    status_label  text
);
INSERT INTO orders_flat VALUES
    (100, 1, 'Ana', 'Berlin', '10,13', 'Lamp,Mug',   1, 'paid'),
    (101, 1, 'Ana', 'Berlin', '14',    'Headphones', 2, 'pending'),
    (102, 2, 'Ben', 'Lagos',  '13',    'Mug',        1, 'paid');

-- ==== Decompose to 3NF ==========================================
CREATE TABLE customers (
    customer_id int PRIMARY KEY, name text NOT NULL, city text NOT NULL
);
INSERT INTO customers
SELECT DISTINCT customer_id, customer_name, customer_city FROM orders_flat;

CREATE TABLE statuses (status_id int PRIMARY KEY, label text NOT NULL UNIQUE);
INSERT INTO statuses SELECT DISTINCT status_code, status_label FROM orders_flat;

CREATE TABLE orders (
    order_id    int PRIMARY KEY,
    customer_id int NOT NULL REFERENCES customers (customer_id),
    status_id   int NOT NULL REFERENCES statuses (status_id)
);
INSERT INTO orders SELECT DISTINCT order_id, customer_id, status_code FROM orders_flat;

CREATE TABLE order_items (
    order_id   int NOT NULL REFERENCES orders (order_id),
    product_id int NOT NULL,
    PRIMARY KEY (order_id, product_id)
);
INSERT INTO order_items
SELECT o.order_id, unnest(string_to_array(o.product_ids, ','))::int
FROM orders_flat o;

SELECT * FROM order_items ORDER BY order_id, product_id;
-- expect: 4 rows

-- ==== Reconstruct the flat shape with a join ====================
SELECT o.order_id, c.city, s.label AS status
FROM orders o
JOIN customers c USING (customer_id)
JOIN statuses  s USING (status_id)
ORDER BY o.order_id;
-- expect: 100 Berlin paid, 101 Berlin pending, 102 Lagos paid

-- ==== The anomaly: one update vs many ===========================
UPDATE customers SET city = 'Munich' WHERE customer_id = 1;   -- ONE row
SELECT city FROM customers WHERE customer_id = 1;              -- unambiguous
-- vs. orders_flat, where you'd have to update every one of Ana's rows

SELECT count(DISTINCT city) AS distinct_cities_for_ana FROM customers WHERE customer_id = 1;
-- expect: 1 (can never be 2)

DROP SCHEMA sqlfp CASCADE;
