-- ============================================================================
-- JSONB patterns & GIN indexing
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/10_jsonb_patterns_and_gin/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE events (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type        text NOT NULL,
    occurred_at timestamptz NOT NULL,
    payload     jsonb NOT NULL DEFAULT '{}',
    CONSTRAINT payload_is_object CHECK (jsonb_typeof(payload) = 'object')
);
INSERT INTO events (type, occurred_at, payload) VALUES
    ('page_view', TIMESTAMPTZ '2024-03-01 10:00+00', '{"path":"/pricing","referrer":"google"}'),
    ('page_view', TIMESTAMPTZ '2024-03-01 10:05+00', '{"path":"/docs"}'),
    ('purchase',  TIMESTAMPTZ '2024-03-01 11:00+00', '{"amount":49,"currency":"EUR","items":["lamp"]}'),
    ('signup',    TIMESTAMPTZ '2024-03-02 09:00+00', '{"plan":"pro","source":"referral"}');

-- ==== Promoted column + expression index ========================
CREATE INDEX ON events (type, occurred_at);
CREATE INDEX ON events (((payload ->> 'amount')::numeric));
ANALYZE events;

SELECT id, payload ->> 'currency' AS ccy, (payload ->> 'amount')::numeric AS amount
FROM events
WHERE type = 'purchase' AND (payload ->> 'amount')::numeric > 20;
-- expect: id 3, EUR, 49

EXPLAIN SELECT id FROM events WHERE type = 'purchase' AND (payload ->> 'amount')::numeric > 20;

-- ==== GIN for containment ======================================
CREATE INDEX ON events USING GIN (payload);
ANALYZE events;
SELECT id, type FROM events WHERE payload @> '{"source":"referral"}';
-- expect: id 4, signup
SELECT id FROM events WHERE payload ? 'referrer';
-- expect: id 1
EXPLAIN SELECT id FROM events WHERE payload @> '{"path":"/pricing"}';

-- ==== Per-type shape validation ================================
ALTER TABLE events ADD CONSTRAINT purchase_has_amount
    CHECK (type <> 'purchase' OR (payload ? 'amount' AND jsonb_typeof(payload -> 'amount') = 'number'));

INSERT INTO events (type, occurred_at, payload)
VALUES ('purchase', TIMESTAMPTZ '2024-03-03 12:00+00', '{"amount": 12, "currency": "USD"}');
DO $$ BEGIN
    INSERT INTO events (type, occurred_at, payload)
    VALUES ('purchase', now(), '{"currency": "USD"}');
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'purchase without amount rejected';
END $$;
SELECT count(*) AS purchases FROM events WHERE type = 'purchase';
-- expect: 2

-- ==== Aggregate over a jsonb field ============================
SELECT payload ->> 'path' AS path, count(*) AS views
FROM events WHERE type = 'page_view'
GROUP BY payload ->> 'path' ORDER BY views DESC, path;

DROP SCHEMA sqlfp CASCADE;
