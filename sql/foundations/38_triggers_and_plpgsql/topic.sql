-- ============================================================================
-- Triggers & PL/pgSQL basics
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/38_triggers_and_plpgsql/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE accounts (
    id      int PRIMARY KEY,
    balance numeric NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE account_log (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id int NOT NULL,
    delta      numeric NOT NULL,
    at         timestamptz NOT NULL DEFAULT now()
);
INSERT INTO accounts (id, balance) VALUES (1, 100), (2, 50);

-- ==== BEFORE: stamp updated_at ================================
CREATE FUNCTION touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;
CREATE TRIGGER trg_touch BEFORE UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ==== AFTER: append-only audit log ===========================
CREATE FUNCTION log_balance_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.balance IS DISTINCT FROM OLD.balance THEN
        INSERT INTO account_log (account_id, delta) VALUES (NEW.id, NEW.balance - OLD.balance);
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_log AFTER UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION log_balance_change();

-- ==== BEFORE: reject overdraft ===============================
CREATE FUNCTION no_overdraft() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.balance < 0 THEN
        RAISE EXCEPTION 'overdraft on account % (balance %)', NEW.id, NEW.balance;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION no_overdraft();

-- ==== Exercise the triggers ==================================
UPDATE accounts SET balance = balance + 30 WHERE id = 1;
UPDATE accounts SET balance = balance - 10 WHERE id = 1;
UPDATE accounts SET balance = balance + 5  WHERE id = 2;

SELECT id, balance, (updated_at > TIMESTAMPTZ '2024-01-01') AS touched FROM accounts ORDER BY id;
SELECT account_id, delta FROM account_log ORDER BY id;
-- expect: log rows (1,+30) (1,-10) (2,+5)

DO $$ BEGIN
    UPDATE accounts SET balance = balance - 999 WHERE id = 1;
EXCEPTION WHEN others THEN RAISE NOTICE 'blocked: %', SQLERRM;
END $$;

-- ==== Plain function the app calls ==========================
CREATE FUNCTION transfer(p_from int, p_to int, p_amt numeric) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE accounts SET balance = balance - p_amt WHERE id = p_from;
    UPDATE accounts SET balance = balance + p_amt WHERE id = p_to;
    IF (SELECT balance FROM accounts WHERE id = p_from) < 0 THEN
        RAISE EXCEPTION 'insufficient funds';
    END IF;
END $$;
SELECT transfer(1, 2, 40);
SELECT id, balance FROM accounts ORDER BY id;
-- expect: 1 -> 80, 2 -> 95

DROP SCHEMA sqlfp CASCADE;
