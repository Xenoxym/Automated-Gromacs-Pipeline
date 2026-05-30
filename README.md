# Automated GROMACS Protein–Ligand Batch Pipeline

Batch molecular dynamics for **one receptor, many docked ligands** (or many poses), starting from docked protein–ligand PDB files. Scripts do **not** hard-code a PDB ID: any folder under `inputs/systems/<system_id>/` works.

**Example case study:** `inputs/systems/lig001/` contains a pose from a [2FVJ](https://www.rcsb.org/structure/2FVJ)-based docking campaign. The same workflow applies to other receptors after you adjust `config.env` and input structures.

## Environment

- **OS:** WSL2 with **Ubuntu 22.04**
- **Conda env `mdtools`:** Open Babel, AmberTools (`antechamber`, `parmchk2`), ACPYPE — **ligand parameterization only**
- **GROMACS (MD):** CUDA build from `install/01_install_gromacs_cuda.sh` → `~/apps/gromacs-2026.2-cuda` (do **not** use conda `gmx` for `mdrun`; it is often CPU-only)

Default force-field route:

- Protein: AMBER99SB-ILDN via `gmx pdb2gmx` (`-ignh`)
- Ligand: GAFF2 / AM1-BCC via AmberTools + ACPYPE
- Water: TIP3P

CHARMM36m + CGenFF is valid but less convenient for fully local automation; see `docs/CHARMM_CGENFF_NOTES.md`.

Repository text files use **LF** line endings (see `.gitattributes`); edit scripts on Windows with **EOL = LF** so WSL/bash does not break.

## Input convention

One docked complex per system. **Folder name = system ID** (any string, e.g. `1001`, `abc123`, `lig001`):

```text
inputs/systems/1001/poses/pose_1_complex.pdb
inputs/systems/abc123/poses/pose_1_complex.pdb
...
```

| Topic | Detail |
|--------|--------|
| **Read by pipeline** | `<system_dir>/poses/pose_1_complex.pdb` by default (`INPUT_POSE_SUBDIR` + `INPUT_POSE_FILENAME` in `config.env`) |
| **Ignored** | `docked_complex.pdb` or other PDBs in `inputs/` — remove extras to avoid confusion |
| **Docking quirk** | Ligand often appears as `ATOM` (not `HETATM`) after a premature `END`, with `REMARK` / `CONECT` before the ligand |

The prepare step automatically:

1. Reads `inputs/systems/<id>/${INPUT_POSE_SUBDIR}/${INPUT_POSE_FILENAME}` (default `poses/pose_1_complex.pdb`).
2. Runs `clean_docked_pdb.py`: protein `ATOM`, ligand `ATOM` → `HETATM`, strips spurious `END` / `REMARK` / `CONECT`.
3. Writes `work/systems/<id>/docked_complex_cleaned.pdb`.
4. Splits, parameterizes protein/ligand, merges `complex.gro`, patches `topol.top`.

Set `LIGAND_RESNAME` and `LIGAND_NET_CHARGE` in `config.env` for your ligand (default `UNL`, charge `0`).

## Data flow

```text
inputs/systems/<system_id>/poses/pose_1_complex.pdb
        │
        ▼  prepare_one_system.sh / prepare_all_systems.sh
work/systems/<system_id>/
        ├── docked_complex_cleaned.pdb
        ├── protein_raw.pdb, ligand_raw.pdb
        ├── protein_processed.gro, topol.top (patched)
        ├── ligand.gro, ligand.itp, ligand_atomtypes.itp
        ├── complex.gro
        └── <LIGAND_RESNAME>.acpype/   (intermediate; gitignored)
        │
        ▼  run_one_system.sh / run_all_systems.sh
        ├── solvated / ionized structures
        ├── index.ndx (Protein_LIG, Water_and_ions)
        ├── em.*, nvt.*, npt.*, md_200ps.* ...
        ├── gmx_version.txt, *_mdrun.log
        │
        ▼  analyze_one_system.sh / plot_rmsd.py
        └── analysis/*.xvg, *.png
```

Logs: `logs/prepare_<id>.log`, `logs/run_<id>.log`; batch lists `prepare_success.txt` / `prepare_failed.txt` (and run equivalents).

## Install (once per WSL machine)

```bash
cd /path/to/Automated-Gromacs-Pipeline

# System packages (cmake helper, FFTW, build tools)
bash install/00_install_system_deps.sh

# CUDA GROMACS — run outside conda if possible
conda deactivate 2>/dev/null || true
bash install/01_install_gromacs_cuda.sh
# Installs CMake 3.28+ on Ubuntu 22.04 if needed; uses system FFTW (GMX_BUILD_OWN_FFTW=OFF)

# Ligand tools (creates conda env mdtools)
bash install/02_install_mdtools_conda.sh
```

## Quick start

```bash
cd /path/to/Automated-Gromacs-Pipeline

# 1. Edit config if needed (ligand name, production MDP, GPU paths)
nano config.env

# 2. Every new shell — mdtools for ACPYPE only; pipeline scripts force CUDA gmx via setup_gmx.sh
conda activate mdtools
# Do not rely on `which gmx` after conda activate — conda may put CPU gmx first on PATH.
# prepare/run/analyze scripts use GMX_CUDA_PREFIX/bin/gmx automatically.
bash scripts/run_one_system.sh work/systems/lig001
# Check: cat work/systems/lig001/gmx_version.txt | grep -i cuda

# 3. Prepare one system
bash scripts/prepare_one_system.sh inputs/systems/lig001

# 4. Sanity-check topology (optional)
grep -E 'ligand_atomtypes|ligand\.itp|UNL|\[ molecules \]' work/systems/lig001/topol.top | head -20
cd work/systems/lig001
gmx grompp -f ../../../mdp/ions.mdp -c complex.gro -p topol.top -o prepare_check.tpr -maxwarn 2
cd ../../..

# 5. Run MD for one system
bash scripts/run_one_system.sh work/systems/lig001

# 6. Analyze one system
bash scripts/analyze_one_system.sh work/systems/lig001

# 7. Plot RMSD / H-bond figures (needs matplotlib)
conda install -c conda-forge matplotlib   # once
python scripts/plot_rmsd.py work/systems/lig001

# 8. Batch all systems under inputs/systems/
bash scripts/prepare_all_systems.sh
bash scripts/run_all_systems.sh
bash scripts/analyze_all_systems.sh
bash scripts/summarize_results.sh
python scripts/plot_rmsd.py --all
```

## Which scripts use the GPU?

Only **`gmx mdrun`** in `run_one_system.sh` uses the GPU. All pipeline shell scripts source **`scripts/setup_gmx.sh`**, which defines a `gmx()` function pointing at **`$GMX_CUDA_PREFIX/bin/gmx`** so **conda’s `gmx` is never used**, even after `conda activate mdtools`.

| Script | GPU? | Main work |
|--------|------|-----------|
| `prepare_one_system.sh` | **No** | Python, `pdb2gmx`, Open Babel, ACPYPE, `grompp` |
| `prepare_all_systems.sh` | **No** | Loops `prepare_one_system.sh` |
| `run_one_system.sh` | **Partial** | `editconf`, `solvate`, `genion`, `grompp`, `make_ndx` = CPU; **`mdrun` = GPU** with fallback |
| `run_all_systems.sh` | **Partial** | Same as `run_one_system.sh` per system |
| `analyze_one_system.sh` | **No** | `trjconv`, `rms`, `hbond` |
| `analyze_all_systems.sh` | **No** | Loops `analyze_one_system.sh` |
| `plot_rmsd.py` | **No** | Matplotlib from `.xvg` |

**`mdrun` fallback order** (see `config.env`):

1. `GMX_MDRUN_GPU_FLAGS` (default `-nb gpu -pme gpu -pin on`)
2. `GMX_MDRUN_GPU_FLAGS_FALLBACK` (default `-nb gpu -pin on`)
3. CPU-only — only if `GMX_MDRUN_ALLOW_CPU_FALLBACK=yes`

Check GPU usage: `work/systems/<id>/gmx_version.txt`, `em_mdrun.log`, `md_200ps_mdrun.log` (no `retrying CPU-only`), and `nvidia-smi` during `mdrun`.

## Recommended execution style

1. **Clean stale work** after failed prepares (old `topol.top` / `complex.gro` may be wrong):

   ```bash
   rm -rf work/systems/lig001    # or entire work/systems/
   ```

2. **Run one system first** — inspect `md_200ps.log`, `*_mdrun.log`, and topology before batching.

3. **Then batch** all directories under `inputs/systems/` that contain `poses/pose_1_complex.pdb`.

4. **After changing `mdp/` or production settings** — update `PRODUCTION_MDP` / `PRODUCTION_DEFFNM` in `config.env`, delete outputs for the affected stage (e.g. `rm -f md_200ps.* md_200ps_mdrun.log`), then re-run `run_one_system.sh`.

## WSL and Windows paths

You may keep the repo on a Windows drive and run from WSL:

```bash
cd /mnt/d/Projects/Automated-Gromacs-Pipeline
```

Heavy MD is usually faster on the **Linux filesystem** than on `/mnt/d/`:

```bash
mkdir -p ~/md_projects
cp -r /mnt/d/Projects/Automated-Gromacs-Pipeline ~/md_projects/
cd ~/md_projects/Automated-Gromacs-Pipeline
conda activate mdtools
```

Edit from Windows via VS Code Remote WSL or Explorer:

```text
\\wsl$\Ubuntu-22.04\home\<your_user>\md_projects\Automated-Gromacs-Pipeline
```

Path helper: `bash scripts/windows_path_helper.sh`

## Configuration (`config.env`)

| Variable | Default | Role |
|----------|---------|------|
| `FORCEFIELD` | `amber99sb-ildn` | Protein FF for `pdb2gmx` |
| `WATERMODEL` | `tip3p` | Water model |
| `LIGAND_RESNAME` | `UNL` | Ligand residue name in PDB |
| `LIGAND_NET_CHARGE` | `0` | Passed to ACPYPE |
| `INPUT_POSE_SUBDIR` | `poses` | Subfolder under each system ID |
| `INPUT_POSE_FILENAME` | `pose_1_complex.pdb` | Pose PDB filename |
| `PRODUCTION_MDP` | `md_200ps.mdp` | Production MDP file under `mdp/` |
| `PRODUCTION_DEFFNM` | `md_200ps` | Output prefix for production `mdrun` |
| `GMX_CUDA_PREFIX` | `~/apps/gromacs-2026.2-cuda` | CUDA GROMACS; sourced by `run_one_system.sh` |
| `GMX_GPU_ID` | `0` | Passed to `mdrun -gpu_id` |
| `GMX_MDRUN_GPU_FLAGS` | `-nb gpu -pme gpu -pin on` | Primary GPU flags |
| `GMX_MDRUN_GPU_FLAGS_FALLBACK` | `-nb gpu -pin on` | Second try before CPU |
| `GMX_MDRUN_ALLOW_CPU_FALLBACK` | `yes` | `no` = fail instead of silent CPU |

Simulation length and thermostat/pressure are set in `mdp/` (`nsteps`, `dt`, etc.). Default production is **~0.2 ns** (`md_200ps.mdp`); use `md_500ps.mdp` or custom MDP for longer runs.

Copy machine-specific overrides to `config.local.env` (gitignored), not committed secrets.

## Outputs

Prepared system (example `lig001`):

```text
work/systems/lig001/
  complex.gro, topol.top, ligand.itp, ligand_atomtypes.itp, ...
```

Main MD artifacts:

```text
em.gro, nvt.gro, npt.gro
md_200ps.xtc, md_200ps.gro, md_200ps.log
gmx_version.txt, em_mdrun.log, md_200ps_mdrun.log, ...
```

Per-system analysis:

```text
analysis/rmsd_protein.xvg
analysis/rmsd_ligand.xvg
analysis/hbond_protein_ligand.xvg
analysis/md_centered.xtc
analysis/rmsd_dual.png      # from plot_rmsd.py
analysis/hbond.png          # optional
```

Batch summaries:

```text
results/performance_summary.tsv
results/basic_status.tsv
results/rmsd_plot_summary.tsv   # from plot_rmsd.py --all
```

## More documentation

- `docs/ANALYSIS.md` — `.xvg` meaning, RMSD interpretation, plotting
- `docs/TROUBLESHOOTING.md` — CRLF, `Water_and_ions`, CMake/FFTW install, GPU/CPU, D-drive performance
- `docs/CHARMM_CGENFF_NOTES.md` — optional CHARMM route
