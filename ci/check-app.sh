#!/usr/bin/env bash
# Flutter app verification: formatting, static analysis and tests.
#
# Usage: bash ci/check-app.sh [all|format|analyze|test]
#
# With no argument every check runs and the script fails if any of them did.
# CI calls the checks one by one so each gets its own step and report.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

what="${1:-all}"
case "$what" in
  all | format | analyze | test) ;;
  *)
    echo "usage: $0 [all|format|analyze|test]" >&2
    exit 2
    ;;
esac

install_flutter
cd "$REPO_ROOT/app"
run_step "flutter pub get" flutter pub get

failed=0
if [ "$what" = all ] || [ "$what" = format ]; then
  run_step "dart format" dart format --output=none --set-exit-if-changed lib test || failed=1
fi
if [ "$what" = all ] || [ "$what" = analyze ]; then
  run_step "flutter analyze" flutter analyze --no-pub || failed=1
fi
if [ "$what" = all ] || [ "$what" = test ]; then
  run_step "flutter test" flutter test --no-pub || failed=1
fi
exit "$failed"
