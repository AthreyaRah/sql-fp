-- ============================================================================
-- Dimensional modeling: the star schema
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/01_dimensional_modeling_star_schema/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

-- ==== OLTP source (normalized) =====================================
CREATE TABLE customers   (customer_id int PRIMARY KEY, name text, city text, country text);
CREATE TABLE products    (product_id int PRIMARY KEY, name text, category text, unit_price numeric);
CREATE TABLE orders      (order_id int PRIMARY KEY, customer_id int, ordered_at date);
CREATE TABLE order_lines (order_id int, product_id int, qty int, PRIMARY KEY (order_id, product_id));

INSERT INTO customers VALUES
    (1, 'Ana', 'Berlin', 'DE'), (2, 'Ben', 'Berlin', 'DE'), (3, 'Chidi', 'Lagos', 'NG');
INSERT INTO products VALUES
    (10, 'Notebook', 'stationery', 6), (11, 'Desk lamp', 'home', 28), (12, 'Mug', 'home', 9);
INSERT INTO orders VALUES
    (100, 1, DATE '2024-01-05'), (101, 2, DATE '2024-01-05'),
    (102, 1, DATE '2024-02-11'), (103, 3, DATE '2024-02-11');
INSERT INTO order_lines VALUES
    (100, 10, 2), (100, 12, 1), (101, 11, 1), (102, 12, 3), (103, 10, 1), (103, 11, 1);

-- ==== Dimensions (denormalized, surrogate keys) ====================
CREATE TABLE dim_customer (
    customer_key int PRIMARY KEY, customer_id int NOT NULL,
    name text, city text, country text
);
INSERT INTO dim_customer
SELECT 500 + customer_id, customer_id, name, city, country FROM customers;

CREATE TABLE dim_product (
    product_key int PRIMARY KEY, product_id int NOT NULL, name text, category text
);
INSERT INTO dim_product SELECT 700 + product_id, product_id, name, category FROM products;

CREATE TABLE dim_date (
    date_key int PRIMARY KEY, d date NOT NULL,
    year int, month int, month_name text, weekday text
);
INSERT INTO dim_date
SELECT to_char(d, 'YYYYMMDD')::int, d,
       extract(year from d)::int, extract(month from d)::int,
       to_char(d, 'Mon'), to_char(d, 'Dy')
FROM generate_series(DATE '2024-01-01', DATE '2024-03-31', INTERVAL '1 day') g (d);

-- ==== Fact table at order-line grain =============================
CREATE TABLE fact_sales AS
SELECT to_char(o.ordered_at, 'YYYYMMDD')::int AS date_key,
       dc.customer_key,
       dp.product_key,
       ol.qty,
       ol.qty * p.unit_price AS revenue
FROM order_lines ol
JOIN orders   o  ON o.order_id   = ol.order_id
JOIN products p  ON p.product_id = ol.product_id
JOIN dim_customer dc ON dc.customer_id = o.customer_id
JOIN dim_product  dp ON dp.product_id  = ol.product_id;

SELECT * FROM fact_sales ORDER BY date_key, customer_key, product_key;
-- expect: 6 rows, total revenue 110

-- ==== The payoff: slice by any dimension ==========================
SELECT c.city, p.category, sum(f.revenue) AS revenue, sum(f.qty) AS units
FROM fact_sales f
JOIN dim_customer c USING (customer_key)
JOIN dim_product  p USING (product_key)
GROUP BY ROLLUP (c.city, p.category)
ORDER BY c.city NULLS LAST, p.category NULLS LAST;

-- ==== Non-additive measure: derive, don't store ==================
SELECT sum(revenue) AS revenue, sum(qty) AS units,
       round(sum(revenue) / sum(qty), 2) AS avg_unit_price
FROM fact_sales;
-- expect: 110 / 8 -> 13.75

DROP SCHEMA sqlfp CASCADE;
