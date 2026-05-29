#!/usr/bin/env python3
"""Normalize docked complex PDB for the GROMACS pipeline.

Handles docking outputs where the ligand is written as ATOM records (not HETATM),
often after a premature END and REMARK/CONECT blocks.
"""
from __future__ import annotations

import argparse
from pathlib import Path

RECORD_WIDTH = 6
PDB_COORD_RECORDS = frozenset({"ATOM", "HETATM"})


def record_type(line: str) -> str:
    return line[:RECORD_WIDTH].strip()


def resname_from_line(line: str) -> str:
    return line[17:20].strip()


def to_hetatm(line: str) -> str:
    if line.startswith("ATOM  "):
        return "HETATM" + line[6:]
    if line.startswith("ATOM"):
        return "HETATM" + line[4:]
    return line


def main() -> None:
    ap = argparse.ArgumentParser(description="Clean pose_1_complex.pdb for splitting")
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--ligand-resname", default="UNL")
    args = ap.parse_args()

    ligand_resname = args.ligand_resname.strip().upper()
    protein_lines: list[str] = []
    ligand_lines: list[str] = []

    with Path(args.input).open(encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n\r")
            if not line.strip():
                continue

            rec = record_type(line)
            if rec in PDB_COORD_RECORDS:
                rn = resname_from_line(line).upper()
                if rn == ligand_resname:
                    ligand_lines.append(to_hetatm(line) + "\n")
                else:
                    protein_lines.append(line + "\n")
                continue

            # Skip TER/END/REMARK/CONECT/etc.; we rebuild record order below.

    if not protein_lines:
        raise SystemExit("ERROR: No protein ATOM/HETATM records found in input PDB.")
    if not ligand_lines:
        raise SystemExit(
            f"ERROR: No ligand records with residue name {ligand_resname!r}. "
            "Set LIGAND_RESNAME in config.env."
        )

    n_protein = len(protein_lines)
    n_ligand = len(ligand_lines)
    out_lines = list(protein_lines)
    if not out_lines[-1].lstrip().startswith("TER"):
        out_lines.append("TER\n")
    out_lines.extend(ligand_lines)
    out_lines.append("END\n")

    out_path = Path(args.output)
    out_path.write_text("".join(out_lines), encoding="utf-8")
    print(
        f"Wrote {out_path} ({n_protein} protein atoms, "
        f"{n_ligand} ligand atoms as HETATM)"
    )


if __name__ == "__main__":
    main()
