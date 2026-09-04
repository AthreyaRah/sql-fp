---
title: "Glossary"
sidebar_position: 1
---

# Glossary

First-principles definitions of the terms that recur across the site. Each links
to the topic that develops it.

**ACID** — the four guarantees a transaction gives: **A**tomicity (all or
nothing), **C**onsistency (constraints hold at commit), **I**solation
(concurrent transactions don't see each other's uncommitted work), **D**urability
(a committed change survives a crash). See [Transactions & ACID](/foundations/transactions-and-acid).

**Anti-join** — "rows in A with *no* match in B". Written `NOT EXISTS` (safe) or
`LEFT JOIN ... WHERE b.key IS NULL`. Not `NOT IN` on a nullable column. See
[Semi-joins & anti-joins](/foundations/semi-joins-and-anti-joins).

**Cardinality** — how many rows. The planner estimates the cardinality of each
step from statistics; a bad estimate is the usual cause of a bad plan. See
[Query optimization](/foundations/query-optimization).

**Correlated subquery** — a subquery that references a column from the outer
query, so it is conceptually re-evaluated per outer row. See
[Correlated subqueries & EXISTS](/foundations/correlated-subqueries-and-exists).

**CTE (Common Table Expression)** — a named subquery in a `WITH` clause, usable
like a table in the main query. See [Common Table Expressions](/foundations/common-table-expressions).

**Grain** — the meaning of one row in a table: "one row per order line", "one row
per customer per day". Every design question in a warehouse starts here. See
[Dimensional modeling](/data-engineering/dimensional-modeling-star-schema).

**Index** — a secondary data structure (usually a B-tree) that maps column values
to row locations, so the engine can find rows without scanning the table. See
[Indexes & the B-tree](/foundations/indexes-and-the-b-tree).

**MVCC (Multi-Version Concurrency Control)** — Postgres keeps old row versions so
readers never block writers and vice versa; each transaction sees a consistent
snapshot. See [Isolation levels & MVCC](/foundations/isolation-levels-and-mvcc).

**NULL** — "unknown", not "empty" and not "zero". Any comparison with `NULL`
yields `NULL` (not true), which `WHERE` treats as "don't keep". See
[Data types, NULL & three-valued logic](/foundations/data-types-null-and-three-valued-logic).

**Predicate** — a boolean expression that filters rows (`status = 'paid'`,
`amount > 100`). A **sargable** predicate can use an index; `WHERE lower(email) =
...` is not sargable unless you index `lower(email)`. See
[Query optimization](/foundations/query-optimization).

**Sargable** — "Search ARGument ABLE": a predicate the engine can satisfy with an
index range scan rather than by evaluating it on every row.

**SCD (Slowly Changing Dimension)** — a dimension whose attributes change
occasionally, and the strategies for handling that: overwrite (Type 1), keep
history with validity windows (Type 2), keep only the previous value (Type 3). See
[Slowly Changing Dimensions — Type 2](/data-engineering/slowly-changing-dimensions-type-2).

**Semi-join** — "rows in A that have *at least one* match in B", without
duplicating A. Written `EXISTS` or `IN`. See
[Semi-joins & anti-joins](/foundations/semi-joins-and-anti-joins).

**Surrogate key** — a meaningless system-generated identifier (a sequence, a
UUID) used as the primary key instead of a "natural" business value. See
[Constraints & keys](/foundations/constraints-and-keys).

**Three-valued logic** — SQL booleans are `true`, `false`, or `NULL` (unknown).
`AND` / `OR` / `NOT` have rules for the third value that trip people up. See
[Data types, NULL & three-valued logic](/foundations/data-types-null-and-three-valued-logic).

**Window function** — a function (`row_number()`, `sum() OVER ...`) that sees a
*window* of related rows around the current one without collapsing them like
`GROUP BY` does. See [Window functions](/foundations/window-functions-partitioning-and-ranking).
