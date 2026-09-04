-- ============================================================================
-- Text: pattern matching, regex & full-text basics
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/33_text_pattern_matching_and_regex/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE contacts (id int PRIMARY KEY, name text NOT NULL, email text NOT NULL, bio text NOT NULL);
INSERT INTO contacts (id, name, email, bio) VALUES
    (1, 'Ana Ng',       'ana.ng@acme.io',       'Backend engineer, loves PostgreSQL and query tuning.'),
    (2, 'Ben Adeyemi',  'ben@example.com',      'Data engineer. Builds pipelines. Postgres, dbt, Airflow.'),
    (3, 'Chidi Okafor', 'chidi.okafor@acme.io', 'SRE. On-call rotations, incident response, Postgres HA.'),
    (4, 'Dana Prima',   'dana@personal.net',    'Frontend. React, TypeScript. Occasionally writes SQL.'),
    (5, 'Eve Zhou',     'eve.zhou@ACME.io',     'PM for the data platform team.');

-- ==== LIKE / ILIKE / regex ======================================
SELECT name,
       email LIKE '%@acme.io'       AS acme_exact,
       email ILIKE '%@acme.io'      AS acme_ci,
       email ~* '@acme\.io$'        AS acme_regex,
       name  ~ '^[A-Z][a-z]+ [A-Z]' AS looks_like_name
FROM contacts ORDER BY id;
-- expect: Eve's ACME.io fails acme_exact but passes acme_ci and acme_regex

-- ==== Anchored prefix indexable, leading % not ==================
CREATE INDEX idx_email ON contacts (email text_pattern_ops);
EXPLAIN SELECT * FROM contacts WHERE email LIKE 'ana%';
EXPLAIN SELECT * FROM contacts WHERE email LIKE '%acme%';

-- ==== Regex extract / replace / split ==========================
SELECT name,
       regexp_replace(email, '@.*$', '')  AS local_part,
       (regexp_match(email, '@(.+)$'))[1] AS domain,
       regexp_split_to_array(name, '\s+') AS name_parts
FROM contacts ORDER BY id;

-- ==== Full-text search with ranking ============================
SELECT c.name, round(ts_rank(to_tsvector('english', c.bio), q)::numeric, 4) AS rank
FROM contacts c, plainto_tsquery('english', 'data pipelines') q
WHERE to_tsvector('english', c.bio) @@ q
ORDER BY rank DESC;
-- expect: Ben ranks top (data engineer, builds pipelines)

-- ==== Case-insensitive exact match via lower() index ============
CREATE INDEX idx_email_lower ON contacts (lower(email));
EXPLAIN SELECT * FROM contacts WHERE lower(email) = lower('ANA.NG@acme.io');

DROP SCHEMA sqlfp CASCADE;
