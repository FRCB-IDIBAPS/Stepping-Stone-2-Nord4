# bowtie2 exercise data: source and provenance

## Contents

| File | Description |
|------|-------------|
| `001.fastq.gz` ... `004.fastq.gz` | Single-end reads (read 1 only), first 500,000 reads of 4 different runs |
| `reference/genome.fa` | Reference genome, plain FASTA (1 sequence) |

The bowtie2 index is **not** stored here; build it at runtime with `bowtie2-build`.

## Organism and reference

- Organism / strain: *Escherichia coli* str. K-12 substr. MG1655 (NCBI taxid 511145).
  The runs are from MG1655-derived isolates (library names suggest antibiotic-selected
  derivatives, e.g. `DHPG500-CIPr-1`, `DHPG500-AMP1-AMPr-1`), all registered under the
  same BioSample.
- Reference: **NC_000913.3**, *Escherichia coli* str. K-12 substr. MG1655, complete genome
  (RefSeq; identical sequence to GenBank U00096.3). Length: **4,641,652 bp**, 1 sequence.

## Study and runs

- BioProject: **PRJNA1133223** ("Escherichia coli str. K-12 substr. MG1655 Genome sequencing"),
  SRA study SRP518631, BioSample SAMN42380001. First public 2025-08-02.
- Platform: Illumina; ENA/SRA metadata states *Illumina NovaSeq 6000* (the read headers carry
  instrument ID `LH00272`, a NovaSeq X-style ID).
- Library: WGS, GENOMIC, RANDOM selection, PAIRED layout in the archive. **Only read 1 (`_1.fastq.gz`) is used**, so the files are single-end.
- Read length: 151 bp (all reads).
- Reads per sample: 500,000 (the first 500,000 reads of each run's read-1 file).

| Sample | Run accession | Library name | Total reads in run (pairs) | Reads kept | Size (bytes) | bowtie2 overall alignment rate |
|--------|---------------|--------------|----------------------------|------------|--------------|-------------------------------|
| 001 | SRR29746197 | DHPG500-CIPr-2 | 3,430,033 | 500,000 | 31,831,602 | **99.81%** |
| 002 | SRR29746198 | DHPG500-CIPr-1 | 3,462,560 | 500,000 | 32,294,629 | **99.72%** |
| 003 | SRR29746199 | DHPG500-AMP1-AMPr-2 | 3,574,111 | 500,000 | 32,161,948 | **99.70%** |
| 004 | SRR29746200 | DHPG500-AMP1-AMPr-1 | 3,323,659 | 500,000 | 31,910,276 | **99.83%** |

Alignment details (bowtie2 2.5.4, `-p 4`, default end-to-end mode, image
`singularity/images/bowtie2.sif`): about 97.0% of reads aligned exactly once, about 2.7% aligned
more than once (rRNA operons, IS elements) and 0.17-0.30% did not align. Wall time was about
9-12 s per sample with 4 threads on a workstation.

## Why this dataset suits the task

- Small genome (4.6 Mb): the index builds in seconds and uses very little memory, well under 4 GB per sample.
- The reference is the exact strain sequenced, so the alignment rate is above 99.7%.
- There are 4 independent runs of the same strain, so the samples have the same size and similar runtimes, which makes them good for comparing Slurm approaches (simple job, job array, threads, container).
- Modern 151 bp Illumina reads; 500k reads per sample give a short but measurable runtime that scales with `-p N`.

## Reproduce

```bash
mkdir -p reference
# Reference genome (NCBI E-utilities)
curl -s -o reference/genome.fa \
  "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_000913.3&rettype=fasta&retmode=text"

# Run metadata / FASTQ URLs (ENA portal API)
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=PRJNA1133223&result=read_run&fields=run_accession,fastq_ftp,read_count,base_count,instrument_model,library_strategy,library_layout&format=tsv"

# First 500,000 reads of read 1 for each run (streams only the start of each file;
# the curl "broken pipe"/exit 23 caused by head is expected)
N=500000
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR297/097/SRR29746197/SRR29746197_1.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 001.fastq.gz
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR297/098/SRR29746198/SRR29746198_1.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 002.fastq.gz
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR297/099/SRR29746199/SRR29746199_1.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 003.fastq.gz
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR297/000/SRR29746200/SRR29746200_1.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 004.fastq.gz
```

Check that each file has exactly 2,000,000 lines (`zcat 00N.fastq.gz | wc -l`). An interrupted
transfer can silently produce a shorter file; if so, download it again. The gzip bytes (and so the
md5) may differ if a different gzip version or level is used, but the FASTQ content is identical.

Verification commands used:

```bash
apptainer exec --bind <dirs> bowtie2.sif bowtie2-build --threads 4 reference/genome.fa <tmp>/genome
apptainer exec --bind <dirs> bowtie2.sif bowtie2 -p 4 -x <tmp>/genome -U 00N.fastq.gz > /dev/null
```

## License / terms

These are public data from the INSDC archives (NCBI SRA / EBI ENA / DDBJ) and NCBI RefSeq.
INSDC places no restrictions on the use or redistribution of the data (see the ENA and NCBI
data-use policies: https://www.ebi.ac.uk/ena/browser/about/policies and
https://www.ncbi.nlm.nih.gov/home/about/policies/). Please cite the original submitters
(BioProject PRJNA1133223) and the reference (Blattner et al. 1997, Science 277:1453; NC_000913.3)
when you reuse the data.

## Checksums (md5sum)

```
dbb613ecca11f7d9222cdc13c1b6d273  001.fastq.gz
0265eb1209f869d901a4053001956221  002.fastq.gz
1911c7a54de5418fe7709cc82ea470ca  003.fastq.gz
bf407f67e0354477ebf5bc27d07b2b49  004.fastq.gz
182c4c48740aa62f1b6ca3c03afd663a  reference/genome.fa
```
