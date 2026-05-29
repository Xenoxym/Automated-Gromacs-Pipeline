#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$PROJECT_DIR/inputs/systems/lig001"
cat > "$PROJECT_DIR/inputs/systems/README_INPUTS.txt" <<'TXT'
Place your docked PDB files like this:

inputs/systems/lig001/docked_complex.pdb
inputs/systems/lig002/docked_complex.pdb
...

The pipeline assumes:
- protein atoms are ATOM records
- ligand atoms are HETATM records
- ligand residue name matches config.env LIGAND_RESNAME, default LIG

Do not put multiple ligands in one PDB unless you intentionally want them treated as one residue group.
TXT

echo "Created example input folders."
