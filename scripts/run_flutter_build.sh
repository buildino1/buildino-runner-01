#!/usr/bin/env bash
set -Eeuo pipefail

: "${SOURCE_ZIP:?SOURCE_ZIP is required}"
: "${BUILD_TARGET:?BUILD_TARGET is required}"
: "${REQUEST_ID:?REQUEST_ID is required}"

case "$BUILD_TARGET" in apk|aab|both) ;; *) echo "Invalid BUILD_TARGET" >&2; exit 2 ;; esac

rm -rf handoff work
mkdir -p handoff/result handoff/logs work/project

status="failure"
failure_stage="initialization"
failure_kind="infrastructure"
failure_code=1
project_dir=""
current_log=""
fallback_signing_used="false"
java_version=""
flavors_json="[]"

write_status() {
  STATUS="$status" FAILURE_STAGE="$failure_stage" FAILURE_KIND="$failure_kind" \
  FAILURE_CODE="$failure_code" PROJECT_DIR="$project_dir" REQUEST_ID="$REQUEST_ID" \
  BUILD_TARGET="$BUILD_TARGET" FALLBACK_SIGNING_USED="$fallback_signing_used" \
  JAVA_VERSION="$java_version" FLAVORS_JSON="$flavors_json" python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
root = Path("handoff")
outputs = []
for path in sorted((root / "result").glob("*")):
    if not path.is_file() or path.suffix not in {".apk", ".aab"}:
        continue
    outputs.append({"type": path.suffix[1:], "name": path.name,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "size": path.stat().st_size})
data = {
    "status": os.environ["STATUS"], "failure_stage": os.environ["FAILURE_STAGE"],
    "failure_kind": os.environ["FAILURE_KIND"], "failure_code": int(os.environ["FAILURE_CODE"]),
    "project_dir": os.environ["PROJECT_DIR"], "request_id": os.environ["REQUEST_ID"],
    "target": os.environ["BUILD_TARGET"], "outputs": outputs,
    "fallback_signing_used": os.environ.get("FALLBACK_SIGNING_USED") == "true",
    "java_version": os.environ.get("JAVA_VERSION") or None,
    "flavors": json.loads(os.environ.get("FLAVORS_JSON", "[]")),
}
report = root / "error-report.json"
if report.is_file():
    data["error_report"] = json.loads(report.read_text(encoding="utf-8"))
(root / "status.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

create_error_report() {
  local args=(--stage "$failure_stage" --code "$failure_code" --output handoff/error-report.json)
  [ -s handoff/preflight.json ] && args+=(--preflight handoff/preflight.json)
  for log in handoff/logs/*.log; do [ -f "$log" ] && args+=(--log "$log"); done
  python3 scripts/analyze_build_error.py "${args[@]}" || true
}

on_exit() {
  local rc=$?
  trap - EXIT
  if [ "$status" != "success" ]; then
    if [ "${failure_code:-0}" -eq 0 ] || [ "${failure_code:-1}" -eq 1 ]; then failure_code="$rc"; fi
    [ "$failure_code" -eq 0 ] && failure_code=1
    create_error_report
  fi
  write_status
  rm -rf work/project
  if [ "$status" = "success" ]; then exit 0; fi
  exit "${failure_code:-1}"
}
trap on_exit EXIT

run_logged() {
  local stage="$1" kind="$2" code="$3" log="$4"; shift 4
  failure_stage="$stage"; failure_kind="$kind"; failure_code="$code"; current_log="$log"
  set +e
  "$@" 2>&1 | tee "$log"
  local rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ]; then failure_code="$rc"; return "$rc"; fi
  return 0
}

failure_stage="source_validation"; failure_kind="user"; failure_code=3
python3 scripts/validate_zip.py "$SOURCE_ZIP" 2>&1 | tee handoff/logs/source-validation.log
failure_stage="source_extract"; failure_code=4
python3 scripts/prepare_source.py "$SOURCE_ZIP" work/project 2>&1 | tee handoff/logs/source-extract.log
project_dir="$(python3 scripts/find_flutter_project.py work/project)"
test -n "$project_dir" && test -f "$project_dir/pubspec.yaml" && test -d "$project_dir/android"

if [ "${FLUTTER_SETUP_OUTCOME:-success}" != "success" ]; then failure_stage="flutter_setup"; failure_kind="infrastructure"; failure_code=12; exit 12; fi
if [ "${JAVA11_SETUP_OUTCOME:-success}" != "success" ] || [ "${JAVA17_SETUP_OUTCOME:-success}" != "success" ] || [ "${JAVA21_SETUP_OUTCOME:-success}" != "success" ]; then
  failure_stage="java_setup"; failure_kind="infrastructure"; failure_code=11; exit 11
fi

failure_stage="project_preflight"; failure_kind="user"; failure_code=13
python3 scripts/buildino_preflight.py "$project_dir" handoff/preflight.json 2>&1 | tee handoff/logs/preflight.log
java_version="$(python3 -c 'import json; print(json.load(open("handoff/preflight.json"))["java_version"])')"
java_home="$(python3 -c 'import json; print(json.load(open("handoff/preflight.json"))["java_home"])')"
fallback_signing_used="$(python3 -c 'import json; print(str(json.load(open("handoff/preflight.json"))["fallback_signing_used"]).lower())')"
flavors_json="$(python3 -c 'import json; print(json.dumps(json.load(open("handoff/preflight.json"))["flavors"], separators=(",",":")))')"
export JAVA_HOME="$java_home"
export PATH="$JAVA_HOME/bin:$PATH"
java -version 2>&1 | tee handoff/logs/java-selected.log

failure_stage="flutter_pub_get"; failure_kind="user"; failure_code=14
set +e
(
  cd "$project_dir"
  flutter --version
  flutter pub get
) 2>&1 | tee handoff/logs/flutter-pub-get.log
rc=${PIPESTATUS[0]}; set -e
[ "$rc" -eq 0 ] || { failure_code="$rc"; exit "$rc"; }

mapfile -t flavors < <(python3 -c 'import json; print("\n".join(json.load(open("handoff/preflight.json"))["flavors"]))')
if [ "${#flavors[@]}" -eq 0 ]; then flavors=(""); fi

build_one() {
  local type="$1" flavor="$2" log suffix cmd output_dir pattern output_path
  if [ "$type" = "apk" ]; then
    suffix="apk"; output_dir="$project_dir/build/app/outputs/flutter-apk"; pattern='*release*.apk'
    cmd=(flutter build apk --release)
  else
    suffix="aab"; output_dir="$project_dir/build/app/outputs/bundle"; pattern='*release*.aab'
    cmd=(flutter build appbundle --release)
  fi
  if [ -n "$flavor" ]; then cmd+=(--flavor "$flavor"); fi
  local label="${type}${flavor:+-$flavor}"
  log="handoff/logs/flutter-build-${label}.log"
  failure_stage="flutter_build_${label//-/_}"; failure_kind="user"; failure_code=20
  set +e
  (cd "$project_dir" && "${cmd[@]}") 2>&1 | tee "$log"
  local rc=${PIPESTATUS[0]}; set -e
  [ "$rc" -eq 0 ] || { failure_code="$rc"; return "$rc"; }
  if [ "$type" = "apk" ]; then
    output_path="$(find "$output_dir" -maxdepth 1 -type f -name "$pattern" -size +0c | { [ -n "$flavor" ] && grep -i "$flavor" || cat; } | sort | tail -n 1 || true)"
  else
    output_path="$(find "$output_dir" -type f -name "$pattern" -size +0c | { [ -n "$flavor" ] && grep -i "$flavor" || cat; } | sort | tail -n 1 || true)"
  fi
  if [ -z "$output_path" ] || [ ! -s "$output_path" ]; then failure_stage="${type}_output_missing"; failure_code=30; return 30; fi
  cp "$output_path" "handoff/result/${REQUEST_ID}${flavor:+-$flavor}.${suffix}"
}

if [ "$BUILD_TARGET" = "apk" ] || [ "$BUILD_TARGET" = "both" ]; then
  for flavor in "${flavors[@]}"; do build_one apk "$flavor" || exit $?; done
fi
if [ "$BUILD_TARGET" = "aab" ] || [ "$BUILD_TARGET" = "both" ]; then
  for flavor in "${flavors[@]}"; do build_one aab "$flavor" || exit $?; done
fi

status="success"; failure_stage="none"; failure_kind="none"; failure_code=0
write_status
