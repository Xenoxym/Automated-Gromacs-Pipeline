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

## `make_ndx` group numbers wrong

`run_one_system.sh` assumes default groups and creates LIG as group 20. If this fails, run manually:

```bash
gmx make_ndx -f em.gro -o index.ndx
```

Inside the prompt:

```text
r UNL
name <new_group_number> LIG
Protein | LIG
name <new_group_number> Protein_LIG
q
```

(Replace `UNL` with your `LIGAND_RESNAME` if different.)

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
