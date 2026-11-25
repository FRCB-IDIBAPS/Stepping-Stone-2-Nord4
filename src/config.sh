# =============================================================================
# Central configuration of the Stepping Stone practical exercise.
# Every value can be overridden from the environment, e.g.
#   DATA_DIR=/gpfs/projects/idib57/my_data sbatch src/1_JOB_SIMPLE.sh fastqc
# NOTE: the #SBATCH --output/--error lines cannot read variables. They use
#       bin/out and bin/err relative to the folder you submit from (the
#       workspace). submit.sh passes $LOG_DIR to sbatch, so changing LOG_DIR
#       works there; with plain sbatch, add --output/--error yourself.
# =============================================================================

# The WORKSPACE: the folder this repository was copied to (data, images and
# results are shared by everyone who uses it). By default it is wherever this
# copy lives, e.g. /gpfs/projects/idib57/Stepping_Stone, so you can copy the
# repository anywhere. Set BASE_DIR to use another copy's data/results instead.
# (Not called HOME on purpose: $HOME is your home folder and many tools need it.)
BASE_DIR="${BASE_DIR:-$REPO_DIR}"

# Input FASTQ files: each task has its own dataset in $DATA_ROOT/<task>/
# (see the SOURCE.md there); every file matching SAMPLE_GLOB is one sample.
# Set DATA_DIR to use one folder for all tasks instead.
DATA_ROOT="${DATA_ROOT:-$BASE_DIR/src/data}"
DATA_DIR="${DATA_DIR:-}"
SAMPLE_GLOB="${SAMPLE_GLOB:-*.fastq.gz}"

# Outputs go to $OUTPUT_ROOT/<user>/<approach>/<task>/ so nobody overwrites anyone
OUTPUT_ROOT="${OUTPUT_ROOT:-$BASE_DIR/output}"

# Slurm stdout/stderr (out/ and err/ subfolders)
LOG_DIR="${LOG_DIR:-$BASE_DIR/bin}"

# Run records used to compare the approaches (see src/collect_results.sh)
RESULTS_DIR="${RESULTS_DIR:-$BASE_DIR/results}"

# Tools Nord4 has no module for (static builds, see software/install.sh).
# The native approaches put $SOFTWARE_DIR/bin on PATH.
SOFTWARE_DIR="${SOFTWARE_DIR:-$BASE_DIR/software}"

# Singularity images, one per task: $SIF_DIR/<task>.sif
SIF_DIR="${SIF_DIR:-$BASE_DIR/singularity/images}"

# Reference for the bowtie2 task (index built once with src/prepare_reference.sh)
REFERENCE_FASTA="${REFERENCE_FASTA:-$DATA_ROOT/bowtie2/reference/genome.fa}"
BOWTIE2_INDEX="${BOWTIE2_INDEX:-$BASE_DIR/reference/bowtie2/genome}"
