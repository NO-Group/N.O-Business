#!/usr/bin/env bash
# Flutter app verification: formatting, static analysis and tests.
#
# Usage: bash ci/check-app.sh
#   NOB_APPLY_FORMAT=1  rewrite files with `dart format` instead of failing
#                       when they are not formatted.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

install_flutter
cd "$REPO_ROOT/app"

run_step "flutter pub get" flutter pub get

if [ "${NOB_APPLY_FORMAT:-0}" = "1" ]; then
  run_step "dart format (apply)" dart format lib test
else
  run_step "dart format" dart format --output=none --set-exit-if-changed lib test
fi

run_step "flutter analyze" flutter analyze --no-pub
run_step "flutter test" flutter test --no-pub
