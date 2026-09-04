-- ============================================================================
-- Connection pooling & prepared statements
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/15_connection_pooling_and_prepared_statements/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE users (id int PRIMARY KEY, email text NOT NULL, region text NOT NULL);
INSERT INTO users SELECT g, 'u' || g || '@x.com', (ARRAY['EU', 'US', 'APAC'])[1 + (g % 3)]
FROM generate_series(1, 5000) g;
CREATE INDEX ON users (region);
ANALYZE users;

-- ==== Parameterised prepared statement =========================
PREPARE users_by_region (text) AS
    SELECT id, email FROM users WHERE region = $1 ORDER BY id LIMIT 3;

EXECUTE users_by_region('EU');
EXECUTE users_by_region('US');

SELECT name FROM pg_prepared_statements;
-- expect: users_by_region

-- ==== The plan a prepared statement uses =======================
PREPARE q (text) AS SELECT count(*) FROM users WHERE region = $1;
EXPLAIN EXECUTE q('EU');
SET plan_cache_mode = 'force_generic_plan';
EXPLAIN EXECUTE q('EU');
RESET plan_cache_mode;

-- ==== Connection-local session state ===========================
SET statement_timeout = '5s';
SELECT current_setting('statement_timeout') AS stmt_timeout;
-- a transaction-mode pool would not carry this to the next transaction

-- ==== The pool budget arithmetic ==============================
SELECT
    300         AS app_instances,
    5           AS pool_per_instance,
    300 * 5     AS app_layer_connections,
    (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS server_max;

DEALLOCATE ALL;
DROP SCHEMA sqlfp CASCADE;
