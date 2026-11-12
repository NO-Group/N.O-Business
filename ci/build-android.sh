#!/usr/bin/env bash
# ============================================================================
# MFSL Office - Android build + publish (GitHub Actions / any Linux box).
#
# ALL CI logic lives here in ci/ so that .github/workflows/build-mfsl.yml
# never has to change: editing files under .github/workflows/ requires a
# GitHub token with the special "workflows" permission, while normal git
# pushes to ci/ work for everyone. Change the build HERE, not in the shim.
#
# What it does:
#   1. Installs Flutter (stable) by shallow clone - no setup action needed.
#   2. Builds the release APK.
#   3. Uploads it to the rolling GitHub Release tagged "ci" as a RAW asset.
#      GitHub serves release assets byte-for-byte: never re-zipped, never
#      encrypted. The download IS "MFSL.Inventory.apk" - nothing to extract,
#      and no "password protected" errors, ever.
#
# Local usage: bash ci/build-android.sh   (needs flutter + gh + a checkout)
# ============================================================================
set -euo pipefail

# --- 0. Exhaustive app-contract gate -----------------------------------------
# Enumerates all 50 API routes, every client /api path and response key, the
# 20 collections, 5 SQL RPCs and grants, operators, versions, dart-defines
# and CI gates. ANY drift fails the build before Flutter is even installed.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$REPO_ROOT/tools/contract_audit.py"

# Gradle 9 needs JDK >= 17; runners ship several JDKs, pin 17 when present.
if [ -n "${JAVA_HOME_17_X64:-}" ]; then
  export JAVA_HOME="${JAVA_HOME_17_X64}"
fi

# --- 1. Flutter (stable) -----------------------------------------------------
FLUTTER_DIR="${RUNNER_TEMP:-/tmp}/flutter"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version

# --- 2. Build -----------------------------------------------------------------
cd "$(cd "$(dirname "$0")" && pwd)/../app"
flutter pub get
# Render every document type headlessly first: a PDF layout/asset bug must
# fail the build here with the real exception (see app/test/pdf_build_test.dart).
set +e
flutter test > "${RUNNER_TEMP:-/tmp}/pdf-test.log" 2>&1
TEST_RC=$?
set -e
tail -80 "${RUNNER_TEMP:-/tmp}/pdf-test.log"
# publish the test log to the rolling release so it can be read remotely
R="${GITHUB_REPOSITORY:-NO-Group/mtek_fire_safety_ltd}"
if command -v gh >/dev/null && [ -n "${GH_TOKEN:-}" ]; then
  RID=$(gh api "repos/$R/releases/tags/ci" -q .id 2>/dev/null || true)
  if [ -n "$RID" ]; then
    AID=$(gh api "repos/$R/releases/$RID/assets" -q '.[] | select(.name=="pdf-test.log") | .id' 2>/dev/null || true)
    [ -n "$AID" ] && gh api -X DELETE "repos/$R/releases/assets/$AID" >/dev/null 2>&1 || true
    curl -sf -X POST -H "Authorization: Bearer $GH_TOKEN" -H "Content-Type: text/plain" \
      --data-binary @"${RUNNER_TEMP:-/tmp}/pdf-test.log" \
      "https://uploads.github.com/repos/$R/releases/$RID/assets?name=pdf-test.log" >/dev/null || true
  fi
fi
if [ "$TEST_RC" -ne 0 ]; then
  echo "PDF render test FAILED (see pdf-test.log on the ci release)"
  # Keep compiler/test failures readable even when the Actions log CDN is
  # unavailable: attach the final lines as a commit comment via GitHub's API.
  if command -v gh >/dev/null && [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_SHA:-}" ]; then
    TAIL=$(tail -c 12000 "${RUNNER_TEMP:-/tmp}/pdf-test.log")
    gh api "repos/$R/commits/$GITHUB_SHA/comments" -f body="Build diagnostic:\n\n\`\`\`text\n$TAIL\n\`\`\`" >/dev/null 2>&1 || true
    printf 'BUILD FAILED at %s\n\n```text\n%s\n```\n' "$GITHUB_SHA" "$TAIL" > "${RUNNER_TEMP:-/tmp}/failed-build-notes.md"
    gh release edit ci --notes-file "${RUNNER_TEMP:-/tmp}/failed-build-notes.md" >/dev/null 2>&1 || true
  fi
  exit "$TEST_RC"
