#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEMS_ROOT="$PROJECT_DIR/work/systems"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
: > "$LOG_DIR/analyze_success.txt"
: > "$LOG_DIR/analyze_failed.txt"

for SYS in "$SYSTEMS_ROOT"/*; do
  if [ -d "$SYS" ]; then
    NAME="$(basename "$SYS")"
    echo "========== ANALYZE $NAME =========="
    set +e
    bash "$PROJECT_DIR/scripts/analyze_one_system.sh" "$SYS" 2>&1 | tee "$LOG_DIR/analyze_${NAME}.log"
    STATUS=${PIPESTATUS[0]}
    set -e
    if [ "$STATUS" -eq 0 ]; then
      echo "$NAME" >> "$LOG_DIR/analyze_success.txt"
    else
      echo "$NAME" >> "$LOG_DIR/analyze_failed.txt"
    fi
  fi
done
