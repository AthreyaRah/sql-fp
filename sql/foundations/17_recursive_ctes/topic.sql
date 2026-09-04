-- ============================================================================
-- Recursive CTEs: hierarchies & graphs
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/17_recursive_ctes/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE employees (
    employee_id int PRIMARY KEY,
    name        text NOT NULL,
    manager_id  int REFERENCES employees (employee_id)
);
INSERT INTO employees (employee_id, name, manager_id) VALUES
    (1, 'Root',   NULL),
    (2, 'Mara',   1),
    (3, 'Nikhil', 1),
    (4, 'Omar',   2),
    (5, 'Priya',  2),
    (6, 'Quinn',  4);

-- ==== Walk up: Quinn -> Root ========================================
WITH RECURSIVE chain AS (
    SELECT employee_id, name, manager_id, 1 AS depth
    FROM employees WHERE employee_id = 6
    UNION ALL
    SELECT e.employee_id, e.name, e.manager_id, c.depth + 1
    FROM employees e JOIN chain c ON e.employee_id = c.manager_id
)
SELECT depth, name FROM chain ORDER BY depth;
-- expect: 1 Quinn, 2 Omar, 3 Mara, 4 Root

-- ==== Walk down: everyone under Mara ================================
WITH RECURSIVE tree AS (
    SELECT employee_id, name, 0 AS depth, name::text AS path
    FROM employees WHERE name = 'Mara'
    UNION ALL
    SELECT e.employee_id, e.name, t.depth + 1, t.path || ' > ' || e.name
    FROM employees e JOIN tree t ON e.manager_id = t.employee_id
    WHERE t.depth < 20
)
SELECT repeat('  ', depth) || name AS org, path FROM tree ORDER BY path;
-- expect: Mara, Mara > Omar, Mara > Omar > Quinn, Mara > Priya

-- ==== Number series ================================================
WITH RECURSIVE n(i) AS (
    SELECT 1
    UNION ALL
    SELECT i + 1 FROM n WHERE i < 10
)
SELECT i, i * i AS square FROM n;
-- expect: 10 rows, 1..10

-- ==== Cycle-safe walk with UNION (dedupes) =========================
WITH RECURSIVE tree AS (
    SELECT employee_id, manager_id FROM employees WHERE employee_id = 1
    UNION
    SELECT e.employee_id, e.manager_id
    FROM employees e JOIN tree t ON e.manager_id = t.employee_id
)
SELECT count(*) AS reachable FROM tree;
-- expect: 6

DROP SCHEMA sqlfp CASCADE;
