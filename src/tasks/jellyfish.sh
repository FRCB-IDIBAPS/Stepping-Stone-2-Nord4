# -----------------------------------------------------------------------------
# TASK: jellyfish - k-mer counting + k-mer frequency histogram
# Profile: CPU AND memory hungry; scales with threads.
#   On Nord4 there is no --mem: memory comes with CPUs (~2 GB per CPU on
#   standard nodes). With a bigger hash (JELLYFISH_HASH) you must ask for more
#   CPUs just to get the RAM.
# -----------------------------------------------------------------------------
TASK_MODULES="jellyfish"
TASK_TOOLS="jellyfish"
TASK_IMAGE="jellyfish.sif"

JELLYFISH_K="${JELLYFISH_K:-21}"         # k-mer length
JELLYFISH_HASH="${JELLYFISH_HASH:-100M}" # initial hash size (~ memory used)

# task_run <fastq> <sample_name> <outdir> <threads>
task_run() {
    local fq=$1 name=$2 outdir=$3 threads=$4
    # jellyfish cannot read .gz files: decompress on the fly into its stdin
    zcat "$fq" | run jellyfish count \
        -m "$JELLYFISH_K" -s "$JELLYFISH_HASH" -C -t "$threads" \
        -o "$outdir/$name.jf" /dev/stdin
    run jellyfish histo -t "$threads" "$outdir/$name.jf" >"$outdir/$name.histo"
    rm -f "$outdir/$name.jf" # large binary hash, not needed after the histogram
}
