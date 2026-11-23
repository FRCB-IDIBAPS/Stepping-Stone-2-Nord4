#!/bin/bash
# =============================================================================
# APPROACH 1 - SEQUENTIAL JOB
# One job, one CPU. The samples are processed one after the other.
#
# Usage (from the repository folder):
#   sbatch src/1_JOB_SIMPLE.sh <task>      # task: fastqc seqkit fastp jellyfish bowtie2
#   bash src/submit.sh 1 <task>            # same + records your place in the queue
# =============================================================================

# JOB DEFINITION PARAMETERS (Name, Stdout, Stderr)   %x = job name, %j = job id
#SBATCH --job-name=JOB_SIMPLE
#SBATCH --output=/gpfs/projects/idib57/Stepping_Stone/bin/out/%x_%j.out
#SBATCH --error=/gpfs/projects/idib57/Stepping_Stone/bin/err/%x_%j.err

# GROUP CREDENTIALS AND BSC QUEUE
#SBATCH --account=idib57
#SBATCH --qos=cli

# RESOURCE ALLOCATION: 1 node, 1 task, 1 CPU (~2 GB RAM on Nord4)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:30:00

# NODE RESERVATION
#SBATCH --reservation=curso

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
job_record_start 1_simple "${#SAMPLES[@]}"   # prints job info, writes the run record at exit
load_software

OUTDIR="$OUTPUT_ROOT/$USER/1_simple/$TASK"
THREADS="${SLURM_CPUS_PER_TASK:-1}"

# ---- The work: one sample after the other -----------------------------------
for fq in "${SAMPLES[@]}"; do
    bash "$REPO_DIR/src/run_sample.sh" "$TASK" "$fq" "$OUTDIR" "$THREADS"
done
