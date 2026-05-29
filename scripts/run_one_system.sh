#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 work/systems/<system_id>"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_DIR/config.env"
# shellcheck source=/dev/null
source "$PROJECT_DIR/scripts/setup_gmx.sh"

SYS_DIR="$(realpath "$1")"
cd "$SYS_DIR"

echo "===== Running $SYS_DIR ====="
echo "GMX_BIN=${GMX_BIN} (gmx function overrides conda PATH)"
gmx -version 2>&1 | head -15 | tee gmx_version.txt

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
  local -a gpu_flags fallback_flags mdrun_base
  local log="${deffnm}_mdrun.log"

  read -r -a gpu_flags <<< "${GMX_MDRUN_GPU_FLAGS:-}"
  read -r -a fallback_flags <<< "${GMX_MDRUN_GPU_FLAGS_FALLBACK:-}"
  mdrun_base=(gmx mdrun -deffnm "$deffnm" -v)
  if [ -n "${GMX_GPU_ID:-}" ]; then
    mdrun_base+=(-gpu_id "$GMX_GPU_ID")
  fi

  echo ">>> mdrun -deffnm $deffnm GPU flags: ${gpu_flags[*]:-none}"
  if [ "${#gpu_flags[@]}" -gt 0 ]; then
    if "${mdrun_base[@]}" "${gpu_flags[@]}" "${extra[@]}" 2>&1 | tee -a "$log"; then
      if grep -qiE 'Using.*GPU|CUDA|NB on GPU|nonbonded on GPU' "$log" 2>/dev/null; then
        echo ">>> $deffnm: GPU path OK (see $log)"
      else
        echo "WARN: $deffnm finished but log may not show GPU — check $log and nvidia-smi"
      fi
      return 0
    fi
    echo "WARN: GPU mdrun failed for $deffnm (flags: ${gpu_flags[*]})" | tee -a "$log"
  fi

  if [ "${#fallback_flags[@]}" -gt 0 ]; then
    echo ">>> retry GPU fallback: ${fallback_flags[*]}"
    if "${mdrun_base[@]}" "${fallback_flags[@]}" "${extra[@]}" 2>&1 | tee -a "$log"; then
      return 0
    fi
    echo "WARN: GPU fallback failed for $deffnm" | tee -a "$log"
  fi

  if [ "${GMX_MDRUN_ALLOW_CPU_FALLBACK:-yes}" = "no" ]; then
    echo "ERROR: GPU mdrun failed and GMX_MDRUN_ALLOW_CPU_FALLBACK=no" >&2
    return 1
  fi
  echo "WARN: retrying CPU-only mdrun for $deffnm" | tee -a "$log"
  gmx mdrun -deffnm "$deffnm" -v "${extra[@]}" 2>&1 | tee -a "$log"
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
  # MDP tc-grps need Protein_LIG and Water_and_ions (nvt/npt/md_*.mdp).
  # Group 1 = Protein (default); 20 = ligand; 21 = Protein_LIG; 22 = !21 (SOL + ions).
  printf "r %s\nname 20 LIG\n1 | 20\nname 21 Protein_LIG\n!21\nname 22 Water_and_ions\nq\n" "$LIGAND_RESNAME" | \
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
