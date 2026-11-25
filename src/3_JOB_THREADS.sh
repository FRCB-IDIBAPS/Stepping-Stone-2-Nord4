#!/bin/bash
# =============================================================================
# APPROACH 3 - PARALLEL JOB WITH TASKS AND THREADS
# One job with 4 tasks x 2 CPUs. Each sample runs as a job step (srun) on
# its own task, all at the same time, and each tool uses 2 threads.
#   --ntasks        = how many processes run side by side (here: samples)
#   --cpus-per-task = how many threads each process can use
#
# Usage (from the repository folder):
#   sbatch src/3_JOB_THREADS.sh <task>
#   sbatch --ntasks=2 --cpus-per-task=4 src/3_JOB_THREADS.sh fastp   # other split
#   bash src/submit.sh 3 <task>
# =============================================================================

# JOB DEFINITION PARAMETERS (Name, Stdout, Stderr)
#SBATCH --job-name=JOB_THREADS
#SBATCH --output=bin/out/%x_%j.out
#SBATCH --error=bin/err/%x_%j.err

# GROUP CREDENTIALS AND BSC QUEUE
#SBATCH --account=idib57
#SBATCH --qos=cli

# RESOURCE ALLOCATION: 1 node, 4 tasks x 2 CPUs = 8 CPUs (~16 GB RAM on Nord4)
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=2
#SBATCH --time=00:15:00

set -eo pipefail
TASK="${1:-fastqc}"
export EXEC_MODE=native

# sbatch runs a COPY of this script, so find the repository from the submit folder
for d in "${REPO_DIR:-}" "${SLURM_SUBMIT_DIR:-$PWD}" "${SLURM_SUBMIT_DIR:-$PWD}/.." "$(dirname "$0")/.."; do
    [[ -f $d/src/lib/common.sh ]] && { source "$d/src/lib/common.sh"; break; }
done
type job_record_start &>/dev/null || { echo "ERROR: submit from the repository folder" >&2; exit 1; }

load_task "$TASK"
load_samples
job_record_start 3_threads "${#SAMPLES[@]}"   # prints job info, writes the run record at exit
load_software                                  # loaded modules are inherited by srun steps

OUTDIR="$OUTPUT_ROOT/$USER/3_threads/$TASK"
THREADS="${SLURM_CPUS_PER_TASK:-1}"
(( ${#SAMPLES[@]} <= ${SLURM_NTASKS:-1} )) ||
    log "NOTE: ${#SAMPLES[@]} samples but ${SLURM_NTASKS:-1} tasks: extra samples wait for a free task"

# ---- The work: every sample as a parallel job step --------------------------
#   --exact    : the step uses only the CPUs it asks for, so steps run side by side
#   &          : start the step in the background and continue with the next one
#   wait <pid> : wait for each step and count the failures
pids=()
for fq in "${SAMPLES[@]}"; do
    srun --nodes=1 --ntasks=1 --cpus-per-task="$THREADS" --exact $(step_mem_option) \
        bash "$REPO_DIR/src/run_sample.sh" "$TASK" "$fq" "$OUTDIR" "$THREADS" &
    pids+=("$!")
done

failed=0
for pid in "${pids[@]}"; do
    wait "$pid" || failed=$((failed + 1))
done
(( failed == 0 )) || die "$failed of ${#SAMPLES[@]} samples failed"
