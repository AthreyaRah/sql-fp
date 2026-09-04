-- ============================================================================
-- Bulk loading: COPY, \copy & staging tables
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/40_bulk_loading_and_copy/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (customer_id int PRIMARY KEY, name text NOT NULL, country text NOT NULL);
INSERT INTO customers VALUES (1, 'Ana', 'DE'), (2, 'Ben', 'NG');

-- ==== COPY FROM STDIN into a loose-typed UNLOGGED staging table ====
CREATE UNLOGGED TABLE stg_customers (customer_id text, name text, country text);

COPY stg_customers (customer_id, name, country) FROM STDIN WITH (FORMAT csv);
3,Chidi,ng
4,Dana,
x,Eve,US
2,Ben Updated,de
\.

SELECT count(*) AS staged FROM stg_customers;
-- expect: 4

-- ==== Validate: which rows are bad? ==============================
SELECT * FROM stg_customers
WHERE customer_id !~ '^\d+$' OR coalesce(trim(country), '') = '';
-- expect: Dana (blank country), Eve (bad id)

-- ==== Transform + load the good rows =============================
INSERT INTO customers (customer_id, name, country)
SELECT customer_id::int, trim(name), upper(trim(country))
FROM stg_customers
WHERE customer_id ~ '^\d+$' AND trim(country) <> ''
ON CONFLICT (customer_id) DO UPDATE
    SET name = EXCLUDED.name, country = EXCLUDED.country;

SELECT * FROM customers ORDER BY customer_id;
-- expect: 1 Ana DE, 2 "Ben Updated" DE, 3 Chidi NG

-- ==== Build-then-index ==========================================
CREATE UNLOGGED TABLE big (id int, v int);
INSERT INTO big SELECT g, g % 100 FROM generate_series(1, 50000) g;
CREATE INDEX ON big (v);
ANALYZE big;
EXPLAIN SELECT count(*) FROM big WHERE v = 7;

-- ==== Export shape (what \copy (...) TO would write) =============
COPY (SELECT * FROM customers ORDER BY customer_id) TO STDOUT WITH (FORMAT csv, HEADER);

DROP SCHEMA sqlfp CASCADE;
