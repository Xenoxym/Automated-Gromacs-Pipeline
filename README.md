# 2FVJ Protein-Ligand GROMACS Batch Pipeline

This project runs a local WSL2/Ubuntu 24.04 GROMACS pipeline starting from docked protein-ligand PDB files.

Default force-field route:

- Protein: AMBER99SB-ILDN via `gmx pdb2gmx`
- Ligand: GAFF2/AM1-BCC via AmberTools + ACPYPE
- Water: TIP3P
- MD engine: GROMACS CUDA build

This route is chosen because it can be run locally and scripted. CHARMM36m + CGenFF is also valid, but CGenFF usually requires external server/binary handling and is less convenient for fully automated local batch processing.

## Input convention

Put one docked complex PDB per system (folder name = system ID, any string):

```text
inputs/systems/1001/pose_1_complex.pdb
inputs/systems/abc123/pose_1_complex.pdb
...
```

The prepare step automatically:

1. Reads `pose_1_complex.pdb` (see `INPUT_POSE_FILENAME` in `config.env`).
2. Converts ligand `ATOM` records (e.g. residue `UNL`) to `HETATM`.
3. Strips premature `END` / REMARK / CONECT blocks before the ligand.
4. Writes `work/systems/<system_id>/docked_complex_cleaned.pdb`.

Set `LIGAND_RESNAME` and `LIGAND_NET_CHARGE` in `config.env` for your ligand.

## Fast workflow

```bash
cd /mnt/d/your_path/2fvj_gromacs_pipeline

# 1. Edit config if needed
nano config.env

# 2. Install tools
bash install/00_install_system_deps.sh
bash install/01_install_gromacs_cuda.sh
bash install/02_install_mdtools_conda.sh

# 3. Activate tools
source ~/.bashrc
source ~/miniforge3/etc/profile.d/conda.sh
conda activate mdtools

# 4. Prepare one system from docked PDB
bash scripts/prepare_one_system.sh inputs/systems/lig001

# 5. Run one system
bash scripts/run_one_system.sh work/systems/lig001

# 6. Analyze one system
bash scripts/analyze_one_system.sh work/systems/lig001

# 7. Batch prepare and run all
bash scripts/prepare_all_systems.sh
bash scripts/run_all_systems.sh
bash scripts/analyze_all_systems.sh
bash scripts/summarize_results.sh
```

## Recommended execution style

Do not run all 39 immediately. First run one system and inspect:

```bash
grep "Performance:" work/systems/lig001/md_200ps.log
ls work/systems/lig001
```

If the first system fails, fix topology/ligand naming before batch running all 39.

## D drive / WSL note

You can keep this project on Windows D drive and run it from WSL via:

```bash
cd /mnt/d/path/to/2fvj_gromacs_pipeline
```

But performance is usually worse on `/mnt/d` than inside WSL Linux storage. Best practice:

- Edit code/files from Windows using VS Code.
- Run heavy MD in WSL Linux filesystem, e.g. `~/md_projects/2fvj_gromacs_pipeline`.
- If you insist on D drive, it works, but expect slower file I/O.

A good compromise:

```bash
cp -r /mnt/d/path/to/2fvj_gromacs_pipeline ~/md_projects/
cd ~/md_projects/2fvj_gromacs_pipeline
```

Edit with VS Code Remote WSL or Windows Explorer via:

```text
\\wsl$\Ubuntu-24.04\home\<your_user>\md_projects\2fvj_gromacs_pipeline
```

## Outputs

Prepared systems:

```text
work/systems/lig001/
```

Main MD files:

```text
em.gro
nvt.gro
npt.gro
md_200ps.xtc
md_200ps.gro
md_200ps.log
```

Analysis files:

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
