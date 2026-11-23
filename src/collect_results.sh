#!/bin/bash
# =============================================================================
# Turn the run records of all participants into tables that compare the four
# approaches for every task.
#
# Usage: bash src/collect_results.sh          # everybody's runs
#        bash src/collect_results.sh --mine   # only your runs
#
# Inputs  (written automatically):
#   results/jobs/<job_id>.tsv         by every job when it ends
#   results/submissions/<id>.tsv      by submit.sh (queue priority and rank)
#   results/sacct/<job_id>.tsv        by this script (CPU time and memory, from sacct)
# Outputs:
#   results/runs.tsv      one line per run (an array = one run)
#   results/summary.tsv   averages per task x approach (successful runs only)
#   (with --mine they go to output/<user>/ instead)
#
# Main columns:
#   queue_wait_s   submit -> first job started
#   compute_s      first job started -> last job finished
#   turnaround_s   submit -> last job finished (what you actually wait)
#   cpu_h          CPU-hours reserved (elapsed x CPUs): what the run "costs"
#   cpu_eff_%      CPU time really used / CPU time reserved
#   rank           position among pending jobs right after submission (submit.sh)
# =============================================================================
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
export LC_ALL=C # decimal point, not comma (ssh may forward e.g. es_ES)

mine=""
case ${1:-} in
    "") ;;
    --mine) mine="$USER" ;;
    *) sed -n '6,7s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac

jobs_dir="$RESULTS_DIR/jobs"
subs_dir="$RESULTS_DIR/submissions"
sacct_dir="$RESULTS_DIR/sacct"
compgen -G "$jobs_dir/*.tsv" >/dev/null || die "No run records yet in $jobs_dir"

if [[ -n $mine ]]; then out_dir="$OUTPUT_ROOT/$USER"; else out_dir="$RESULTS_DIR"; fi
mkdir -p "$out_dir"

# ---- 1) CPU time and peak memory from sacct ---------------------------------
# Only finished jobs you are allowed to see; cached so others can reuse them.
# Prints: job_id state alloc_cpus total_cpu_s max_rss_mb
sacct_summary() {
    sacct -n -P -j "$1" --format=JobIDRaw,State,AllocCPUS,TotalCPU,MaxRSS 2>/dev/null | awk -F'|' -v id="$1" '
        function secs(t,   d, a, n) {          # [D-]HH:MM:SS[.ms] | MM:SS.ms
            d = 0
            if (index(t, "-")) { d = substr(t, 1, index(t, "-") - 1); t = substr(t, index(t, "-") + 1) }
            n = split(t, a, ":")
            if (n == 3) return d * 86400 + a[1] * 3600 + a[2] * 60 + a[3]
            if (n == 2) return d * 86400 + a[1] * 60 + a[2]
            return d * 86400 + a[1]
        }
        function mb(r,   u, v) {
            u = substr(r, length(r)); v = r + 0
            if (u == "K") return v / 1024
            if (u == "M") return v
            if (u == "G") return v * 1024
            if (u == "T") return v * 1048576
            return v / 1048576
        }
        $1 == id { state = $2; alloc = $3; cpu = secs($4) }
        { m = mb($5); if (m > rss) rss = m }
        END {
            if (state == "" || state ~ /^(PENDING|RUNNING|COMPLETING|REQUEUED|SUSPENDED)/) exit 1
            sub(/ .*/, "", state)                  # "CANCELLED by 123" -> CANCELLED
            printf "%s\t%s\t%s\t%.0f\t%.0f\n", id, state, alloc, cpu, rss
        }'
}

