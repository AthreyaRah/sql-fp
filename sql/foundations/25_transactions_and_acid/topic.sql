-- ============================================================================
-- Transactions & ACID
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/25_transactions_and_acid/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE accounts (
    id      text PRIMARY KEY,
    balance numeric NOT NULL CHECK (balance >= 0)
);
INSERT INTO accounts VALUES ('alice', 100), ('bob', 20);

-- ==== Atomic transfer ==============================================
BEGIN;
UPDATE accounts SET balance = balance - 30 WHERE id = 'alice';
UPDATE accounts SET balance = balance + 30 WHERE id = 'bob';
COMMIT;
SELECT * FROM accounts ORDER BY id;
-- expect: alice 70, bob 50

-- ==== Rollback undoes everything ===================================
BEGIN;
UPDATE accounts SET balance = 0 WHERE id = 'alice';
UPDATE accounts SET balance = 999 WHERE id = 'bob';
ROLLBACK;
SELECT * FROM accounts ORDER BY id;
-- expect: alice 70, bob 50 (unchanged)

-- ==== Constraint failure aborts the transaction ===================
DO $$ BEGIN
    UPDATE accounts SET balance = balance - 200 WHERE id = 'alice';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'overdraft rejected, txn rolled back';
END $$;
SELECT * FROM accounts ORDER BY id;
-- expect: alice 70, bob 50

-- ==== Savepoints: partial rollback ================================
BEGIN;
UPDATE accounts SET balance = balance - 30 WHERE id = 'alice';
SAVEPOINT debited;
UPDATE accounts SET balance = balance + 30 WHERE id = 'carol';   -- 0 rows
ROLLBACK TO SAVEPOINT debited;
UPDATE accounts SET balance = balance + 30 WHERE id = 'bob';
COMMIT;
SELECT * FROM accounts ORDER BY id;
-- expect: alice 40, bob 80

DROP SCHEMA sqlfp CASCADE;
