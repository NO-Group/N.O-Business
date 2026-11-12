#!/usr/bin/env bash
# Formats the app with `dart format` and, inside GitHub Actions, commits the
# result back to the current branch. Locally it only rewrites the files.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

install_flutter
cd "$REPO_ROOT/app"
run_step "flutter pub get" flutter pub get
run_step "dart format (apply)" dart format lib test

cd "$REPO_ROOT"
if git diff --quiet -- app/lib app/test; then
  echo "Already formatted."
  exit 0
fi
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  echo "Files were reformatted; review and commit them."
  exit 0
fi
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add app/lib app/test
git commit --quiet -m "style(app): apply dart format"
git push --quiet origin "HEAD:${GITHUB_REF_NAME}"
echo "Pushed formatting commit to ${GITHUB_REF_NAME}."
