-- ============================================================================
-- Query optimization: sargability, statistics, join algorithms
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/30_query_optimization/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE users (
    user_id int PRIMARY KEY,
    email   text NOT NULL,
    created_at timestamptz NOT NULL
);
CREATE TABLE orders (
    order_id bigint PRIMARY KEY,
    user_id  int NOT NULL,
    status   text NOT NULL,
    total    numeric NOT NULL,
    created_at timestamptz NOT NULL
);
INSERT INTO users
SELECT g, 'u' || g || '@x.com', TIMESTAMPTZ '2023-01-01' + (g || ' minutes')::interval
FROM generate_series(1, 20000) g;
INSERT INTO orders
SELECT g, (g % 20000) + 1,
       (ARRAY['paid', 'pending', 'cancelled'])[1 + (g % 3)],
       (g % 500) + 1,
       TIMESTAMPTZ '2024-01-01' + ((g * 6) || ' minutes')::interval
FROM generate_series(1, 40000) g;
ANALYZE users;
ANALYZE orders;

CREATE INDEX idx_created ON orders (created_at);
CREATE INDEX idx_orders_user ON orders (user_id);
ANALYZE orders;

-- ==== Non-sargable vs sargable ===================================
EXPLAIN SELECT count(*) FROM orders WHERE date(created_at) = DATE '2024-02-01';
EXPLAIN SELECT count(*) FROM orders
WHERE created_at >= TIMESTAMPTZ '2024-02-01' AND created_at < TIMESTAMPTZ '2024-02-02';

SELECT count(*) AS feb1 FROM orders
WHERE created_at >= TIMESTAMPTZ '2024-02-01' AND created_at < TIMESTAMPTZ '2024-02-02';
-- expect: 240  (one row every 6 minutes)

-- ==== Join algorithm shifts with selectivity =====================
EXPLAIN SELECT u.email, count(*) FROM users u JOIN orders o USING (user_id)
WHERE u.user_id = 7 GROUP BY u.email;
EXPLAIN SELECT u.email, count(*) FROM users u JOIN orders o USING (user_id)
WHERE o.status = 'paid' GROUP BY u.email;

-- ==== Pre-aggregate rewrite ====================================
EXPLAIN
SELECT u.email, coalesce(a.n, 0) AS n
FROM users u
LEFT JOIN (SELECT user_id, count(*) n, sum(total) spent FROM orders GROUP BY user_id) a
  USING (user_id);

-- ==== Extended statistics for correlated columns ================
EXPLAIN SELECT count(*) FROM orders WHERE status = 'paid' AND total < 50;
CREATE STATISTICS st_orders (dependencies) ON status, total FROM orders;
ANALYZE orders;
EXPLAIN SELECT count(*) FROM orders WHERE status = 'paid' AND total < 50;

DROP SCHEMA sqlfp CASCADE;
