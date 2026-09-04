-- ============================================================================
-- Data types, NULL & three-valued logic
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/02_data_types_null_and_three_valued_logic/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

-- ==== Setup: the same rows as the hand-trace ================================
CREATE TABLE employees (
    employee_id int PRIMARY KEY,
    name        text NOT NULL,
    manager_id  int,        -- NULL = "no manager" (the CEO)
    bonus       numeric     -- NULL = "not decided yet"
);

INSERT INTO employees (employee_id, name, manager_id, bonus) VALUES
    (1, 'Root',   NULL, 5000),
    (2, 'Mara',   1,    2000),
    (3, 'Nikhil', 1,    NULL),
    (4, 'Omar',   2,    NULL),
    (5, 'Priya',  2,    900);

-- ==== The trace: WHERE bonus > 1000 drops the two NULL rows ================
SELECT employee_id, name, bonus FROM employees WHERE bonus > 1000 ORDER BY employee_id;
-- expect: 2 rows (Root, Mara). NULL > 1000 is NULL, which WHERE drops.

-- ==== <> also drops NULLs ================================================
SELECT name, bonus FROM employees WHERE bonus <> 1000 ORDER BY name;
-- expect: Mara(2000), Priya(900) -- Nikhil & Omar dropped even though "unknown <> 1000"

SELECT name, bonus FROM employees WHERE bonus <> 1000 OR bonus IS NULL ORDER BY name;
-- expect: Mara, Nikhil, Omar, Priya

-- ==== IS NULL vs = NULL =================================================
SELECT name, (bonus = NULL) AS eq_null, (bonus IS NULL) AS is_null FROM employees ORDER BY name;
-- expect: eq_null is NULL for every row; is_null is true for Nikhil & Omar

-- ==== NULL-safe comparison, COALESCE, count ==============================
SELECT
    name,
    bonus,
    bonus IS DISTINCT FROM 900 AS distinct_from_900,
    coalesce(bonus, 0)         AS bonus_or_zero
FROM employees ORDER BY name;

SELECT count(bonus) AS non_null_bonuses, count(*) AS all_rows, avg(bonus) AS avg_bonus
FROM employees;
-- expect: 3, 5, 2633.33...  (avg ignores the 2 NULLs)

-- ==== The NOT IN landmine ===============================================
SELECT name FROM employees
WHERE employee_id NOT IN (SELECT manager_id FROM employees);
-- expect: 0 rows -- the subquery contains NULL

-- ==== Fix: NOT EXISTS ==================================================
SELECT e.name FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM employees m WHERE m.manager_id = e.employee_id)
ORDER BY e.name;
-- expect: Nikhil, Omar, Priya

DROP SCHEMA sqlfp CASCADE;
