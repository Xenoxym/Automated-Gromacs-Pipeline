#!/usr/bin/env python3
"""Patch pdb2gmx topol.top for an ACPYPE ligand (idempotent)."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

SECTION_RE = re.compile(r"^\s*\[\s*([^\]]+)\s*\]", re.IGNORECASE)
FORCEFIELD_INCLUDE_RE = re.compile(
    r'^\s*#include\s+"(?P<path>[^"]*forcefield\.itp)"\s*$',
    re.IGNORECASE,
)
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')
MOLECULE_ENTRY_RE = re.compile(r"^(\s*)(\S+)(\s+)(\d+)(\s*)$")


def normalize_name(name: str) -> str:
    return name.strip().upper()


def has_include(lines: list[str], include_file: str) -> bool:
    target = include_file.strip().lower()
    for line in lines:
        m = INCLUDE_RE.match(line)
        if m and m.group(1).strip().lower() == target:
            return True
    return False


def insert_after_forcefield(
    lines: list[str],
    include_files: list[str],
) -> list[str]:
    if all(has_include(lines, inc) for inc in include_files):
        return lines

    out: list[str] = []
    inserted = False
    for line in lines:
        out.append(line)
        if inserted:
            continue
        if FORCEFIELD_INCLUDE_RE.match(line):
            for inc in include_files:
                if not has_include(lines, inc):
                    out.append(f'#include "{inc}"\n')
            inserted = True
    if not inserted:
        raise SystemExit('ERROR: Could not find #include "…forcefield.itp" in topol.top')
    return out


def patch_system_name(lines: list[str], system_name: str) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = SECTION_RE.match(line)
        if m and normalize_name(m.group(1)) == "SYSTEM":
            out.append(line)
            i += 1
            while i < len(lines) and (
                lines[i].strip() == "" or lines[i].lstrip().startswith(";")
            ):
                out.append(lines[i])
                i += 1
            if i < len(lines) and not SECTION_RE.match(lines[i]):
                out.append(f"{system_name}\n")
                i += 1
            continue
        out.append(line)
        i += 1
    return out


def add_ligand_to_molecules(lines: list[str], ligand_name: str) -> list[str]:
    ligand_key = normalize_name(ligand_name)
    out: list[str] = []
    i = 0
    found_molecules = False
    ligand_present = False

    while i < len(lines):
        line = lines[i]
        m = SECTION_RE.match(line)
        if m and normalize_name(m.group(1)) == "MOLECULES":
            found_molecules = True
            out.append(line)
            i += 1
            while i < len(lines):
                cur = lines[i]
                cur_section = SECTION_RE.match(cur)
                if cur_section:
                    break
                stripped = cur.strip()
                if stripped == "" or stripped.startswith(";"):
                    out.append(cur)
                    i += 1
                    continue
                entry = MOLECULE_ENTRY_RE.match(cur)
                if entry:
                    name = entry.group(2)
                    if normalize_name(name) == ligand_key:
                        ligand_present = True
                    out.append(cur)
                    i += 1
                    continue
                out.append(cur)
                i += 1
            if not ligand_present:
                out.append(f"{ligand_name:<20s} 1\n")
            continue

        out.append(line)
        i += 1

    if not found_molecules:
        raise SystemExit("ERROR: Could not find [ molecules ] section in topol.top")
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--topol", required=True)
    ap.add_argument("--ligand-name", default="UNL")
    ap.add_argument("--atomtypes-include", default="ligand_atomtypes.itp")
    ap.add_argument("--ligand-include", default="ligand.itp")
    ap.add_argument("--system-name", default="Protein-ligand complex")
    args = ap.parse_args()

    path = Path(args.topol)
    raw = path.read_text(encoding="utf-8", errors="replace")
    raw = raw.replace("\r\n", "\n").replace("\r", "\n")
    lines = raw.splitlines(True)

    includes = [args.atomtypes_include, args.ligand_include]
    lines = insert_after_forcefield(lines, includes)
    lines = patch_system_name(lines, args.system_name)
    lines = add_ligand_to_molecules(lines, args.ligand_name)

    path.write_text("".join(lines), encoding="utf-8")
    print(f"Patched {path} (ligand {args.ligand_name}, includes after forcefield.itp)")


if __name__ == "__main__":
    main()
