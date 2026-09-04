---
title: "Check yourself: answers"
sidebar_position: 3
---

# "Check yourself" — answers

Short answers to the five questions ending each topic. Try them from memory
first; the topic page has the full reasoning and a runnable version.

## Foundations

### 1 · The relational model
1. Rows have a physical order you can observe (but must not rely on), and
   duplicate rows are allowed unless a key forbids them — so a table is a bag,
   not a set.
2. Every operator takes tables and returns a table (closure), so a query's input
   can be another query — no special syntax for nesting.
3. `SELECT DISTINCT city FROM customers`: a hash aggregate on 100 rows, an index
   scan of a `city` index on 100M — same SQL, planner's choice.
4. `0` and `''` are real values in the domain; "we don't know" is not. `NULL` is
   the absence marker, which forces three-valued logic.
5. Inserts/updates + `VACUUM` moving rows; a parallel or different scan plan; a
   hash aggregate step reordering output.

### 2 · Data types, NULL & three-valued logic
1. Root (5000) and Priya (900). Mara is excluded (`2000 <> 2000` is false), and
   so are Nikhil and Omar — `NULL <> 2000` is `NULL`, which `WHERE` drops. So
   it's "everyone except Mara *and* except the two unknowns", not just "except
   Mara".
2. `x = NULL` is always `NULL` (unknown); `x IS NULL` is a real boolean —
   `true` when `x` is `NULL`. `NULL = NULL` → `NULL`; `NULL IS NULL` → `true`.
3. `orders.manager_id` contains a `NULL` (Root). `x NOT IN (…, NULL)` expands to
   `… AND x <> NULL`, and `something AND NULL` is never `true`, so every row is
   dropped.
4. `2633.33` — `avg` ignores `NULL`s: `(5000 + 2000 + 900) / 3`. Only Root,
   Mara, and Priya contribute; Nikhil and Omar (`NULL`) are not counted in the
   divisor.
5. `UNIQUE` treats each `NULL` as an unknown distinct from every other, so many
   `NULL`s are allowed. Forbid with `UNIQUE NULLS NOT DISTINCT` (PG15+) or a
   partial index / `NOT NULL`.

### 3 · Logical query processing order
1. `FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY →
   LIMIT/OFFSET`.
2. `ORDER BY` (step 7) runs after `SELECT` (step 5) which binds the alias;
   `WHERE` (step 2) runs before it.
3. `ERROR: aggregate functions are not allowed in WHERE`. You meant `HAVING
   sum(amount) > 100`.
4. Legal — `ORDER BY` can sort by any expression over the `FROM` columns, not
   only ones in the `SELECT` list.
5. A `SELECT` alias isn't visible to sibling `SELECT` expressions. Fix: repeat
   the expression, or wrap in a subquery/CTE that exposes `line_total`.

### 4 · Filtering rows
1. If it's still sold, `discontinued_on IS NULL`, and `NULL <> DATE '2020-01-01'`
   is `NULL` → dropped.
2. `x BETWEEN 10 AND 20`; `x >= 10 AND x <= 20`; `x IN (…)` only if discrete.
3. `NULL` — no arm matched and there's no `ELSE`.
4. "Desk lamp": `D` + one char (`e`) + `sk` + rest → matches. "Dusk": `D` + `u` +
   `sk` + `` → matches `D_sk%` too.
5. `IN (1,2,NULL)` is same as `IN (1,2)` for matching (the `NULL` just never
   matches). `NOT IN (1,2,NULL)` is *always* not-true → returns nothing.

### 5 · Sorting & limiting
1. Without `ORDER BY` the engine returns rows in whatever order the plan
   produces; `LIMIT` then slices that arbitrary order.
2. `ORDER BY city` → `NULL`s last; `ORDER BY city DESC` → `NULL`s first (Postgres
   defaults).
3. Total = every row has a unique position (last sort key is unique). Pagination
   slices the sequence, so ambiguous ties let rows repeat or vanish between
   pages.
