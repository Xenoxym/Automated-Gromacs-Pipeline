#!/usr/bin/env bash
set -euo pipefail

cat <<'TXT'
Windows D: drive paths in WSL (example):

D:\Projects\Automated-Gromacs-Pipeline
becomes:
/mnt/d/Projects/Automated-Gromacs-Pipeline

Example:
cd /mnt/d/Projects/Automated-Gromacs-Pipeline
conda activate mdtools

Recommended faster option (WSL native filesystem):
mkdir -p ~/md_projects
cp -r /mnt/d/Projects/Automated-Gromacs-Pipeline ~/md_projects/
cd ~/md_projects/Automated-Gromacs-Pipeline

Edit from Windows Explorer (Ubuntu 22.04 WSL):
\\wsl$\Ubuntu-22.04\home\<your_user>\md_projects\Automated-Gromacs-Pipeline

If your distro name differs, run: wsl -l -v

Or use VS Code Remote WSL:
code .
TXT
