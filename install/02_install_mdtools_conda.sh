#!/usr/bin/env bash
set -euo pipefail

# Installs Miniforge if missing, then creates mdtools env with AmberTools/ACPYPE/OpenBabel/RDKit.
# This is used for local ligand parameterization.

MINIFORGE="$HOME/miniforge3"

if [ ! -d "$MINIFORGE" ]; then
  cd /tmp
  wget -nc https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
  bash Miniforge3-Linux-x86_64.sh -b -p "$MINIFORGE"
fi

source "$MINIFORGE/etc/profile.d/conda.sh"
conda config --set channel_priority strict

if ! conda env list | awk '{print $1}' | grep -qx "mdtools"; then
  conda create -y -n mdtools -c conda-forge \
    python=3.11 \
    ambertools \
    acpype \
    openbabel \
    rdkit \
    biopython \
    numpy \
    pandas
fi

conda activate mdtools
python - <<'PY'
import sys
print('Python:', sys.version)
PY

command -v antechamber
command -v parmchk2
command -v acpype
command -v obabel

echo "mdtools env ready. Use: conda activate mdtools"
echo "Do NOT conda install gromacs into mdtools — MD uses CUDA GROMACS from install/01 (see GMX_CUDA_PREFIX in config.env)."
