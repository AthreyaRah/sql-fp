#!/usr/bin/env python3
"""Generate stub topic pages and SQL scripts from the curriculum below.

    python tools/scaffold.py

- Creates docs/<track>/<nn>-<slug>.mdx for every topic that does not exist.
- Creates sql/<track>/<nn>_<slug>/topic.sql stub alongside it.
- Never touches a page whose first line is `<!-- status: authored -->`.
- Writes each track's _category_.json.

Sidebar order comes from `sidebar_position` frontmatter (the topic number).
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
SQL = ROOT / "sql"

# (slug, title)
FOUNDATIONS = [
    ("the-relational-model", "The relational model & what a query engine does"),
    ("data-types-null-and-three-valued-logic", "Data types, NULL & three-valued logic"),
    ("logical-query-processing-order", "Logical query processing order"),
    ("filtering-rows", "Filtering rows: WHERE, IN, BETWEEN, LIKE, CASE"),
    ("sorting-and-limiting", "Sorting & limiting: ORDER BY, NULLS, LIMIT/OFFSET"),
    ("inner-join", "INNER JOIN: the cross-product-and-filter model"),
    ("outer-joins", "Outer joins: LEFT, RIGHT, FULL & NULL semantics"),
    ("self-joins-and-cross-joins", "Self-joins & CROSS JOIN"),
    ("on-vs-where", "ON vs WHERE: predicate placement in joins"),
    ("semi-joins-and-anti-joins", "Semi-joins & anti-joins (EXISTS, NOT IN trap)"),
    ("group-by-and-aggregation", "Aggregation & GROUP BY"),
    ("having-vs-where", "HAVING vs WHERE"),
    ("grouping-sets-rollup-cube", "GROUPING SETS, ROLLUP, CUBE"),
    ("subqueries", "Subqueries: scalar, row, table"),
    ("correlated-subqueries-and-exists", "Correlated subqueries & EXISTS"),
    ("common-table-expressions", "Common Table Expressions (WITH)"),
    ("recursive-ctes", "Recursive CTEs: hierarchies & graphs"),
    ("window-functions-partitioning-and-ranking", "Window functions: PARTITION BY & ranking"),
    ("window-frames", "Window frames: running totals & moving averages"),
    ("set-operations", "Set operations: UNION, INTERSECT, EXCEPT"),
    ("distinct-and-distinct-on", "DISTINCT & DISTINCT ON"),
    ("modifying-data", "Modifying data: INSERT, UPDATE, DELETE, RETURNING"),
    ("upsert-and-merge", "Upsert & MERGE: INSERT ... ON CONFLICT"),
    ("constraints-and-keys", "Constraints & keys: PK, FK, UNIQUE, CHECK"),
    ("transactions-and-acid", "Transactions & ACID"),
    ("isolation-levels-and-mvcc", "Isolation levels & MVCC"),
    ("indexes-and-the-b-tree", "Indexes from first principles: the B-tree"),
    ("index-types", "Index types & when each wins"),
    ("reading-query-plans", "Reading query plans: EXPLAIN & EXPLAIN ANALYZE"),
    ("query-optimization", "Query optimization: sargability, stats, join algorithms"),
    ("views-and-materialized-views", "Views & materialized views"),
    ("dates-times-and-time-zones", "Dates, times, intervals & time zones"),
    ("text-pattern-matching-and-regex", "Text: pattern matching, regex & full-text basics"),
    ("json-and-jsonb", "JSON & JSONB"),
    ("arrays", "Arrays"),
    ("lateral-joins", "LATERAL joins & set-returning functions"),
    ("generated-columns-domains-and-types", "Generated columns, domains & custom types"),
    ("triggers-and-plpgsql", "Triggers & PL/pgSQL basics"),
    ("roles-privileges-and-row-level-security", "Roles, privileges & row-level security"),
    ("bulk-loading-and-copy", "Bulk loading: COPY, \\\\copy & staging tables"),
    ("numeric-precision-money-and-rounding", "Numeric precision, money & rounding"),
]

BACKEND = [
    ("keyset-pagination-and-the-n-plus-1-problem", "Keyset pagination & the N+1 problem"),
    ("reading-explain-plans-and-query-optimization", "Reading EXPLAIN plans & query optimization"),
]

DATA_ENGINEERING = [
    ("dimensional-modeling-star-schema", "Dimensional modeling: the star schema"),
    ("slowly-changing-dimensions-type-2", "Slowly Changing Dimensions — Type 2"),
]

TRACKS = {
    "foundations": ("Foundations", 4, FOUNDATIONS),
    "backend": ("Backend Engineering", 5, BACKEND),
    "data-engineering": ("Data Engineering", 6, DATA_ENGINEERING),
}

PAGE_STUB = """---
title: "{title}"
sidebar_position: {n}
slug: /{track}/{slug}
---

{{/* status: stub */}}

# {title}

:::warning Stub
Not written yet — on the build list. Every topic on this site follows the
structure below.
:::

## First principles

## The mechanism

## Hand-trace on dummy data

## Build it in SQL

## Build → Break → Fix → Why

## Pitfalls & idioms

## See also

## Check yourself
"""

SQL_STUB = """-- ============================================================================
-- {title}
-- Run:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/{track}/{dir}/topic.sql
-- ============================================================================

DROP SCHEMA IF EXISTS sqlfp CASCADE;
CREATE SCHEMA sqlfp;
SET search_path = sqlfp;

-- ==== (stub) {title} ======================================================
SELECT 'stub: {title}' AS todo;

DROP SCHEMA sqlfp CASCADE;
"""


def is_authored(path: Path) -> bool:
    if not path.exists():
        return False
    head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:12])
    return "status: authored" in head


def main() -> None:
    for track, (label, position, topics) in TRACKS.items():
        tdir = DOCS / track
        tdir.mkdir(parents=True, exist_ok=True)
        # _category_.json and index.mdx are maintained by hand.
        for i, (slug, title) in enumerate(topics, start=1):
            page = tdir / f"{i:02d}-{slug}.mdx"
            if not is_authored(page):
                page.write_text(
                    PAGE_STUB.format(title=title, n=i + 1, track=track, slug=slug),
                    encoding="utf-8",
                )
            sdir = SQL / track / f"{i:02d}_{slug.replace('-', '_')}"
            sdir.mkdir(parents=True, exist_ok=True)
            script = sdir / "topic.sql"
            if not script.exists():
                script.write_text(
                    SQL_STUB.format(title=title, track=track, dir=sdir.name),
                    encoding="utf-8",
                )
    print("scaffold complete")


if __name__ == "__main__":
    main()
