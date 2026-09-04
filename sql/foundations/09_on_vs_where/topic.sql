-- ============================================================================
-- ON vs WHERE: predicate placement in joins
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/09_on_vs_where/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE customers (customer_id int PRIMARY KEY, name text NOT NULL);
CREATE TABLE orders (
    order_id int PRIMARY KEY, customer_id int, status text NOT NULL, amount numeric NOT NULL
);
INSERT INTO customers VALUES (1, 'Ana'), (2, 'Ben'), (3, 'Chidi');
INSERT INTO orders VALUES
    (100, 1, 'paid',     40),
    (101, 1, 'refunded', 12),
    (102, 2, 'paid',     75);

-- ==== status='paid' in WHERE: Chidi disappears (wrong for this goal) ====
SELECT c.name, coalesce(sum(o.amount), 0) AS paid_total
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status = 'paid'
GROUP BY c.name ORDER BY c.name;
-- expect: Ana 40, Ben 75  (Chidi gone)

-- ==== status='paid' in ON: Chidi kept with 0 (correct) ================
SELECT c.name, coalesce(sum(o.amount), 0) AS paid_total
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'paid'
GROUP BY c.name ORDER BY c.name;
-- expect: Ana 40, Ben 75, Chidi 0

-- ==== On an INNER join the two placements are equivalent ==============
SELECT count(*) FROM customers c JOIN orders o
  ON o.customer_id = c.customer_id WHERE o.status = 'paid';
SELECT count(*) FROM customers c JOIN orders o
  ON o.customer_id = c.customer_id AND o.status = 'paid';
-- expect: both 2

-- ==== A left-side filter belongs in WHERE ============================
SELECT c.name, coalesce(sum(o.amount), 0) AS paid_total
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'paid'
WHERE c.name <> 'Ben'
GROUP BY c.name ORDER BY c.name;
-- expect: Ana 40, Chidi 0

DROP SCHEMA sqlfp CASCADE;
