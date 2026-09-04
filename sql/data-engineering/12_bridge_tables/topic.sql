-- ============================================================================
-- Bridge tables for many-to-many in a star schema
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/data-engineering/12_bridge_tables/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE dim_customer (customer_key int PRIMARY KEY, name text);
CREATE TABLE dim_channel  (channel_key int PRIMARY KEY, name text);
INSERT INTO dim_customer VALUES (1, 'Ana'), (2, 'Ben');
INSERT INTO dim_channel  VALUES (10, 'email'), (11, 'ads'), (12, 'organic');

CREATE TABLE fact_purchase (
    purchase_id int PRIMARY KEY, customer_key int NOT NULL, revenue numeric(12, 2) NOT NULL
);
INSERT INTO fact_purchase VALUES (100, 1, 90), (101, 2, 40);

-- ==== Weighted attribution =====================================
CREATE TABLE bridge_purchase_channel (
    purchase_key int NOT NULL REFERENCES fact_purchase (purchase_id),
    channel_key  int NOT NULL REFERENCES dim_channel (channel_key),
    weight numeric(5, 4) NOT NULL,
    PRIMARY KEY (purchase_key, channel_key)
);
INSERT INTO bridge_purchase_channel VALUES
    (100, 10, 0.5), (100, 11, 0.3), (100, 12, 0.2),
    (101, 10, 1.0);

-- weights sum to 1.0 per purchase (a load-time assertion)
SELECT bool_and(w = 1.0) AS all_weights_ok FROM (
    SELECT purchase_key, sum(weight) AS w FROM bridge_purchase_channel GROUP BY purchase_key
) s;
-- expect: true

SELECT c.name AS channel, sum(f.revenue * b.weight) AS attributed_revenue
FROM fact_purchase f
JOIN bridge_purchase_channel b ON b.purchase_key = f.purchase_id
JOIN dim_channel c ON c.channel_key = b.channel_key
GROUP BY c.name ORDER BY c.name;
-- expect: ads 27, email 85, organic 18

SELECT sum(f.revenue * b.weight)               AS attributed,
       (SELECT sum(revenue) FROM fact_purchase) AS actual
FROM fact_purchase f JOIN bridge_purchase_channel b ON b.purchase_key = f.purchase_id;
-- expect: 130, 130 (reconciles)

-- ==== Without weights: inflated total =========================
SELECT sum(f.revenue) AS inflated_total
FROM fact_purchase f JOIN bridge_purchase_channel b ON b.purchase_key = f.purchase_id;
-- expect: 90*3 + 40 = 310 (NOT 130 -- influenced revenue, don't total it)

-- ==== Group key variant ======================================
CREATE TABLE dim_channel_group (group_key int PRIMARY KEY, label text);
CREATE TABLE bridge_group_channel (group_key int, channel_key int, weight numeric, PRIMARY KEY (group_key, channel_key));
INSERT INTO dim_channel_group VALUES (1, 'email+ads+organic'), (2, 'email only');
INSERT INTO bridge_group_channel VALUES (1,10,0.5),(1,11,0.3),(1,12,0.2),(2,10,1.0);

ALTER TABLE fact_purchase ADD COLUMN channel_group_key int;
UPDATE fact_purchase SET channel_group_key = CASE purchase_id WHEN 100 THEN 1 ELSE 2 END;

SELECT c.name, sum(f.revenue * b.weight) AS attributed
FROM fact_purchase f
JOIN bridge_group_channel b ON b.group_key = f.channel_group_key
JOIN dim_channel c ON c.channel_key = b.channel_key
GROUP BY c.name ORDER BY c.name;
-- expect: same as the per-fact bridge (ads 27, email 85, organic 18)

DROP SCHEMA sqlfp CASCADE;
