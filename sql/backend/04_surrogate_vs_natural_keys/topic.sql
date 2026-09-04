-- ============================================================================
-- Surrogate vs natural keys: bigint, UUID, uuidv7
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/04_surrogate_vs_natural_keys/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE countries (iso2 char(2) PRIMARY KEY, name text NOT NULL);
INSERT INTO countries VALUES ('DE', 'Germany'), ('NG', 'Nigeria'), ('CA', 'Canada');

CREATE TABLE users (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email        text,
    country_iso2 char(2) NOT NULL REFERENCES countries (iso2)
);

-- ==== Surrogate PK + natural UNIQUE key ==========================
INSERT INTO users (email, country_iso2) VALUES ('ana@x.com', 'DE'), ('ben@x.com', 'NG')
RETURNING id, email;

ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE (email);
DO $$ BEGIN
    INSERT INTO users (email, country_iso2) VALUES ('ana@x.com', 'CA');
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'natural key still enforced';
END $$;

-- fixing the email touches ONE row; it is not the PK, so no cascade
UPDATE users SET email = 'ana@example.com' WHERE email = 'ana@x.com';
SELECT id, email FROM users ORDER BY id;

-- ==== Natural key as PK: the cascade ============================
CREATE TABLE company (name text PRIMARY KEY);
CREATE TABLE contract (
    id int PRIMARY KEY,
    company_name text REFERENCES company (name) ON UPDATE CASCADE
);
INSERT INTO company VALUES ('Acme'), ('Globex');
INSERT INTO contract VALUES (1, 'Acme'), (2, 'Acme'), (3, 'Globex');

UPDATE company SET name = 'Acme International' WHERE name = 'Acme';
SELECT id, company_name FROM contract ORDER BY id;
-- expect: rows 1,2 now 'Acme International' -- every FK row rewritten

-- ==== Key generation options ===================================
SELECT gen_random_uuid() IS NOT NULL AS uuid_available;
-- expect: true (PG13+ core)

DROP SCHEMA sqlfp CASCADE;
