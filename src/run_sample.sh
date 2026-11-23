#!/bin/bash
# =============================================================================
# Process ONE sample with ONE task. All four approaches call this script; they
# only differ in HOW MANY copies run at the same time and WHERE.
#
# Usage: bash src/run_sample.sh <task> <fastq> <outdir> <threads>
# Set EXEC_MODE=container to run the tool inside its Singularity image.
# =============================================================================
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

(( $# == 4 )) || die "Usage: run_sample.sh <task> <fastq> <outdir> <threads>"
task=$1 fq=$2 outdir=$3 threads=$4

load_task "$task"
[[ -r $fq ]] || die "Cannot read input file $fq"
name=$(sample_name "$fq")
mkdir -p "$outdir"

log "START $task $name | threads=$threads | $EXEC_MODE | $(hostname -s)"
t0=$(date +%s)

# On failure: say which sample failed and show the end of its tool log, if any
on_exit() {
    local rc=$? f
    (( rc == 0 )) && return
    log "FAILED $task $name (exit $rc)" >&2
    for f in "$outdir/$name".*.log; do
        [[ -f $f ]] && { echo "--- last lines of $f" >&2; tail -n 5 "$f" >&2; }
    done
}
trap on_exit EXIT

task_run "$fq" "$name" "$outdir" "$threads"

log "DONE  $task $name | $(fmt_duration $(($(date +%s) - t0)))"
