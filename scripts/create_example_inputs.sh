#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$PROJECT_DIR/inputs/systems/lig001"
cat > "$PROJECT_DIR/inputs/systems/README_INPUTS.txt" <<'TXT'
Place one docked pose per system (folder name = system ID):

inputs/systems/lig001/pose_1_complex.pdb
inputs/systems/lig002/pose_1_complex.pdb
...

The pipeline reads INPUT_POSE_FILENAME from config.env (default: pose_1_complex.pdb).
Other PDB names in inputs/ (e.g. docked_complex.pdb) are ignored.

Docking exports often use ATOM for the ligand after a premature END; prepare runs
clean_docked_pdb.py to fix that. Set LIGAND_RESNAME in config.env (default UNL).

Do not put multiple ligands in one PDB unless you intend one residue group.
TXT

echo "Created example input folders."
