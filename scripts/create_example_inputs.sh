#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$PROJECT_DIR/inputs/systems/lig001/poses"
cat > "$PROJECT_DIR/inputs/systems/README_INPUTS.txt" <<'TXT'
Place one docked pose per system (folder name = compound / system ID):

inputs/systems/lig001/poses/pose_1_complex.pdb
inputs/systems/lig002/poses/pose_1_complex.pdb
...

The pipeline reads:
  <system_dir>/<INPUT_POSE_SUBDIR>/<INPUT_POSE_FILENAME>
Defaults in config.env: poses/pose_1_complex.pdb

Other PDB names under inputs/ (e.g. docked_complex.pdb at system root) are ignored.

Docking exports often use ATOM for the ligand after a premature END; prepare runs
clean_docked_pdb.py to fix that. Set LIGAND_RESNAME in config.env (default UNL).

Do not put multiple ligands in one PDB unless you intend one residue group.
TXT

echo "Created example input folders."
