-- ============================================================================
-- Soft deletes, timestamps & audit columns
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/backend/06_soft_deletes_and_audit_columns/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

CREATE TABLE documents (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id   int NOT NULL,
    slug       text NOT NULL,
    title      text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);
INSERT INTO documents (owner_id, slug, title) VALUES
    (1, 'roadmap', 'Roadmap'), (1, 'budget', 'Budget'), (2, 'notes', 'Notes');

-- ==== Partial unique index + a live view ========================
CREATE UNIQUE INDEX slug_live_unique ON documents (owner_id, slug) WHERE deleted_at IS NULL;
CREATE VIEW live_documents AS SELECT * FROM documents WHERE deleted_at IS NULL;

UPDATE documents SET deleted_at = now() WHERE slug = 'budget';
SELECT slug FROM live_documents ORDER BY slug;
-- expect: notes, roadmap

-- re-create budget: allowed (the constraint only covers live rows)
INSERT INTO documents (owner_id, slug, title) VALUES (1, 'budget', 'Budget v2');
SELECT count(*) FILTER (WHERE deleted_at IS NULL) AS live FROM documents WHERE slug = 'budget';
-- expect: 1

-- ==== updated_at via trigger, can't be forged ===================
CREATE FUNCTION touch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
CREATE TRIGGER trg_touch BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION touch();

UPDATE documents SET title = 'Roadmap 2025', updated_at = TIMESTAMPTZ '2020-01-01' WHERE slug = 'roadmap'
RETURNING (updated_at > TIMESTAMPTZ '2024-01-01') AS is_recent;
-- expect: true (the trigger overrode the forged value)

-- ==== Append-only audit log =====================================
CREATE TABLE audit_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tbl text NOT NULL, row_id bigint NOT NULL, action text NOT NULL,
    at timestamptz NOT NULL DEFAULT now(), old_row jsonb, new_row jsonb
);
CREATE FUNCTION audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_log (tbl, row_id, action, old_row, new_row)
    VALUES (TG_TABLE_NAME, coalesce(NEW.id, OLD.id), lower(TG_OP), to_jsonb(OLD), to_jsonb(NEW));
    RETURN NULL;
END $$;
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON documents
FOR EACH ROW EXECUTE FUNCTION audit();

UPDATE documents SET title = 'Notes FINAL' WHERE slug = 'notes';
UPDATE documents SET deleted_at = now() WHERE slug = 'notes';
SELECT action, old_row ->> 'title' AS old_title, new_row ->> 'title' AS new_title
FROM audit_log ORDER BY id;
-- expect: two 'update' rows for the notes doc

DROP SCHEMA sqlfp CASCADE;
