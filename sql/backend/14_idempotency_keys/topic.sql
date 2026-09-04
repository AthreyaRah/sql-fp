-- ============================================================================
-- Idempotency keys & exactly-once writes
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/14_idempotency_keys/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE payments (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id      int NOT NULL,
    amount          numeric NOT NULL,
    idempotency_key text NOT NULL UNIQUE,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE accounts (id int PRIMARY KEY, balance numeric NOT NULL);
INSERT INTO accounts VALUES (1, 100);

-- ==== A charge that is safe to retry ============================
CREATE PROCEDURE charge(p_account int, p_amount numeric, p_key text) LANGUAGE plpgsql AS $$
DECLARE was_new bool;
BEGIN
    INSERT INTO payments (account_id, amount, idempotency_key)
    VALUES (p_account, p_amount, p_key)
    ON CONFLICT (idempotency_key) DO NOTHING;
    GET DIAGNOSTICS was_new = ROW_COUNT;

    IF was_new THEN
        UPDATE accounts SET balance = balance - p_amount WHERE id = p_account;
    END IF;
END $$;

CALL charge(1, 30, 'abc');   -- new: debits
CALL charge(1, 30, 'abc');   -- retry: no-op
CALL charge(1, 30, 'abc');   -- retry: no-op

SELECT count(*) AS payment_rows FROM payments;
-- expect: 1
SELECT balance FROM accounts WHERE id = 1;
-- expect: 70 (charged once)

-- a genuinely different operation uses a different key
CALL charge(1, 10, 'def');
SELECT count(*) AS payment_rows FROM payments;
-- expect: 2
SELECT balance FROM accounts WHERE id = 1;
-- expect: 60

-- ==== Dedup an at-least-once event stream =======================
CREATE TABLE processed_events (event_id text PRIMARY KEY);
CREATE TABLE order_totals (order_id int PRIMARY KEY, total numeric NOT NULL DEFAULT 0);

DO $$
DECLARE i int; is_new bool;
BEGIN
    FOR i IN 1..3 LOOP   -- event 'e1' delivered 3 times
        INSERT INTO processed_events (event_id) VALUES ('e1') ON CONFLICT DO NOTHING;
        GET DIAGNOSTICS is_new = ROW_COUNT;
        IF is_new THEN
            INSERT INTO order_totals (order_id, total) VALUES (5, 10)
            ON CONFLICT (order_id) DO UPDATE SET total = order_totals.total + 10;
        END IF;
    END LOOP;
END $$;

SELECT total FROM order_totals WHERE order_id = 5;
-- expect: 10 (not 30)

DROP SCHEMA sqlfp CASCADE;
