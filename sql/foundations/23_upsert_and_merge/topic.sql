-- ============================================================================
-- Upsert & MERGE: INSERT ... ON CONFLICT
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/23_upsert_and_merge/topic.sql
-- (MERGE requires PostgreSQL 15+)
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE inventory (
    sku        text PRIMARY KEY,
    qty        int  NOT NULL,
    updated_at date NOT NULL DEFAULT DATE '2024-01-01'
);
INSERT INTO inventory (sku, qty) VALUES ('A1', 5), ('B2', 0);

CREATE TABLE shipment (sku text, qty int);
INSERT INTO shipment VALUES ('A1', 3), ('C3', 10);

-- ==== ON CONFLICT DO UPDATE =========================================
INSERT INTO inventory (sku, qty) VALUES ('A1', 3), ('C3', 10)
ON CONFLICT (sku) DO UPDATE
  SET qty = inventory.qty + EXCLUDED.qty, updated_at = DATE '2024-06-01'
RETURNING sku, qty;
-- expect: A1 -> 8, C3 -> 10

SELECT * FROM inventory ORDER BY sku;
-- expect: A1 8, B2 0, C3 10

-- ==== ON CONFLICT DO NOTHING =======================================
INSERT INTO inventory (sku, qty) VALUES ('A1', 999) ON CONFLICT (sku) DO NOTHING;
SELECT qty FROM inventory WHERE sku = 'A1';
-- expect: 8 (unchanged)

-- ==== MERGE: reconcile against shipment ============================
DELETE FROM shipment;
INSERT INTO shipment VALUES ('B2', 0), ('A1', 2), ('D4', 7);

MERGE INTO inventory i
USING shipment s ON i.sku = s.sku
WHEN MATCHED AND s.qty = 0 THEN DELETE
WHEN MATCHED               THEN UPDATE SET qty = i.qty + s.qty
WHEN NOT MATCHED           THEN INSERT (sku, qty) VALUES (s.sku, s.qty);

SELECT * FROM inventory ORDER BY sku;
-- expect: A1 10, C3 10, D4 7  (B2 deleted)

DROP SCHEMA sqlfp CASCADE;
