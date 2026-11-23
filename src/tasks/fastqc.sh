# -----------------------------------------------------------------------------
# TASK: fastqc - quality-control report of one FASTQ file
# Profile: light CPU, ~250 MB RAM, a few minutes per file.
#   FastQC uses ONE thread per FILE: --threads only helps when several files are
#   given at once. With one file per call, extra CPUs sit idle (check the
#   CPU-efficiency column in collect_results.sh).
# -----------------------------------------------------------------------------
TASK_MODULES="java fastqc"
TASK_TOOLS="fastqc"
TASK_IMAGE="fastqc.sif"

# task_run <fastq> <sample_name> <outdir> <threads>
task_run() {
    local fq=$1 name=$2 outdir=$3 threads=$4
    run fastqc --quiet --threads "$threads" --outdir "$outdir" "$fq"
}
