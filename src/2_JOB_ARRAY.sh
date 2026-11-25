#!/bin/bash
# =============================================================================
# APPROACH 2 - PARALLEL JOB ARRAY
# One independent job per sample. Slurm can start them at different times and
# on different nodes. Each array element processes the sample number
# $SLURM_ARRAY_TASK_ID of the (sorted) list of FASTQ files.
#
# Usage (from the repository folder):
#   sbatch src/2_JOB_ARRAY.sh <task>              # --array=1-4 below = 4 samples
#   sbatch --array=1-10%5 src/2_JOB_ARRAY.sh fastp # 10 samples, max 5 running at once
#   bash src/submit.sh 2 <task>                    # sets --array to the number of files
# =============================================================================

# JOB DEFINITION PARAMETERS (Name, Stdout, Stderr)   %A = array id, %a = element
#SBATCH --job-name=JOB_ARRAY
#SBATCH --output=bin/out/%x_%A_%a.out
#SBATCH --error=bin/err/%x_%A_%a.err

# GROUP CREDENTIALS AND BSC QUEUE
#SBATCH --account=idib57
#SBATCH --qos=cli

# RESOURCE ALLOCATION - PER ARRAY ELEMENT: 1 node, 1 task, 2 CPUs (~4 GB RAM)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:15:00
#SBATCH --array=1-4

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
job_record_start 2_array 1   # prints job info, writes the run record at exit
load_software

# Pick THIS element's sample (array ids start at 1, bash arrays at 0)
idx="${SLURM_ARRAY_TASK_ID:?this script must be submitted as an array (--array=1-N)}"
(( idx >= 1 && idx <= ${#SAMPLES[@]} )) || die "Array index $idx but only ${#SAMPLES[@]} input files"
if (( idx == 1 && ${SLURM_ARRAY_TASK_MAX:-0} < ${#SAMPLES[@]} )); then
    log "WARNING: array covers 1-$SLURM_ARRAY_TASK_MAX but there are ${#SAMPLES[@]} files"
fi
fq="${SAMPLES[idx - 1]}"

OUTDIR="$OUTPUT_ROOT/$USER/2_array/$TASK"
THREADS="${SLURM_CPUS_PER_TASK:-1}"

# ---- The work: one sample per array element ---------------------------------
bash "$REPO_DIR/src/run_sample.sh" "$TASK" "$fq" "$OUTDIR" "$THREADS"
