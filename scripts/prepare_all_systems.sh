#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_DIR/config.env"

INPUT_ROOT="$PROJECT_DIR/inputs/systems"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
: > "$LOG_DIR/prepare_success.txt"
: > "$LOG_DIR/prepare_failed.txt"

shopt -s nullglob
for SYS in "$INPUT_ROOT"/*/; do
  [ -d "$SYS" ] || continue
  NAME="$(basename "$SYS")"
  POSE="$SYS/${INPUT_POSE_SUBDIR}/${INPUT_POSE_FILENAME}"
  if [ ! -f "$POSE" ]; then
    echo "SKIP $NAME (no ${INPUT_POSE_SUBDIR}/${INPUT_POSE_FILENAME})"
    continue
  fi

  echo "========== PREPARE $NAME =========="
  set +e
  bash "$PROJECT_DIR/scripts/prepare_one_system.sh" "$SYS" 2>&1 | tee "$LOG_DIR/prepare_${NAME}.log"
  STATUS=${PIPESTATUS[0]}
  set -e
  if [ "$STATUS" -eq 0 ]; then
    echo "$NAME" >> "$LOG_DIR/prepare_success.txt"
  else
    echo "$NAME" >> "$LOG_DIR/prepare_failed.txt"
  fi
done

echo "Done. See $LOG_DIR/prepare_success.txt and $LOG_DIR/prepare_failed.txt"
