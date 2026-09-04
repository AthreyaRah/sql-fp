-- ============================================================================
-- Numeric precision, money & rounding
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/41_numeric_precision_money_and_rounding/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE line_items (
    id         int PRIMARY KEY,
    qty        int NOT NULL,
    unit_price numeric(12, 2) NOT NULL,
    tax_rate   numeric(5, 4)  NOT NULL
);
INSERT INTO line_items (id, qty, unit_price, tax_rate) VALUES
    (1, 3, 9.99, 0.1900),
    (2, 1, 0.10, 0.0700),
    (3, 7, 2.05, 0.1900);

-- ==== numeric exact, float not ================================
SELECT
    0.1::numeric + 0.2::numeric       AS num_sum,
    0.1::float8  + 0.2::float8        AS float_sum,
    (0.1::float8 + 0.2::float8) = 0.3 AS float_eq_3;
-- expect: 0.3, 0.30000000000000004, false

-- ==== Line total: full precision, round once ==================
SELECT id,
       qty * unit_price                            AS subtotal,
       qty * unit_price * (1 + tax_rate)           AS with_tax_exact,
       round(qty * unit_price * (1 + tax_rate), 2) AS line_total
FROM line_items ORDER BY id;
-- expect line_total: 35.66, 0.11, 17.08

-- ==== round-then-sum vs sum-then-round ========================
WITH per_line AS (
    SELECT round(qty * unit_price * (1 + tax_rate), 2) AS rounded,
           qty * unit_price * (1 + tax_rate)           AS exact
    FROM line_items
)
SELECT sum(rounded) AS sum_of_rounded, round(sum(exact), 2) AS round_of_sum FROM per_line;
-- expect: 52.85 vs 52.85 here, but they can differ

-- ==== Integer division truncates =============================
SELECT 7 / 2 AS int_div, 7 / 2.0 AS one_float, 7::numeric / 2 AS cast_num, 7 % 2 AS rem;
-- expect: 3, 3.5, 3.5, 1

-- ==== Cents as bigint =======================================
CREATE TABLE payments (id int, amount_cents bigint);
INSERT INTO payments VALUES (1, 999), (2, 10), (3, 2050);
SELECT sum(amount_cents) AS total_cents, (sum(amount_cents) / 100.0)::numeric(12, 2) AS total_dollars
FROM payments;
-- expect: 3059, 30.59

-- ==== numeric(p,s) rounds on store, errors on overflow ========
CREATE TABLE t (x numeric(5, 2));
INSERT INTO t VALUES (123.456);   -- rounds to 123.46
SELECT x FROM t;
DO $$ BEGIN
    INSERT INTO t VALUES (12345.67);   -- 7 digits > precision 5
EXCEPTION WHEN numeric_value_out_of_range THEN RAISE NOTICE 'overflow rejected';
END $$;

DROP SCHEMA sqlfp CASCADE;
