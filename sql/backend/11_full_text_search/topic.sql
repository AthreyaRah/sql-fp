-- ============================================================================
-- Full-text search: tsvector, tsquery, ranking
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/11_full_text_search/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

-- to_tsvector('english', ...) is STABLE, not IMMUTABLE, so a GENERATED column
-- needs an IMMUTABLE wrapper (safe as long as you don't change the config).
CREATE FUNCTION article_search(title text, body text, tags text[])
RETURNS tsvector LANGUAGE sql IMMUTABLE AS $$
    SELECT setweight(to_tsvector('english', coalesce(title, '')), 'A')
        || setweight(to_tsvector('english', coalesce(body, '')), 'B')
        || setweight(to_tsvector('english', array_to_string(coalesce(tags, '{}'), ' ')), 'C')
$$;

CREATE TABLE articles (
    id    int PRIMARY KEY,
    title text NOT NULL,
    body  text NOT NULL,
    tags  text[] NOT NULL DEFAULT '{}',
    search tsvector GENERATED ALWAYS AS (article_search(title, body, tags)) STORED
);
CREATE INDEX articles_search_idx ON articles USING GIN (search);

INSERT INTO articles (id, title, body, tags) VALUES
    (1, 'Indexing in PostgreSQL', 'A guide to B-tree, GIN and BRIN indexes and how the planner chooses.', ARRAY['postgres','performance']),
    (2, 'Query tuning basics',    'Read EXPLAIN, find the slow node, add an index. Tuning is iterative.', ARRAY['postgres']),
    (3, 'Kafka for beginners',    'Topics, partitions, consumer groups. Streaming data at scale.', ARRAY['kafka','streaming']),
    (4, 'Writing good tests',     'Fast, isolated, deterministic. A test that flakes is worse than none.', ARRAY['testing']);
ANALYZE articles;

-- ==== Match (stemmed) ==========================================
SELECT id, title FROM articles
WHERE search @@ websearch_to_tsquery('english', 'index tuning')
ORDER BY id;
-- expect: id 2

-- ==== Ranking + snippet =======================================
SELECT a.id, a.title,
       round(ts_rank(a.search, q)::numeric, 4) AS rank,
       ts_headline('english', a.body, q, 'StartSel=[, StopSel=]') AS snippet
FROM articles a, websearch_to_tsquery('english', 'index OR tuning') q
WHERE a.search @@ q
ORDER BY rank DESC, a.id;

-- ==== Phrase + exclusion ======================================
SELECT id, title FROM articles
WHERE search @@ websearch_to_tsquery('english', '"consumer groups" -testing');
-- expect: id 3

-- ==== Plan uses the GIN index =================================
EXPLAIN SELECT id FROM articles WHERE search @@ to_tsquery('english', 'index');

DROP SCHEMA sqlfp CASCADE;
