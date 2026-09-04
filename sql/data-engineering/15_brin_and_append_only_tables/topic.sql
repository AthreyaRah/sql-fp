-- ============================================================================
-- BRIN indexes for append-only fact tables
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/15_brin_and_append_only_tables/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE fact_events (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_at timestamptz NOT NULL,
    user_id  int NOT NULL,
    amount   numeric
);
INSERT INTO fact_events (event_at, user_id, amount)
SELECT TIMESTAMPTZ '2024-01-01' + (g || ' minutes')::interval,
       (g % 1000) + 1,
       (g % 200) + 1
FROM generate_series(0, 60000) g;
ANALYZE fact_events;

-- ==== Correlation check =======================================
SELECT attname, round(correlation::numeric, 3) AS correlation
FROM pg_stats
WHERE schemaname = 'sqlfp' AND tablename = 'fact_events' AND attname IN ('event_at', 'user_id')
ORDER BY attname;
-- expect: event_at ~1.0 (correlated), user_id ~0 (scattered)

-- ==== BRIN on the correlated column ==========================
CREATE INDEX idx_brin ON fact_events USING BRIN (event_at);
ANALYZE fact_events;

EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM fact_events
WHERE event_at BETWEEN TIMESTAMPTZ '2024-01-15' AND TIMESTAMPTZ '2024-01-16';

SELECT pg_size_pretty(pg_relation_size('sqlfp.idx_brin'))    AS brin_size,
       pg_size_pretty(pg_relation_size('sqlfp.fact_events')) AS table_size;
-- expect: brin_size tiny relative to table_size

-- ==== BRIN on an uncorrelated column: no pruning =============
CREATE INDEX idx_brin_user ON fact_events USING BRIN (user_id);
ANALYZE fact_events;
EXPLAIN SELECT count(*) FROM fact_events WHERE user_id = 42;
-- expect: Seq Scan (BRIN can exclude nothing)

-- ==== pages_per_range tuning =================================
CREATE INDEX idx_brin_fine ON fact_events USING BRIN (event_at) WITH (pages_per_range = 32);
ANALYZE fact_events;
EXPLAIN SELECT count(*) FROM fact_events
WHERE event_at BETWEEN TIMESTAMPTZ '2024-01-15' AND TIMESTAMPTZ '2024-01-15 06:00';

-- ==== B-tree for point lookups, BRIN for ranges ==============
CREATE INDEX idx_btree_user ON fact_events (user_id);
ANALYZE fact_events;
EXPLAIN SELECT * FROM fact_events WHERE user_id = 42;
-- expect: uses idx_btree_user

DROP SCHEMA sqlfp CASCADE;
