#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEPENDS_DIR="${DEPENDS_DIR:-$ROOT_DIR/depends}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/artifacts/runtime-import}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/artifacts/runtime-work}"
RUNTIME_NAME="${RUNTIME_NAME:-runtime}"

echo "[prepare_runtime] ROOT_DIR=$ROOT_DIR"
echo "[prepare_runtime] DEPENDS_DIR=$DEPENDS_DIR"
echo "[prepare_runtime] OUT_DIR=$OUT_DIR"

rm -rf "$OUT_DIR" "$WORK_DIR"
mkdir -p "$OUT_DIR" "$WORK_DIR"

extract_one() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  case "$src" in
    *.tar.xz|*.txz|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar)
      tar -xf "$src" -C "$dst"
      ;;
    *.zip)
      unzip -q "$src" -d "$dst"
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

maybe_extract_tree() {
  local src_dir="$1"
  local changed=0
  while IFS= read -r -d '' archive; do
    local rel
    rel="$(basename "$archive")"
    local dst="$WORK_DIR/extract-${rel//[^A-Za-z0-9._-]/_}"
    if extract_one "$archive" "$dst"; then
      changed=1
    fi
  done < <(find "$src_dir" -type f \( -name "*.zip" -o -name "*.tar" -o -name "*.tar.xz" -o -name "*.txz" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" -o -name "*.tbz2" \) -print0 || true)
  return "$changed"
}

if [[ -d "$DEPENDS_DIR" ]]; then
  cp -R "$DEPENDS_DIR"/. "$WORK_DIR/raw" 2>/dev/null || true
fi

if [[ -d "$WORK_DIR/raw" ]]; then
  maybe_extract_tree "$WORK_DIR/raw" || true
fi
maybe_extract_tree "$WORK_DIR" || true

mapfile -d '' JVM_LIST < <(find "$WORK_DIR" -type f -name "libjvm.dylib" -print0 || true)
if [[ "${#JVM_LIST[@]}" -eq 0 ]]; then
  echo "[prepare_runtime] ERROR: no libjvm.dylib found under $WORK_DIR"
  exit 1
fi

selected_jvm=""
for candidate in "${JVM_LIST[@]}"; do
  if [[ "$candidate" == */lib/server/libjvm.dylib ]]; then
    selected_jvm="$candidate"
    break
  fi
done
if [[ -z "$selected_jvm" ]]; then
  selected_jvm="${JVM_LIST[0]}"
fi

runtime_root=""
if [[ "$selected_jvm" == */lib/server/libjvm.dylib ]]; then
  runtime_root="$(dirname "$(dirname "$(dirname "$selected_jvm")")")"
elif [[ "$selected_jvm" == */lib/libjvm.dylib ]]; then
  runtime_root="$(dirname "$(dirname "$selected_jvm")")"
else
  runtime_root="$(dirname "$selected_jvm")"
fi

if [[ ! -d "$runtime_root" ]]; then
  echo "[prepare_runtime] ERROR: runtime root not found for $selected_jvm"
  exit 1
fi

runtime_out="$OUT_DIR/$RUNTIME_NAME"
mkdir -p "$runtime_out"
cp -R "$runtime_root"/. "$runtime_out"/

if [[ ! -f "$runtime_out/lib/server/libjvm.dylib" && -f "$runtime_out/lib/libjvm.dylib" ]]; then
  mkdir -p "$runtime_out/lib/server"
  cp "$runtime_out/lib/libjvm.dylib" "$runtime_out/lib/server/libjvm.dylib"
fi

if [[ ! -f "$runtime_out/lib/server/libjvm.dylib" ]]; then
  echo "[prepare_runtime] ERROR: prepared runtime missing lib/server/libjvm.dylib"
  exit 1
fi

magic="$(xxd -p -l 4 "$runtime_out/lib/server/libjvm.dylib" | tr -d '\n' | tr '[:lower:]' '[:upper:]')"
human_magic="${magic:0:2}-${magic:2:2}-${magic:4:2}-${magic:6:2}"

{
  echo "runtime_path=$runtime_out"
  echo "libjvm=$runtime_out/lib/server/libjvm.dylib"
  echo "magic=$human_magic"
  echo "size_bytes=$(wc -c < "$runtime_out/lib/server/libjvm.dylib" | tr -d ' ')"
  if command -v file >/dev/null 2>&1; then
    file "$runtime_out/lib/server/libjvm.dylib"
  fi
} | tee "$OUT_DIR/runtime-summary.txt"

cd "$OUT_DIR"
zip -qr "runtime-import.zip" "$RUNTIME_NAME"
echo "[prepare_runtime] done: $OUT_DIR/runtime-import.zip"
