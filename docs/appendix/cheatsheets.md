---
title: "Cheat sheets"
sidebar_position: 2
---

# Cheat sheets

Fast reference for the patterns you reach for daily. Each links to the topic that
explains *why*.

## Logical processing order

```
FROM / JOIN  →  WHERE  →  GROUP BY  →  HAVING  →  SELECT  →  DISTINCT  →  ORDER BY  →  LIMIT
```

You write `SELECT` first; the engine runs it almost last. That's why you can't
use a `SELECT` alias in `WHERE`, but you can in `ORDER BY`.
[Logical query processing order](/foundations/logical-query-processing-order)

## NULL

```sql
x = NULL          -- always NULL (never true) — wrong
x IS NULL         -- right
x <> 3            -- drops NULLs too (NULL <> 3 is NULL)
x IS DISTINCT FROM 3      -- NULL-safe "not equal", keeps NULLs
COALESCE(x, 0)    -- first non-NULL
count(x)          -- ignores NULLs;  count(*) does not
```

[Data types, NULL & three-valued logic](/foundations/data-types-null-and-three-valued-logic)

## Joins

```sql
A JOIN B        ON ...   -- inner: only matching pairs
A LEFT JOIN B   ON ...   -- all of A; B columns NULL where no match
A FULL JOIN B   ON ...   -- all of both; NULLs on either side
A CROSS JOIN B           -- every combination (no ON)

-- anti-join: A rows with no B
WHERE NOT EXISTS (SELECT 1 FROM B WHERE B.a_id = A.id)
```

Filter the outer side in `ON`, not `WHERE`, or you turn a `LEFT JOIN` back into
an inner one. [ON vs WHERE](/foundations/on-vs-where)

## Aggregation

```sql
SELECT k, count(*), sum(v), avg(v), min(v), max(v)
FROM t GROUP BY k
HAVING count(*) > 1;         -- filter groups (WHERE filters rows, before grouping)

sum(v) FILTER (WHERE cond)   -- conditional aggregate
count(DISTINCT v)
```

[Aggregation & GROUP BY](/foundations/group-by-and-aggregation) ·
[HAVING vs WHERE](/foundations/having-vs-where)

## Window functions

```sql
row_number() OVER (PARTITION BY k ORDER BY t)   -- 1,2,3… no ties
rank()       OVER (...)                          -- 1,2,2,4
dense_rank() OVER (...)                          -- 1,2,2,3
lag(v)  OVER (PARTITION BY k ORDER BY t)         -- previous row's v
sum(v)  OVER (PARTITION BY k ORDER BY t
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)   -- running total
avg(v)  OVER (ORDER BY t ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) -- 3-row moving avg
```

Default frame with `ORDER BY` is `RANGE UNBOUNDED PRECEDING → CURRENT ROW` — and
`RANGE` lumps ties together. Use `ROWS` when you mean rows.
[Window frames](/foundations/window-frames)

## Top-N per group

```sql
SELECT * FROM (
  SELECT *, row_number() OVER (PARTITION BY k ORDER BY score DESC) AS rn
  FROM t
) s WHERE rn <= 3;
```

## Keyset pagination

```sql
-- page 1
SELECT * FROM t ORDER BY created_at, id LIMIT 20;
-- next page: pass the last row's (created_at, id)
SELECT * FROM t
WHERE (created_at, id) > ($1, $2)
ORDER BY created_at, id LIMIT 20;
```

Not `OFFSET 100000` — that reads and throws away 100 000 rows.
[Keyset pagination](/backend/keyset-pagination-and-the-n-plus-1-problem)

## Upsert

```sql
INSERT INTO t (id, v) VALUES ($1, $2)
ON CONFLICT (id) DO UPDATE SET v = EXCLUDED.v;

INSERT INTO t (id, v) VALUES ($1, $2)
ON CONFLICT (id) DO NOTHING;
```

[Upsert & MERGE](/foundations/upsert-and-merge)

## Reading a plan

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```

- `Seq Scan` on a big table with a selective filter → missing/unused index.
- `rows=1000` (estimated) vs `actual rows=900000` → stale stats; `ANALYZE t`.
- Read inner-most / most-indented node first.

[Reading query plans](/foundations/reading-query-plans)
