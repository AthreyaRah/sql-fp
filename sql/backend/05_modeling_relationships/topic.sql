-- ============================================================================
-- Modeling relationships: 1:1, 1:N, M:N
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/05_modeling_relationships/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE users (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, email text NOT NULL UNIQUE);
CREATE TABLE roles (id int PRIMARY KEY, name text NOT NULL UNIQUE);
INSERT INTO users (email) VALUES ('ana@x.com'), ('ben@x.com'), ('chidi@x.com');
INSERT INTO roles VALUES (1, 'admin'), (2, 'editor'), (3, 'viewer');

-- ==== 1:N: FK on the many side, indexed ==========================
CREATE TABLE orders (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES users (id),
    amount numeric NOT NULL
);
CREATE INDEX ON orders (user_id);
INSERT INTO orders (user_id, amount) VALUES (1, 40), (1, 12), (2, 75);

-- ==== 1:1: PK = FK ==============================================
CREATE TABLE user_profiles (
    user_id bigint PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    bio text
);
INSERT INTO user_profiles VALUES (1, 'Backend engineer');
DO $$ BEGIN
    INSERT INTO user_profiles VALUES (1, 'again');
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'one profile per user enforced';
END $$;

-- ==== M:N: junction table with composite PK =====================
CREATE TABLE user_roles (
    user_id bigint NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role_id int    NOT NULL REFERENCES roles (id),
    granted_at date NOT NULL DEFAULT DATE '2024-01-01',
    PRIMARY KEY (user_id, role_id)
);
CREATE INDEX ON user_roles (role_id);
INSERT INTO user_roles (user_id, role_id) VALUES (1, 1), (1, 2), (2, 2), (3, 3);

DO $$ BEGIN
    INSERT INTO user_roles (user_id, role_id) VALUES (1, 1);
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'duplicate grant rejected';
END $$;

-- ==== Both directions of the M:N ================================
SELECT u.email, r.name AS role
FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
WHERE u.email = 'ana@x.com'
ORDER BY r.name;
-- expect: admin, editor

SELECT r.name, string_agg(u.email, ', ' ORDER BY u.email) AS users
FROM roles r
LEFT JOIN user_roles ur ON ur.role_id = r.id
LEFT JOIN users u ON u.id = ur.user_id
GROUP BY r.name ORDER BY r.name;
-- expect: editor -> ana, ben

-- ==== ON DELETE CASCADE removes the grants ======================
DELETE FROM users WHERE email = 'chidi@x.com';
SELECT count(*) AS grants_left FROM user_roles;
-- expect: 3 (chidi's viewer grant is gone)

DROP SCHEMA sqlfp CASCADE;
