#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${ROOT_DIR}/logs/paid-calls.jsonl"
SUMMARY_FILE="${ROOT_DIR}/logs/external-user-call-summary.json"

usage() {
  cat <<'EOF'
Usage:
  ./simulate-external-user-call.sh [--host <url>] [--output <path>]

Description:
  Simulates one external user paid call by invoking:
    POST /api/btc-price-paid
  Then runs verify-first-paid-call.sh and writes a compact summary.

Options:
  --host <url>     API host base URL (default: http://127.0.0.1:8822)
  --output <path>  Output summary path (default: logs/external-user-call-summary.json)
  -h, --help       Show help.
EOF
}

HOST_URL="http://127.0.0.1:8822"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -lt 2 ]] && { echo "Error: --host requires a value"; exit 1; }
      HOST_URL="$2"
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && { echo "Error: --output requires a value"; exit 1; }
      SUMMARY_FILE="$2"
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

mkdir -p "$(dirname "$SUMMARY_FILE")"

health_json="$(curl -sS "${HOST_URL}/api/health")"
if ! printf "%s" "$health_json" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj.get("ok") is True'; then
  echo "Health check failed at ${HOST_URL}/api/health"
  exit 2
fi

echo "Calling paid endpoint as external user simulation..."
paid_json="$(curl -sS -X POST "${HOST_URL}/api/btc-price-paid")"
if ! printf "%s" "$paid_json" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj.get("txHash")'; then
  echo "Paid call failed or txHash missing."
  printf '%s\n' "$paid_json"
  exit 2
fi

verify_json="$("${ROOT_DIR}/verify-first-paid-call.sh" --json --log "$LOG_FILE")"

python3 - "$SUMMARY_FILE" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

summary_path = pathlib.Path(sys.argv[1])
paid = json.loads(pathlib.Path("/dev/stdin").read_text())
PY