4. `OFFSET 200000` computes and discards 200 000 rows; `OFFSET 20` discards 20 —
   roughly 10 000× more work.
5. `CREATE INDEX ON t (signup_date DESC)` (add the pk for a total order:
   `(signup_date DESC, id DESC)`).

### 6 · INNER JOIN
1. Take the Cartesian product `A × B`, keep the pairs where the `ON` predicate is
   `true`.
2. 3 — the pairs (Ana,100),(Ana,101),(Ben,102). Order 103 has `customer_id
   NULL`, and `NULL = anything` is never `true`.
3. No pair `(customer, order)` satisfies the `ON` predicate for a customer with
   no orders, so it's filtered out.
4. Joining `order_items` changed the grain to one row per (order, item); the
   coarser `orders.amount` is now repeated per item and `SUM` over-counts.
5. No — inner join is commutative; `A JOIN B` and `B JOIN A` return the same
   rows.

### 7 · Outer joins
1. `A LEFT JOIN B` = the inner join **plus** every unmatched row of `A`, with
   `B`'s columns `NULL`.
2. Chidi and Dana are added (they matched no order); their `order_id`, `amount`
   etc. are `NULL`.
3. `o.status = 'paid'` is `NULL` for the padded rows, `WHERE` keeps only `true`,
   so they're dropped and the join collapses to inner. Put it in `ON`.
4. Two left rows that matched nothing (counted as 1 by `count(*)`, as 0 by
   `count(o.order_id)`).
5. `SELECT * FROM orders o LEFT JOIN customers c USING (customer_id) WHERE
   c.customer_id IS NULL;` or `WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE
   c.customer_id = o.customer_id)`.

### 8 · Self-joins & CROSS JOIN
1. The two instances are independent inputs; unqualified column names would be
   ambiguous, and you need to name each role.
2. A row trivially equals itself on `manager_id`, so `(Omar, Omar)` satisfies the
   join. Remove with `a.employee_id <> b.employee_id`.
3. `a.id < b.id` yields each unordered pair once (no self, no `(x,y)`+`(y,x)`
   duplicate); `<>` yields both orderings.
4. 6 (`3 × 2`). A legitimate use: generate all size/colour SKUs, or a
   store×day grid.
5. Window function — `lag(hired) OVER (ORDER BY hired)` is one ordered pass; a
   self-join to "the previous row" needs a correlated `MAX(... < current)`.

### 9 · ON vs WHERE
1. Inner join: no difference in result (only style). Left join: a `WHERE` on the
   right table drops the padded rows → becomes an inner join.
2. An inner join between `A` and `B` on `A.k = B.k AND B.status = 'x'`.
3. In `ON` — `LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.year =
   2024` — so customers with no 2024 order are still kept.
4. When you want the anti-join: "left rows that matched nothing".
5. `WHERE` — `city` is a property of the preserved (left) table; filtering it
   there is correct and doesn't collapse the outer join.

### 10 · Semi-joins & anti-joins
1. Each `A` row at most once (no fan-out) and only `A`'s columns.
2. The subquery yields a `NULL`; `x NOT IN (…, NULL)` can never be `true`.
3. `NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)`, or
   `LEFT JOIN orders … WHERE orders.order_id IS NULL`, or add `WHERE customer_id
   IS NOT NULL` to the `NOT IN` subquery.
4. No — `EXISTS` only checks whether the subquery returns any row; the select
   list is ignored.
5. A semi-join: `WHERE EXISTS (…)` or `WHERE customer_id IN (SELECT …)`.

### 11 · Aggregation & GROUP BY
1. A grouping column, or an aggregate over the group.
2. `count(*)` counts rows; `sum(amount)` skips `NULL`s, and if the group's only
   `amount` is `NULL`, the sum is `NULL`.
3. `ERROR: column "orders.status" must appear in the GROUP BY clause`. Fixes:
   `GROUP BY customer_id, status`; drop/aggregate `status`; or `WHERE status =
   …` and don't select it.
