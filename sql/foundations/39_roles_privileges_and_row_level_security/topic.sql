-- ============================================================================
-- Roles, privileges & row-level security
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/39_roles_privileges_and_row_level_security/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE documents (
    id        int PRIMARY KEY,
    tenant_id int NOT NULL,
    title     text NOT NULL,
    body      text NOT NULL
);
INSERT INTO documents VALUES
    (1, 10, 'Acme roadmap', '...'),
    (2, 10, 'Acme budget',  '...'),
    (3, 20, 'Globex memo',  '...'),
    (4, 20, 'Globex hiring', '...');

-- ==== Roles & GRANT ============================================
DROP ROLE IF EXISTS sqlfp_ro;
DROP ROLE IF EXISTS sqlfp_rw;
CREATE ROLE sqlfp_ro;
CREATE ROLE sqlfp_rw;
GRANT USAGE ON SCHEMA sqlfp TO sqlfp_ro, sqlfp_rw;
GRANT SELECT ON documents TO sqlfp_ro;
GRANT SELECT, INSERT, UPDATE ON documents TO sqlfp_rw;
GRANT sqlfp_ro TO sqlfp_rw;   -- membership: rw inherits ro

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'sqlfp' AND table_name = 'documents'
  AND grantee IN ('sqlfp_ro', 'sqlfp_rw')
ORDER BY grantee, privilege_type;

-- ==== Row-level security ======================================
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON documents
    USING (tenant_id = current_setting('app.tenant_id', true)::int)
    WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::int);

-- act as the non-exempt role
SET ROLE sqlfp_rw;
SET app.tenant_id = '10';
SELECT id, tenant_id FROM documents ORDER BY id;
-- expect: only ids 1, 2

SELECT count(*) AS cross_tenant FROM documents WHERE id = 3;
-- expect: 0 (id 3 belongs to tenant 20)

INSERT INTO documents VALUES (5, 10, 'Acme Q3', '...');   -- allowed (same tenant)
DO $$ BEGIN
    INSERT INTO documents VALUES (6, 20, 'sneaky', '...');
EXCEPTION WHEN others THEN RAISE NOTICE 'WITH CHECK blocked cross-tenant insert';
END $$;

SET app.tenant_id = '20';
SELECT id, tenant_id FROM documents ORDER BY id;
-- expect: only ids 3, 4

RESET ROLE;
RESET app.tenant_id;

-- owner sees everything (RLS not FORCEd here)
SELECT count(*) AS all_rows FROM documents;
-- expect: 5

DROP SCHEMA sqlfp CASCADE;
DROP ROLE IF EXISTS sqlfp_ro;
DROP ROLE IF EXISTS sqlfp_rw;
