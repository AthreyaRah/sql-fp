-- ============================================================================
-- Indexes from first principles: the B-tree
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/27_indexes_and_the_b_tree/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE events (
    id         bigint PRIMARY KEY,
    user_id    int    NOT NULL,
    kind       text   NOT NULL,
    created_at timestamptz NOT NULL
);
INSERT INTO events (id, user_id, kind, created_at)
SELECT g,
       (g % 500) + 1,
       (ARRAY['click', 'view', 'purchase', 'signup'])[1 + (g % 4)],
       TIMESTAMPTZ '2024-01-01' + (g || ' minutes')::interval
FROM generate_series(1, 40000) AS g;
ANALYZE events;

-- ==== Before: Seq Scan for user_id = 250 ============================
EXPLAIN SELECT * FROM events WHERE user_id = 250;
-- expect: Seq Scan on events

-- ==== After: Index Scan / Bitmap Heap Scan ==========================
CREATE INDEX idx_events_user ON events (user_id);
ANALYZE events;
EXPLAIN SELECT * FROM events WHERE user_id = 250;
-- expect: an index scan of some form

SELECT count(*) AS rows_for_user_250 FROM events WHERE user_id = 250;
-- expect: 80

-- ==== Non-selective predicate: planner keeps the Seq Scan ===========
CREATE INDEX idx_events_kind ON events (kind);
ANALYZE events;
EXPLAIN SELECT * FROM events WHERE kind = 'click';
-- expect: Seq Scan (kind='click' is ~25% of rows)

-- ==== Range on an indexed timestamp ================================
CREATE INDEX idx_events_created ON events (created_at);
ANALYZE events;
EXPLAIN SELECT count(*) FROM events
WHERE created_at BETWEEN TIMESTAMPTZ '2024-01-01' AND TIMESTAMPTZ '2024-01-02';

-- ==== Composite index: leading-column rule ========================
CREATE INDEX idx_uk ON events (user_id, kind);
ANALYZE events;
EXPLAIN SELECT * FROM events WHERE user_id = 10 AND kind = 'view';  -- can use idx_uk
EXPLAIN SELECT * FROM events WHERE kind = 'view';                    -- cannot use idx_uk

DROP SCHEMA sqlfp CASCADE;