4. `SELECT customer_id, count(*) FILTER (WHERE status='paid') AS paid,
   count(*) FILTER (WHERE status='cancelled') AS cancelled FROM orders GROUP BY
   customer_id;`
5. Joining `order_items` fans out order rows; `SUM(o.amount)` repeats per item.
   Pre-aggregate orders in a CTE, then join.

### 12 · HAVING vs WHERE
1. `WHERE` filters individual rows (before grouping); `HAVING` filters whole
   groups (after grouping).
2. `count(*)` doesn't exist until groups are formed, and `WHERE` runs before
   that.
3. `status = 'paid'` → `WHERE` (row property); "3+ total orders" → `HAVING
   count(*) >= 3`.
4. `HAVING` can reference any aggregate; `WHERE` cannot reference a `SELECT`
   alias.
5. `ERROR: column "orders.status" must appear in the GROUP BY clause` — `status`
   isn't a grouping column and the group holds many statuses.

### 13 · GROUPING SETS, ROLLUP, CUBE
1. `GROUPING SETS ((a,b), (a), ())`.
2. `NULL` in both. Distinguish with `GROUPING(region)` = `1` for a rolled-up
   `NULL`, `0` for a real value.
3. Four: `(region,category)`, `(region)`, `(category)`, `()`.
4. One scan + shared aggregation vs `N` scans; the planner can compute all
   grouping sets from a single sorted/hashed pass.
5. `GROUP BY GROUPING SETS ((region), ())` (or `ROLLUP(region)`).

### 14 · Subqueries
1. Scalar (in a `WHERE`/`SELECT` value slot), row (`(a,b) = (SELECT …)`), table
   (`FROM (SELECT …) t` or `IN (SELECT …)`).
2. Zero rows → `NULL`. More than one → runtime error `more than one row returned
   by a subquery used as an expression`.
3. `ERROR: more than one row …`. Fix: `IN (SELECT max(price) … GROUP BY
   category)`, or a correlated `= (SELECT max(p2.price) … WHERE p2.category =
   p.category)`.
4. Derived tables must be named so their columns can be referenced.
5. Always — `x = ANY (subquery)` is defined to be exactly `x IN (subquery)`.

### 15 · Correlated subqueries & EXISTS
1. It references an outer column, so it's conceptually evaluated once per outer
   row.
2. `EXISTS` stops at the first matching row (short-circuit); `COUNT(*) > 0`
   enumerates and counts all of them.
3. No — `EXISTS` ignores its select list.
4. (a) `(SELECT count(*) FROM orders o WHERE o.customer_id = c.customer_id)` in
   the `SELECT`; (b) `LEFT JOIN (SELECT customer_id, count(*) n FROM orders
   GROUP BY customer_id) g USING (customer_id)`.
5. You correlated too loosely, so the subquery returns several rows for one outer
   row — tighten the `WHERE`, or aggregate.

### 16 · Common Table Expressions
1. Readability (top-to-bottom pipeline), reuse (name once), chaining/recursion.
2. Not a temp table — scoped to the one statement, no stats, no indexes, gone
   afterwards.
3. Inlines when referenced once and side-effect-free; still materializes when
   referenced multiple times, marked `MATERIALIZED`, or data-modifying.
4. `WITH f AS (SELECT … WHERE …), g AS (SELECT k, sum(x) FROM f GROUP BY k)
   SELECT * FROM g WHERE sum > 10;`
5. `WITH x AS MATERIALIZED (…)` referenced three times.

### 17 · Recursive CTEs
1. Anchor (starting rows), `UNION [ALL]`, recursive term (joins the CTE to a
   table to step one level).
2. When a recursive step produces zero new rows.
3. `UNION ALL` keeps every produced row (loops forever on a cycle); `UNION`
   dedupes the accumulated set (a revisited node adds nothing, so cycles
   terminate).
4. `UNION` instead of `UNION ALL`; a `WHERE depth < N` guard; or the `CYCLE`
   clause (PG14+).
5. `WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < 100)
   SELECT i FROM n;`

