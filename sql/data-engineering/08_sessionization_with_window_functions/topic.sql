-- ============================================================================
-- Sessionization with window functions
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/08_sessionization_with_window_functions/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE events (user_id int NOT NULL, ts timestamptz NOT NULL, page text NOT NULL);
INSERT INTO events (user_id, ts, page) VALUES
    (1, TIMESTAMPTZ '2024-03-01 09:00+00', '/home'),
    (1, TIMESTAMPTZ '2024-03-01 09:05+00', '/pricing'),
    (1, TIMESTAMPTZ '2024-03-01 09:20+00', '/docs'),
    (1, TIMESTAMPTZ '2024-03-01 11:00+00', '/home'),
    (1, TIMESTAMPTZ '2024-03-01 11:10+00', '/checkout'),
    (2, TIMESTAMPTZ '2024-03-01 09:02+00', '/home'),
    (2, TIMESTAMPTZ '2024-03-01 09:40+00', '/blog');

-- ==== Assign session ids ======================================
CREATE VIEW sessioned AS
SELECT user_id, ts, page,
       user_id || '-' || sum(is_new) OVER (PARTITION BY user_id ORDER BY ts) AS session_id
FROM (
    SELECT *,
        CASE WHEN ts - lag(ts) OVER w > INTERVAL '30 min' OR lag(ts) OVER w IS NULL
             THEN 1 ELSE 0 END AS is_new
    FROM events WINDOW w AS (PARTITION BY user_id ORDER BY ts)
) g;

SELECT user_id, ts, session_id FROM sessioned ORDER BY user_id, ts;
-- expect: user 1 -> sessions 1-1 (x3), 1-2 (x2); user 2 -> 2-1, 2-2

-- ==== Session-level metrics ===================================
SELECT session_id,
       count(*)                              AS pageviews,
       max(ts) - min(ts)                     AS duration,
       (array_agg(page ORDER BY ts))[1]      AS entry_page,
       (array_agg(page ORDER BY ts DESC))[1] AS exit_page,
       (count(*) = 1)                        AS bounced
FROM sessioned GROUP BY session_id ORDER BY session_id;
-- expect: 1-1 dur 20min entry /home exit /docs; 1-2 dur 10min entry /home exit /checkout

-- ==== Tune the threshold: 60 min merges user 2's sessions =======
SELECT user_id, count(DISTINCT session_id) AS sessions FROM (
    SELECT user_id, user_id || '-' || sum(is_new) OVER (PARTITION BY user_id ORDER BY ts) AS session_id
    FROM (
        SELECT *, CASE WHEN ts - lag(ts) OVER w > INTERVAL '60 min' OR lag(ts) OVER w IS NULL
                       THEN 1 ELSE 0 END AS is_new
        FROM events WINDOW w AS (PARTITION BY user_id ORDER BY ts)
    ) g
) s GROUP BY user_id ORDER BY user_id;
-- expect: user 1 -> 2, user 2 -> 1

DROP SCHEMA sqlfp CASCADE;
