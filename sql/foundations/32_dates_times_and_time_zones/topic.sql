-- ============================================================================
-- Dates, times, intervals & time zones
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/32_dates_times_and_time_zones/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;
SET timezone = 'UTC';

CREATE TABLE events (id int PRIMARY KEY, name text NOT NULL, at timestamptz NOT NULL);
INSERT INTO events (id, name, at) VALUES
    (1, 'login',    TIMESTAMPTZ '2024-03-10 23:30:00+00'),
    (2, 'view',     TIMESTAMPTZ '2024-03-11 00:15:00+00'),
    (3, 'purchase', TIMESTAMPTZ '2024-03-11 08:45:00+00'),
    (4, 'logout',   TIMESTAMPTZ '2024-03-11 21:05:00+00'),
    (5, 'login',    TIMESTAMPTZ '2024-03-12 06:00:00+00');

-- ==== Berlin-day vs UTC-day rollup ================================
SELECT
    date_trunc('day', at AT TIME ZONE 'Europe/Berlin')::date AS berlin_day,
    date_trunc('day', at)::date                              AS utc_day,
    count(*)
FROM events
GROUP BY 1, 2
ORDER BY 1;
-- expect: Berlin puts event 1 on 2024-03-11 (00:30 local), UTC puts it on 2024-03-10

-- ==== Same instant, three notations ==============================
SELECT
    TIMESTAMPTZ '2024-03-11 08:45:00+00' = TIMESTAMPTZ '2024-03-11 03:45:00-05' AS same,
    TIMESTAMPTZ '2024-03-11 08:45:00+00' AT TIME ZONE 'Asia/Tokyo' AS tokyo_wall,
    TIMESTAMPTZ '2024-03-11 08:45:00+00' AT TIME ZONE 'UTC'        AS utc_wall;
-- expect: same = true; tokyo_wall = 2024-03-11 17:45:00

-- ==== Interval arithmetic + half-open range =======================
SELECT name, at,
       at + INTERVAL '90 minutes'        AS plus_90m,
       age(TIMESTAMPTZ '2024-04-01', at) AS how_long_ago
FROM events
WHERE at >= TIMESTAMPTZ '2024-03-11 00:00+00'
  AND at <  TIMESTAMPTZ '2024-03-12 00:00+00'
ORDER BY at;
-- expect: 3 rows (view, purchase, logout)

-- ==== Gap filling with generate_series + LEFT JOIN ================
SELECT d::date AS day, count(e.id) AS events
FROM generate_series(DATE '2024-03-10', DATE '2024-03-12', INTERVAL '1 day') g (d)
LEFT JOIN events e ON e.at >= d AND e.at < d + INTERVAL '1 day'
GROUP BY d
ORDER BY d;
-- expect: 2024-03-10 -> 1, 2024-03-11 -> 3, 2024-03-12 -> 1 (UTC buckets)

-- ==== DST: '1 day' respects the calendar, '24 hours' is exact ======
SELECT
    TIMESTAMPTZ '2024-03-30 12:00+01' + INTERVAL '1 day'   AS plus_1_day,   -- CET->CEST that night
    TIMESTAMPTZ '2024-03-30 12:00+01' + INTERVAL '24 hours' AS plus_24_hours;

DROP SCHEMA sqlfp CASCADE;
