# -----------------------------------------------------------------------------
# TASK: bowtie2 - align reads to a reference, then sort and index the BAM
# Profile: heaviest task, CPU bound, scales very well with threads.
#   RAM depends on the reference: small genomes need little memory, a human
#   index needs ~4 GB, i.e. at least 2-3 CPUs on Nord4 standard nodes.
# Requires a bowtie2 index (built once by the instructors):
#   sbatch src/prepare_reference.sh
# -----------------------------------------------------------------------------
TASK_MODULES="bowtie2 samtools"
TASK_TOOLS="bowtie2 samtools"
TASK_IMAGE="bowtie2.sif"

# task_run <fastq> <sample_name> <outdir> <threads>
task_run() {
    local fq=$1 name=$2 outdir=$3 threads=$4
    [[ -f $BOWTIE2_INDEX.1.bt2 || -f $BOWTIE2_INDEX.1.bt2l ]] ||
        die "bowtie2 index not found at $BOWTIE2_INDEX (run: sbatch src/prepare_reference.sh)"

    run bowtie2 -p "$threads" -x "$BOWTIE2_INDEX" -U "$fq" 2>"$outdir/$name.bowtie2.log" |
        run samtools sort -@ "$threads" -m 512M -o "$outdir/$name.bam" -
    run samtools index "$outdir/$name.bam"
}
