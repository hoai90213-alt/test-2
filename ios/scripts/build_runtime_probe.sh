#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIN_IOS="${MIN_IOS:-14.0}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/ios-native}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/artifacts}"
RUNTIME_OUT_DIR="$OUT_DIR/runtime-libs"
LOG_PATH="$OUT_DIR/runtime-probe-build.log"
BUILD_CONFIG="${BUILD_CONFIG:-Release}"
CMAKE_GENERATOR_IOS="${CMAKE_GENERATOR_IOS:-Xcode}"
CMAKE_GENERATOR_AMETHYST="${CMAKE_GENERATOR_AMETHYST:-Unix Makefiles}"
ZOMDROID_BUILD_GLFW="${ZOMDROID_BUILD_GLFW:-OFF}"
ZOMDROID_BUILD_LINKER="${ZOMDROID_BUILD_LINKER:-ON}"
ZOMDROID_BUILD_ANDROID_JNI="${ZOMDROID_BUILD_ANDROID_JNI:-OFF}"
ARM_DYNAREC="${ARM_DYNAREC:-ON}"
ARM64="${ARM64:-ON}"
REQUIRED_RUNTIME_LIBS="${REQUIRED_RUNTIME_LIBS:-libbox64.dylib libzomdroid.dylib libzomdroidlinker.dylib}"
CURRENT_BUILD_MODE=""

mkdir -p "$OUT_DIR" "$RUNTIME_OUT_DIR"
rm -rf "$BUILD_DIR"

get_sdk_path() {
  local sdk_path
  if sdk_path="$(xcrun --sdk iphoneos --show-sdk-path 2>/tmp/zomdroid-sdk.err)"; then
    printf '%s\n' "$sdk_path"
    return 0
  fi

  echo "[runtime_probe] xcrun failed to resolve iphoneos SDK:"
  cat /tmp/zomdroid-sdk.err || true
  rm -f /tmp/zomdroid-sdk.err

  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    echo "[runtime_probe] Trying to switch developer dir to /Applications/Xcode.app/Contents/Developer"
    sudo -n xcode-select -s /Applications/Xcode.app/Contents/Developer >/dev/null 2>&1 || true
  fi

  sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
  printf '%s\n' "$sdk_path"
}

cmake_build_targets() {
  local targets=(zomdroid)
  if [[ "$ZOMDROID_BUILD_LINKER" == "ON" ]]; then
    targets+=(zomdroidlinker box64)
  fi
  printf '%s\n' "${targets[@]}"
}

run_build_mode() {
  local mode="$1"
  local sdk_path="$2"
  local -a mode_args=()
  local -a build_targets=()
  local target

  while IFS= read -r target; do
    build_targets+=("$target")
  done < <(cmake_build_targets)

  if [[ "${#build_targets[@]}" -eq 0 ]]; then
    echo "[runtime_probe] No build targets resolved"
    return 1
  fi

  case "$mode" in
    ios-xcode)
      CURRENT_BUILD_MODE="$mode"
      mode_args=(
        -G "$CMAKE_GENERATOR_IOS"
        -DCMAKE_SYSTEM_NAME=iOS
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
      )
      ;;
    amethyst-darwin)
      CURRENT_BUILD_MODE="$mode"
      mode_args=(
        -G "$CMAKE_GENERATOR_AMETHYST"
        -DCMAKE_CROSSCOMPILING=true
        -DCMAKE_SYSTEM_NAME=Darwin
        -DCMAKE_SYSTEM_PROCESSOR=aarch64
        -DCMAKE_C_FLAGS=-arch\ arm64
        -DCMAKE_CXX_FLAGS=-arch\ arm64
      )
      ;;
    *)
      echo "[runtime_probe] Unknown build mode: $mode"
      return 1
      ;;
  esac

  echo "[runtime_probe] ===== Mode: $mode ====="
  rm -rf "$BUILD_DIR"

  cmake -S "$ROOT_DIR/app/src/main/cpp" -B "$BUILD_DIR" \
    "${mode_args[@]}" \
    -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_BUILD_TYPE="$BUILD_CONFIG" \
    -DZOMDROID_BUILD_GLFW="$ZOMDROID_BUILD_GLFW" \
    -DZOMDROID_BUILD_ANDROID_JNI="$ZOMDROID_BUILD_ANDROID_JNI" \
    -DZOMDROID_BUILD_LINKER="$ZOMDROID_BUILD_LINKER" \
    -DARM_DYNAREC="$ARM_DYNAREC" \
    -DARM64="$ARM64"

  echo "[runtime_probe] Building targets (${build_targets[*]})"
  cmake --build "$BUILD_DIR" \
    --config "$BUILD_CONFIG" \
    --target "${build_targets[@]}" \
    --parallel "$(sysctl -n hw.logicalcpu)"
}

