#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "${ROOT_DIR}/../.." && pwd)"
fi
FORMAT="text"
OUTPUT_PATH="${ROOT_DIR}/results/slither-gate-latest.txt"
TARGET_DIR="${REPO_ROOT}/karma-core/contracts/core/SettlementEngine.sol"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/slither-gate.sh [--format <text|json>] [--output <path>] [--target <path>] [--path-filter <glob>]

Description:
  Runs Slither static analysis against repo target; returns non-zero on findings.
  If Slither is not installed, exits non-zero with actionable guidance.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      [[ $# -lt 2 ]] && { echo "Error: --format requires a value"; exit 1; }
      FORMAT="$2"
      if [[ "$FORMAT" != "text" && "$FORMAT" != "json" ]]; then
        echo "Error: --format must be text or json"
        exit 1
      fi
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && { echo "Error: --output requires a value"; exit 1; }
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --target)
      [[ $# -lt 2 ]] && { echo "Error: --target requires a value"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --path-filter)
      [[ $# -lt 2 ]] && { echo "Error: --path-filter requires a value"; exit 1; }
      PATH_FILTER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="${ROOT_DIR}/${OUTPUT_PATH}"
fi
if [[ "$TARGET_DIR" != /* ]]; then
  TARGET_DIR="${ROOT_DIR}/${TARGET_DIR}"
fi
mkdir -p "$(dirname "$OUTPUT_PATH")"

if [[ ! -e "$TARGET_DIR" ]]; then
  msg="slither target does not exist: $TARGET_DIR"
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"status":"fail","reason":"%s"}\n' "$msg" > "$OUTPUT_PATH"
    cat "$OUTPUT_PATH"
  else
    echo "status: fail" | tee "$OUTPUT_PATH"
    echo "reason: $msg" | tee -a "$OUTPUT_PATH"
  fi
  exit 2
fi

if ! command -v slither >/dev/null 2>&1; then
  msg="slither not found. install via: pip install slither-analyzer"
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"status":"fail","reason":"%s"}\n' "$msg" > "$OUTPUT_PATH"
    cat "$OUTPUT_PATH"
  else
    echo "status: fail" | tee "$OUTPUT_PATH"
    echo "reason: $msg" | tee -a "$OUTPUT_PATH"
  fi
  exit 2
fi

cd "$ROOT_DIR"
if [[ "$FORMAT" == "json" ]]; then
  set +e
  SOLC_ARGS="--allow-paths ${REPO_ROOT}/karma-core/contracts,${REPO_ROOT}"
  if [[ -n "${PATH_FILTER:-}" ]]; then
    slither_out="$(slither "$TARGET_DIR" --filter-paths "$PATH_FILTER" --solc-args "$SOLC_ARGS" --json "$OUTPUT_PATH" 2>&1)"
  else
    slither_out="$(slither "$TARGET_DIR" --solc-args "$SOLC_ARGS" --json "$OUTPUT_PATH" 2>&1)"
  fi
  slither_code=$?
  set -e
  if [[ "$slither_code" -ne 0 ]]; then
    printf "%s\n" "$slither_out" > "$OUTPUT_PATH"
    if rg -n "analyzed \\([1-9][0-9]* contracts" "$OUTPUT_PATH" >/dev/null; then
      echo "slither findings detected (see $OUTPUT_PATH)"
      exit 2
    fi
    echo "slither failed to analyze contracts (see $OUTPUT_PATH)"
    exit 2
  fi
  cat "$OUTPUT_PATH"
else
  set +e
  SOLC_ARGS="--allow-paths ${REPO_ROOT}/karma-core/contracts,${REPO_ROOT}"
  if [[ -n "${PATH_FILTER:-}" ]]; then
    slither_out="$(slither "$TARGET_DIR" --filter-paths "$PATH_FILTER" --solc-args "$SOLC_ARGS" 2>&1)"
  else
    slither_out="$(slither "$TARGET_DIR" --solc-args "$SOLC_ARGS" 2>&1)"
  fi
  slither_code=$?
  set -e
  printf "%s\n" "$slither_out" > "$OUTPUT_PATH"
  if [[ "$slither_code" -ne 0 ]]; then
    if rg -n "analyzed \\([1-9][0-9]* contracts" "$OUTPUT_PATH" >/dev/null; then
      echo "slither findings detected (see $OUTPUT_PATH)"
    else
      echo "slither failed to analyze contracts (see $OUTPUT_PATH)"
    fi
    exit 2
  fi
  if rg -n "No contract was analyzed|analyzed \\(0 contracts" "$OUTPUT_PATH" >/dev/null; then
    echo "slither analyzed zero contracts (see $OUTPUT_PATH)"
    exit 2
  fi
fi

echo "slither-gate: PASS"
