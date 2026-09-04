-- ============================================================================
-- SCD Types 0, 1, 3, 4 & 6
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/05_scd_types_1_3_4_6/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE stg_customer (
    customer_id int PRIMARY KEY, name text NOT NULL, email text NOT NULL,
    city text NOT NULL, tier text NOT NULL
);
INSERT INTO stg_customer VALUES
    (1, 'Ana Ng', 'ana@x.com', 'Berlin', 'gold'),
    (2, 'Ben',    'ben@x.com', 'Lagos',  'silver');

-- ==== Type 1 (overwrite) ======================================
CREATE TABLE dim1 (customer_id int PRIMARY KEY, email text, signup_channel text NOT NULL DEFAULT 'organic');
INSERT INTO dim1 (customer_id, email) SELECT customer_id, email FROM stg_customer;
UPDATE dim1 SET email = 'ana.ng@x.com' WHERE customer_id = 1;   -- old value gone
SELECT customer_id, email FROM dim1 ORDER BY customer_id;
-- expect: 1 -> ana.ng@x.com

-- ==== Type 3 (previous value column) ==========================
CREATE TABLE dim3 (customer_id int PRIMARY KEY, tier text NOT NULL, prev_tier text, tier_changed_at date);
INSERT INTO dim3 SELECT customer_id, tier, NULL, NULL FROM stg_customer;

CREATE PROCEDURE set_tier(p_id int, p_new text, p_date date) LANGUAGE plpgsql AS $$
BEGIN
    UPDATE dim3 SET prev_tier = tier, tier = p_new, tier_changed_at = p_date
    WHERE customer_id = p_id AND tier IS DISTINCT FROM p_new;
END $$;
CALL set_tier(1, 'platinum', DATE '2024-03-01');
CALL set_tier(1, 'diamond',  DATE '2024-06-01');
SELECT customer_id, tier, prev_tier FROM dim3 WHERE customer_id = 1;
-- expect: diamond, platinum  (gold is lost -- only ONE prior value)

-- ==== Type 4 (current in dim, history in side table) ==========
CREATE TABLE dim4 (customer_id int PRIMARY KEY, city text NOT NULL, tier text NOT NULL);
CREATE TABLE dim4_history (customer_id int, attr text, old_value text, new_value text, changed_at date);
INSERT INTO dim4 SELECT customer_id, city, tier FROM stg_customer;

CREATE FUNCTION log_dim_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tier IS DISTINCT FROM OLD.tier THEN
        INSERT INTO dim4_history VALUES (OLD.customer_id, 'tier', OLD.tier, NEW.tier, DATE '2024-03-01');
    END IF;
    IF NEW.city IS DISTINCT FROM OLD.city THEN
        INSERT INTO dim4_history VALUES (OLD.customer_id, 'city', OLD.city, NEW.city, DATE '2024-03-01');
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg AFTER UPDATE ON dim4 FOR EACH ROW EXECUTE FUNCTION log_dim_change();

UPDATE dim4 SET tier = 'platinum', city = 'Munich' WHERE customer_id = 1;
SELECT count(*) AS history_rows FROM dim4_history;
-- expect: 2

-- ==== Type 6 (Type 2 + current_ column) =======================
CREATE TABLE dim6 (
    customer_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id int NOT NULL, tier text NOT NULL, current_tier text NOT NULL,
    valid_from date NOT NULL, valid_to date NOT NULL DEFAULT DATE '9999-12-31',
    is_current boolean NOT NULL DEFAULT true
);
INSERT INTO dim6 (customer_id, tier, current_tier, valid_from)
SELECT customer_id, tier, tier, DATE '2024-01-01' FROM stg_customer;

UPDATE dim6 SET valid_to = DATE '2024-03-01', is_current = false WHERE customer_id = 1 AND is_current;
INSERT INTO dim6 (customer_id, tier, current_tier, valid_from)
VALUES (1, 'platinum', 'platinum', DATE '2024-03-01');
UPDATE dim6 SET current_tier = 'platinum' WHERE customer_id = 1;

SELECT tier, current_tier, is_current FROM dim6 WHERE customer_id = 1 ORDER BY valid_from;
-- expect: (gold, platinum, false), (platinum, platinum, true)

-- "group by current tier" needs no join to is_current:
SELECT current_tier, count(DISTINCT customer_id) AS customers FROM dim6 GROUP BY current_tier ORDER BY current_tier;

DROP SCHEMA sqlfp CASCADE;
