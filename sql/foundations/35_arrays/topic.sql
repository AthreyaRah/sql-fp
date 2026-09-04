-- ============================================================================
-- Arrays
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/35_arrays/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE posts (id int PRIMARY KEY, title text NOT NULL, tags text[] NOT NULL DEFAULT '{}');
INSERT INTO posts (id, title, tags) VALUES
    (1, 'Indexing basics',  ARRAY['sql', 'postgres', 'index']),
    (2, 'Window functions', ARRAY['sql', 'postgres']),
    (3, 'Kafka intro',      ARRAY['kafka', 'streaming']),
    (4, 'Untagged draft',   '{}');

-- ==== Indexing, slicing, ANY ==================================
SELECT title,
       tags[1]               AS first_tag,
       tags[2:3]             AS middle,
       array_length(tags, 1) AS n_tags,
       'sql' = ANY (tags)    AS is_sql
FROM posts ORDER BY id;
-- expect: tags[0] would be NULL; indexing is 1-based

-- ==== Containment & overlap (GIN) ============================
CREATE INDEX idx_tags ON posts USING GIN (tags);
SELECT title FROM posts WHERE tags @> ARRAY['sql', 'postgres'] ORDER BY id;
-- expect: Indexing basics, Window functions
SELECT title FROM posts WHERE tags && ARRAY['kafka', 'sql'] ORDER BY id;
-- expect: Indexing basics, Window functions, Kafka intro
EXPLAIN SELECT title FROM posts WHERE tags @> ARRAY['postgres'];

-- ==== unnest <-> array_agg ===================================
SELECT tag, count(*) AS posts
FROM posts, unnest(tags) AS tag
GROUP BY tag ORDER BY posts DESC, tag;
-- expect: postgres 2, sql 2, index 1, kafka 1, streaming 1

SELECT array_agg(DISTINCT tag ORDER BY tag) AS all_tags
FROM posts, unnest(tags) AS tag;
-- expect: {index,kafka,postgres,sql,streaming}

-- ==== Array vs junction table ================================
CREATE TABLE post_tags AS SELECT id AS post_id, unnest(tags) AS tag FROM posts;
SELECT p.title FROM posts p JOIN post_tags pt ON pt.post_id = p.id WHERE pt.tag = 'sql' ORDER BY p.id;
-- expect: Indexing basics, Window functions

-- ==== Element mutation ======================================
UPDATE posts SET tags = array_append(tags, 'featured') WHERE id = 4;
UPDATE posts SET tags = array_remove(tags, 'index') WHERE id = 1;
SELECT id, tags FROM posts ORDER BY id;

DROP SCHEMA sqlfp CASCADE;
