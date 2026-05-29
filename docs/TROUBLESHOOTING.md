# Troubleshooting

## `No HETATM records with residue name 'UNL'`

Docking output often has the ligand as `ATOM` records after a premature `END`.
`prepare_one_system.sh` runs `clean_docked_pdb.py` automatically.

Check the cleaned file:

```bash
grep '^HETATM' work/systems/<id>/docked_complex_cleaned.pdb | head
```

If the residue name differs, edit `config.env`:

```bash
LIGAND_RESNAME="MOL"
```

Re-run prepare on a **clean** `work/systems/<id>/` directory.

## Wrong input file (`docked_complex.pdb` in `inputs/`)

The pipeline reads only `INPUT_POSE_FILENAME` (default `pose_1_complex.pdb`).
Files such as `inputs/systems/<id>/docked_complex.pdb` are **ignored**.
Delete or rename duplicates so you do not edit the wrong PDB.

## `Could not find [ molecules ] in topol.top`

Usually a Windows CRLF parsing issue in an older script version, or a non-standard `topol.top`.
Re-run prepare on a clean `work/systems/<id>/`; `patch_topology.py` normalizes line endings and patches idempotently.

Verify includes:

```bash
grep -E 'ligand_atomtypes|ligand\.itp|UNL|\[ molecules \]' work/systems/<id>/topol.top
```

## Stale or half-finished `work/systems/<id>/`

After a failed prepare, remove debug leftovers and re-run:

```bash
rm -rf work/systems/<id>
bash scripts/prepare_one_system.sh inputs/systems/<id>
```

Do not reuse an unpatched `topol.top` or old `complex.gro` from a failed run.

## `acpype` fails

Most common causes:

1. Wrong ligand net charge (`LIGAND_NET_CHARGE` in `config.env`).
2. Bad ligand geometry from docking output.
3. Missing hydrogens / protonation issues.
4. Metal-containing or covalent ligands: GAFF2 route may not be appropriate.

Inspect `work/systems/<id>/ligand.mol2` in PyMOL, ChimeraX, or Open Babel.

## `Atomtype ... not found`

Ligand atomtypes must appear **before** molecule definitions in `topol.top`:

```top
#include ".../forcefield.itp"
#include "ligand_atomtypes.itp"
...
#include "ligand.itp"
```

Re-run `prepare_one_system.sh` if `patch_topology.py` was skipped or an old `topol.top` is in use.

## `Group Water_and_ions referenced in the .mdp file was not found`

`nvt.mdp` / `npt.mdp` / `md_*.mdp` use `tc-grps = Protein_LIG Water_and_ions`. An old `index.ndx` may only define `Protein_LIG`.

After `em.gro` exists, regenerate the index and re-run from NVT:

```bash
cd work/systems/<id>
rm -f index.ndx nvt.* npt.* md_200ps.*
printf "r UNL\nname 20 LIG\n1 | 20\nname 21 Protein_LIG\n!21\nname 22 Water_and_ions\nq\n" | \
  gmx make_ndx -f em.gro -o index.ndx
cd <project_root>
bash scripts/run_one_system.sh work/systems/<id>
```

Replace `UNL` with `LIGAND_RESNAME` from `config.env` if different.

## `make_ndx` group numbers wrong

`run_one_system.sh` assumes default group 1 is `Protein` and creates groups 20–22 (`LIG`, `Protein_LIG`, `Water_and_ions`). If `1 | 20` fails, run `gmx make_ndx -f em.gro -o index.ndx` interactively and define `Protein_LIG` plus `!Protein_LIG` named `Water_and_ions`.

## `which gmx` points to miniconda (CPU) instead of CUDA GROMACS

**Why:** `conda activate mdtools` prepends `.../envs/mdtools/bin` to `PATH`. If `gmx` exists there (e.g. `conda install gromacs`), it wins over `source GMXRC`, because you activate conda **after** opening the shell or after sourcing CUDA.

**Pipeline fix:** `prepare_one_system.sh`, `run_one_system.sh`, and `analyze_one_system.sh` source `scripts/setup_gmx.sh`, which sets `GMX_BIN=$GMX_CUDA_PREFIX/bin/gmx` and a **`gmx()` shell function** so scripts never call conda’s binary.

**What you should do:**

```bash
# 1. Confirm CUDA binary exists
ls -la ~/apps/gromacs-2026.2-cuda/bin/gmx

# 2. Set path in config.env
GMX_CUDA_PREFIX="${HOME}/apps/gromacs-2026.2-cuda"

# 3. Remove conda gromacs if installed (recommended)
conda activate mdtools
conda remove -y gromacs 2>/dev/null || true
which gmx    # may be empty while mdtools is active — that is OK

# 4. Run via project scripts (not bare `gmx` after conda activate)
bash scripts/run_one_system.sh work/systems/lig001
cat work/systems/lig001/gmx_version.txt | grep -i cuda
```

Manual commands in the shell still use `PATH`; either `conda deactivate`, or:

```bash
export GMX_BIN=~/apps/gromacs-2026.2-cuda/bin/gmx
alias gmx="$GMX_BIN"
```

## GPU / `mdrun` flags not supported

Conda GROMACS builds may not support every GPU flag. `run_one_system.sh` falls back: full GPU → `-nb gpu` only → CPU.

Edit `config.env`:

```bash
GMX_MDRUN_GPU_FLAGS="-nb gpu -pme gpu -bonded gpu -pin on"
```

If still failing:

```bash
GMX_MDRUN_GPU_FLAGS="-nb gpu -pin on"
```

Or empty for CPU-only.

## `CMake 3.28 or higher is required` (GROMACS CUDA install)

GROMACS **2026.2** needs CMake ≥ 3.28. **Ubuntu 22.04** `apt` ships **3.22.1**.

Upgrade CMake, then re-run (prefer **`conda deactivate`** first):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates gpg wget
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
. /etc/os-release
echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${VERSION_CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/kitware.list
sudo apt-get update
sudo apt-get install -y cmake
cmake --version
bash install/01_install_gromacs_cuda.sh
```

Current `install/01_install_gromacs_cuda.sh` checks CMake and installs from Kitware if needed.

## `Cannot build FFTW3 automatically with ninja`

GROMACS + **Ninja** cannot use `GMX_BUILD_OWN_FFTW=ON`. Use system FFTW from `install/00_install_system_deps.sh` (`libfftw3-dev`):

```bash
sudo apt-get install -y libfftw3-dev
cd ~/src/gromacs-2026.2/build
rm -rf *
cmake .. -G Ninja \
  -DGMX_GPU=CUDA \
  -DGMX_BUILD_OWN_FFTW=OFF \
  -DREGRESSIONTEST_DOWNLOAD=ON \
  -DCMAKE_INSTALL_PREFIX="$HOME/apps/gromacs-2026.2-cuda" \
  -DCMAKE_CUDA_ARCHITECTURES=89
ninja -j"$(nproc)"
ninja install
```

Or re-run `bash install/01_install_gromacs_cuda.sh` after pulling the updated script.

## Running from Windows D: drive is slow

`/mnt/d/...` has higher I/O latency than the WSL ext4 home directory. For long MD:

```bash
mkdir -p ~/md_projects
cp -r /mnt/d/Projects/Automated-Gromacs-Pipeline ~/md_projects/
cd ~/md_projects/Automated-Gromacs-Pipeline
conda activate mdtools
```

Edit from Windows:

```text
\\wsl$\Ubuntu-22.04\home\<your_user>\md_projects\Automated-Gromacs-Pipeline
```

Adjust `Ubuntu-22.04` if your WSL distro name differs (`wsl -l -v`).