### 18 · Window functions
1. A window function computes over a set of related rows but returns every input
   row; `GROUP BY` collapses each group to one.
2. `row_number` → 1,2,3,4; `rank` → 1,1,3,4; `dense_rank` → 1,1,2,3.
3. Window functions are evaluated after `WHERE`, so their result isn't available
   to `WHERE` on the same level.
4. `SELECT * FROM (SELECT *, row_number() OVER (PARTITION BY game ORDER BY points
   DESC, player) rn FROM scores) s WHERE rn <= 3;`
5. The total row count, alongside every row — cost of zero extra queries (one
   extra pass).

### 19 · Window frames
1. (a) `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`; (b) `ROWS BETWEEN 6
   PRECEDING AND CURRENT ROW`; (c) `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING`.
2. `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
3. Default frame ends at `CURRENT ROW`, so `last_value` returns the current
   row's value. Fix: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`,
   or `first_value` with reversed order.
4. `ROWS` counts physical rows; `RANGE` groups rows sharing the current
   `ORDER BY` value into the same frame edge → tied rows get the same aggregate.
5. `amount - lag(amount) OVER (PARTITION BY region ORDER BY d)`.

### 20 · Set operations
1. `UNION` removes duplicate rows (sorts/hashes to do so); `UNION ALL`
   concatenates. `UNION ALL` is the safe default.
2. `UNION ALL` — `UNION` still pays for a dedup pass over the combined input even
   though there are no duplicates to remove.
3. One trailing `ORDER BY` covers the whole result; to sort just `A`, wrap it:
   `(SELECT … ORDER BY … LIMIT …) UNION ALL …`.
4. `INTERSECT` uses `NULL`-equals-`NULL` matching; `WHERE a = b` uses `=`, which
   is `NULL` (not true) when either side is `NULL`.
5. `EXCEPT` (last-night's snapshot `EXCEPT` tonight's).

### 21 · DISTINCT & DISTINCT ON
1. One row per unique `(city, name)` pair — not one per city.
2. The `ORDER BY` must begin with the `DISTINCT ON` expressions, so rows for the
   same key are adjacent and the "winner" is first.
3. `SELECT * FROM (SELECT *, row_number() OVER (PARTITION BY product_id ORDER BY
   changed_at DESC) rn FROM price_history) s WHERE rn = 1;`
4. It can't use a plain index and must sort/hash all values to dedupe them.
5. A join fanned out and produced duplicate rows; you probably wanted a
   semi-join (`EXISTS`), not `DISTINCT`.

### 22 · Modifying data
1. Sets `x = 0` for **every row** in the table.
2. The affected rows' *final* values (defaults, `BEFORE`-trigger changes,
   generated columns) — atomically, without a race with a concurrent write.
3. `UPDATE products p SET price = p.price * (1 + b.pct/100) FROM price_bumps b
   WHERE b.product_id = p.product_id;`
4. Non-deterministic: Postgres applies one of the matching source rows,
   arbitrarily. Make the source unique or aggregate it.
5. `WITH moved AS (DELETE FROM active WHERE … RETURNING *) INSERT INTO archive
   SELECT * FROM moved;` — one statement, atomic.

### 23 · Upsert & MERGE
1. There's a gap between the `SELECT` and the write where another transaction can
   insert/update the same key → duplicate or lost update.
2. `EXCLUDED` is the row you tried to insert; use it (with the existing row) in
   `DO UPDATE`.
3. `DO NOTHING` for idempotent inserts ("record it unless already there"); `DO
   UPDATE` for insert-or-merge.
