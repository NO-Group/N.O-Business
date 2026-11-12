#!/usr/bin/env bash
# Database verification: applies every migration to a throw-away PostgreSQL
# instance and runs the SQL test suite (tenant isolation, roles, business
# flows, documents and audit).
#
# Needs only Python 3. PostgreSQL itself comes from the `pgserver` wheel, so
# no Docker and no system database are required.
#
# Usage: bash ci/check-db.sh [-v]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

VENV="$WORK_DIR/nob-db-venv"
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check -r "$REPO_ROOT/supabase/tests/requirements.txt"
fi

cd "$REPO_ROOT"
run_step "database migrations and tests" "$VENV/bin/python" supabase/tests/run.py "$@"
