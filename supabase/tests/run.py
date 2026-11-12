#!/usr/bin/env python3
"""Apply the migrations to a throwaway PostgreSQL and run the SQL test suite.

Usage
  python supabase/tests/run.py                 # ephemeral server via `pgserver`
  python supabase/tests/run.py --psql-url URL  # an existing EMPTY scratch database

The second form needs `psql` on PATH and a superuser connection to a database
you are happy to throw away. Never point it at a real project: the suite
installs a fake `auth` schema and creates the API roles.
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
MIGRATIONS = HERE.parent / "migrations"


def run_file(psql: str, url: str, path: pathlib.Path) -> tuple[bool, str]:
    proc = subprocess.run(
        [psql, url, "-X", "-q", "-o", "/dev/null", "-v", "ON_ERROR_STOP=1", "-f", str(path)],
        capture_output=True,
        text=True,
    )
    return proc.returncode == 0, proc.stdout + proc.stderr


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--psql-url", help="superuser URL of an empty scratch database")
    parser.add_argument("-v", "--verbose", action="store_true", help="print every assertion")
    args = parser.parse_args()

    server = None
    tmp = None
    if args.psql_url:
        psql, url = shutil.which("psql"), args.psql_url
        if not psql:
            print("psql not found on PATH", file=sys.stderr)
            return 2
    else:
        try:
            import pgserver  # type: ignore
        except ImportError:
            print("Install the ephemeral server first:  pip install pgserver", file=sys.stderr)
            return 2
        tmp = tempfile.mkdtemp(prefix="nob-pg-")
        server = pgserver.get_server(tmp, cleanup_mode="delete")
        url = server.get_uri()
        psql = str(pathlib.Path(pgserver.__file__).parent / "pginstall" / "bin" / "psql")

    migrations = sorted(MIGRATIONS.glob("*.sql"))
    tests = sorted(HERE.glob("*.test.sql"))
    steps = (
        [("shim", HERE / "support" / "supabase_shim.sql")]
        + [("migration", m) for m in migrations]
        + [("helpers", HERE / "support" / "test_helpers.sql")]
        + [("test", t) for t in tests]
    )

    failed = False
    assertions = 0
    try:
        for kind, path in steps:
            ok, output = run_file(psql, url, path)
            passed = output.count("NOTICE:  ok - ")
            assertions += passed
            label = f"{kind:<9} {path.name}"
            if ok:
                suffix = f"  ({passed} assertions)" if kind == "test" else ""
                print(f"PASS  {label}{suffix}")
                if args.verbose and kind == "test":
                    for line in output.splitlines():
                        if "NOTICE:  ok - " in line:
                            print("        " + line.split("NOTICE:  ", 1)[1])
            else:
                failed = True
                print(f"FAIL  {label}")
                print("\n".join("      " + line for line in output.strip().splitlines()[-25:]))
                break
    finally:
        if server is not None:
            server.cleanup()
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failed:
        print("Database suite FAILED")
        return 1
    print(f"Database suite passed: {len(migrations)} migrations, {len(tests)} test files, "
          f"{assertions} assertions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
