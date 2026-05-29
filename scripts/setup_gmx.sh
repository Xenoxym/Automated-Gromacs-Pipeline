#!/usr/bin/env bash
# Source after config.env. Forces pipeline scripts to use CUDA GROMACS, not conda gmx.
# Usage: source "$PROJECT_DIR/scripts/setup_gmx.sh"

set -euo pipefail

_gmx_from_path() {
  command -v gmx 2>/dev/null || true
}

if [ -n "${GMX_CUDA_PREFIX:-}" ] && [ -x "${GMX_CUDA_PREFIX}/bin/gmx" ]; then
  export GMX_BIN="${GMX_CUDA_PREFIX}/bin/gmx"
  export PATH="${GMX_CUDA_PREFIX}/bin:${PATH}"
  # shellcheck source=/dev/null
  [ -f "${GMX_CUDA_PREFIX}/bin/GMXRC" ] && source "${GMX_CUDA_PREFIX}/bin/GMXRC"
elif _gmx_from_path; then
  export GMX_BIN="$(_gmx_from_path)"
  echo "WARN: GMX_CUDA_PREFIX not found; using PATH gmx: ${GMX_BIN}" >&2
else
  echo "ERROR: no gmx found. Set GMX_CUDA_PREFIX or install GROMACS." >&2
  return 1 2>/dev/null || exit 1
fi

# Bash function shadows any other 'gmx' on PATH (e.g. miniconda after conda activate).
gmx() {
  "${GMX_BIN}" "$@"
}
export -f gmx 2>/dev/null || true

if ! "${GMX_BIN}" -version 2>&1 | grep -qi cuda; then
  echo "WARN: ${GMX_BIN} does not report CUDA in -version output." >&2
fi
