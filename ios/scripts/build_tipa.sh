#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_NAME="${APP_NAME:-ZomdroidIOSPoC}"
BUNDLE_ID="${BUNDLE_ID:-org.zomdroid.iospoc}"
MIN_IOS="${MIN_IOS:-14.0}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/artifacts}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/ios}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
FRAMEWORKS_DIR="$APP_DIR/Frameworks"
PAYLOAD_DIR="$OUT_DIR/Payload"
TIPA_PATH="$OUT_DIR/${APP_NAME}.tipa"
RUNTIME_LIB_DIR="${RUNTIME_LIB_DIR:-$OUT_DIR/runtime-libs}"
REQUIRE_RUNTIME_LIBS="${REQUIRE_RUNTIME_LIBS:-0}"
REQUIRED_RUNTIME_LIBS="${REQUIRED_RUNTIME_LIBS:-libbox64.dylib libzomdroid.dylib libzomdroidlinker.dylib}"
MIN_TIPA_SIZE_BYTES="${MIN_TIPA_SIZE_BYTES:-0}"
STUB_RUNTIME_MARKER="${RUNTIME_LIB_DIR}/STUB_RUNTIME.txt"
ALLOW_SMALL_TIPA_WITH_STUB="${ALLOW_SMALL_TIPA_WITH_STUB:-0}"

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG_BIN="$(xcrun --sdk iphoneos --find clang)"

file_size_bytes() {
  local file_path="$1"
  if stat -f%z "$file_path" >/dev/null 2>&1; then
    stat -f%z "$file_path"
  else
    stat -c%s "$file_path"
  fi
}

echo "[build_tipa] Cleaning previous build output"
rm -rf "$BUILD_DIR" "$PAYLOAD_DIR" "$TIPA_PATH"
mkdir -p "$APP_DIR" "$FRAMEWORKS_DIR" "$PAYLOAD_DIR"
echo "[build_tipa] APP_NAME=$APP_NAME"
echo "[build_tipa] BUNDLE_ID=$BUNDLE_ID"
echo "[build_tipa] RUNTIME_LIB_DIR=$RUNTIME_LIB_DIR"
echo "[build_tipa] REQUIRE_RUNTIME_LIBS=$REQUIRE_RUNTIME_LIBS"
echo "[build_tipa] REQUIRED_RUNTIME_LIBS=$REQUIRED_RUNTIME_LIBS"

echo "[build_tipa] Compiling iOS executable"
"$CLANG_BIN" \
  -arch arm64 \
  -isysroot "$SDK_PATH" \
  -miphoneos-version-min="$MIN_IOS" \
  -fobjc-arc \
  -Wl,-rpath,@executable_path/Frameworks \
  -framework UIKit \
  -framework Foundation \
  "$ROOT_DIR/ios/bootstrap/main.m" \
  -o "$APP_DIR/$APP_NAME"
chmod 755 "$APP_DIR/$APP_NAME"

echo "[build_tipa] Preparing Info.plist"
cp "$ROOT_DIR/ios/bootstrap/Info.plist" "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $MIN_IOS" "$APP_DIR/Info.plist"

echo "[build_tipa] Preparing entitlements"
ENTITLEMENTS_PATH="$BUILD_DIR/entitlements.plist"
cp "$ROOT_DIR/ios/bootstrap/entitlements.trollstore.plist" "$ENTITLEMENTS_PATH"
/usr/libexec/PlistBuddy -c "Set :application-identifier $BUNDLE_ID" "$ENTITLEMENTS_PATH"

if command -v ldid >/dev/null 2>&1; then
  echo "[build_tipa] Signing with ldid"
  ldid -S"$ENTITLEMENTS_PATH" "$APP_DIR/$APP_NAME"
else
  echo "[build_tipa] ldid not found, using ad-hoc codesign fallback"
  codesign -s - --force "$APP_DIR/$APP_NAME"
fi

runtime_candidates=()
if [[ -d "$RUNTIME_LIB_DIR" ]]; then
  shopt -s nullglob
  runtime_candidates=("$RUNTIME_LIB_DIR"/*.dylib)
  shopt -u nullglob
fi

if [[ -f "$STUB_RUNTIME_MARKER" ]] && [[ "$ALLOW_SMALL_TIPA_WITH_STUB" == "1" ]] && [[ "$MIN_TIPA_SIZE_BYTES" -gt 0 ]]; then
  echo "::warning title=build_tipa::Stub runtime detected, skipping minimum .tipa size threshold"
  MIN_TIPA_SIZE_BYTES=0
fi

if [[ "${#runtime_candidates[@]}" -eq 0 ]]; then
  if [[ "$REQUIRE_RUNTIME_LIBS" == "1" ]]; then
    echo "[build_tipa] ERROR: runtime libs are required but none were found in $RUNTIME_LIB_DIR"
    exit 1
  fi
  echo "[build_tipa] No runtime dylibs found, continuing bootstrap-only package"
else
  echo "[build_tipa] Copying runtime dylibs from $RUNTIME_LIB_DIR"
  cp -f "${runtime_candidates[@]}" "$FRAMEWORKS_DIR/"
  chmod 755 "$FRAMEWORKS_DIR"/*.dylib
  if command -v ldid >/dev/null 2>&1; then
    for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
      ldid -S "$dylib"
    done
  else
    for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
      codesign -s - --force "$dylib"
    done
  fi
fi

if [[ "$REQUIRE_RUNTIME_LIBS" == "1" ]]; then
  missing_required=()
  for required_lib in $REQUIRED_RUNTIME_LIBS; do
    if [[ ! -f "$FRAMEWORKS_DIR/$required_lib" ]]; then
      missing_required+=("$required_lib")
    fi
  done
  if [[ "${#missing_required[@]}" -gt 0 ]]; then
    echo "[build_tipa] ERROR: missing required runtime libs in Frameworks:"
    printf '  %s\n' "${missing_required[@]}"
    echo "[build_tipa] Existing Frameworks content:"
    ls -la "$FRAMEWORKS_DIR"
    exit 1
  fi
fi

echo "[build_tipa] Packaging Payload"
cp -R "$APP_DIR" "$PAYLOAD_DIR/"

(
  cd "$OUT_DIR"
  zip -qry "$(basename "$TIPA_PATH")" Payload
)

if [[ "$REQUIRE_RUNTIME_LIBS" == "1" ]]; then
  package_missing=()
  zip_entries="$(unzip -Z1 "$TIPA_PATH")"
  for required_lib in $REQUIRED_RUNTIME_LIBS; do
    required_path="Payload/$APP_NAME.app/Frameworks/$required_lib"
    if ! printf '%s\n' "$zip_entries" | grep -Fxq "$required_path"; then
      package_missing+=("$required_path")
    fi
  done
  if [[ "${#package_missing[@]}" -gt 0 ]]; then
    echo "[build_tipa] ERROR: missing required files in .tipa payload:"
    printf '  %s\n' "${package_missing[@]}"
    exit 1
  fi
fi

tipa_size_bytes="$(file_size_bytes "$TIPA_PATH")"
echo "[build_tipa] Output size: $tipa_size_bytes bytes"
if [[ "$MIN_TIPA_SIZE_BYTES" -gt 0 ]] && [[ "$tipa_size_bytes" -lt "$MIN_TIPA_SIZE_BYTES" ]]; then
  echo "[build_tipa] ERROR: .tipa size is below threshold ($MIN_TIPA_SIZE_BYTES bytes)"
  exit 1
fi

echo "[build_tipa] Done: $TIPA_PATH"
