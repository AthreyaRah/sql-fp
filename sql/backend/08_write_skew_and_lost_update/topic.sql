-- ============================================================================
-- Write skew & lost update in practice
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/08_write_skew_and_lost_update/topic.sql
-- Single connection: shows the fixes' mechanics, not a live race.
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE doctors (name text PRIMARY KEY, on_call boolean NOT NULL);
INSERT INTO doctors VALUES ('Alice', true), ('Bob', true);

CREATE TABLE accounts (id text PRIMARY KEY, balance int NOT NULL CHECK (balance >= 0));
INSERT INTO accounts VALUES ('a', 100);

-- ==== Lost update: atomic UPDATE is the fix =====================
UPDATE accounts SET balance = balance - 30 WHERE id = 'a' AND balance >= 30
RETURNING balance;
-- expect: 70

WITH w AS (
    UPDATE accounts SET balance = balance - 90 WHERE id = 'a' AND balance >= 90
    RETURNING balance
)
SELECT count(*) AS applied FROM w;
-- expect: 0 (only 70 left) -> app sees "insufficient funds"

-- ==== Write skew: the invariant as a constraint =================
CREATE TABLE on_call_count (k int PRIMARY KEY DEFAULT 1, n int NOT NULL CHECK (n >= 1));
INSERT INTO on_call_count (n) VALUES (2);

UPDATE on_call_count SET n = n - 1;   -- 2 -> 1 ok
DO $$ BEGIN
    UPDATE on_call_count SET n = n - 1;   -- 1 -> 0
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'last doctor cannot go off call';
END $$;
SELECT n FROM on_call_count;
-- expect: 1

-- ==== Write skew: FOR UPDATE the rows you reason about ==========
BEGIN;
SELECT name FROM doctors WHERE on_call FOR UPDATE;
UPDATE doctors SET on_call = false
WHERE name = 'Alice' AND (SELECT count(*) FROM doctors WHERE on_call) > 1;
COMMIT;
SELECT name, on_call FROM doctors ORDER BY name;
-- expect: Alice false, Bob true

-- ==== SERIALIZABLE detects the cycle (single txn here just shows it runs) ====
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT count(*) FROM doctors WHERE on_call;
COMMIT;

DROP SCHEMA sqlfp CASCADE;
