#!/usr/bin/env python3
"""Split cleaned docked complex PDB into protein and ligand files."""
from __future__ import annotations

import argparse
from pathlib import Path

PDB_COORD_RECORDS = frozenset({"ATOM", "HETATM"})


def resname_from_line(line: str) -> str:
    return line[17:20].strip()


def to_hetatm(line: str) -> str:
    if line.startswith("ATOM  "):
        return "HETATM" + line[6:]
    if line.startswith("ATOM"):
        return "HETATM" + line[4:]
    return line


def main() -> None:
    ap = argparse.ArgumentParser(description="Split docked complex PDB into protein and ligand")
    ap.add_argument("--input", required=True)
    ap.add_argument("--ligand-resname", default="UNL")
    ap.add_argument("--protein-out", required=True)
    ap.add_argument("--ligand-out", required=True)
    args = ap.parse_args()

    ligand_resname = args.ligand_resname.strip().upper()
    protein_lines: list[str] = []
    ligand_lines: list[str] = []

    with Path(args.input).open(encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n\r")
            if not line:
                continue
            rec = line[:6].strip()
            if rec not in PDB_COORD_RECORDS:
                continue
            rn = resname_from_line(line).upper()
            if rn == ligand_resname:
                ligand_lines.append(to_hetatm(line) + "\n")
            else:
                protein_lines.append(line + "\n")

    if not protein_lines:
        raise SystemExit("ERROR: No protein ATOM/HETATM records found.")
    if not ligand_lines:
        raise SystemExit(
            f"ERROR: No ligand records with residue name {ligand_resname!r}. "
            "Check LIGAND_RESNAME or run clean_docked_pdb.py first."
        )

    Path(args.protein_out).write_text("".join(protein_lines) + "TER\nEND\n", encoding="utf-8")
    Path(args.ligand_out).write_text("".join(ligand_lines) + "TER\nEND\n", encoding="utf-8")

    print(f"Wrote {args.protein_out} with {len(protein_lines)} protein atoms")
    print(f"Wrote {args.ligand_out} with {len(ligand_lines)} ligand atoms")


if __name__ == "__main__":
    main()
