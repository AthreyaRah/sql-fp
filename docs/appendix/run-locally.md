---
title: "Run locally (optional)"
sidebar_position: 4
---

# Run locally (optional)

You don't need this. Every topic page has a live editor running real PostgreSQL
in your browser. Set up a local database only if you want to:

- run the repo's `sql/**/topic.sql` scripts as one file,
- use pgAdmin's schema browser and plan visualiser,
- work with bigger data than the toy tables, or
- use `psql` because you like `psql`.

## The five-minute version

### macOS

```bash
brew install postgresql@16
brew services start postgresql@16
echo 'export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
createdb "$(whoami)"        # a default database
export DATABASE_URL="postgresql://$(whoami)@localhost:5432/postgres"
createdb postgres 2>/dev/null || true
psql "$DATABASE_URL" -c "SELECT version();"
```

Or use [Postgres.app](https://postgresapp.com/): drag to `/Applications`, open,
click **Initialize**, and add its `bin` to your PATH.

### Windows

1. Download the **PostgreSQL 16** installer from
   [enterprisedb.com/downloads/postgres-postgresql-downloads](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads).
2. Run it. Keep *PostgreSQL Server*, *pgAdmin 4*, *Command Line Tools*. Set the
   `postgres` password to `postgres` (or remember what you choose). Port `5432`.
3. Add `C:\Program Files\PostgreSQL\16\bin` to your **Path** (search "Edit the
   system environment variables"), open a new PowerShell:

   ```powershell
   setx DATABASE_URL "postgresql://postgres:postgres@localhost:5432/postgres"
   psql "$env:DATABASE_URL" -c "SELECT version();"
   ```

### Linux

```bash
sudo apt install postgresql-16 postgresql-client-16      # or your distro's package
sudo -u postgres psql -c "ALTER ROLE postgres PASSWORD 'postgres';"
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/postgres"
```

## pgAdmin 4

Windows installer already includes it. macOS/Linux: download from
[pgadmin.org/download](https://www.pgadmin.org/download/). On first launch set a
**master password** (encrypts saved credentials locally).

**Register a server**: right-click *Servers* → *Register* → *Server*:

| Field | Value |
|---|---|
| Name | `Local` |
| Host | `localhost` |
| Port | `5432` |
| Maintenance DB | `postgres` |
| Username | `postgres` (Windows) or your OS username (macOS/Homebrew) |
| Password | what you set, or blank for macOS trust auth |

Then select the `postgres` database → **Query Tool** to run SQL.

## Running a topic script

From the repo root:

```bash
git clone https://github.com/AthreyaRah/sql-fp && cd sql-fp
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/foundations/11_group_by_and_aggregation/topic.sql
```

Each script drops and recreates its own schema (`sqlfp`), so it's safe to re-run
and it never touches anything else. Run them all (what CI does):

```bash
python tools/run_sql.py
```

:::warning pgAdmin and `psql` commands
The scripts are plain SQL and paste into the pgAdmin Query Tool as-is. They're
run in CI with `psql -v ON_ERROR_STOP=1` so any error fails loudly. Section
headers are `-- ==== label ====` comments; expected answers are `-- expect:`
comments.
:::

## Troubleshooting

| Symptom | Fix |
|---|---|
| `psql: command not found` | `bin` directory not on PATH; open a new terminal after adding it. |
| `could not connect to server` | Server not running. macOS: `brew services start postgresql@16`. Windows: start service `postgresql-x64-16`. |
| `role "postgres" does not exist` | Homebrew/macOS: connect as your OS username, or `createuser -s postgres`. |
| `database "postgres" does not exist` | `createdb postgres`. |
| `password authentication failed` | Wrong password — it's the one from install, not your OS login. |
