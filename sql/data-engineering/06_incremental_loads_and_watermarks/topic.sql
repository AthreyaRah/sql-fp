-- ============================================================================
-- Incremental loads & watermarks
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/06_incremental_loads_and_watermarks/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE src_orders (
    order_id    int PRIMARY KEY,
    customer_id int NOT NULL,
    amount      numeric NOT NULL,
    updated_at  timestamptz NOT NULL
);
INSERT INTO src_orders VALUES
    (100, 1, 40, TIMESTAMPTZ '2024-03-01 09:00+00'),
    (101, 2, 15, TIMESTAMPTZ '2024-03-01 11:00+00'),
    (102, 1, 90, TIMESTAMPTZ '2024-03-02 08:00+00');

CREATE TABLE dw_orders (
    order_id int PRIMARY KEY, customer_id int NOT NULL, amount numeric NOT NULL,
    updated_at timestamptz NOT NULL, loaded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE load_state (table_name text PRIMARY KEY, watermark timestamptz NOT NULL);
INSERT INTO load_state VALUES ('dw_orders', TIMESTAMPTZ '2000-01-01');

CREATE PROCEDURE load_dw_orders() LANGUAGE plpgsql AS $$
DECLARE wm timestamptz;
BEGIN
    SELECT watermark INTO wm FROM load_state WHERE table_name = 'dw_orders' FOR UPDATE;

    INSERT INTO dw_orders (order_id, customer_id, amount, updated_at)
    SELECT order_id, customer_id, amount, updated_at
    FROM src_orders
    WHERE updated_at > wm - INTERVAL '1 hour'
    ON CONFLICT (order_id) DO UPDATE
        SET amount = EXCLUDED.amount, updated_at = EXCLUDED.updated_at, loaded_at = now();

    UPDATE load_state
    SET watermark = greatest(wm, (SELECT max(updated_at) FROM src_orders))
    WHERE table_name = 'dw_orders';
END $$;

-- ==== Run 1: full load =========================================
CALL load_dw_orders();
SELECT count(*) AS loaded FROM dw_orders;
-- expect: 3
SELECT watermark FROM load_state WHERE table_name = 'dw_orders';
-- expect: 2024-03-02 08:00

-- ==== Source changes, then run 2: only the delta ===============
UPDATE src_orders SET amount = 25, updated_at = TIMESTAMPTZ '2024-03-03 10:00+00' WHERE order_id = 101;
INSERT INTO src_orders VALUES (103, 3, 7, TIMESTAMPTZ '2024-03-03 12:00+00');

CALL load_dw_orders();
SELECT order_id, amount FROM dw_orders ORDER BY order_id;
-- expect: 100/40, 101/25, 102/90, 103/7

-- ==== Run 3: no changes -> no-op ==============================
CALL load_dw_orders();
SELECT count(*) AS rows FROM dw_orders;
-- expect: 4 (unchanged)

-- ==== Insert-only source: watermark on a monotonic id ==========
CREATE TABLE src_events (id bigint PRIMARY KEY, kind text);
INSERT INTO src_events SELECT g, 'e' FROM generate_series(1, 100) g;
CREATE TABLE dw_events (id bigint PRIMARY KEY, kind text);
CREATE TABLE ev_state (last_id bigint NOT NULL);
INSERT INTO ev_state VALUES (0);

INSERT INTO dw_events SELECT id, kind FROM src_events WHERE id > (SELECT last_id FROM ev_state);
UPDATE ev_state SET last_id = (SELECT max(id) FROM dw_events);
SELECT (SELECT count(*) FROM dw_events) AS loaded, (SELECT last_id FROM ev_state) AS wm;
-- expect: 100, 100

DROP SCHEMA sqlfp CASCADE;
