# -----------------------------------------------------------------------------
# TASK: fastp - adapter and quality trimming
# Profile: CPU bound, scales well with threads (up to ~8), ~1 GB RAM.
#   Writing the compressed output (.fastq.gz) is the most expensive part.
# -----------------------------------------------------------------------------
TASK_MODULES="fastp"
TASK_TOOLS="fastp"
TASK_IMAGE="fastp.sif"

# task_run <fastq> <sample_name> <outdir> <threads>
task_run() {
    local fq=$1 name=$2 outdir=$3 threads=$4
    run fastp \
        --in1 "$fq" \
        --out1 "$outdir/$name.trimmed.fastq.gz" \
        --thread "$threads" \
        --json "$outdir/$name.fastp.json" \
        --html "$outdir/$name.fastp.html" \
        --report_title "$name" \
        2>"$outdir/$name.fastp.log"
}
