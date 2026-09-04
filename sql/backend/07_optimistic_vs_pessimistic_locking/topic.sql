-- ============================================================================
-- Optimistic vs pessimistic locking
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/07_optimistic_vs_pessimistic_locking/topic.sql
-- Single connection: shows the mechanics, not two sessions racing.
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE documents (
    id int PRIMARY KEY, title text NOT NULL, body text NOT NULL, version int NOT NULL DEFAULT 1
);
INSERT INTO documents VALUES (1, 'Draft', 'hello', 1);

CREATE TABLE jobs (id int PRIMARY KEY, status text NOT NULL DEFAULT 'queued', worker text);
INSERT INTO jobs VALUES (1, 'queued', NULL), (2, 'queued', NULL), (3, 'queued', NULL);

-- ==== Optimistic: version check =================================
UPDATE documents SET title = 'A edit', version = version + 1
WHERE id = 1 AND version = 1
RETURNING id, version;
-- expect: 1 row, version 2

WITH b AS (
    UPDATE documents SET title = 'B edit', version = version + 1
    WHERE id = 1 AND version = 1                 -- stale version
    RETURNING id
)
SELECT count(*) AS b_rows_updated FROM b;
-- expect: 0  -> B must reload & retry

SELECT title, version FROM documents;
-- expect: 'A edit', 2

-- ==== Pessimistic: SELECT FOR UPDATE ===========================
BEGIN;
SELECT body FROM documents WHERE id = 1 FOR UPDATE;
UPDATE documents SET body = 'edited under lock' WHERE id = 1;
COMMIT;
SELECT body FROM documents;

-- ==== Job queue: FOR UPDATE SKIP LOCKED ========================
BEGIN;
WITH claimed AS (
    SELECT id FROM jobs WHERE status = 'queued' ORDER BY id LIMIT 1
    FOR UPDATE SKIP LOCKED
)
UPDATE jobs SET status = 'running', worker = 'A'
WHERE id IN (SELECT id FROM claimed)
RETURNING id, worker;
COMMIT;
SELECT id, status, worker FROM jobs ORDER BY id;
-- expect: job 1 running/A, jobs 2-3 queued

-- ==== Trivial increment: neither scheme needed =================
UPDATE documents SET version = version + 1 WHERE id = 1;   -- atomic on its own
SELECT version FROM documents;

DROP SCHEMA sqlfp CASCADE;
