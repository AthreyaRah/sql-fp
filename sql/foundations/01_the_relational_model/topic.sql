-- ============================================================================
-- The relational model & what a query engine does
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/01_the_relational_model/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

-- ==== Setup: the same rows as the hand-trace ================================
CREATE TABLE customers (
    customer_id int PRIMARY KEY,
    name        text NOT NULL,
    city        text NOT NULL
);

INSERT INTO customers (customer_id, name, city) VALUES
    (1, 'Ana',   'Berlin'),
    (2, 'Ben',   'Berlin'),
    (3, 'Chidi', 'Lagos'),
    (4, 'Dana',  'Toronto');

-- ==== A bag: projection keeps duplicates ===================================
SELECT city FROM customers;
-- expect: 4 rows, 'Berlin' twice

-- ==== A set: DISTINCT collapses duplicates =================================
SELECT DISTINCT city FROM customers ORDER BY city;
-- expect: 3 rows -> Berlin, Lagos, Toronto

-- ==== Closure: the result of a query is a table ============================
SELECT count(*) AS distinct_cities
FROM (SELECT DISTINCT city FROM customers) AS t;
-- expect: 3

-- ==== Declarative: you never said HOW =====================================
EXPLAIN SELECT DISTINCT city FROM customers;
-- expect: a plan (HashAggregate over a Seq Scan on this tiny table)

-- ==== BREAK: relying on row order without ORDER BY =========================
-- SELECT DISTINCT city FROM customers;   -- order is NOT guaranteed; add ORDER BY

DROP SCHEMA sqlfp CASCADE;
