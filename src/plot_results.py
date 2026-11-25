#!/usr/bin/env python3
"""
Plot the comparison tables written by src/collect_results.sh and highlight,
for every task, which approach is best on each metric (time, cost, efficiency).

Usage (run it on YOUR machine or anywhere with a display; it only reads a small
TSV, nothing heavy):
    python3 src/plot_results.py                          # output/<you>/summary.tsv
    python3 src/plot_results.py output/idib057549        # a folder with summary.tsv
    python3 src/plot_results.py results/summary.tsv      # everybody's runs
Options:
    -o FILE        image to write (default: summary.png next to summary.tsv)
    --no-show      only write the image, do not open a window
    --dark         dark background
    --tolerance X  values within X (fraction, default 0.05 = 5%) of the best
                   count as a tie: 29 s vs 30 s of queue wait is not a "win"

If runs.tsv is next to summary.tsv, task/approach pairs whose runs all FAILED
are marked as "failed" instead of just being missing.

Needs only matplotlib (pip install matplotlib).
"""
import argparse
import csv
import getpass
import os
import sys
from pathlib import Path

APPROACHES = ["1_simple", "2_array", "3_threads", "4_container"]
LABEL = {a: a.replace("_", " ") for a in APPROACHES}  # "2 array"

# (column, title, better, explanation). "speedup" is derived from compute_s.
METRICS = [
    ("turnaround_s", "Turnaround (s)", "lower", "submit → last job finished: what you wait"),
    ("compute_s", "Compute time (s)", "lower", "first job started → last job finished"),
    ("speedup", "Speed-up vs 1 simple (×)", "higher", "compute time of 1 simple / this approach"),
    ("cpu_h", "CPU-hours reserved", "lower", "elapsed × CPUs: what the run costs"),
    ("cpu_eff_%", "CPU efficiency (%)", "higher", "CPU time used / CPU time reserved"),
    ("queue_wait_s", "Queue wait (s)", "lower", "submit → first job started"),
]

# Validated categorical slots (one fixed colour per approach) + neutral tokens
THEMES = {
    "light": dict(series=["#2a78d6", "#eb6834", "#1baf7a", "#eda100"], surface="#fcfcfb",
                  text="#0b0b0b", text2="#52514e", muted="#898781", grid="#e1e0d9",
                  axis="#c3c2b7", win_bg="#eef4fc"),
    "dark": dict(series=["#3987e5", "#d95926", "#199e70", "#c98500"], surface="#1a1a19",
                 text="#f0efec", text2="#c3c2b7", muted="#898781", grid="#2c2c2a",
                 axis="#383835", win_bg="#1f2a38"),
}
DIM = 0.30  # opacity of the bars that are not the best for their task


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def read_tsv(path):
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def load(summary_path, runs_path):
    """data[task][approach][metric] = value (None when missing)."""
    data, failed = {}, set()
    for row in read_tsv(summary_path):
        d = data.setdefault(row["task"], {}).setdefault(row["approach"], {})
        for col, *_ in METRICS:
            if col != "speedup":
                d[col] = num(row.get(col))
    for task, per in data.items():
        base = per.get("1_simple", {}).get("compute_s")
        for a, d in per.items():
            c = d.get("compute_s")
            d["speedup"] = base / c if base and c else None

    if runs_path and runs_path.exists():
        ok, bad = set(), set()
        for row in read_tsv(runs_path):
            key = (row["task"], row["approach"])
            (ok if row.get("status") == "OK" else bad).add(key)
            data.setdefault(row["task"], {})
        failed = bad - ok
    return data, failed


def winners(per_task, col, better, tol):
    """Approaches within `tol` of the best value (ties are shared wins)."""
    vals = {a: d.get(col) for a, d in per_task.items() if d.get(col) is not None}
    if not vals:
        return [], None
    best = min(vals.values()) if better == "lower" else max(vals.values())
    margin = abs(best) * tol
    if better == "lower":
        win = [a for a, v in vals.items() if v <= best + margin]
    else:
        win = [a for a, v in vals.items() if v >= best - margin]
    return [a for a in APPROACHES if a in win], best


def fmt(v, col):
    if v is None:
        return "-"
    if col == "cpu_h":
        return f"{v:.3f}"
    if col == "speedup":
        return f"{v:.1f}×"
    if col == "cpu_eff_%":
        return f"{v:.0f}%"
    return f"{v:.0f}"


def winner_name(w, per_task):
    """'3 threads', '2 array = 3 threads', or 'all tie'"""
    if len(w) > 1 and len(w) == len(per_task):
        return "all tie"
    if len(w) <= 2:
        return " = ".join(LABEL[a] for a in w)
    return " = ".join(a.split("_")[0] for a in w)


def scoreboard(data, tol):
    """rows[task] = {col: (winners, best_value, n_approaches_with_data)}"""
    board = {}
    for task, per in data.items():
        board[task] = {}
        for col, _, better, _ in METRICS:
            w, best = winners(per, col, better, tol)
            n = sum(1 for d in per.values() if d.get(col) is not None)
            board[task][col] = (w, best, n)
    return board


