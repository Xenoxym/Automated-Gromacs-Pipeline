#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 work/systems/<system_id>"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_DIR/config.env"

SYS_DIR="$(realpath "$1")"
cd "$SYS_DIR"

echo "===== Running $SYS_DIR ====="

for f in complex.gro topol.top ligand.itp ligand_atomtypes.itp; do
  if [ ! -f "$f" ]; then
    echo "ERROR: Missing $f. Run prepare_one_system.sh first."
    exit 1
  fi
done

run_mdrun() {
  local deffnm="$1"
  shift
  local extra=("$@")
  echo ">>> mdrun -deffnm $deffnm (try GPU: $GMX_MDRUN_GPU_FLAGS)"
  if gmx mdrun -deffnm "$deffnm" -v $GMX_MDRUN_GPU_FLAGS "${extra[@]}"; then
    return 0
  fi
  echo "WARN: GPU mdrun failed for $deffnm; retrying with -nb gpu only"
  if gmx mdrun -deffnm "$deffnm" -v -nb gpu -pin on "${extra[@]}"; then
    return 0
  fi
  echo "WARN: Partial GPU failed; retrying CPU mdrun for $deffnm"
  gmx mdrun -deffnm "$deffnm" -v "${extra[@]}"
}

if [ ! -f boxed.gro ]; then
  gmx editconf \
    -f complex.gro \
    -o boxed.gro \
    -c \
    -d "$BOX_DISTANCE" \
    -bt "$BOX_TYPE"
fi

if [ ! -f solvated.gro ]; then
  gmx solvate \
    -cp boxed.gro \
    -cs spc216.gro \
    -o solvated.gro \
    -p topol.top
fi

if [ ! -f ions.tpr ]; then
  gmx grompp \
    -f "$PROJECT_DIR/mdp/ions.mdp" \
    -c solvated.gro \
    -p topol.top \
    -o ions.tpr \
    -maxwarn 2
fi

if [ ! -f solv_ions.gro ]; then
  echo "SOL" | gmx genion \
    -s ions.tpr \
    -o solv_ions.gro \
    -p topol.top \
    -pname NA \
    -nname CL \
    -neutral \
    -conc "$ION_CONCENTRATION"
fi

if [ ! -f em.gro ]; then
  gmx grompp \
    -f "$PROJECT_DIR/mdp/minim.mdp" \
    -c solv_ions.gro \
    -p topol.top \
    -o em.tpr \
    -maxwarn 2

  run_mdrun em
fi

if [ ! -f index.ndx ]; then
  printf "r %s\nname 20 LIG\n1 | 20\nname 21 Protein_LIG\nq\n" "$LIGAND_RESNAME" | \
    gmx make_ndx -f em.gro -o index.ndx
fi

if [ ! -f nvt.gro ]; then
  gmx grompp \
    -f "$PROJECT_DIR/mdp/nvt.mdp" \
    -c em.gro \
    -r em.gro \
    -p topol.top \
    -n index.ndx \
    -o nvt.tpr \
    -maxwarn 2

  run_mdrun nvt
fi

if [ ! -f npt.gro ]; then
  gmx grompp \
    -f "$PROJECT_DIR/mdp/npt.mdp" \
    -c nvt.gro \
    -r nvt.gro \
    -t nvt.cpt \
    -p topol.top \
    -n index.ndx \
    -o npt.tpr \
    -maxwarn 2

  run_mdrun npt
fi

if [ ! -f "${PRODUCTION_DEFFNM}.gro" ]; then
  gmx grompp \
    -f "$PROJECT_DIR/mdp/$PRODUCTION_MDP" \
    -c npt.gro \
    -t npt.cpt \
    -p topol.top \
    -n index.ndx \
    -o "${PRODUCTION_DEFFNM}.tpr" \
    -maxwarn 2

  run_mdrun "$PRODUCTION_DEFFNM"
fi

echo "===== Finished $SYS_DIR ====="
