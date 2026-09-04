-- ============================================================================
-- Sorting & limiting: ORDER BY, NULLS, LIMIT/OFFSET
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/05_sorting_and_limiting/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (
    customer_id int PRIMARY KEY,
    name        text NOT NULL,
    city        text,
    signup_date date NOT NULL
);

INSERT INTO customers (customer_id, name, city, signup_date) VALUES
    (1, 'Ana',   'Berlin',  DATE '2023-01-05'),
    (2, 'Ben',   NULL,      DATE '2023-02-11'),
    (3, 'Chidi', 'Lagos',   DATE '2023-02-11'),
    (4, 'Dana',  'Toronto', DATE '2023-03-02'),
    (5, 'Eve',   NULL,      DATE '2023-05-19'),
    (6, 'Farah', 'Cairo',   DATE '2023-07-01');

-- ==== The trace: two sort keys, then OFFSET 1 LIMIT 3 ==================
SELECT customer_id, name, signup_date
FROM customers
ORDER BY signup_date DESC, name ASC
LIMIT 3 OFFSET 1;
-- expect: Eve, Dana, Ben

-- ==== Where NULLs land ================================================
SELECT name, city FROM customers ORDER BY city;              -- NULLs last
SELECT name, city FROM customers ORDER BY city DESC;         -- NULLs first
SELECT name, city FROM customers ORDER BY city ASC NULLS FIRST;

-- ==== Sort by an expression / alias ==================================
SELECT name, length(name) AS len FROM customers ORDER BY len DESC, name;

-- ==== Stable pagination needs a unique last key =======================
SELECT name, signup_date FROM customers
ORDER BY signup_date DESC, customer_id DESC
LIMIT 3;
-- expect: Farah, Eve, Dana

-- ==== BREAK: unstable pagination without a tie-breaker ================
-- SELECT name FROM customers ORDER BY signup_date DESC LIMIT 2 OFFSET 2;
--   Ben/Chidi tie on 2023-02-11; their relative order is undefined -> a page can
--   repeat or skip one of them.

DROP SCHEMA sqlfp CASCADE;