def overall(board_row):
    """Approach(es) with most wins on the time/cost/efficiency metrics."""
    count = {}
    for col, (w, _, n) in board_row.items():
        if col == "queue_wait_s" or n < 2:  # queue wait is mostly noise; 1 entry = no contest
            continue
        for a in w:
            count[a] = count.get(a, 0) + 1
    if not count:
        return [], 0
    top = max(count.values())
    return [a for a in APPROACHES if count.get(a) == top], top


def print_board(data, board, failed):
    """Same information as the figure, as text (also the accessible view)."""
    cols = [m[0] for m in METRICS]
    head = ["task"] + [m[1].split(" (")[0] for m in METRICS] + ["most wins"]
    rows = []
    for task in sorted(data):
        r = [task]
        for col in cols:
            w, best, n = board[task][col]
            if not w:
                r.append("-")
            else:
                r.append(" = ".join(LABEL[a] for a in w) + f" ({fmt(best, col)})" + (" only" if n == 1 else ""))
        ow, k = overall(board[task])
        r.append(" = ".join(LABEL[a] for a in ow) + f" ({k})" if ow else "-")
        rows.append(r)
    widths = [max(len(x[i]) for x in rows + [head]) for i in range(len(head))]
    line = lambda r: "  ".join(c.ljust(widths[i]) for i, c in enumerate(r))
    print("Best approach per task (ties within tolerance share the win)")
    print(line(head))
    print(line(["-" * w for w in widths]))
    for r in rows:
        print(line(r))
    if failed:
        print("\nFailed (no successful run): " + ", ".join(f"{t}/{LABEL.get(a, a)}" for t, a in sorted(failed)))