4. `MERGE` can `DELETE` and have multiple `WHEN` branches; `ON CONFLICT` supports
   `RETURNING` (Postgres `MERGE` doesn't yet).
5. `INSERT INTO events (id, …) VALUES (…) ON CONFLICT (id) DO NOTHING;`

### 24 · Constraints & keys
1. `PRIMARY KEY` is `UNIQUE NOT NULL` **and** the declared row identity (one per
   table, target of FKs, auto-indexed).
2. Each `NULL` is "unknown", not equal to any other, so `UNIQUE` allows many.
   Stop it with `UNIQUE NULLS NOT DISTINCT`, `NOT NULL`, or a partial index.
3. `NO ACTION`/`RESTRICT` (block), `CASCADE`, `SET NULL`, `SET DEFAULT`.
4. Postgres doesn't auto-index FK columns; without one, parent deletes and joins
   on that column scan the child table.
5. `ALTER TABLE … ADD CONSTRAINT … CHECK (…) NOT VALID;` then `ALTER TABLE …
   VALIDATE CONSTRAINT …;` — the first is instant metadata, the second scans
   without an exclusive lock.

### 25 · Transactions & ACID
1. A: all statements land or none. C: constraints hold at commit. I: concurrent
   transactions don't see each other's uncommitted work. D: a committed change
   survives a crash.
2. "Aborted" — every further statement errors until you `ROLLBACK` (or `ROLLBACK
   TO` a savepoint).
3. Partial rollback: undo part of a transaction (`ROLLBACK TO SAVEPOINT`) while
   keeping the earlier work and continuing.
4. They hold locks and prevent `VACUUM` from removing old row versions → bloat,
   slower queries for everyone.
5. Alice debited, Bob never credited — atomicity violated (the two statements
   weren't one indivisible unit).

### 26 · Isolation levels & MVCC
1. Readers see a snapshot of already-committed row versions; writers create new
   versions — neither waits on the other (only two writers to the same row
   serialize).
2. `READ COMMITTED` — a fresh snapshot at the start of each statement; `REPEATABLE
   READ` — one snapshot taken at the first query, held for the transaction.
3. A reads `x=5`; B reads `x=5`; A writes `6` and commits; B writes `6` and
   commits — one increment lost.
4. Fold the check into the `UPDATE`'s `WHERE` + act on `RETURNING`; `SELECT …
   FOR UPDATE`; `REPEATABLE READ`/`SERIALIZABLE` + retry, or a `version` column.
5. It must catch serialization-failure errors (`40001`) and retry the whole
   transaction.

### 27 · Indexes & the B-tree
1. A B-tree is shallow and sorted: a few page reads descend to the key. A scan
   reads every row.
2. No — 60% of rows means jumping to scattered rows costs more than reading the
   table sequentially; the planner correctly scans.
3. All three: `user_id = 1` (left prefix), `created_at > x` (only if it can also
   bound `user_id`; alone it can't use this index well), `user_id = 1 AND
   created_at > x` (ideal).
4. Index the expression: `CREATE INDEX ON t (lower(email))`.
5. `ANALYZE <table>` (autovacuum does it eventually, not immediately).

### 28 · Index types
1. When most queries only touch a subset (soft-deleted rows excluded, one status)
   — the index is smaller and cheaper to maintain.
2. `INCLUDE (cols)` lets a query be answered from the index alone (Index Only
   Scan) — but only if the table's visibility map is fresh (recently vacuumed).
3. GIN; GiST; BRIN.
4. A B-tree on `email` is sorted by `email`, not by `lower(email)` — the derived
   value isn't in the index.
5. `CREATE INDEX ON t (a, b, c)`.

### 29 · Reading query plans
1. Bottom-up / inside-out: the most-indented node runs first.
2. An arbitrary cost estimate for comparing plans; it is **not** time.
3. A large under-estimate — likely stale statistics or correlated columns. Try
   `ANALYZE`; then a higher stats target or `CREATE STATISTICS`.
4. The node ran 2000 times; multiply its per-loop `actual time` by 2000 for the
   real contribution.
5. `EXPLAIN ANALYZE` **executes** the statement, so an `UPDATE` really updates —
   wrap it in `BEGIN; … ROLLBACK;`.

### 30 · Query optimization
1. Sargable = `column <op> constant`, usable by an index range scan. Non-sargable:
   `date(created_at) = d` → use a half-open range; `total * 1.2 > 100` → `total >
   100/1.2`.
2. Nested Loop when the outer side is small and the inner is indexed; Hash Join
   for big unsorted equality joins. It picks wrong when row estimates are wrong.
3. The index is on `created_at`; `date(created_at)` is a different, uncomputed
   value, so every row must be evaluated → Seq Scan.
4. `ANALYZE` the table.
5. Pre-aggregate the detail table in a CTE/subquery before joining — turns a huge
   join+group into a small join.

### 31 · Views & materialized views
1. `VIEW` stores no data (it's a saved query); `MATERIALIZED VIEW` stores the
   result rows.
2. It's combined with the view's own predicates and pushed into one scan of the
   underlying tables.
3. When the data must be current (it's stale between refreshes), or when a plain
   fast view would do.
4. Needs a `UNIQUE` index on the matview; buys a refresh that doesn't take an
   `ACCESS EXCLUSIVE` lock (reads aren't blocked).
5. Neither directly — maintain a summary table via triggers or the write path,
   or use an incremental-materialized-view extension.

## Backend Engineering

### 1 · Keyset pagination & the N+1 problem
1. `OFFSET n` is defined as "produce the ordered result and discard the first
   `n`"; the engine must generate those `n` rows. `LIMIT 20` alone stops after
   20.
2. The sort key must be unique so every row has one definite position — otherwise
   `LIMIT`/the cursor slices an ambiguous sequence and rows repeat or vanish.
3. `SELECT … WHERE (created_at, id) < ($1, $2) ORDER BY created_at DESC, id DESC
   LIMIT 20;`
4. N+1: one query per row. Fixes: a `JOIN`, or a batch load `WHERE id =
   ANY($ids)`.
5. Shallow pages, or when the product genuinely needs "jump to page N" / total
   page counts — then cap the offset.

### 2 · Reading EXPLAIN plans & query optimization
1. A selective predicate with no supporting index — every row read and filtered.
   Add an index on that predicate's column(s).
2. Rows arrive in physical order, not `created_at` order, so a `Sort` node is
   needed; a B-tree on `(… , created_at DESC)` returns rows already ordered.
3. `(a, b, c DESC)` — equality columns first, then the range/sort column, matching
   the `ORDER BY` direction.
4. `Index Cond` — the predicate was used to seek in the index (vs `Filter`,
   checked after fetching the row).
5. One composite index serves filter + order + `LIMIT` in a single scan and costs
   one index to maintain on writes; three single-column indexes each need
   updating and still leave a `Sort`.

## Data Engineering

### 1 · Dimensional modeling: the star schema
1. Grain = what one fact row means. You decide it first because every measure
   must be a single well-defined number at that grain, and you can only roll up,
   never drill below it.
2. Fact: tall/narrow, one row per event, additive measures + dimension FKs.
   Dimension: short/wide, denormalized descriptive attributes, surrogate PK.
3. `revenue` additive; `unit_price` non-additive; `headcount` additive;
   `account_balance` semi-additive (sum across entities, not across time).
4. To decouple from the source system and to give each *version* of a dimension
   row (Type 2) its own stable identity.
5. Store additive `revenue` and `qty` in the fact; compute `avg order value =
   sum(revenue) / count(distinct order)` (or `/ sum(qty)` for avg unit price) at
   query time.

### 2 · Slowly Changing Dimensions — Type 2
1. Type 1 overwrites `city` in place — the old value is gone. Type 2 closes the
   old row (`valid_to`, `is_current=false`) and inserts a new version — full
   history, nothing lost.
2. A *version* of the customer. Facts store the `customer_key` current at the
   event date, freezing that customer's attributes as of then.
3. `<>` returns `NULL` when either side is `NULL`, so a change into/out of `NULL`
   would be missed; `IS DISTINCT FROM` is `NULL`-safe.
4. Re-running against an unchanged source is a no-op — guaranteed by the "only
   act when attributes `IS DISTINCT FROM` the current row" check. Test: run
   twice, compare row count and contents.
5. `WHERE customer_id = ? AND :as_of >= valid_from AND :as_of < valid_to`.
