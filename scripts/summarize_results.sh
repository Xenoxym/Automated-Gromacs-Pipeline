#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_DIR/config.env"
SYSTEMS_ROOT="$PROJECT_DIR/work/systems"
RESULTS_DIR="$PROJECT_DIR/results"
mkdir -p "$RESULTS_DIR"

PERF_OUT="$RESULTS_DIR/performance_summary.tsv"
STATUS_OUT="$RESULTS_DIR/basic_status.tsv"

echo -e "system\tperformance_ns_per_day" > "$PERF_OUT"
echo -e "system\tprepared\tem\tnvt\tnpt\tproduction\tanalysis" > "$STATUS_OUT"

for SYS in "$SYSTEMS_ROOT"/*; do
  [ -d "$SYS" ] || continue
  NAME="$(basename "$SYS")"
  LOG="$SYS/${PRODUCTION_DEFFNM}.log"
  if [ -f "$LOG" ]; then
    PERF=$(grep "Performance:" "$LOG" | tail -n 1 | awk '{print $2}')
    echo -e "$NAME\t${PERF:-NA}" >> "$PERF_OUT"
  else
    echo -e "$NAME\tNO_LOG" >> "$PERF_OUT"
  fi

  prepared=$([ -f "$SYS/complex.gro" ] && echo yes || echo no)
  em=$([ -f "$SYS/em.gro" ] && echo yes || echo no)
  nvt=$([ -f "$SYS/nvt.gro" ] && echo yes || echo no)
  npt=$([ -f "$SYS/npt.gro" ] && echo yes || echo no)
  prod=$([ -f "$SYS/${PRODUCTION_DEFFNM}.gro" ] && echo yes || echo no)
  analysis=$([ -f "$SYS/analysis/rmsd_protein.xvg" ] && echo yes || echo no)
  echo -e "$NAME\t$prepared\t$em\t$nvt\t$npt\t$prod\t$analysis" >> "$STATUS_OUT"
done

echo "Wrote: $PERF_OUT"
echo "Wrote: $STATUS_OUT"
