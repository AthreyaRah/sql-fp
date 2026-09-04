-- ============================================================================
-- shop_schema.sql — the shared toy dataset
-- ----------------------------------------------------------------------------
-- A deliberately tiny online shop: five tables, ~a dozen rows each, all values
-- fixed (no random, no now()). Small enough to hand-trace on paper.
--
-- Most topic scripts do NOT load this — they create their own 4-6 row tables so
-- the rows match that page's hand-trace exactly. Load this when you want a
-- slightly richer playground:
--
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/_shared/shop_schema.sql
--
-- It builds everything inside schema `shop` and leaves it in place.
-- ============================================================================
\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path = shop;

CREATE TABLE customers (
    customer_id  int PRIMARY KEY,
    name         text NOT NULL,
    city         text NOT NULL,
    signup_date  date NOT NULL
);

INSERT INTO customers (customer_id, name, city, signup_date) VALUES
    (1, 'Ana',    'Berlin',    DATE '2023-01-05'),
    (2, 'Ben',    'Berlin',    DATE '2023-02-11'),
    (3, 'Chidi',  'Lagos',     DATE '2023-02-20'),
    (4, 'Dana',   'Toronto',   DATE '2023-03-02'),
    (5, 'Eve',    'Lagos',     DATE '2023-05-19'),
    (6, 'Farah',  'Cairo',     DATE '2023-07-01');

CREATE TABLE employees (
    employee_id  int PRIMARY KEY,
    name         text NOT NULL,
    manager_id   int REFERENCES employees (employee_id),
    hired        date NOT NULL,
    salary       numeric(9, 2) NOT NULL
);

INSERT INTO employees (employee_id, name, manager_id, hired, salary) VALUES
    (1, 'Root',   NULL, DATE '2019-01-01', 180000),
    (2, 'Mara',   1,    DATE '2020-03-15', 140000),
    (3, 'Nikhil', 1,    DATE '2020-06-01', 138000),
    (4, 'Omar',   2,    DATE '2021-09-20', 110000),
    (5, 'Priya',  2,    DATE '2022-01-10', 105000),
    (6, 'Quinn',  3,    DATE '2022-04-04', 102000);

CREATE TABLE products (
    product_id  int PRIMARY KEY,
    name        text NOT NULL,
    category    text NOT NULL,
    price       numeric(9, 2) NOT NULL
);

INSERT INTO products (product_id, name, category, price) VALUES
    (10, 'Notebook',    'stationery', 6.00),
    (11, 'Pen pack',    'stationery', 4.50),
    (12, 'Desk lamp',   'home',       28.00),
    (13, 'Mug',         'home',       9.00),
    (14, 'Headphones',  'tech',       75.00),
    (15, 'USB cable',   'tech',       8.00);

CREATE TABLE orders (
    order_id     int PRIMARY KEY,
    customer_id  int NOT NULL REFERENCES customers (customer_id),
    status       text NOT NULL CHECK (status IN ('paid', 'pending', 'cancelled')),
    ordered_at   date NOT NULL,
    amount       numeric(9, 2) NOT NULL
);

INSERT INTO orders (order_id, customer_id, status, ordered_at, amount) VALUES
    (100, 1, 'paid',      DATE '2023-06-01', 40.00),
    (101, 1, 'paid',      DATE '2023-06-14', 12.00),
    (102, 2, 'pending',   DATE '2023-06-15', 75.00),
    (103, 3, 'paid',      DATE '2023-06-20', 9.00),
    (104, 3, 'cancelled', DATE '2023-06-21', 28.00),
    (105, 4, 'paid',      DATE '2023-07-02', 8.00),
    (106, 1, 'paid',      DATE '2023-07-09', 75.00),
    (107, 5, 'pending',   DATE '2023-07-11', 6.00);

CREATE TABLE order_items (
    order_id    int NOT NULL REFERENCES orders (order_id),
    product_id  int NOT NULL REFERENCES products (product_id),
    quantity    int NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id)
);

INSERT INTO order_items (order_id, product_id, quantity) VALUES
    (100, 12, 1), (100, 13, 1), (100, 15, 1),
    (101, 10, 2),
    (102, 14, 1),
    (103, 13, 1),
    (104, 12, 1),
    (105, 15, 1),
    (106, 14, 1),
    (107, 10, 1);

\echo 'shop schema loaded:  6 customers, 6 employees, 6 products, 8 orders, 10 order_items'
