#!/usr/bin/env bash
set -Eeuo pipefail

: "${SOURCE_ZIP:?SOURCE_ZIP is required}"
: "${BUILD_TARGET:?BUILD_TARGET is required}"
: "${REQUEST_ID:?REQUEST_ID is required}"

case "$BUILD_TARGET" in
  apk|aab|both) ;;
  *) echo "Invalid BUILD_TARGET" >&2; exit 2 ;;
esac

rm -rf handoff work
mkdir -p handoff/result handoff/logs work/project

status="failure"
failure_stage="initialization"
failure_kind="infrastructure"
failure_code=1
project_dir=""

write_status() {
  STATUS="$status" \
  FAILURE_STAGE="$failure_stage" \
  FAILURE_KIND="$failure_kind" \
  FAILURE_CODE="$failure_code" \
  PROJECT_DIR="$project_dir" \
  REQUEST_ID="$REQUEST_ID" \
  BUILD_TARGET="$BUILD_TARGET" \
  python3 - <<'PY'
import json, os
from pathlib import Path

root = Path("handoff")
root.mkdir(parents=True, exist_ok=True)
outputs = []
for output_type, extension in (("apk", ".apk"), ("aab", ".aab")):
    matches = sorted((root / "result").glob(f"*{extension}"))
    if not matches:
        continue
    path = matches[0]
    import hashlib
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    outputs.append({
        "type": output_type,
        "name": path.name,
        "sha256": digest,
        "size": path.stat().st_size,
    })

data = {
    "status": os.environ["STATUS"],
    "failure_stage": os.environ["FAILURE_STAGE"],
    "failure_kind": os.environ["FAILURE_KIND"],
    "failure_code": int(os.environ["FAILURE_CODE"]),
    "project_dir": os.environ["PROJECT_DIR"],
    "request_id": os.environ["REQUEST_ID"],
    "target": os.environ["BUILD_TARGET"],
    "outputs": outputs,
}
(root / "status.json").write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
}

on_exit() {
  local rc=$?
  trap - EXIT
  if [ "$status" != "success" ]; then
    failure_code="${failure_code:-$rc}"
    if [ "$failure_code" -eq 0 ]; then failure_code="$rc"; fi
  fi
  write_status
  rm -rf work/project
  if [ "$status" = "success" ]; then exit 0; fi
  exit "${failure_code:-1}"
}
trap on_exit EXIT

failure_stage="source_validation"
failure_kind="user"
python3 scripts/validate_zip.py "$SOURCE_ZIP" 2>&1 | tee handoff/logs/source-validation.log

failure_stage="source_extract"
python3 scripts/prepare_source.py "$SOURCE_ZIP" work/project 2>&1 | tee handoff/logs/source-extract.log
project_dir="$(python3 scripts/find_flutter_project.py work/project)"
test -n "$project_dir"
test -f "$project_dir/pubspec.yaml"
test -d "$project_dir/android"

if [ "${JAVA_SETUP_OUTCOME:-success}" != "success" ]; then
  failure_stage="java_setup"
  failure_kind="infrastructure"
  failure_code=11
  exit "$failure_code"
fi
if [ "${FLUTTER_SETUP_OUTCOME:-success}" != "success" ]; then
  failure_stage="flutter_setup"
  failure_kind="infrastructure"
  failure_code=12
  exit "$failure_code"
fi

failure_stage="flutter_pub_get"
failure_kind="user"
(
  cd "$project_dir"
  flutter --version
  flutter pub get
) 2>&1 | tee handoff/logs/flutter-pub-get.log

if [ "$BUILD_TARGET" = "apk" ] || [ "$BUILD_TARGET" = "both" ]; then
  failure_stage="flutter_build_apk"
  (
    cd "$project_dir"
    flutter build apk --release
  ) 2>&1 | tee handoff/logs/flutter-build-apk.log

  apk_path="$project_dir/build/app/outputs/flutter-apk/app-release.apk"
  if [ ! -s "$apk_path" ]; then
    apk_path="$(find "$project_dir/build/app/outputs/flutter-apk" -maxdepth 1 -type f -name '*release*.apk' -size +0c | sort | head -n 1 || true)"
  fi
  if [ -z "$apk_path" ] || [ ! -s "$apk_path" ]; then
    failure_stage="apk_output_missing"
    failure_code=20
    exit "$failure_code"
  fi
  cp "$apk_path" "handoff/result/${REQUEST_ID}.apk"
fi

if [ "$BUILD_TARGET" = "aab" ] || [ "$BUILD_TARGET" = "both" ]; then
  failure_stage="flutter_build_aab"
  (
    cd "$project_dir"
    flutter build appbundle --release
  ) 2>&1 | tee handoff/logs/flutter-build-aab.log

  aab_path="$project_dir/build/app/outputs/bundle/release/app-release.aab"
  if [ ! -s "$aab_path" ]; then
    aab_path="$(find "$project_dir/build/app/outputs/bundle" -type f -name '*release*.aab' -size +0c | sort | head -n 1 || true)"
  fi
  if [ -z "$aab_path" ] || [ ! -s "$aab_path" ]; then
    failure_stage="aab_output_missing"
    failure_code=30
    exit "$failure_code"
  fi
  cp "$aab_path" "handoff/result/${REQUEST_ID}.aab"
fi

status="success"
failure_stage="none"
failure_kind="none"
failure_code=0
write_status
