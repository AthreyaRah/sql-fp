-- ============================================================================
-- Index types & when each wins
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/28_index_types/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE docs (
    id       bigint PRIMARY KEY,
    owner_id int    NOT NULL,
    status   text   NOT NULL,
    tags     text[] NOT NULL DEFAULT '{}',
    body     jsonb  NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL,
    deleted_at timestamptz
);
INSERT INTO docs (id, owner_id, status, tags, body, created_at, deleted_at)
SELECT g,
       (g % 200) + 1,
       (ARRAY['draft', 'published', 'archived'])[1 + (g % 3)],
       CASE WHEN g % 5 = 0 THEN ARRAY['urgent', 'sql'] ELSE ARRAY['sql'] END,
       jsonb_build_object('words', g % 1000),
       TIMESTAMPTZ '2024-01-01' + (g || ' minutes')::interval,
       CASE WHEN g % 50 = 0 THEN TIMESTAMPTZ '2024-06-01' END
FROM generate_series(1, 30000) AS g;
ANALYZE docs;

-- ==== Partial index ===============================================
CREATE INDEX idx_docs_live ON docs (owner_id, created_at DESC)
    WHERE deleted_at IS NULL AND status = 'published';
ANALYZE docs;
EXPLAIN SELECT id, created_at FROM docs
WHERE owner_id = 7 AND deleted_at IS NULL AND status = 'published'
ORDER BY created_at DESC LIMIT 20;

-- ==== Covering index -> Index Only Scan ===========================
CREATE INDEX idx_cov ON docs (owner_id) INCLUDE (status, created_at);
ANALYZE docs;
EXPLAIN SELECT owner_id, status, created_at FROM docs WHERE owner_id = 7;

-- ==== GIN for arrays and jsonb ===================================
CREATE INDEX idx_tags ON docs USING GIN (tags);
CREATE INDEX idx_body ON docs USING GIN (body jsonb_path_ops);
ANALYZE docs;
EXPLAIN SELECT count(*) FROM docs WHERE tags @> ARRAY['urgent'];
EXPLAIN SELECT count(*) FROM docs WHERE body @> '{"words": 5}';
SELECT count(*) AS urgent FROM docs WHERE tags @> ARRAY['urgent'];
-- expect: 6000

-- ==== Expression index ==========================================
CREATE INDEX idx_words ON docs (((body ->> 'words')::int));
ANALYZE docs;
EXPLAIN SELECT count(*) FROM docs WHERE (body ->> 'words')::int = 5;

-- ==== BRIN ======================================================
CREATE INDEX idx_brin ON docs USING BRIN (created_at);
ANALYZE docs;
EXPLAIN SELECT count(*) FROM docs WHERE created_at > TIMESTAMPTZ '2024-01-15';

DROP SCHEMA sqlfp CASCADE;
