# Analysis outputs and plotting

After `analyze_one_system.sh`, each prepared/run system has an `analysis/` folder under `work/systems/<id>/`.

## Files from GROMACS (`analyze_one_system.sh`)

| File | Content |
|------|---------|
| `md_centered.xtc` | Trajectory centered on protein (PBC mol) |
| `rmsd_protein.xvg` | Backbone RMSD vs first frame |
| `rmsd_ligand.xvg` | Ligand RMSD (needs `LIG` in `index.ndx`) |
| `hbond_protein_ligand.xvg` | Protein–ligand H-bond count vs time |

`.xvg` units from GROMACS: **time in ps**, **RMSD in nm**. For plots and the table below, convert to **ns** (÷ 1000) and **Å** (× 10).

## Plots (`plot_rmsd.py`)

Requires `matplotlib` in `mdtools`:

```bash
conda activate mdtools
conda install -c conda-forge matplotlib
```

One system:

```bash
python scripts/plot_rmsd.py work/systems/lig001
```

All systems with analysis data:

```bash
python scripts/plot_rmsd.py --all
```

Outputs per system:

```text
work/systems/<id>/analysis/rmsd_dual.png    # protein + ligand RMSD
work/systems/<id>/analysis/hbond.png        # if hbond xvg exists
```

Batch summary:

```text
results/rmsd_plot_summary.tsv
```

## RMSD interpretation (Å)

| RMSD range | Stability | Notes |
|------------|-----------|--------|
| &lt; 2.0 Å | ★★★★★ Very stable | Little conformational change |
| 2.0–3.0 Å | ★★★★ Stable | Normal fluctuations, good binding |
| 3.0–5.0 Å | ★★★ Acceptable | Some motion, overall stable |
| &gt; 5.0 Å | ★★ Unstable | Large change or ligand departure |

**Plateau:** In the second half of the trajectory, RMSD fluctuates around a mean without a sustained climb → equilibrated.

**Protein vs ligand:**

- Protein often stable around **2–3 Å**.
- Ligand ideally **&lt; 3 Å** in the pocket.
- Ligand RMSD rising while protein stays low → possible unbinding or pose change.
- Both rising together → possible global rearrangement, not necessarily loss of binding.

## Simulation length

Default production is **`md_200ps`** (~**0.2 ns**). Long interpretations (e.g. 50–100 ns plateaus) require a longer `mdp` and `PRODUCTION_MDP` / `PRODUCTION_DEFFNM` in `config.env`.

## Workflow

```text
run_one_system.sh  →  md_*.xtc, md_*.tpr
analyze_one_system.sh  →  analysis/*.xvg
plot_rmsd.py  →  analysis/*.png + results/rmsd_plot_summary.tsv
summarize_results.sh  →  results/*_summary.tsv (run status, performance)
```
