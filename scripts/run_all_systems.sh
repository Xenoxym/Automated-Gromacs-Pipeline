#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEMS_ROOT="$PROJECT_DIR/work/systems"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
: > "$LOG_DIR/run_success.txt"
: > "$LOG_DIR/run_failed.txt"

shopt -s nullglob
for SYS in "$SYSTEMS_ROOT"/*/; do
  [ -d "$SYS" ] || continue
  NAME="$(basename "$SYS")"
  if [ ! -f "$SYS/complex.gro" ] || [ ! -f "$SYS/topol.top" ]; then
    echo "SKIP $NAME (not prepared: missing complex.gro or topol.top)"
    continue
  fi

  echo "========== RUN $NAME =========="
  set +e
  bash "$PROJECT_DIR/scripts/run_one_system.sh" "$SYS" 2>&1 | tee "$LOG_DIR/run_${NAME}.log"
  STATUS=${PIPESTATUS[0]}
  set -e
  if [ "$STATUS" -eq 0 ]; then
    echo "$NAME" >> "$LOG_DIR/run_success.txt"
  else
    echo "$NAME" >> "$LOG_DIR/run_failed.txt"
  fi
done

echo "Done. See $LOG_DIR/run_success.txt and $LOG_DIR/run_failed.txt"
