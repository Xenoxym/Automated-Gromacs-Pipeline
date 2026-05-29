# Optional CHARMM36m + CGenFF route

This project defaults to AMBER99SB-ILDN + GAFF2 because it is easier to automate locally with AmberTools + ACPYPE.

CHARMM36m + CGenFF is also a common protein-ligand MD route. Typical steps:

1. Use CHARMM36m for protein in GROMACS.
2. Generate ligand parameters using CGenFF / ParamChem / CHARMM-GUI.
3. Convert CGenFF output to GROMACS ligand `.itp`/`.prm`.
4. Include ligand parameters in `topol.top` in correct order.
5. Use CHARMM-compatible water/ion parameters.

Do not mix CHARMM protein force field with GAFF ligand parameters casually. Use a coherent force-field family unless you know exactly what you are doing.
