-- ============================================================================
-- Window functions: PARTITION BY & ranking
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/18_window_functions_partitioning_and_ranking/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE scores (player text NOT NULL, game text NOT NULL, points int NOT NULL);
INSERT INTO scores (player, game, points) VALUES
    ('Ana',   'chess', 30),
    ('Ben',   'chess', 30),
    ('Chidi', 'chess', 20),
    ('Dana',  'chess', 10),
    ('Ana',   'go',    12),
    ('Ben',   'go',    25),
    ('Chidi', 'go',    25);

-- ==== Three rankings side by side ==================================
SELECT player, game, points,
       row_number() OVER w AS rn,
       rank()       OVER w AS rnk,
       dense_rank() OVER w AS dense
FROM scores
WINDOW w AS (PARTITION BY game ORDER BY points DESC)
ORDER BY game, points DESC, player;
-- expect chess: (30 rn1 rnk1), (30 rn2 rnk1), (20 rn3 rnk3), (10 rn4 rnk4)

-- ==== Top-2 per game (filter a window result in a subquery) ========
SELECT player, game, points
FROM (
    SELECT player, game, points,
           row_number() OVER (PARTITION BY game ORDER BY points DESC, player) AS rn
    FROM scores
) ranked
WHERE rn <= 2
ORDER BY game, rn;

-- ==== Window aggregate: score vs game average =====================
SELECT player, game, points,
       round(avg(points) OVER (PARTITION BY game), 1) AS game_avg
FROM scores
ORDER BY game, points DESC, player;

-- ==== BREAK: window function in WHERE ============================
-- SELECT player, row_number() OVER (PARTITION BY game ORDER BY points DESC) AS rn
-- FROM scores WHERE rn = 1;   -- ERROR: column "rn" does not exist

-- ==== count(*) OVER () ===========================================
SELECT player, points, count(*) OVER () AS total_rows FROM scores ORDER BY player;

DROP SCHEMA sqlfp CASCADE;
