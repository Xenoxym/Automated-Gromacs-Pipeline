# Automated GROMACS Protein–Ligand Batch Pipeline

Batch molecular dynamics for **one receptor, many docked ligands** (or many poses), starting from docked protein–ligand PDB files. Scripts do **not** hard-code a PDB ID: any folder under `inputs/systems/<system_id>/` works.

**Example case study:** `inputs/systems/lig001/` contains a pose from a [2FVJ](https://www.rcsb.org/structure/2FVJ)-based docking campaign. The same workflow applies to other receptors after you adjust `config.env` and input structures.

## Environment

- **OS:** WSL2 with **Ubuntu 22.04**
- **Conda env `mdtools`:** `gmx`, Open Babel, AmberTools (`antechamber`, `parmchk2`), ACPYPE
- **GROMACS:** CUDA build for `mdrun` (install scripts target a local CUDA build; conda `gmx` may need GPU flag fallback — see `docs/TROUBLESHOOTING.md`)

Default force-field route:

- Protein: AMBER99SB-ILDN via `gmx pdb2gmx` (`-ignh`)
- Ligand: GAFF2 / AM1-BCC via AmberTools + ACPYPE
- Water: TIP3P

CHARMM36m + CGenFF is valid but less convenient for fully local automation; see `docs/CHARMM_CGENFF_NOTES.md`.

## Input convention

One docked complex per system. **Folder name = system ID** (any string, e.g. `1001`, `abc123`, `lig001`):

```text
inputs/systems/1001/pose_1_complex.pdb
inputs/systems/abc123/pose_1_complex.pdb
...
```

| Topic | Detail |
|--------|--------|
| **Read by pipeline** | Only `pose_1_complex.pdb` (or the name in `INPUT_POSE_FILENAME` in `config.env`) |
| **Ignored** | `docked_complex.pdb` or other PDBs in `inputs/` — remove extras to avoid confusion |
| **Docking quirk** | Ligand often appears as `ATOM` (not `HETATM`) after a premature `END`, with `REMARK` / `CONECT` before the ligand |

The prepare step automatically:

1. Reads `inputs/systems/<id>/${INPUT_POSE_FILENAME}`.
2. Runs `clean_docked_pdb.py`: protein `ATOM`, ligand `ATOM` → `HETATM`, strips spurious `END` / `REMARK` / `CONECT`.
3. Writes `work/systems/<id>/docked_complex_cleaned.pdb`.
4. Splits, parameterizes protein/ligand, merges `complex.gro`, patches `topol.top`.

Set `LIGAND_RESNAME` and `LIGAND_NET_CHARGE` in `config.env` for your ligand (default `UNL`, charge `0`).

## Data flow

```text
inputs/systems/<system_id>/pose_1_complex.pdb
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
        └── em.*, nvt.*, npt.*, md_200ps.* ...
```

Logs: `logs/prepare_<id>.log`, `logs/run_<id>.log`; batch lists `prepare_success.txt` / `prepare_failed.txt` (and run equivalents).

## Quick start

```bash
cd /mnt/d/Projects/Automated-Gromacs-Pipeline   # or your clone path

# 1. Edit config if needed
nano config.env

# 2. Install (once per WSL instance)
bash install/00_install_system_deps.sh
bash install/01_install_gromacs_cuda.sh
bash install/02_install_mdtools_conda.sh

# 3. Activate tools
source ~/.bashrc
source ~/miniforge3/etc/profile.d/conda.sh   # adjust if miniconda/mamba elsewhere
conda activate mdtools

# 4. Prepare one system
bash scripts/prepare_one_system.sh inputs/systems/lig001

# 5. Sanity-check topology (optional)
grep -E 'ligand_atomtypes|ligand\.itp|UNL|\[ molecules \]' work/systems/lig001/topol.top | head -20
cd work/systems/lig001
gmx grompp -f ../../../mdp/ions.mdp -c complex.gro -p topol.top -o prepare_check.tpr -maxwarn 2
cd ../../..

# 6. Run MD for one system
bash scripts/run_one_system.sh work/systems/lig001

# 7. Analyze one system
bash scripts/analyze_one_system.sh work/systems/lig001

# 8. Batch all systems under inputs/systems/
bash scripts/prepare_all_systems.sh
bash scripts/run_all_systems.sh
bash scripts/analyze_all_systems.sh
bash scripts/summarize_results.sh
```

## Recommended execution style

1. **Clean stale work** after failed prepares (old `topol.top` / `complex.gro` may be wrong):

   ```bash
   rm -rf work/systems/lig001    # or entire work/systems/
   ```

2. **Run one system first** — inspect `md_200ps.log`, topology, and ligand groups before batching dozens of poses.

3. **Then batch** all directories under `inputs/systems/` that contain `pose_1_complex.pdb`.

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
| `INPUT_POSE_FILENAME` | `pose_1_complex.pdb` | Input pose per system |
| `PRODUCTION_MDP` / `PRODUCTION_DEFFNM` | `md_200ps` | Production run |
| `GMX_MDRUN_GPU_FLAGS` | full GPU set | See troubleshooting if unsupported |

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
```

Per-system analysis:

```text
analysis/rmsd_protein.xvg
analysis/rmsd_ligand.xvg
analysis/hbond_protein_ligand.xvg
```

Batch summaries:

```text
results/performance_summary.tsv
results/basic_status.tsv
```

## More documentation

- `docs/TROUBLESHOOTING.md` — ligand `ATOM`/`HETATM`, topology patch, ACPYPE, GPU flags, D-drive performance
- `docs/CHARMM_CGENFF_NOTES.md` — optional CHARMM route
