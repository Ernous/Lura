#!/usr/bin/env bash
set -euo pipefail

# This script creates a Flutter app (if missing), wires channels, adds xterm, and
# prepares Android Gradle to consume the gomobile AAR built from ./termbridge.

APP_DIR=${APP_DIR:-"flutter_app"}
CHANNEL_METHOD=${CHANNEL_METHOD:-"game.method"}
CHANNEL_EVENTS=${CHANNEL_EVENTS:-"game.events"}

command -v flutter >/dev/null 2>&1 || {
  echo "[setup] flutter not found. Install Flutter SDK and ensure it is on PATH." >&2
  exit 1
}

echo "[setup] Ensuring Flutter app exists at ${APP_DIR}"
if [[ ! -d "${APP_DIR}" ]]; then
  flutter create --org com.example --project-name lura_flutter "${APP_DIR}"
fi

pushd "${APP_DIR}" >/dev/null

echo "[setup] Adding xterm dependency"
flutter pub add xterm >/dev/null

echo "[setup] Writing lib/main.dart from template"
install -d lib
cp -f ../templates/flutter/lib/main.dart lib/main.dart

echo "[setup] Ensuring android/app/libs exists"
mkdir -p android/app/libs

APP_BUILD_GRADLE=android/app/build.gradle.kts
echo "[setup] Patching ${APP_BUILD_GRADLE} to include AAR and packaging options"

# Skip patching since we're using Kotlin DSL with different syntax
echo "[setup] Using Kotlin DSL build configuration - skipping Groovy-style patches"

echo "[setup] Ensuring minSdk >= 23"
# Skip minSdk patching for Kotlin DSL as it uses different syntax
echo "[setup] minSdk configuration handled in Kotlin DSL build file"

APP_BUILD_GRADLE_PROJ=android/build.gradle.kts
if ! grep -q "flatDir" "$APP_BUILD_GRADLE_PROJ"; then
  echo "[setup] flatDir repository already configured in project-level Kotlin DSL"
fi

# Skip repository and dependency configuration for Kotlin DSL
echo "[setup] Repository and dependency configuration handled in Kotlin DSL build files"

echo "[setup] Updating MainActivity to wire channels"
MAIN_ACTIVITY_FILE=$(find android/app/src/main/kotlin -name MainActivity.kt | head -n 1)
if [[ -z "${MAIN_ACTIVITY_FILE}" ]]; then
  echo "[setup] ERROR: MainActivity.kt not found" >&2
  exit 1
fi

PKG_LINE=$(grep -E '^package ' "${MAIN_ACTIVITY_FILE}" | head -n 1 || true)
PKG_NAME=${PKG_LINE#package }
if [[ -z "${PKG_NAME}" ]]; then
  PKG_NAME="com.example.lura_flutter"
fi

echo "[setup] Writing MainActivity from template"
PKG_ESCAPED=$(printf '%s' "$PKG_NAME" | sed 's/[\/&]/\\&/g')
sed -e "s/\${PACKAGE_NAME}/${PKG_ESCAPED}/g" \
    -e "s/\${CHANNEL_METHOD}/${CHANNEL_METHOD}/g" \
    -e "s/\${CHANNEL_EVENTS}/${CHANNEL_EVENTS}/g" \
    ../templates/android/MainActivity.kt > "${MAIN_ACTIVITY_FILE}"

popd >/dev/null

echo "[setup] Flutter app is ready: ${APP_DIR}"

