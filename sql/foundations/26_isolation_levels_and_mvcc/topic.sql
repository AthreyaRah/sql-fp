-- ============================================================================
-- Isolation levels & MVCC
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/26_isolation_levels_and_mvcc/topic.sql
-- Single connection: this shows the mechanics, not two sessions racing.
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE seats (seat_id int PRIMARY KEY, held_by text);
INSERT INTO seats VALUES (1, NULL), (2, NULL), (3, 'ana');

-- ==== Current isolation level ======================================
SHOW transaction_isolation;
-- expect: read committed

-- ==== Atomic claim: check + write in one statement =================
UPDATE seats SET held_by = 'me'
WHERE seat_id = (SELECT seat_id FROM seats WHERE held_by IS NULL ORDER BY seat_id LIMIT 1)
RETURNING seat_id;
-- expect: seat 1

-- ==== SELECT ... FOR UPDATE SKIP LOCKED ===========================
BEGIN;
SELECT seat_id FROM seats WHERE held_by IS NULL ORDER BY seat_id
    LIMIT 1 FOR UPDATE SKIP LOCKED;
-- expect: seat 2
UPDATE seats SET held_by = 'you' WHERE seat_id = 2;
COMMIT;
SELECT * FROM seats ORDER BY seat_id;

-- ==== REPEATABLE READ: frozen snapshot ============================
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT count(*) FILTER (WHERE held_by IS NULL) AS free FROM seats;
SELECT count(*) FILTER (WHERE held_by IS NULL) AS free_again FROM seats;
COMMIT;
-- expect: both 0 (all seats taken by now, and consistent within the txn)

-- ==== Optimistic concurrency with a version column ================
CREATE TABLE doc (id int PRIMARY KEY, body text, version int NOT NULL DEFAULT 1);
INSERT INTO doc VALUES (1, 'hello', 1);
UPDATE doc SET body = 'hello world', version = version + 1 WHERE id = 1 AND version = 1
RETURNING version;
-- expect: 2 (a stale writer passing version=1 again would update 0 rows)

DROP SCHEMA sqlfp CASCADE;
