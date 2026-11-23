#!/bin/bash
# =============================================================================
# INSTRUCTORS - build the bowtie2 index used by the "bowtie2" task. Run ONCE
# before the course. Reads $REFERENCE_FASTA (default: the reference that
# matches the bowtie2 dataset, src/data/bowtie2/reference/genome.fa) and
# writes the index to $BOWTIE2_INDEX (default: reference/bowtie2/genome).
#
# Usage (from the repository folder):
#   sbatch src/prepare_reference.sh                        # module bowtie2
#   sbatch --export=ALL,EXEC_MODE=container src/prepare_reference.sh   # image
# =============================================================================
#SBATCH --job-name=PREPARE_REFERENCE
#SBATCH --output=/gpfs/projects/idib57/Stepping_Stone/bin/out/%x_%j.out
#SBATCH --error=/gpfs/projects/idib57/Stepping_Stone/bin/err/%x_%j.err
#SBATCH --account=idib57
#SBATCH --qos=cli
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00

set -eo pipefail
for d in "${REPO_DIR:-}" "${SLURM_SUBMIT_DIR:-$PWD}" "${SLURM_SUBMIT_DIR:-$PWD}/.." "$(dirname "$0")/.."; do
    [[ -f $d/src/lib/common.sh ]] && { source "$d/src/lib/common.sh"; break; }
done
type load_task &>/dev/null || { echo "ERROR: submit from the repository folder" >&2; exit 1; }

load_task bowtie2
load_software
[[ -r $REFERENCE_FASTA ]] || die "Reference FASTA not found: $REFERENCE_FASTA"

mkdir -p "$(dirname "$BOWTIE2_INDEX")"
log "Building bowtie2 index $BOWTIE2_INDEX from $REFERENCE_FASTA"
run bowtie2-build --threads "${SLURM_CPUS_PER_TASK:-1}" "$REFERENCE_FASTA" "$BOWTIE2_INDEX"
chmod -R g+rX "$(dirname "$BOWTIE2_INDEX")"
log "Done"
