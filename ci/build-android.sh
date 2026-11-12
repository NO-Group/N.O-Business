#!/usr/bin/env bash
# Builds the release Android APK into dist/.
#
# Backend configuration and signing material come from the environment and
# are never written to the repository:
#   NOB_SUPABASE_URL, NOB_SUPABASE_ANON_KEY   backend (public client key only)
#   NOB_ANDROID_KEYSTORE_BASE64               PKCS#12 keystore, base64
#   NOB_SIGNING_PASSWORD                      keystore + key password
#   NOB_ANDROID_KEY_ALIAS                     optional, defaults to no-business
#
# Without the backend values the app still builds and opens on a screen that
# explains it has not been configured. Without the signing values the APK is
# signed with the debug key and must not be distributed.
#
# Usage: bash ci/build-android.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Gradle needs JDK 17+. GitHub runners expose several; prefer 17 when present.
if [ -n "${JAVA_HOME_17_X64:-}" ]; then
  export JAVA_HOME="$JAVA_HOME_17_X64"
fi

install_flutter
cd "$REPO_ROOT/app"

PUB_VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '\r' | head -1)"
BUILD_NAME="${PUB_VERSION%%+*}"
# versionCode must increase with every published build; use the CI run number.
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-${PUB_VERSION##*+}}"

if [ -z "${NOB_SUPABASE_URL:-}" ] || [ -z "${NOB_SUPABASE_ANON_KEY:-}" ]; then
  echo "::warning::NOB_SUPABASE_URL / NOB_SUPABASE_ANON_KEY are not set; this build opens on the 'not configured' screen."
fi

if [ -n "${NOB_ANDROID_KEYSTORE_BASE64:-}" ] && [ -n "${NOB_SIGNING_PASSWORD:-}" ]; then
  KEYSTORE="$WORK_DIR/no-business-release.p12"
  ( umask 077 && printf '%s' "$NOB_ANDROID_KEYSTORE_BASE64" | base64 --decode > "$KEYSTORE" )
  trap 'rm -f "$KEYSTORE"' EXIT
  export NOB_ANDROID_KEYSTORE="$KEYSTORE"
  export NOB_ANDROID_STORE_PASSWORD="$NOB_SIGNING_PASSWORD"
  export NOB_ANDROID_KEY_PASSWORD="$NOB_SIGNING_PASSWORD"
  echo "Signing with the release key."
else
  echo "::warning::Release signing secrets are not set; the APK is signed with the debug key and is for testing only."
fi

run_step "flutter pub get" flutter pub get
run_step "flutter build apk" flutter build apk --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define="APP_VERSION=$BUILD_NAME+$BUILD_NUMBER" \
  --dart-define="SUPABASE_URL=${NOB_SUPABASE_URL:-}" \
  --dart-define="SUPABASE_ANON_KEY=${NOB_SUPABASE_ANON_KEY:-}"

APK="build/app/outputs/flutter-apk/app-release.apk"
test -s "$APK"
mkdir -p "$REPO_ROOT/dist"
cp "$APK" "$REPO_ROOT/dist/NO-Business-$BUILD_NAME.apk"
ls -l "$REPO_ROOT/dist"