fi
# Rasterise the rendered PDFs (page 1, 70 dpi) and commit them to docs/previews
# so document layout can be reviewed without a device. Best-effort.
if command -v pdftoppm >/dev/null || (sudo apt-get install -y -qq poppler-utils >/dev/null 2>&1); then
  mkdir -p ../docs/previews
  for f in build/pdf_preview/*.pdf; do
    pdftoppm -png -r 70 -f 1 -l 1 "$f" "../docs/previews/$(basename "${f%.pdf}")" && \
      mv "../docs/previews/$(basename "${f%.pdf}")-1.png" "../docs/previews/$(basename "${f%.pdf}").png" 2>/dev/null || true
  done
  ( cd .. && git config user.name ci-bot && git config user.email ci@users.noreply.github.com && \
    git add docs/previews && git diff --cached --quiet || \
    ( git commit -qm "ci: refresh PDF layout previews [skip ci]" && git push -q origin "HEAD:${GITHUB_REF_NAME}" ) ) || true
fi
# Reusable production identity. Once the two repository secrets are installed,
# every APK is signed by the same key and can update earlier MFSL Office builds.
if [ -n "${MFSL_ANDROID_KEYSTORE_BASE64:-}" ] && [ -n "${MFSL_SIGNING_PASSWORD:-}" ]; then
  KEYSTORE="${RUNNER_TEMP:-/tmp}/mfsl-office-android.p12"
  printf '%s' "$MFSL_ANDROID_KEYSTORE_BASE64" | base64 --decode > "$KEYSTORE"
  chmod 600 "$KEYSTORE"
  export MFSL_ANDROID_KEYSTORE="$KEYSTORE"
  export MFSL_ANDROID_STORE_PASSWORD="$MFSL_SIGNING_PASSWORD"
  export MFSL_ANDROID_KEY_PASSWORD="$MFSL_SIGNING_PASSWORD"
  export MFSL_ANDROID_KEY_ALIAS="com.n_o_group.mfsl_office"
  echo "Building with the persistent MFSL Office production signing key."
else
  echo "::warning::Production Android signing secrets are absent; using the debug identity."
fi
# Publish each APK with a strictly increasing Android versionCode. Without
# this, Android treats a newer download as the same/previous version instead
# of offering an in-place upgrade.
# Single source of truth: the `version: X.Y.Z+N` line in app/pubspec.yaml.
# The Edge Function advertises the SAME string on /health so installed builds
# can detect a newer release; fail the build rather than ship a mismatch.
PUB_VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '\r' | head -1)"
BUILD_NAME="${PUB_VERSION%%+*}"
APP_BUILD_NUMBER="${PUB_VERSION##*+}"
EDGE_VERSION="$(grep -o "const APP_VERSION = '[^']*'" ../supabase/functions/data-api/index.ts | head -1 | cut -d"'" -f2)"
if [ -z "$PUB_VERSION" ] || [ "$PUB_VERSION" != "$EDGE_VERSION" ]; then
  echo "::error::App version drift: pubspec.yaml='$PUB_VERSION' but data-api APP_VERSION='$EDGE_VERSION'. Both must match or the in-app update checker will be wrong."
  exit 1
fi
# Android versionCode must strictly INCREASE for in-place upgrades, so keep
# using the CI run number. The logical +N stays stable and is what the
# updater compares (Android's OS version string may legitimately differ).
ANDROID_VERSION_CODE="${GITHUB_RUN_NUMBER:-$APP_BUILD_NUMBER}"
echo "App version $PUB_VERSION (Android versionCode $ANDROID_VERSION_CODE)"
set +e
flutter build apk --release \
  --build-name="$BUILD_NAME" \
  --build-number="$ANDROID_VERSION_CODE" \
  --dart-define="APP_VERSION=${PUB_VERSION}" \
  > "${RUNNER_TEMP:-/tmp}/apk-build.log" 2>&1
BUILD_RC=$?
set -e
tail -100 "${RUNNER_TEMP:-/tmp}/apk-build.log"
if [ "$BUILD_RC" -ne 0 ]; then
  TAIL=$(tail -c 14000 "${RUNNER_TEMP:-/tmp}/apk-build.log")
  printf 'APK BUILD FAILED at %s\n\n```text\n%s\n```\n' "${GITHUB_SHA:-unknown}" "$TAIL" > "${RUNNER_TEMP:-/tmp}/failed-build-notes.md"
  gh release edit ci --notes-file "${RUNNER_TEMP:-/tmp}/failed-build-notes.md" >/dev/null 2>&1 || true
  exit "$BUILD_RC"
fi

APK="build/app/outputs/flutter-apk/app-release.apk"
test -s "$APK"

STAGE="${RUNNER_TEMP:-/tmp}/MFSL.Inventory.apk"  # dots: GitHub renames asset spaces to dots
cp "$APK" "$STAGE"

# --- 3. Publish to the rolling "ci" release (raw asset, no zip wrapper) -------
TAG="ci"
TITLE="MFSL Office - auto builds (rolling)"
NOTES="$(mktemp)"
SHA="${GITHUB_SHA:-local}"
REF="${GITHUB_REF_NAME:-local}"
{
  echo "Auto build \`${SHA:0:7}\` ($REF), $(date -u '+%Y-%m-%d %H:%M UTC')."
  echo "Version \`${PUB_VERSION}\` | Android versionCode \`${ANDROID_VERSION_CODE}\` | commit \`${SHA}\` | run \`${GITHUB_RUN_NUMBER:-local}\`."
  echo ""
  echo "These assets are RAW files - GitHub never re-zips release assets, so there is"
  echo "nothing to extract and no \"password protected\" errors. Ever."
  echo ""
  echo "- \`MFSL.Inventory.apk\` - sideload onto Android (open this link on the phone)."
  echo "- \`MFSL.Inventory.Setup.msix\` - Windows installer (from the Windows job)."
  echo "- \`MFSL-Office-portable.zip\` - portable Windows folder (from the Windows job)."
} >"$NOTES"

# View-or-create, then upload with retries: the Windows job runs in parallel
# and touches the same release; per-asset last writer wins, which is fine.
for _ in 1 2 3; do
  gh release view "$TAG" >/dev/null 2>&1 ||
    gh release create "$TAG" --target "${GITHUB_SHA:-HEAD}" --prerelease \
      --title "$TITLE" --notes-file "$NOTES" >/dev/null 2>&1 || true
  if gh release upload "$TAG" "$STAGE" --clobber; then
    # Refresh notes so the body always shows the latest build (assets-only
    # uploads don't touch the body).
    gh release edit "$TAG" --notes-file "$NOTES" >/dev/null 2>&1 || true
    echo "Published $STAGE to release $TAG"
    exit 0
  fi
  sleep 15
done
echo "ERROR: could not upload $STAGE to release $TAG" >&2
exit 1
