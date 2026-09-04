-- ============================================================================
-- Self-joins & CROSS JOIN
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/08_self_joins_and_cross_joins/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE employees (
    employee_id int PRIMARY KEY,
    name        text NOT NULL,
    manager_id  int,
    salary      numeric NOT NULL
);
INSERT INTO employees (employee_id, name, manager_id, salary) VALUES
    (1, 'Root',   NULL, 180000),
    (2, 'Mara',   1,    140000),
    (3, 'Nikhil', 1,    138000),
    (4, 'Omar',   2,    110000),
    (5, 'Priya',  2,    105000);

CREATE TABLE sizes  (size text);
CREATE TABLE colors (color text);
INSERT INTO sizes  VALUES ('S'), ('M'), ('L');
INSERT INTO colors VALUES ('red'), ('blue');

-- ==== Self-join: employee -> manager =================================
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER BY e.employee_id;
-- expect: Root -> NULL; Mara/Nikhil -> Root; Omar/Priya -> Mara

-- ==== Self-join: out-earned same-team colleague ======================
SELECT a.name AS higher, b.name AS lower
FROM employees a
JOIN employees b ON a.manager_id = b.manager_id AND a.salary > b.salary
ORDER BY a.name;
-- expect: Mara > Nikhil; Omar > Priya

-- ==== CROSS JOIN: grid ==============================================
SELECT s.size, c.color FROM sizes s CROSS JOIN colors c ORDER BY s.size, c.color;
-- expect: 6 rows

-- ==== generate_series ==============================================
SELECT d::date AS day
FROM generate_series(DATE '2024-01-01', DATE '2024-01-05', INTERVAL '1 day') AS g(d);
-- expect: 5 rows

-- ==== BREAK: self-join without excluding the diagonal ================
-- SELECT a.name, b.name FROM employees a JOIN employees b
--   ON a.manager_id = b.manager_id;    -- pairs each person with themselves too

-- ==== Fix ==========================================================
SELECT a.name, b.name
FROM employees a JOIN employees b
  ON a.manager_id = b.manager_id AND a.employee_id < b.employee_id
ORDER BY a.name, b.name;
-- expect: each unordered same-team pair once (Mara/Nikhil, Omar/Priya)

DROP SCHEMA sqlfp CASCADE;