def plot(data, board, failed, theme, tol, out, show, source):
    import matplotlib

    if not show:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch, Rectangle

    T = THEMES[theme]
    color = dict(zip(APPROACHES, T["series"]))
    tasks = sorted(data)
    plt.rcParams.update({
        "font.size": 10, "axes.edgecolor": T["axis"], "axes.labelcolor": T["text2"],
        "xtick.color": T["text2"], "ytick.color": T["muted"], "text.color": T["text"],
        "figure.facecolor": T["surface"], "axes.facecolor": T["surface"],
        "savefig.facecolor": T["surface"],
    })

    fig = plt.figure(figsize=(16, 11.5))
    grid = fig.add_gridspec(3, 3, height_ratios=[0.95, 1, 1], hspace=0.5, wspace=0.22,
                            left=0.05, right=0.98, top=0.90, bottom=0.06)
    fig.suptitle("Which approach fits each task best?", x=0.05, ha="left",
                 fontsize=16, fontweight="bold", color=T["text"])
    fig.text(0.05, 0.935, f"Best value per task highlighted · ties within {tol:.0%} share the win · "
             "faded bars = not the best", color=T["text2"], fontsize=10)
    fig.text(0.05, 0.012, f"source: {source}", color=T["muted"], fontsize=8.5)

    # ---- scoreboard: rows = tasks, columns = metrics + most wins -------------
    ax = fig.add_subplot(grid[0, :])
    ax.set_axis_off()
    cols = METRICS + [("overall", "Most wins", "", "time, cost and efficiency metrics")]
    ncol, nrow = len(cols), len(tasks)
    cw, rh, x0 = 1.0 / (ncol + 0.6), 1.0 / (nrow + 1.3), 0.6 / (ncol + 0.6)
    for j, (col, title, better, _) in enumerate(cols):
        x = x0 + j * cw
        sub = f"{better} is better" if better else "count of wins"
        ax.text(x + 0.008, 1 - rh * 0.35, title, fontweight="bold", fontsize=9.5, va="center", color=T["text"])
        ax.text(x + 0.008, 1 - rh * 0.85, sub, fontsize=8.5, va="center", color=T["muted"])
    for i, task in enumerate(tasks):
        y = 1 - rh * (i + 1.75)
        ax.add_line(plt.Line2D([0, 1], [y + rh / 2, y + rh / 2], color=T["grid"], lw=0.8))
        ax.text(0.0, y, task, fontweight="bold", va="center", fontsize=10.5, color=T["text"])
        for j, (col, *_rest) in enumerate(cols):
            x = x0 + j * cw
            if col == "overall":
                w, k = overall(board[task])
                val = f"{k} wins" if w else ""
                n = 2
            else:
                w, best, n = board[task][col]
                val = fmt(best, col) + ("  (only run)" if n == 1 else "")
            if not w:
                ax.text(x + 0.008, y, "no data", va="center", color=T["muted"], fontsize=9)
                continue
            if col == "overall":
                ax.add_patch(Rectangle((x, y - rh * 0.45), cw * 0.96, rh * 0.9, color=T["win_bg"], lw=0))
            for k_, a in enumerate(w[:4]):  # colour chips carry identity, text names it
                ax.add_patch(Rectangle((x + 0.008 + k_ * 0.011, y + rh * 0.06), 0.008, rh * 0.32,
                                       color=color[a], lw=0, alpha=1 if n > 1 else 0.5))
            name = winner_name(w, data[task])
            ax.text(x + 0.012 + min(len(w), 4) * 0.011, y + rh * 0.22, name, va="center", fontsize=9.5,
                    color=T["text"] if n > 1 else T["muted"])
            ax.text(x + 0.008, y - rh * 0.22, val, va="center", fontsize=8.5, color=T["text2"])
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)

    # ---- one bar chart per metric: groups = tasks, bars = approaches ---------
    width = 0.19
    for m, (col, title, better, expl) in enumerate(METRICS):
        ax = fig.add_subplot(grid[1 + m // 3, m % 3])
        top = max([d.get(col) or 0 for per in data.values() for d in per.values()] + [1e-9])
        for i, task in enumerate(tasks):
            w = board[task][col][0]
            contest = board[task][col][2] > 1
            win_x, win_v = [], []
            for k, a in enumerate(APPROACHES):
                x = i + (k - 1.5) * width
                v = data[task].get(a, {}).get(col)
                if v is None:
                    if (task, a) in failed:
                        ax.text(x, top * 0.02, "×", ha="center", va="bottom", color=T["muted"], fontsize=9)
                    continue
                best = a in w and contest
                ax.bar(x, v, width * 0.9, color=color[a], alpha=1 if best or not contest else DIM,
                       edgecolor=T["surface"], linewidth=1.5, zorder=2)
                if best:
                    win_x.append(x)
                    win_v.append(v)
            if win_x:  # one label per task, centred over the (tied) best bars
                best_v = board[task][col][1]
                ax.text(sum(win_x) / len(win_x), max(win_v) + top * 0.02, fmt(best_v, col),
                        ha="center", va="bottom", fontsize=8, color=T["text"], fontweight="bold")
        ax.set_title(title, loc="left", fontweight="bold", fontsize=11, color=T["text"], pad=16)
        ax.text(0, 1.02, f"{better} is better · {expl}", transform=ax.transAxes, fontsize=8.5,
                color=T["muted"], va="bottom")
        ax.set_xlim(-0.55, len(tasks) - 0.45)
        ax.set_xticks(range(len(tasks)))
        ax.set_xticklabels(tasks)
        ax.tick_params(axis="x", length=0)
        ax.tick_params(axis="y", length=0, labelsize=8.5)
        ax.set_ylim(0, top * 1.18)
        ax.grid(axis="y", color=T["grid"], lw=0.8, zorder=0)
        for s in ("top", "right", "left"):
            ax.spines[s].set_visible(False)
        ax.spines["bottom"].set_color(T["axis"])

    handles = [Patch(color=color[a], label=LABEL[a]) for a in APPROACHES]
    handles.append(Patch(color=T["surface"], label="×  failed / not available"))
    leg = fig.legend(handles=handles, loc="upper right", ncol=5, frameon=False, fontsize=10,
                     bbox_to_anchor=(0.98, 0.965), handlelength=1.2)
    for t in leg.get_texts():  # (labelcolor= needs matplotlib >= 3.5; Nord4 has older)
        t.set_color(T["text"])

    fig.savefig(out, dpi=130)
    print(f"\nFigure written to {out}")
    if show:
        plt.show()


def main():
    repo = Path(__file__).resolve().parent.parent
    default = repo / "output" / os.environ.get("USER", getpass.getuser()) / "summary.tsv"
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("summary", nargs="?", default=str(default), help="summary.tsv or the folder that has it")
    p.add_argument("-o", "--output", help="image to write (default: summary.png next to summary.tsv)")
    p.add_argument("--no-show", action="store_true", help="do not open a window")
    p.add_argument("--dark", action="store_true", help="dark background")
    p.add_argument("--tolerance", type=float, default=0.05, help="tie margin as a fraction (default 0.05)")
    a = p.parse_args()

    summary = Path(a.summary)
    if summary.is_dir():
        summary = summary / "summary.tsv"
    if not summary.exists():
        sys.exit(f"Not found: {summary}\nRun `sbatch src/collect_results.sh --mine` first, "
                 "or pass the path of a summary.tsv")
    out = Path(a.output) if a.output else summary.with_suffix(".png")

    data, failed = load(summary, summary.with_name("runs.tsv"))
    if not any(data.values()):
        sys.exit(f"No successful runs in {summary}")
    board = scoreboard(data, a.tolerance)
    print_board(data, board, failed)

    try:
        import matplotlib  # noqa: F401
    except ImportError:
        sys.exit("\nNo figure: matplotlib is not installed for this python3 "
                 f"({sys.executable}).\nInstall it (pip install --user matplotlib), load a Python "
                 "module that has it, or run this script on your own machine.")

    show = not a.no_show and (sys.platform == "darwin" or os.name == "nt"
                              or bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")))
    plot(data, board, failed, "dark" if a.dark else "light", a.tolerance, out, show, summary)


if __name__ == "__main__":
    main()
