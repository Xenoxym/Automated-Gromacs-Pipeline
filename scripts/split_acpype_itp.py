#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

SECTION_RE = re.compile(r"^\s*\[\s*([^\]]+)\s*\]")

# GROMACS requires atomtypes before any moleculetype.
# ACPYPE often puts [ atomtypes ] inside one ligand itp; this script splits it.

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--atomtypes-out", required=True)
    ap.add_argument("--ligand-out", required=True)
    args = ap.parse_args()

    text = Path(args.input).read_text().splitlines(True)
    atomtypes = []
    rest = []
    current_section = None
    in_atomtypes = False

    for line in text:
        m = SECTION_RE.match(line)
        if m:
            current_section = m.group(1).strip().lower()
            in_atomtypes = current_section == "atomtypes"
        if in_atomtypes:
            atomtypes.append(line)
        else:
            # Drop [ defaults ] if present; protein force field provides defaults.
            if current_section == "defaults":
                continue
            rest.append(line)

    if not any("[ atomtypes ]" in line for line in atomtypes):
        Path(args.atomtypes_out).write_text("; No ligand atomtypes found in input ITP.\n")
    else:
        Path(args.atomtypes_out).write_text("; Ligand atom types extracted from ACPYPE output.\n" + "".join(atomtypes) + "\n")

    Path(args.ligand_out).write_text("; Ligand bonded topology extracted from ACPYPE output.\n" + "".join(rest) + "\n")
    print(f"Wrote {args.atomtypes_out}")
    print(f"Wrote {args.ligand_out}")

if __name__ == "__main__":
    main()
