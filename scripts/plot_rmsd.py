#!/usr/bin/env python3
"""Plot protein–ligand complex RMSD (and optional H-bond) from analyze_one_system.sh outputs."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def read_xvg(path: Path) -> tuple[list[float], list[float]]:
    t: list[float] = []
    y: list[float] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line or line[0] in "#@":
            continue
        parts = line.split()
        if len(parts) >= 2:
            t.append(float(parts[0]))
            y.append(float(parts[1]))
    return t, y


def ps_to_ns(ps: list[float]) -> list[float]:
    return [x / 1000.0 for x in ps]


def nm_to_angstrom(nm: list[float]) -> list[float]:
    return [x * 10.0 for x in nm]


def plot_rmsd_complex(
    analysis_dir: Path,
    out_path: Path,
    system_id: str,
) -> dict[str, float]:
    import matplotlib.pyplot as plt

    xvg = analysis_dir / "rmsd_complex.xvg"
    if not xvg.is_file():
        raise FileNotFoundError(f"Missing {xvg} (run analyze_one_system.sh first)")

    tp, rp = read_xvg(xvg)
    time_ns = ps_to_ns(tp)
    rmsd_A = nm_to_angstrom(rp)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(time_ns, rmsd_A, label="Protein_LIG (complex)", color="steelblue", lw=1.5)

    ax.set_xlabel("Time (ns)")
    ax.set_ylabel("RMSD (Å)")
    ax.set_title(f"Complex RMSD — {system_id}")
    ax.legend(loc="best")
    ax.grid(True, alpha=0.25)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)

    return {
        "complex_mean_A": sum(rmsd_A) / len(rmsd_A),
        "complex_max_A": max(rmsd_A),
        "t_end_ns": time_ns[-1] if time_ns else 0.0,
    }


def plot_hbond(analysis_dir: Path, out_path: Path, system_id: str) -> None:
    import matplotlib.pyplot as plt

    hb_xvg = analysis_dir / "hbond_protein_ligand.xvg"
    if not hb_xvg.is_file():
        return

    t, n = read_xvg(hb_xvg)
    fig, ax = plt.subplots(figsize=(8, 3.5))
    ax.plot(ps_to_ns(t), n, color="purple", lw=1.5)
    ax.set_xlabel("Time (ns)")
    ax.set_ylabel("H-bonds (count)")
    ax.set_title(f"Protein–ligand H-bonds — {system_id}")
    ax.grid(True, alpha=0.25)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


def plot_one_system(sys_dir: Path, skip_existing: bool) -> dict[str, str] | None:
    sys_dir = sys_dir.resolve()
    system_id = sys_dir.name
    analysis_dir = sys_dir / "analysis"
    if not analysis_dir.is_dir():
        print(f"SKIP {system_id}: no analysis/ directory", file=sys.stderr)
        return None

    rmsd_png = analysis_dir / "rmsd_complex.png"
    hbond_png = analysis_dir / "hbond.png"
    if skip_existing and rmsd_png.is_file():
        print(f"SKIP {system_id}: {rmsd_png} exists")
        return {"system": system_id, "status": "skipped"}

    try:
        stats = plot_rmsd_complex(analysis_dir, rmsd_png, system_id)
        plot_hbond(analysis_dir, hbond_png, system_id)
    except FileNotFoundError as e:
        print(f"SKIP {system_id}: {e}", file=sys.stderr)
        return None

    print(f"OK {system_id}: {rmsd_png}")
    if hbond_png.is_file():
        print(f"    {hbond_png}")
    return {
        "system": system_id,
        "status": "ok",
        "t_end_ns": f"{stats['t_end_ns']:.4f}",
        "complex_mean_A": f"{stats['complex_mean_A']:.3f}",
        "complex_max_A": f"{stats['complex_max_A']:.3f}",
    }


def write_summary(rows: list[dict[str, str]], out_tsv: Path) -> None:
    if not rows:
        return
    cols = ["system", "status", "t_end_ns", "complex_mean_A", "complex_max_A"]
    lines = ["\t".join(cols)]
    for r in rows:
        lines.append("\t".join(r.get(c, "") for c in cols))
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    out_tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {out_tsv}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Plot complex RMSD from work/systems/<id>/analysis/rmsd_complex.xvg"
    )
    parser.add_argument(
        "system_dir",
        nargs="?",
        help="Path to work/systems/<id> (omit with --all)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Plot every work/systems/*/ that has analysis/rmsd_complex.xvg",
    )
    parser.add_argument(
        "--project-dir",
        type=Path,
        default=None,
        help="Project root (default: parent of scripts/)",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip if analysis/rmsd_complex.png already exists",
    )
    args = parser.parse_args()

    try:
        import matplotlib  # noqa: F401
    except ImportError:
        print("ERROR: matplotlib required. Try: conda install -c conda-forge matplotlib", file=sys.stderr)
        return 1

    project_dir = (args.project_dir or Path(__file__).resolve().parent.parent).resolve()
    results_dir = project_dir / "results"
    rows: list[dict[str, str]] = []

    if args.all:
        systems_root = project_dir / "work" / "systems"
        if not systems_root.is_dir():
            print(f"ERROR: {systems_root} not found", file=sys.stderr)
            return 1
        for sys_dir in sorted(systems_root.iterdir()):
            if sys_dir.is_dir():
                row = plot_one_system(sys_dir, args.skip_existing)
                if row:
                    rows.append(row)
    elif args.system_dir:
        row = plot_one_system(Path(args.system_dir), args.skip_existing)
        if row:
            rows.append(row)
    else:
        parser.print_help()
        return 1

    write_summary(rows, results_dir / "rmsd_plot_summary.tsv")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
