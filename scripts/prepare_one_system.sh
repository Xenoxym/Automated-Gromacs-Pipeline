#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 inputs/systems/<system_id>"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_DIR/config.env"

INPUT_DIR="$(realpath "$1")"
SYSTEM_ID="$(basename "$INPUT_DIR")"
WORK_DIR="$PROJECT_DIR/work/systems/$SYSTEM_ID"
INPUT_POSE="$INPUT_DIR/${INPUT_POSE_FILENAME}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

if [ ! -f "$INPUT_POSE" ]; then
  echo "ERROR: Input not found: $INPUT_POSE"
  echo "Expected: <system_dir>/${INPUT_POSE_FILENAME}"
  exit 1
fi

echo "===== [$SYSTEM_ID] Clean docked PDB ====="
python "$PROJECT_DIR/scripts/clean_docked_pdb.py" \
  --input "$INPUT_POSE" \
  --output "$CLEANED_COMPLEX_FILENAME" \
  --ligand-resname "$LIGAND_RESNAME"

echo "===== [$SYSTEM_ID] Split docked PDB ====="
python "$PROJECT_DIR/scripts/split_docked_pdb.py" \
  --input "$CLEANED_COMPLEX_FILENAME" \
  --ligand-resname "$LIGAND_RESNAME" \
  --protein-out protein_raw.pdb \
  --ligand-out ligand_raw.pdb

echo "===== [$SYSTEM_ID] Protein topology with pdb2gmx ====="
gmx pdb2gmx \
  -f protein_raw.pdb \
  -o protein_processed.gro \
  -p topol.top \
  -ff "$FORCEFIELD" \
  -water "$WATERMODEL" \
  -ignh

echo "===== [$SYSTEM_ID] Ligand PDB -> MOL2 with OpenBabel ====="
obabel ligand_raw.pdb -O ligand.mol2 -h

echo "===== [$SYSTEM_ID] Ligand topology with ACPYPE / GAFF2 ====="
rm -rf "${LIGAND_RESNAME}.acpype"
acpype \
  -i ligand.mol2 \
  -b "$LIGAND_RESNAME" \
  -c "$ACPYPE_CHARGE_METHOD" \
  -n "$LIGAND_NET_CHARGE" \
  -a gaff2

ACPYPE_DIR="${LIGAND_RESNAME}.acpype"
ACPYPE_ITP="$ACPYPE_DIR/${LIGAND_RESNAME}_GMX.itp"
ACPYPE_GRO="$ACPYPE_DIR/${LIGAND_RESNAME}_GMX.gro"

if [ ! -f "$ACPYPE_ITP" ]; then
  echo "ERROR: ACPYPE ITP not found: $ACPYPE_ITP"
  find "$ACPYPE_DIR" -maxdepth 1 -type f -print || true
  exit 1
fi
if [ ! -f "$ACPYPE_GRO" ]; then
  echo "ERROR: ACPYPE GRO not found: $ACPYPE_GRO"
  find "$ACPYPE_DIR" -maxdepth 1 -type f -print || true
  exit 1
fi

cp "$ACPYPE_GRO" ligand.gro

python "$PROJECT_DIR/scripts/split_acpype_itp.py" \
  --input "$ACPYPE_ITP" \
  --atomtypes-out ligand_atomtypes.itp \
  --ligand-out ligand.itp

echo "===== [$SYSTEM_ID] Merge coordinates ====="
python "$PROJECT_DIR/scripts/merge_gro.py" \
  --protein-gro protein_processed.gro \
  --ligand-gro ligand.gro \
  --output complex.gro

echo "===== [$SYSTEM_ID] Patch topology ====="
python "$PROJECT_DIR/scripts/patch_topology.py" \
  --topol topol.top \
  --ligand-name "$LIGAND_RESNAME" \
  --atomtypes-include ligand_atomtypes.itp \
  --ligand-include ligand.itp

echo "===== [$SYSTEM_ID] Sanity grompp (ions MDP, no solvent yet) ====="
gmx grompp \
  -f "$PROJECT_DIR/mdp/ions.mdp" \
  -c complex.gro \
  -p topol.top \
  -o prepare_check.tpr \
  -maxwarn 2

echo "Prepared system: $WORK_DIR"
echo "Next: cd $WORK_DIR && gmx grompp -f ../../../mdp/ions.mdp -c complex.gro -p topol.top -o test.tpr"
echo "Then: bash $PROJECT_DIR/scripts/run_one_system.sh $WORK_DIR"
