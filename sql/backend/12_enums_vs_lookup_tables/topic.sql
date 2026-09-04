-- ============================================================================
-- Enums vs lookup tables
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/12_enums_vs_lookup_tables/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE order_statuses (
    code  text PRIMARY KEY,
    label text NOT NULL,
    is_terminal boolean NOT NULL DEFAULT false,
    sort  int NOT NULL
);
INSERT INTO order_statuses VALUES
    ('pending',   'Pending',   false, 1),
    ('paid',      'Paid',      false, 2),
    ('shipped',   'Shipped',   false, 3),
    ('delivered', 'Delivered', true,  4),
    ('cancelled', 'Cancelled', true,  5);

CREATE TABLE orders (id int PRIMARY KEY, status text NOT NULL REFERENCES order_statuses (code));
CREATE INDEX ON orders (status);
INSERT INTO orders VALUES (1, 'paid'), (2, 'pending'), (3, 'delivered');

-- ==== Add a value: one INSERT, transactional ====================
INSERT INTO order_statuses VALUES ('refunded', 'Refunded', true, 6);

DO $$ BEGIN
    INSERT INTO orders VALUES (4, 'shpped');
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'typo rejected by FK';
END $$;

-- ==== Join for labels; filter on metadata =======================
SELECT o.id, s.label
FROM orders o JOIN order_statuses s ON s.code = o.status
WHERE NOT s.is_terminal
ORDER BY s.sort;
-- expect: (2, Pending), (1, Paid)

-- ==== Native ENUM: compact, ordered, rigid ======================
CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
CREATE TABLE checkins (id int, m mood);
INSERT INTO checkins VALUES (1, 'happy'), (2, 'sad'), (3, 'ok');
SELECT id FROM checkins WHERE m >= 'ok' ORDER BY m;
-- expect: 3, 1
SELECT enum_range(NULL::mood) AS all_values;
SELECT pg_column_size('happy'::mood) AS bytes;
-- expect: 4
ALTER TYPE mood ADD VALUE 'ecstatic';

-- ==== CHECK list ===============================================
CREATE TABLE flags (id int, kind text CHECK (kind IN ('feature', 'bug', 'chore')));
INSERT INTO flags VALUES (1, 'bug'), (2, 'feature');
DO $$ BEGIN
    INSERT INTO flags VALUES (3, 'spike');
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'value not in CHECK list';
END $$;
SELECT count(*) AS flag_rows FROM flags;
-- expect: 2

DROP SCHEMA sqlfp CASCADE;
