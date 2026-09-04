-- ============================================================================
-- Set operations: UNION, INTERSECT, EXCEPT
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/20_set_operations/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE web_signups    (email text NOT NULL);
CREATE TABLE mobile_signups (email text NOT NULL);
INSERT INTO web_signups    VALUES ('ana@x.com'), ('ben@x.com'), ('ben@x.com'), ('chidi@x.com');
INSERT INTO mobile_signups VALUES ('ben@x.com'), ('dana@x.com'), ('ana@x.com');

-- ==== UNION (dedup) vs UNION ALL (concat) ============================
SELECT email FROM web_signups UNION SELECT email FROM mobile_signups ORDER BY email;
-- expect: 4 rows (ana, ben, chidi, dana)

SELECT count(*) AS all_rows FROM (
    SELECT email FROM web_signups UNION ALL SELECT email FROM mobile_signups
) u;
-- expect: 7

-- ==== INTERSECT / EXCEPT ===========================================
SELECT email FROM web_signups INTERSECT SELECT email FROM mobile_signups ORDER BY email;
-- expect: ana, ben
SELECT email FROM web_signups EXCEPT SELECT email FROM mobile_signups;
-- expect: chidi
SELECT email FROM mobile_signups EXCEPT SELECT email FROM web_signups;
-- expect: dana

-- ==== Tag the source, UNION ALL ===================================
SELECT email, 'web'    AS source FROM web_signups
UNION ALL
SELECT email, 'mobile' AS source FROM mobile_signups
ORDER BY email, source;

-- ==== EXCEPT ALL is multiplicity-aware ============================
SELECT email FROM web_signups EXCEPT ALL SELECT email FROM mobile_signups ORDER BY email;
-- expect: ben (one copy left), chidi

DROP SCHEMA sqlfp CASCADE;
