#!/bin/bash
# =============================================================================
# Re-create the input datasets of every task in src/data/<task>/.
# Each sample is the first N reads of a public ENA run (see <task>/SOURCE.md).
# The datasets are already in git: you only need this to rebuild or change them.
#
# Run OFF-CLUSTER (Nord4 has no internet), then copy src/data to Nord4:
#   bash src/data/download.sh                # all tasks
#   bash src/data/download.sh fastp bowtie2  # only these
#   FORCE=1 bash src/data/download.sh        # download again even if complete
#   rsync -av --progress src/data/ <user>@transfer1.bsc.es:/gpfs/projects/idib57/Stepping_Stone/src/data/
#
# Only the beginning of each run is streamed (curl | zcat | head), so nothing
# big is downloaded. A file is accepted only when it has exactly N reads: the
# ENA server sometimes drops the connection and leaves a short file silently.
# =============================================================================
set -eu

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENA="https://ftp.sra.ebi.ac.uk/vol1/fastq"
TRIES=5

# task  sample  ENA path (without .fastq.gz)            reads
# jellyfish uses WHOLE low-depth runs (reads = full run): its reads are sorted by
# genome position, so the first N reads would cover only part of the genome.
MANIFEST="
fastqc     001  SRR103/008/SRR1039508/SRR1039508_1      500000
fastqc     002  SRR103/009/SRR1039509/SRR1039509_1      500000
fastqc     003  SRR103/002/SRR1039512/SRR1039512_1      500000
fastqc     004  SRR103/003/SRR1039513/SRR1039513_1      500000
seqkit     001  SRR258/008/SRR2584408/SRR2584408        500000
seqkit     002  SRR258/004/SRR2584864/SRR2584864        500000
seqkit     003  SRR258/003/SRR2584853/SRR2584853_1      500000
seqkit     004  SRR258/003/SRR2584863/SRR2584863_1      500000
fastp      001  SRR196/042/SRR19658642/SRR19658642      1000000
fastp      002  SRR196/043/SRR19658643/SRR19658643      1000000
fastp      003  SRR196/044/SRR19658644/SRR19658644      1000000
fastp      004  SRR196/049/SRR19658649/SRR19658649      1000000
jellyfish  001  SRR372/009/SRR3728979/SRR3728979_1      623034
jellyfish  002  SRR373/007/SRR3730697/SRR3730697_1      636223
jellyfish  003  SRR373/003/SRR3730723/SRR3730723_1      663034
jellyfish  004  SRR373/000/SRR3731860/SRR3731860_1      667055
bowtie2    001  SRR297/097/SRR29746197/SRR29746197_1    500000
bowtie2    002  SRR297/098/SRR29746198/SRR29746198_1    500000
bowtie2    003  SRR297/099/SRR29746199/SRR29746199_1    500000
bowtie2    004  SRR297/000/SRR29746200/SRR29746200_1    500000
"

# Reference genomes: task  file  URL
REFERENCES="
bowtie2  reference/genome.fa  https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_000913.3&rettype=fasta&retmode=text
"

count_lines() { zcat "$1" 2>/dev/null | wc -l; }

# Usage: fetch <task> <sample> <ena_path> <reads>
fetch() {
    local task=$1 sample=$2 path=$3 reads=$4
    local out="$here/$task/$sample.fastq.gz" tmp="$here/$task/.$sample.fastq.gz.part"
    local want=$((4 * reads)) try got

    if [[ -f $out && -z ${FORCE:-} && $(count_lines "$out") -eq $want ]]; then
        echo "  ok    $task/$sample.fastq.gz (already complete)"
        return 0
    fi
    mkdir -p "$here/$task"
    for ((try = 1; try <= TRIES; try++)); do
        # head closes the pipe early: curl's "broken pipe" (exit 23) is expected
        curl -sS --retry 3 "$ENA/$path.fastq.gz" 2>/dev/null | zcat 2>/dev/null |
            head -n "$want" | gzip -6 >"$tmp" || true
        got=$(count_lines "$tmp")
        if [[ $got -eq $want ]] && zcat "$tmp" | head -n 1 | grep -q '^@'; then
            mv "$tmp" "$out"
            echo "  ok    $task/$sample.fastq.gz ($reads reads, $(du -h "$out" | cut -f1))"
            return 0
        fi
        echo "  retry $task/$sample.fastq.gz (got $((got / 4)) of $reads reads, attempt $try/$TRIES)"
        sleep $((try * 5))
    done
    rm -f "$tmp"
    echo "  FAIL  $task/$sample.fastq.gz" >&2
    return 1
}

# Usage: fetch_reference <task> <file> <url>
fetch_reference() {
    local task=$1 file=$2 url=$3 out="$here/$1/$2"
    if [[ -s $out && -z ${FORCE:-} ]] && head -c 1 "$out" | grep -q '>'; then
        echo "  ok    $task/$file (already present)"
        return 0
    fi
    mkdir -p "$(dirname "$out")"
    if curl -sS --retry 5 -o "$out.part" "$url" && head -c 1 "$out.part" | grep -q '>'; then
        mv "$out.part" "$out"
        echo "  ok    $task/$file ($(grep -c '^>' "$out") sequence(s), $(du -h "$out" | cut -f1))"
    else
        rm -f "$out.part"
        echo "  FAIL  $task/$file" >&2
        return 1
    fi
}

command -v curl >/dev/null || { echo "ERROR: curl is required" >&2; exit 1; }

wanted=" $* "                      # tasks given on the command line (none = all)
selected() { [[ $wanted == "  " || $wanted == *" $1 "* ]]; }

failed=0
while read -r task sample path reads; do
    [[ -z $task || $task == @* ]] && continue
    selected "$task" || continue
    fetch "$task" "$sample" "$path" "$reads" || failed=$((failed + 1))
done <<<"$MANIFEST"

while read -r task file url; do
    [[ -z $task ]] && continue
    selected "$task" || continue
    fetch_reference "$task" "$file" "$url" || failed=$((failed + 1))
done <<<"$REFERENCES"

if ((failed)); then
    echo "$failed file(s) failed: run the script again (complete files are skipped)" >&2
    exit 1
fi
echo "All requested datasets are complete in $here"
