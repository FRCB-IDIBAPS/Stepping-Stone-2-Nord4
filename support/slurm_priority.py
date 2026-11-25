#!/usr/bin/env python3
"""
Draw support/slurm_priority.png: the Slurm multifactor priority formula, what
each factor means, and a real Nord4 example taken from the exercise
(results/submissions/<job_id>.tsv, written by src/submit.sh from `sprio`).

    python3 support/slurm_priority.py            # writes support/slurm_priority.png

Needs only matplotlib.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyBboxPatch, Rectangle  # noqa: E402

OUT = Path(__file__).with_suffix(".png")

# Palette (validated categorical slots) and neutral tokens, light theme
SURFACE, TEXT, TEXT2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
PANEL = "#f3f2ee"

# Factor, colour, what it measures, what raises it, value in the example job
FACTORS = [
    ("Fair-share", "#2a78d6", "How much your account used recently,\ncompared with the share it was given",
     "Your group used little lately\n(past usage fades over time)", 5199),
    ("QOS", "#eb6834", "Priority of the quality of service\nyou asked for (--qos=cli)",
     "Using a QOS with a higher priority", 1000),
    ("Job size", "#1baf7a", "How many CPUs / nodes\nthe job requests",
     "Asking for more resources\n(1 CPU = 14, 8 CPUs = 16 here)", 16),
    ("Age", "#eda100", "How long the job has been\nwaiting in the queue",
     "Waiting longer (grows until a\nmaximum age, then stays flat)", 0),
    ("Partition", "#e87ba4", "Priority of the partition\nthe job was sent to",
     "Submitting to a higher-priority\npartition", 0),
]
EXAMPLE = "bowtie2 · approach 3 (job 38045988), right after submission"
TOTAL = 6214  # sprio total (the sum of the rounded terms can differ by 1)


def main():
    plt.rcParams.update({"font.size": 12, "text.color": TEXT,
                         "figure.facecolor": SURFACE, "savefig.facecolor": SURFACE})
    fig = plt.figure(figsize=(16, 9))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 9)
    ax.set_axis_off()

    # ---- title --------------------------------------------------------------
    ax.text(0.6, 8.45, "How Slurm decides which job starts first", fontsize=24, fontweight="bold")
    ax.text(0.6, 8.0, "Every pending job gets a priority number, recalculated every few minutes. "
            "The highest number starts first as soon as its resources are free.",
            fontsize=13, color=TEXT2)

    # ---- formula ------------------------------------------------------------
    ax.add_patch(FancyBboxPatch((0.6, 6.45), 14.8, 1.2, boxstyle="round,pad=0,rounding_size=0.12",
                                fc=PANEL, ec="none"))
    formula = (r"$\mathrm{Priority} \;=\; W_{\mathrm{fairshare}} F_{\mathrm{fairshare}}"
               r" + W_{\mathrm{QOS}} F_{\mathrm{QOS}}"
               r" + W_{\mathrm{size}} F_{\mathrm{size}}"
               r" + W_{\mathrm{age}} F_{\mathrm{age}}"
               r" + W_{\mathrm{partition}} F_{\mathrm{partition}}"
               r" \;(+\, \mathrm{site} + \Sigma\, W_{\mathrm{TRES}} F_{\mathrm{TRES}} - \mathrm{nice})$")
    ax.text(8.0, 7.17, formula, fontsize=19, ha="center", va="center")
    ax.text(8.0, 6.68, "each factor F is a number between 0 and 1   ·   each weight W is chosen by the "
            "site administrators (see them with  sprio -w)", fontsize=11.5, ha="center",
            va="center", color=TEXT2)

    # ---- factor table -------------------------------------------------------
    x_name, x_what, x_up, x_val = 0.95, 3.0, 7.3, 11.2
    y = 6.05
    for x, h in ((x_name, "Factor"), (x_what, "What it measures"), (x_up, "It goes up when..."),
                 (x_val, "Your job on Nord4")):
        ax.text(x, y, h, fontsize=12, fontweight="bold", color=TEXT2, va="center")
    row_h = 0.62
    for i, (name, col, what, up, val) in enumerate(FACTORS):
        yy = y - 0.55 - i * row_h
        ax.plot([0.6, 15.4], [yy + row_h / 2, yy + row_h / 2], color=GRID, lw=1)
        ax.add_patch(Rectangle((0.6, yy - 0.11), 0.22, 0.22, color=col, lw=0))
        ax.text(x_name, yy, name, fontsize=13, fontweight="bold", va="center")
        ax.text(x_what, yy, what, fontsize=10.5, va="center", color=TEXT, linespacing=1.15)
        ax.text(x_up, yy, up, fontsize=10.5, va="center", color=TEXT, linespacing=1.15)
        share = (f"{val / TOTAL:.0%} of the total" if val / TOTAL >= 0.01 else "<1% of the total") if val else "nothing yet" if name == "Age" else "no effect here"
        ax.text(x_val, yy, f"{val:,}", fontsize=13, fontweight="bold", va="center")
        ax.text(x_val + 0.85, yy, share, fontsize=10.5, va="center", color=TEXT2)

    # ---- example: stacked bar -----------------------------------------------
    yb = 1.82
    ax.text(0.6, yb + 0.55, f"Example: {EXAMPLE}", fontsize=13, fontweight="bold")
    ax.text(15.4, yb + 0.55, f"Priority = {TOTAL:,}", fontsize=13, fontweight="bold", ha="right")
    x0, width = 0.6, 14.8
    left = x0
    for name, col, _, _, val in FACTORS:
        if not val:
            continue
        w = width * val / TOTAL
        ax.add_patch(Rectangle((left, yb - 0.2), max(w - 0.03, 0.04), 0.4, color=col, lw=0))
        if w > 1.5:
            ax.text(left + 0.12, yb, f"{name}  {val:,}", fontsize=12, va="center", color="#ffffff",
                    fontweight="bold")
        else:  # thin segment: label beside it
            ax.annotate(f"{name}  {val:,}", (left + w / 2, yb - 0.2), (left + w / 2 - 0.1, yb - 0.55),
                        fontsize=11, ha="right", va="center", color=TEXT,
                        arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))
        left += w
    ax.text(0.6, yb - 0.55, "Age 0 and Partition 0: the job had just been submitted, and the "
            "partition adds nothing.", fontsize=10.5, color=TEXT2, va="center")
    ax.text(0.6, yb - 0.88, "Priority sets the order, but backfill can still start a lower-priority "
            "job early if it fits in a gap without delaying any job above it.",
            fontsize=10.5, color=TEXT2, va="center")

    # ---- footer: commands + backfill note ------------------------------------
    ax.add_patch(FancyBboxPatch((0.6, 0.2), 14.8, 0.6, boxstyle="round,pad=0,rounding_size=0.12",
                                fc=PANEL, ec="none"))
    ax.text(0.85, 0.5, "Try it:", fontsize=11.5, fontweight="bold", va="center")
    cmds = [("sprio -w", "weights"), ("sprio -j <jobid>", "your job's factors"),
            ("sshare -U", "your fair-share"), ("squeue --me --start", "estimated start")]
    for x, (c, d) in zip((1.9, 4.75, 8.85, 11.75), cmds):
        ax.text(x, 0.5, c, fontsize=11.5, family="monospace", va="center")
        ax.text(x + 0.105 * len(c) + 0.2, 0.5, d, fontsize=10.5, color=TEXT2, va="center")

    fig.savefig(OUT, dpi=120)
    print(f"Written {OUT}")


if __name__ == "__main__":
    main()
