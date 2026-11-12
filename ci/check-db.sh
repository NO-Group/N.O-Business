#!/usr/bin/env bash
# Database verification: applies every migration to a throw-away PostgreSQL
# instance and runs the SQL test suite (tenant isolation, roles, business
# flows, documents and audit).
#
# Needs only Python 3.9-3.12. PostgreSQL itself comes from the `pgserver`
# wheel, so no Docker and no system database are required.
#
# Usage: bash ci/check-db.sh [-v]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# The pgserver wheel bundles PostgreSQL and is published for CPython 3.9-3.12.
PYTHON="${NOB_PYTHON:-}"
if [ -z "$PYTHON" ]; then
  for candidate in python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON="$candidate"
      break
    fi
  done
fi

VENV="$WORK_DIR/nob-db-venv"
setup_venv() {
  "$PYTHON" --version
  "$PYTHON" -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check \
    -r "$REPO_ROOT/supabase/tests/requirements.txt"
}
if [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -c "import pgserver" 2>/dev/null; then
  run_step "python environment" setup_venv
fi

cd "$REPO_ROOT"
run_step "database migrations and tests" "$VENV/bin/python" supabase/tests/run.py "$@"
