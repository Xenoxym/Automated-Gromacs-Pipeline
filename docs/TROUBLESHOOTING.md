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

## `Could not find [ molecules ] in topol.top`

Usually a Windows CRLF parsing issue in an older script version, or a non-standard `topol.top`.
Re-run prepare on a clean `work/systems/<id>/` directory; `patch_topology.py` normalizes line endings.

## `acpype` fails

Most common causes:

1. Wrong ligand net charge.
2. Bad ligand geometry from docking output.
3. Missing hydrogens/protonation issue.
4. Metal-containing ligand or covalent ligand: GAFF2 route may not be appropriate.

Try manually inspecting `ligand.mol2` in PyMOL/ChimeraX/OpenBabel.

## `Atomtype ... not found`

The ligand atomtypes were not included before molecule definitions. Check `topol.top` contains:

```top
#include ".../forcefield.itp"
#include "ligand_atomtypes.itp"
...
#include "ligand.itp"
```

## `make_ndx` group numbers wrong

The script assumes default group numbers and creates LIG as group 20. If this fails, run manually:

```bash
gmx make_ndx -f em.gro -o index.ndx
```

Commands inside interactive prompt:

```text
r LIG
name <new_group_number> LIG
Protein | LIG
name <new_group_number> Protein_LIG
q
```

## `GPU update not supported`

Edit `config.env`:

```bash
GMX_MDRUN_GPU_FLAGS="-nb gpu -pme gpu -bonded gpu -pin on"
```

If still failing:

```bash
GMX_MDRUN_GPU_FLAGS="-nb gpu -pin on"
```

## Running from D drive is slow

Move project into WSL native filesystem:

```bash
mkdir -p ~/md_projects
cp -r /mnt/d/path/to/2fvj_gromacs_pipeline ~/md_projects/
cd ~/md_projects/2fvj_gromacs_pipeline
```
