# SQL from First Principles

The machinery under SQL, taught from zero. Every topic: the mechanism, a
**hand-trace** on a handful of real rows, a **live SQL editor** on the page
(real PostgreSQL in your browser — nothing to install), and four
**Build → Break → Fix → Why** scenarios.

Sibling project of [python-fp](https://github.com/AthreyaRah/python-fp).

**Live site:** https://athreyarah.github.io/sql-fp/

## Tracks

| Track | What it covers | Status |
|---|---|---|
| **Foundations** (31 topics) | relational model, `NULL` & 3VL, processing order, joins, aggregation, subqueries, CTEs, window functions, transactions, isolation/MVCC, indexes, reading query plans, optimization, views | complete |
| **Backend Engineering** | keyset pagination & N+1, `EXPLAIN`-driven optimization (+ backlog) | 2 flagship topics; more on the way |
| **Data Engineering** | dimensional modeling (star schema), Slowly Changing Dimensions Type 2 (+ backlog) | 2 flagship topics; more on the way |

## How it works

- **The site** is [Docusaurus](https://docusaurus.io). The in-page SQL editor is
  [PGlite](https://pglite.dev) — PostgreSQL compiled to WebAssembly — so it runs
  a real query engine (`EXPLAIN`, CTEs, window functions, `MERGE`, transactions)
  with no server and no signup.
- **Every topic** also has a self-contained script at
  `sql/<track>/<nn>_<slug>/topic.sql` — schema, seed rows (identical to the
  hand-trace), and every query from the page — that runs on a stock PostgreSQL.
- **CI** (`.github/workflows/ci.yml`) runs every `topic.sql` end-to-end against a
  throwaway `postgres:16` container under `ON_ERROR_STOP`, plus the site build
  with broken links treated as errors. If a claim on the site stops being true,
  the build goes red.

## Run the site locally

```bash
git clone https://github.com/AthreyaRah/sql-fp && cd sql-fp
npm install
npm start           # http://localhost:3000/sql-fp/
npm run build       # production build; fails on broken links
```

## Run the SQL scripts locally

You don't need to — the site's editor is enough. But if you want `psql` / pgAdmin
(see [docs: Run locally](https://athreyarah.github.io/sql-fp/appendix/run-locally)):

```bash
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/postgres"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/11_group_by_and_aggregation/topic.sql

python tools/run_sql.py                 # run every script (what CI does)
python tools/run_sql.py foundations     # one track
cd tools && pytest                      # same, as parametrized tests
```

## Repo layout

```
docs/
  index.mdx  how-to-use.mdx
  foundations/   31 topic .mdx + index
  backend/       topics + index (backlog listed)
  data-engineering/ topics + index (backlog listed)
  appendix/      glossary, cheatsheets, check-yourself answers, run-locally
src/components/
  QueryTrace/    the step-by-step hand-trace component
  SqlRunner/     the in-page PGlite editor
sql/
  _shared/shop_schema.sql
  <track>/<nn>_<slug>/topic.sql
tools/
  run_sql.py  test_sql.py  scaffold.py
.github/workflows/  ci.yml  deploy.yml
```

## Deploying (GitHub Pages)

`deploy.yml` publishes on every push to `main`. One-time: repo **Settings → Pages
→ Source → GitHub Actions**.

## v1 / v2

This is **v1**: the hand-traces are static step-by-step tables. **v2** adds an
optional step mode to the *same* `<QueryTrace>` component — one step at a time,
Next/Prev, rows animating between states — driven by the same data. No page
rewrites.

## Contributing

Corrections, new Backend/Data-Engineering topics, and additional dialects
welcome. A topic is a `docs/<track>/<nn>-<slug>.mdx` page **and** a matching
`sql/<track>/<nn>_<slug>/topic.sql` that CI runs; keep the seed data in the
script identical to the page's hand-trace. `python tools/scaffold.py` creates
stubs from the curriculum list.

MIT licensed. Educational reference.
