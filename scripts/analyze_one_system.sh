#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 work/systems/lig001"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_DIR/config.env"
# shellcheck source=/dev/null
source "$PROJECT_DIR/scripts/setup_gmx.sh"

SYS_DIR="$(realpath "$1")"
cd "$SYS_DIR"
mkdir -p analysis

TPR="${PRODUCTION_DEFFNM}.tpr"
XTC="${PRODUCTION_DEFFNM}.xtc"

if [ ! -f "$TPR" ] || [ ! -f "$XTC" ]; then
  echo "ERROR: Missing $TPR or $XTC"
  exit 1
fi

if [ ! -f analysis/md_centered.xtc ]; then
  # Center on Protein, output System.
  printf "Protein\nSystem\n" | gmx trjconv \
    -s "$TPR" \
    -f "$XTC" \
    -o analysis/md_centered.xtc \
    -pbc mol \
    -center
fi

if [ ! -f analysis/rmsd_protein.xvg ]; then
  printf "Backbone\nBackbone\n" | gmx rms \
    -s "$TPR" \
    -f analysis/md_centered.xtc \
    -o analysis/rmsd_protein.xvg
fi

if [ ! -f analysis/rmsd_ligand.xvg ]; then
  # Fit on protein backbone, RMSD on ligand (standard protein–ligand metric; NOT LIG|LIG).
  printf "Backbone\nLIG\n" | gmx rms \
    -s "$TPR" \
    -f analysis/md_centered.xtc \
    -n index.ndx \
    -o analysis/rmsd_ligand.xvg || true
fi

if [ ! -f analysis/hbond_protein_ligand.xvg ]; then
  printf "Protein\nLIG\n" | gmx hbond \
    -s "$TPR" \
    -f analysis/md_centered.xtc \
    -n index.ndx \
    -num analysis/hbond_protein_ligand.xvg || true
fi

echo "Analysis done: $SYS_DIR"
