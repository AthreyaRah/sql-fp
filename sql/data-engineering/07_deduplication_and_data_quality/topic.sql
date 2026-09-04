-- ============================================================================
-- Deduplication & data-quality checks
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/07_deduplication_and_data_quality/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE stg_events (
    event_id text, user_id int, kind text, ts timestamptz, amount numeric,
    ingested_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO stg_events (event_id, user_id, kind, ts, amount) VALUES
    ('e1', 1, 'purchase', TIMESTAMPTZ '2024-03-01 10:00+00', 40),
    ('e1', 1, 'purchase', TIMESTAMPTZ '2024-03-01 10:00+00', 40),
    ('e2', 1, 'purchase', TIMESTAMPTZ '2024-03-01 10:00+00', 45),
    ('e3', 2, 'view',     TIMESTAMPTZ '2024-03-01 11:00+00', NULL),
    ('e4', NULL, 'view',  TIMESTAMPTZ '2024-03-01 12:00+00', NULL),
    ('e5', 3, 'purchase', TIMESTAMPTZ '2024-03-01 13:00+00', -10);

-- ==== Dedup: keep one row per event_id ==========================
CREATE VIEW deduped AS
SELECT event_id, user_id, kind, ts, amount, ingested_at FROM (
    SELECT *, row_number() OVER (PARTITION BY event_id ORDER BY ingested_at DESC, ts DESC) AS rn
    FROM stg_events
) d WHERE rn = 1;

SELECT count(*) AS raw FROM stg_events;       -- expect: 6
SELECT count(*) AS deduped FROM deduped;      -- expect: 5

-- ==== Quality battery: each column should be 0 ==================
SELECT
    count(*) FILTER (WHERE user_id IS NULL)                   AS null_user,
    count(*) FILTER (WHERE amount IS NOT NULL AND amount < 0) AS negative_amount,
    count(*) FILTER (WHERE kind NOT IN ('purchase', 'view'))  AS bad_kind,
    count(*) - count(DISTINCT event_id)                       AS dup_keys
FROM deduped;
-- expect: 1, 1, 0, 0

-- ==== Quarantine bad rows ======================================
CREATE TABLE stg_events_rejects (LIKE stg_events, reason text);
INSERT INTO stg_events_rejects
SELECT event_id, user_id, kind, ts, amount, ingested_at,
       CASE WHEN user_id IS NULL THEN 'null user_id'
            WHEN amount < 0       THEN 'negative amount' END
FROM deduped
WHERE user_id IS NULL OR amount < 0;

SELECT event_id, reason FROM stg_events_rejects ORDER BY event_id;
-- expect: e4 null user_id, e5 negative amount

-- ==== Fuzzy dedup on a normalised key ==========================
CREATE TABLE companies (id int, name text);
INSERT INTO companies VALUES (1, 'Acme Inc'), (2, 'ACME, Inc.'), (3, 'Acme  inc'), (4, 'Globex');

SELECT lower(regexp_replace(name, '[^a-z0-9]', '', 'gi')) AS norm_key,
       count(*) AS variants, min(id) AS canonical_id
FROM companies GROUP BY 1 ORDER BY 1;
-- expect: 'acmeinc' -> 3 variants; 'globex' -> 1

DROP SCHEMA sqlfp CASCADE;
