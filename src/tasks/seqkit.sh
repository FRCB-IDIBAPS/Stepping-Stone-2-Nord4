# -----------------------------------------------------------------------------
# TASK: seqkit - read statistics (number of reads, length, N50, Q20/Q30...)
# Profile: very short, limited by disk reading (I/O), tiny RAM.
#   The work takes seconds, so queueing, job start-up and container start-up
#   become a large share of the total time. Good to see when parallelising
#   is NOT worth it.
# -----------------------------------------------------------------------------
TASK_MODULES="seqkit"
TASK_TOOLS="seqkit"
TASK_IMAGE="seqkit.sif"

# task_run <fastq> <sample_name> <outdir> <threads>
task_run() {
    local fq=$1 name=$2 outdir=$3 threads=$4
    run seqkit stats --all --tabular --threads "$threads" "$fq" >"$outdir/$name.stats.tsv"
}
