-- ============================================================================
-- Declarative partitioning & partition pruning
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/14_table_partitioning/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE fact_events (
    id       bigint GENERATED ALWAYS AS IDENTITY,
    event_at timestamptz NOT NULL,
    user_id  int NOT NULL,
    kind     text NOT NULL,
    amount   numeric
) PARTITION BY RANGE (event_at);

CREATE TABLE fact_events_2024_01 PARTITION OF fact_events FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE fact_events_2024_02 PARTITION OF fact_events FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE fact_events_2024_03 PARTITION OF fact_events FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

INSERT INTO fact_events (event_at, user_id, kind, amount)
SELECT TIMESTAMPTZ '2024-01-01' + (g || ' hours')::interval,
       (g % 500) + 1,
       (ARRAY['view', 'click', 'purchase'])[1 + (g % 3)],
       CASE WHEN g % 3 = 2 THEN (g % 100) + 1 END
FROM generate_series(0, 2100) g;
ANALYZE fact_events;

-- ==== Partition pruning ======================================
EXPLAIN SELECT count(*) FROM fact_events WHERE event_at >= TIMESTAMPTZ '2024-03-01';
-- expect: scans only fact_events_2024_03

EXPLAIN SELECT count(*) FROM fact_events WHERE kind = 'purchase';
-- expect: Append over all 3 partitions (no partition-key filter)

SELECT count(*) AS total FROM fact_events;
-- expect: 2101

-- ==== O(1) lifecycle =========================================
DROP TABLE fact_events_2024_01;
SELECT min(event_at)::date AS earliest, count(*) AS after_drop FROM fact_events;
-- expect: earliest 2024-02-01

-- ==== Attach a pre-built partition ===========================
CREATE TABLE fact_events_2024_04 (LIKE fact_events INCLUDING ALL);
INSERT INTO fact_events_2024_04 (event_at, user_id, kind) VALUES (TIMESTAMPTZ '2024-04-05', 1, 'view');
ALTER TABLE fact_events ATTACH PARTITION fact_events_2024_04 FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
SELECT count(*) AS april FROM fact_events WHERE event_at >= TIMESTAMPTZ '2024-04-01';
-- expect: 1

-- ==== PK must include the partition key ======================
DO $$ BEGIN
    ALTER TABLE fact_events ADD PRIMARY KEY (id);
EXCEPTION WHEN others THEN RAISE NOTICE 'PK must include partition key: %', SQLERRM;
END $$;
ALTER TABLE fact_events ADD PRIMARY KEY (id, event_at);
SELECT count(*) FROM fact_events;

DROP SCHEMA sqlfp CASCADE;
