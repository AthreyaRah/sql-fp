-- ============================================================================
-- Window frames: running totals & moving averages
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/19_window_frames/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE daily_sales (d date NOT NULL, region text NOT NULL, amount numeric NOT NULL);
INSERT INTO daily_sales (d, region, amount) VALUES
    (DATE '2024-01-01', 'EU', 10),
    (DATE '2024-01-02', 'EU', 20),
    (DATE '2024-01-03', 'EU', 20),
    (DATE '2024-01-04', 'EU',  5),
    (DATE '2024-01-05', 'EU', 45),
    (DATE '2024-01-01', 'US', 30),
    (DATE '2024-01-02', 'US', 10);

-- ==== Running total + moving average + day-over-day ==================
SELECT d, amount,
    sum(amount) OVER (PARTITION BY region ORDER BY d
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
    round(avg(amount) OVER (PARTITION BY region ORDER BY d
                      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)     AS mov_avg_3,
    amount - lag(amount) OVER (PARTITION BY region ORDER BY d)          AS dod_change
FROM daily_sales
WHERE region = 'EU'
ORDER BY d;
-- expect running_total: 10, 30, 50, 55, 100

-- ==== ROWS vs RANGE with ties on the sort key =======================
SELECT d, amount,
    sum(amount) OVER (ORDER BY amount ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_sum,
    sum(amount) OVER (ORDER BY amount RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS range_sum
FROM daily_sales WHERE region = 'EU'
ORDER BY amount, d;
-- expect: the two amount=20 rows differ under ROWS, match under RANGE

-- ==== first_value / last_value ====================================
SELECT d, region, amount,
    first_value(amount) OVER (PARTITION BY region ORDER BY d) AS first_day,
    last_value(amount)  OVER (PARTITION BY region ORDER BY d
                              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_day
FROM daily_sales ORDER BY region, d;

DROP SCHEMA sqlfp CASCADE;