{
  echo "[runtime_probe] ROOT_DIR=$ROOT_DIR"
  echo "[runtime_probe] MIN_IOS=$MIN_IOS"
  echo "[runtime_probe] BUILD_DIR=$BUILD_DIR"
  echo "[runtime_probe] RUNTIME_OUT_DIR=$RUNTIME_OUT_DIR"
  echo "[runtime_probe] BUILD_CONFIG=$BUILD_CONFIG"
  echo "[runtime_probe] CMAKE_GENERATOR_IOS=$CMAKE_GENERATOR_IOS"
  echo "[runtime_probe] CMAKE_GENERATOR_AMETHYST=$CMAKE_GENERATOR_AMETHYST"
  echo "[runtime_probe] ZOMDROID_BUILD_GLFW=$ZOMDROID_BUILD_GLFW"
  echo "[runtime_probe] ZOMDROID_BUILD_LINKER=$ZOMDROID_BUILD_LINKER"
  echo "[runtime_probe] ZOMDROID_BUILD_ANDROID_JNI=$ZOMDROID_BUILD_ANDROID_JNI"
  echo "[runtime_probe] xcode-select -p: $(xcode-select -p || true)"
  echo "[runtime_probe] xcodebuild: $(xcodebuild -version | tr '\n' ' ' || true)"

  SDK_PATH="$(get_sdk_path)"
  echo "[runtime_probe] SDK_PATH=$SDK_PATH"
  echo "[runtime_probe] Trying mode ios-xcode first, then amethyst-darwin fallback"

  if ! run_build_mode ios-xcode "$SDK_PATH"; then
    echo "[runtime_probe] ios-xcode mode failed, trying amethyst-darwin mode"
    run_build_mode amethyst-darwin "$SDK_PATH"
  fi

  dylibs=()
  while IFS= read -r dylib; do
    dylibs+=("$dylib")
  done < <(find "$BUILD_DIR" -type f -name "*.dylib" | sort)
  if [[ "${#dylibs[@]}" -eq 0 ]]; then
    echo "[runtime_probe] No dylibs were produced"
    echo "[runtime_probe] Last attempted mode: $CURRENT_BUILD_MODE"
    exit 1
  fi

  echo "[runtime_probe] Produced dylibs (mode=$CURRENT_BUILD_MODE):"
  for dylib in "${dylibs[@]}"; do
    dylib_size="$(stat -f%z "$dylib" 2>/dev/null || stat -c%s "$dylib")"
    echo "  $dylib ($dylib_size bytes)"
  done

  cp -f "${dylibs[@]}" "$RUNTIME_OUT_DIR/"
  missing_required=()
  for required_lib in $REQUIRED_RUNTIME_LIBS; do
    if [[ ! -f "$RUNTIME_OUT_DIR/$required_lib" ]]; then
      missing_required+=("$required_lib")
    fi
  done

  if [[ "${#missing_required[@]}" -gt 0 ]]; then
    echo "[runtime_probe] Missing required runtime libs:"
    printf '  %s\n' "${missing_required[@]}"
    echo "[runtime_probe] Available runtime libs:"
    ls -la "$RUNTIME_OUT_DIR"
    exit 1
  fi

  echo "[runtime_probe] Runtime package ready:"
  ls -la "$RUNTIME_OUT_DIR"
} 2>&1 | tee "$LOG_PATH"

echo "[runtime_probe] Done"
