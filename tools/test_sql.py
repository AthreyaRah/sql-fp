"""pytest wrapper around the SQL harness — one case per topic script.

    pytest tools/

Needs a reachable Postgres (DATABASE_URL, or the local default). CI starts a
postgres:16 service container first. Each script is isolated: it creates and
drops its own schema, so tests do not interfere with each other.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from run_sql import DEFAULT_DSN, SQL_ROOT, run_one

SCRIPTS = sorted(SQL_ROOT.rglob("*.sql"))
DSN = os.environ.get("DATABASE_URL", DEFAULT_DSN)


@pytest.mark.parametrize("script", SCRIPTS, ids=[str(s.relative_to(SQL_ROOT.parent)) for s in SCRIPTS])
def test_script_runs_clean(script: Path) -> None:
    ok, _elapsed, detail = run_one(script, DSN)
    assert ok, f"{script} failed:\n{detail}"
