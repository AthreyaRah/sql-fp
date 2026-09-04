#!/usr/bin/env python3
"""Run every topic's self-contained SQL script and report a pass/fail table.

    python tools/run_sql.py                       # every sql/**/*.sql
    python tools/run_sql.py foundations           # one track
    python tools/run_sql.py sql/foundations/11_group_by/topic.sql

Each script is run with `psql -v ON_ERROR_STOP=1`, so any error fails the run.
This is the "does every claim on the site still execute?" check. CI runs it against
a throwaway postgres:16 service container; locally, point DATABASE_URL at any
Postgres you like (the scripts create and drop their own schema).

    export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres
"""

from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL_ROOT = ROOT / "sql"
DEFAULT_DSN = "postgresql://postgres:postgres@localhost:5432/postgres"


def discover(args: list[str]) -> list[Path]:
    if not args:
        return sorted(SQL_ROOT.rglob("*.sql"))
    out: list[Path] = []
    for a in args:
        p = Path(a)
        if p.is_file():
            out.append(p.resolve())
        elif (SQL_ROOT / a).is_dir():
            out.extend(sorted((SQL_ROOT / a).rglob("*.sql")))
        else:
            print(f"skip: {a} is neither a file nor a track under sql/")
    return out


def run_one(script: Path, dsn: str) -> tuple[bool, float, str]:
    started = time.perf_counter()
    proc = subprocess.run(
        ["psql", dsn, "-v", "ON_ERROR_STOP=1", "-q", "-f", str(script)],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    elapsed = time.perf_counter() - started
    ok = proc.returncode == 0
    detail = "" if ok else (proc.stdout + "\n" + proc.stderr).strip()
    return ok, elapsed, detail


def main(argv: list[str]) -> int:
    dsn = os.environ.get("DATABASE_URL", DEFAULT_DSN)
    scripts = discover(argv)
    if not scripts:
        print("no .sql scripts found")
        return 0

    width = max(len(str(s.relative_to(ROOT))) for s in scripts)
    failures = 0
    for s in scripts:
        rel = str(s.relative_to(ROOT))
        ok, elapsed, detail = run_one(s, dsn)
        failures += not ok
        print(f"{rel:<{width}}  {'ok  ' if ok else 'FAIL'}  {elapsed:6.2f}s")
        if not ok:
            print("  --- psql output ---")
            for line in detail.splitlines():
                print(f"  {line}")

    total = len(scripts)
    print(f"\n{total - failures}/{total} scripts ran clean")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
