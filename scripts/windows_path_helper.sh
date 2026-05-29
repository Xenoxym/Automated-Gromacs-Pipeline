#!/usr/bin/env bash
set -euo pipefail

cat <<'TXT'
Windows D drive paths in WSL:

D:\md\2fvj_gromacs_pipeline
becomes:
/mnt/d/md/2fvj_gromacs_pipeline

Example:
cd /mnt/d/md/2fvj_gromacs_pipeline

Recommended faster option:
mkdir -p ~/md_projects
cp -r /mnt/d/md/2fvj_gromacs_pipeline ~/md_projects/
cd ~/md_projects/2fvj_gromacs_pipeline

Edit from Windows Explorer using:
\\wsl$\Ubuntu-24.04\home\<your_user>\md_projects\2fvj_gromacs_pipeline

Or use VS Code:
code .
TXT
