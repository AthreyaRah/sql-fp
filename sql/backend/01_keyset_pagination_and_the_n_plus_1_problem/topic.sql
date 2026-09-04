-- ============================================================================
-- Keyset pagination & the N+1 problem
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/01_keyset_pagination_and_the_n_plus_1_problem/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE authors (author_id int PRIMARY KEY, name text NOT NULL);
CREATE TABLE posts (
    post_id    bigint PRIMARY KEY,
    author_id  int NOT NULL REFERENCES authors (author_id),
    title      text NOT NULL,
    created_at timestamptz NOT NULL
);
INSERT INTO authors SELECT g, 'author ' || g FROM generate_series(1, 50) g;
INSERT INTO posts
SELECT g, (g % 50) + 1, 'post ' || g,
       TIMESTAMPTZ '2024-01-01' + (g || ' minutes')::interval
FROM generate_series(1, 50000) g;
CREATE INDEX idx_posts_feed ON posts (created_at DESC, post_id DESC);
CREATE INDEX idx_posts_author ON posts (author_id);
ANALYZE authors;
ANALYZE posts;

-- ==== OFFSET cost grows with page number ==========================
EXPLAIN SELECT post_id FROM posts ORDER BY created_at DESC, post_id DESC LIMIT 20 OFFSET 40;
EXPLAIN SELECT post_id FROM posts ORDER BY created_at DESC, post_id DESC LIMIT 20 OFFSET 40000;

-- ==== Keyset page 1, then "next" via a tuple compare ===============
SELECT post_id, created_at FROM posts
ORDER BY created_at DESC, post_id DESC LIMIT 5;

EXPLAIN
SELECT post_id, created_at FROM posts
WHERE (created_at, post_id) < (TIMESTAMPTZ '2024-01-01 13:56:00+00', 49996)
ORDER BY created_at DESC, post_id DESC
LIMIT 5;

-- ==== N+1 shape vs a single join =================================
-- the loop (3 iterations, note the duplicate):
SELECT * FROM authors WHERE author_id = 3;
SELECT * FROM authors WHERE author_id = 3;
SELECT * FROM authors WHERE author_id = 7;

-- one join instead:
SELECT p.post_id, p.title, a.name AS author
FROM posts p JOIN authors a USING (author_id)
ORDER BY p.created_at DESC, p.post_id DESC
LIMIT 20;

-- ==== Batch load: WHERE author_id = ANY(...) =====================
WITH page AS (
    SELECT post_id, author_id, title FROM posts
    ORDER BY created_at DESC, post_id DESC LIMIT 20
)
SELECT count(*) AS authors_fetched
FROM authors WHERE author_id = ANY (SELECT author_id FROM page);

-- ==== Nested shape from SQL =====================================
SELECT a.author_id, a.name,
       json_agg(json_build_object('post_id', p.post_id) ORDER BY p.created_at DESC) AS recent
FROM authors a
JOIN LATERAL (
    SELECT * FROM posts p WHERE p.author_id = a.author_id ORDER BY created_at DESC LIMIT 3
) p ON true
WHERE a.author_id <= 3
GROUP BY a.author_id, a.name
ORDER BY a.author_id;

DROP SCHEMA sqlfp CASCADE;
