-- ============================================================================
-- Grain & measure additivity, in depth
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/04_grain_and_measure_additivity/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

-- grain = one row per order line
CREATE TABLE fact_order_line (
    order_id int, line_no int, date_key int, product_key int,
    qty int, unit_price numeric(10, 2),
    extended numeric(12, 2),   -- qty * unit_price (additive)
    order_ship numeric(10, 2)  -- per-ORDER shipping, repeated per line
);
INSERT INTO fact_order_line VALUES
    (100, 1, 20240101, 10, 2, 6.00,  12.00, 5.00),
    (100, 2, 20240101, 12, 1, 9.00,   9.00, 5.00),
    (101, 1, 20240102, 14, 1, 75.00, 75.00, 8.00);

CREATE TABLE fact_inventory (date_key int, product_key int, on_hand int);
INSERT INTO fact_inventory VALUES
    (20240101, 10, 100), (20240101, 12, 40),
    (20240102, 10,  92), (20240102, 12, 55);

-- ==== Additive vs mixed-grain =================================
SELECT date_key, sum(extended) AS revenue FROM fact_order_line GROUP BY date_key ORDER BY date_key;
-- expect: 20240101 -> 21, 20240102 -> 75

SELECT date_key, sum(order_ship) AS shipping_wrong FROM fact_order_line GROUP BY date_key ORDER BY date_key;
-- expect: 20240101 -> 10 (WRONG: order 100's 5.00 counted twice)

SELECT date_key, sum(order_ship) AS shipping_right FROM (
    SELECT DISTINCT order_id, date_key, order_ship FROM fact_order_line
) o GROUP BY date_key ORDER BY date_key;
-- expect: 20240101 -> 5, 20240102 -> 8

-- ==== Non-additive: recompute ================================
SELECT round(avg(unit_price), 2)          AS wrong_avg_of_prices,
       round(sum(extended) / sum(qty), 2) AS right_weighted_avg
FROM fact_order_line;
-- expect: 30.00 vs 24.00

-- ==== Semi-additive: inventory ==============================
SELECT product_key, sum(on_hand) AS nonsense FROM fact_inventory GROUP BY product_key ORDER BY product_key;
-- expect: 192, 95 -- meaningless across time

SELECT DISTINCT ON (product_key) product_key, date_key, on_hand
FROM fact_inventory ORDER BY product_key, date_key DESC;
-- expect: latest snapshot per product (10 -> 92, 12 -> 55)

SELECT date_key, sum(on_hand) AS total_units FROM fact_inventory GROUP BY date_key ORDER BY date_key;
-- expect: SUM across products on one day is fine (140, 147)

DROP SCHEMA sqlfp CASCADE;
