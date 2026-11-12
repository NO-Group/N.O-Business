#!/usr/bin/env bash
# Shared helpers for the CI scripts. Source this file; do not execute it.
#
# All build logic lives in ci/ so the same commands run on a laptop and in
# GitHub Actions; the workflow file only wires jobs, secrets and artifacts.

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$CI_DIR/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
FLUTTER_VERSION="$(tr -d '[:space:]' < "$CI_DIR/flutter-version")"

# Installs the pinned Flutter SDK (ci/flutter-version) unless that exact
# version is already on PATH.
install_flutter() {
  if command -v flutter >/dev/null 2>&1 &&
    flutter --version 2>/dev/null | grep -q "Flutter ${FLUTTER_VERSION} "; then
    return 0
  fi
  local dir="$WORK_DIR/flutter-$FLUTTER_VERSION"
  if [ ! -x "$dir/bin/flutter" ]; then
    git clone --quiet --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$dir"
  fi
  export PATH="$dir/bin:$PATH"
  flutter config --no-analytics >/dev/null 2>&1 || true
  flutter --version
}

# run_step <name> <command...>
# Runs a command, mirrors its output to a log file and, when it fails inside
# GitHub Actions, surfaces the end of that log as an error annotation so the
# cause is visible on the run summary page without opening the raw log.
run_step() {
  local name="$1"
  shift
  local log
  log="$WORK_DIR/$(printf '%s' "$name" | tr -c 'A-Za-z0-9' '-').log"
  echo "::group::$name"
  set +e
  "$@" 2>&1 | tee "$log"
  local rc=${PIPESTATUS[0]}
  set -e
  echo "::endgroup::"
  if [ "$rc" -ne 0 ]; then
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
      annotate_failure "$name" "$log"
    fi
    echo "FAILED: $name (exit $rc)" >&2
    return "$rc"
  fi
  echo "ok: $name"
}

# annotate_failure <title> <logfile>
# Emits the tail of the log as GitHub error annotations, in chunks, because a
# single annotation is truncated at a few kilobytes.
annotate_failure() {
  local title="$1" log="$2"
  python3 - "$title" "$log" <<'PY'
import sys

title, path = sys.argv[1], sys.argv[2]
with open(path, "r", errors="replace") as handle:
    text = handle.read()

CHUNK, MAX_CHUNKS = 3800, 9
tail = text[-CHUNK * MAX_CHUNKS:]
chunks = [tail[i:i + CHUNK] for i in range(0, len(tail), CHUNK)] or ["(no output)"]
for index, chunk in enumerate(chunks, start=1):
    body = chunk.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print(f"::error title={title} [{index}/{len(chunks)}]::{body}")
PY
}