if command -v sacct >/dev/null; then
    mkdir -p "$sacct_dir"
    for f in "$jobs_dir"/*.tsv; do
        id=$(basename "$f" .tsv)
        [[ $id =~ ^[0-9]+$ && ! -s $sacct_dir/$id.tsv ]] || continue
        if sacct_summary "$id" >"$sacct_dir/.$id.tmp"; then
            mv "$sacct_dir/.$id.tmp" "$sacct_dir/$id.tsv"
        else
            rm -f "$sacct_dir/.$id.tmp"
        fi
    done
fi

# ---- 2) Merge: one line per run + averages per task x approach --------------
cat_dir() { find "$1" -maxdepth 1 -name '*.tsv' -exec cat {} + 2>/dev/null || true; }

summary_body=$(awk -F'\t' -v OFS='\t' -v mine="$mine" -v runs_out="$out_dir/runs.tsv" '
    FILENAME == ARGV[1] { sa_cpu[$1] = $4; sa_rss[$1] = $5; next }
    FILENAME == ARGV[2] { s_rank[$1] = $13; s_pend[$1] = $14; next }
    {
        # job record: 1 run_id 2 job_id 3 user 4 approach 5 task 6 mode 7 n_samples
        # 8 nodes 9 node_list 10 ntasks 11 cpus_per_task 12 alloc_cpus 13 partition
        # 14 qos 15 reservation 16 priority 17 submit 18 start 19 end 20 wait 21 elapsed 22 exit
        if (NF < 22 || (mine != "" && $3 != mine)) next
        r = $1
        if (!(r in user)) {
            order[++nr] = r; user[r] = $3; appr[r] = $4; task[r] = $5
            fsub[r] = $17; fstart[r] = $18; lend[r] = $19
        }
        njobs[r]++; samples[r] += $7; cpus[r] += $12
        n = split($9, nl, ",")
        for (i = 1; i <= n; i++) if (!((r, nl[i]) in seen)) { seen[r, nl[i]] = 1; nodes[r]++ }
        if ($17 < fsub[r]) fsub[r] = $17
        if ($18 < fstart[r]) fstart[r] = $18
        if ($19 > lend[r]) lend[r] = $19
        alloc_s[r] += $21 * $12
        if ($2 in sa_cpu) { used_s[r] += sa_cpu[$2]; n_sa[r]++; if (sa_rss[$2] > rss[r]) rss[r] = sa_rss[$2] }
        if ($22 != 0) failed[r]++
        if ($16 != "-") { prio[r] += $16; n_prio[r]++ }
    }
    END {
        print "run_id", "user", "task", "approach", "status", "jobs", "samples", "nodes", "cpus",
              "queue_wait_s", "compute_s", "turnaround_s", "cpu_h", "cpu_eff_%", "max_rss_mb",
              "priority", "rank", "pending" > runs_out
        for (k = 1; k <= nr; k++) {
            r = order[k]
            status = failed[r] ? "FAILED" : "OK"
            wait = fstart[r] - fsub[r]; comp = lend[r] - fstart[r]; turn = lend[r] - fsub[r]
            cpuh = alloc_s[r] / 3600
            eff = (n_sa[r] == njobs[r] && alloc_s[r] > 0) ? 100 * used_s[r] / alloc_s[r] : -1
            pr = n_prio[r] ? prio[r] / n_prio[r] : -1
            rk = (r in s_rank) ? s_rank[r] : -1
            print r, user[r], task[r], appr[r], status, njobs[r], samples[r], nodes[r], cpus[r],
                  wait, comp, turn, sprintf("%.3f", cpuh),
                  (eff < 0 ? "-" : sprintf("%.0f", eff)), (n_sa[r] ? sprintf("%.0f", rss[r]) : "-"),
                  (pr < 0 ? "-" : sprintf("%.0f", pr)), (rk < 0 ? "-" : rk),
                  ((r in s_pend) ? s_pend[r] : "-") > runs_out

            if (status != "OK") continue
            g = task[r] "\t" appr[r]
            if (!(g in G)) G[g] = 1
            G_n[g]++; G_cpus[g] += cpus[r]; G_nodes[g] += nodes[r]
            G_wait[g] += wait; G_comp[g] += comp; G_turn[g] += turn; G_cpuh[g] += cpuh
            if (eff >= 0) { G_eff[g] += eff; G_neff[g]++ }
            if (pr >= 0)  { G_prio[g] += pr; G_nprio[g]++ }
            if (rk > 0)   { G_rank[g] += rk; G_nrank[g]++ }
        }
        for (g in G) {
            n = G_n[g]
            print g, n, sprintf("%.0f", G_cpus[g] / n), sprintf("%.1f", G_nodes[g] / n),
                  sprintf("%.0f", G_wait[g] / n), sprintf("%.0f", G_comp[g] / n),
                  sprintf("%.0f", G_turn[g] / n), sprintf("%.3f", G_cpuh[g] / n),
                  (G_neff[g]  ? sprintf("%.0f", G_eff[g] / G_neff[g]) : "-"),
                  (G_nprio[g] ? sprintf("%.0f", G_prio[g] / G_nprio[g]) : "-"),
                  (G_nrank[g] ? sprintf("%.1f", G_rank[g] / G_nrank[g]) : "-")
        }
    }' <(cat_dir "$sacct_dir") <(cat_dir "$subs_dir") <(cat_dir "$jobs_dir") | sort -t $'\t' -k1,1 -k2,2)

# runs.tsv: keep the header, sort by task, approach, run id
{ head -n 1 "$out_dir/runs.tsv"; tail -n +2 "$out_dir/runs.tsv" | sort -t $'\t' -k3,3 -k4,4 -k1,1n; } >"$out_dir/.runs.tmp"
mv "$out_dir/.runs.tmp" "$out_dir/runs.tsv"

{
    printf 'task\tapproach\truns\tcpus\tnodes\tqueue_wait_s\tcompute_s\tturnaround_s\tcpu_h\tcpu_eff_%%\tpriority\trank\n'
    [[ -n $summary_body ]] && printf '%s\n' "$summary_body"
} >"$out_dir/summary.tsv"

# ---- 3) Show --------------------------------------------------------------
pretty() { column -t -s $'\t' "$1"; }

if [[ -n $mine ]]; then
    echo "== Your runs ($out_dir/runs.tsv)"
    pretty "$out_dir/runs.tsv"
    echo
fi
echo "== Average per task and approach, successful runs ($out_dir/summary.tsv)"
pretty "$out_dir/summary.tsv"
echo
echo "cpu_eff_% needs sacct data: it appears once the jobs have finished."
