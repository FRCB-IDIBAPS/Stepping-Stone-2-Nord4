# fastp test data: source and provenance

## Dataset

- **Organism:** *Homo sapiens* (human serum, circulating miRNA)
- **Study:** "Machine Learning-based Exceptional Response Prediction of Nivolumab Monotherapy with Circulating MicroRNAs in Non-Small Cell Lung Cancer"
- **BioProject / ENA study:** PRJNA849256 (SRA study SRP381786), first public 2025-06-23
- **Platform / instrument:** Illumina NextSeq 550
- **Library:** miRNA-Seq, TRANSCRIPTOMIC, size fractionation, SINGLE-end. Library layout matches QIAseq miRNA
  (insert + 3' adapter `AACTGTAGGCAC` + 12 nt UMI + Illumina TruSeq adapter `AGATCGGAAGAGC...`)
- **Read length:** 76 nt (fixed, untrimmed raw reads)
- **Quality encoding:** Phred+33 (observed quality characters `#`..`E`, NextSeq binned qualities)
- **Reads per sample:** 1,000,000 (the first 1,000,000 reads of each run)

| File | Run | Sample | Experiment | Sample title | Reads in full run | Size | md5sum |
|---|---|---|---|---|---|---|---|
| 001.fastq.gz | SRR19658642 | SAMN29047491 | SRX15708548 | serum, miRNA, PF5131 | 7,183,721 | 25,745,357 B | 804565c91c5ed09be14e0e6526763b76 |
| 002.fastq.gz | SRR19658643 | SAMN29047492 | SRX15708547 | serum, miRNA, PF5130 | 6,659,911 | 25,577,550 B | 0684849820f724a4931a842c938c9abf |
| 003.fastq.gz | SRR19658644 | SAMN29047493 | SRX15708546 | serum, miRNA, PF5128 | 6,432,233 | 24,912,799 B | 6d3a366789946a197dea74a87baa47b7 |
| 004.fastq.gz | SRR19658649 | SAMN29047386 | SRX15708541 | serum, miRNA, PF5384 | 6,851,885 | 25,679,893 B | ee0d54ecd17e03f0a5bf415da3dbd46d |

Total folder size: ~98 MB.

## Adapter content (measured on the 1,000,000 reads of each file)

| File | TruSeq `AGATCGGAAGAGC` | QIAseq 3' `AACTGTAGGCAC` | small RNA `TGGAATTCTCGG` |
|---|---|---|---|
| 001 | 94.20 % | 91.56 % | 0.00 % |
| 002 | 92.27 % | 90.77 % | 0.00 % |
| 003 | 93.50 % | 91.87 % | 0.00 % |
| 004 | 94.01 % | 91.06 % | 0.00 % |

Validation: all files pass `gzip -t`, have 4,000,000 lines (divisible by 4), every header starts with `@`,
every separator line starts with `+`, and quality length equals sequence length.

## Why this dataset suits the task

Circulating miRNAs are ~22 nt, but the reads are 76 nt, so more than 90 % of reads run through the
insert into adapter sequence. Untrimmed, these reads would not map to miRNA references. Trimming has a large, visible
effect. Example with fastp 0.23.4 (`singularity/images/fastp.sif`) on 001.fastq.gz, default settings
(`fastp --in1 001.fastq.gz --out1 trimmed.fastq.gz`, about 4 s on a laptop):

- auto-detected adapter: "Illumina TruSeq Adapter Read 1" (`AGATCGGAAGAGC...`)
- reads with adapter trimmed: 959,797 / 1,000,000 (96 %)
- bases: 76.0 M -> 47.8 M (27.96 M bases removed as adapter)

Auto-detection removes only the outer TruSeq adapter. The QIAseq 3' adapter and UMI stay in the read.
To trim down to the miRNA insert itself, add `--adapter_sequence AACTGTAGGCAC`. On 001 this trims
967,114 reads, discards 389,616 reads as too short (adapter dimers), and keeps 604,192 reads / 15.3 M bases
(mean length ~25 nt). Either command works for the runtime-comparison exercise.

The reads are modern Phred+33 data (no Phred+64 problems). The NextSeq two-colour chemistry also lets
fastp turn on its poly-G tail trimming automatically.

## How to reproduce

ENA file report (FASTQ URLs, read counts, metadata):

```bash
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=PRJNA849256&result=read_run&fields=run_accession,sample_accession,experiment_accession,sample_title,fastq_ftp,fastq_bytes,fastq_md5,read_count,base_count,instrument_model,library_strategy,library_source,library_selection,library_layout,scientific_name,first_public,study_title&format=tsv"
```

Stream only the first 1,000,000 reads of each run (ignore curl "broken pipe" / exit 23 caused by `head`):

```bash
N=1000000
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR196/042/SRR19658642/SRR19658642.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 001.fastq.gz
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR196/043/SRR19658643/SRR19658643.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 002.fastq.gz
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR196/044/SRR19658644/SRR19658644.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 003.fastq.gz
curl -s https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR196/049/SRR19658649/SRR19658649.fastq.gz | zcat | head -n $((4*N)) | gzip -6 > 004.fastq.gz
```

Note: the ENA FTP/HTTPS server sometimes returned an empty stream. Check that each file has 4,000,000 lines
(`zcat 00X.fastq.gz | wc -l`) and retry if needed. The FASTQ content is deterministic. The `.gz` bytes, and
so the md5sums, can differ with another gzip version or level. The md5sums above are for gzip level 6 on the
original download.

Adapter check used:

```bash
zcat 001.fastq.gz | awk 'NR%4==2{n++; if(index($0,"AGATCGGAAGAGC"))a++} END{print a/n}'
```

## License / terms

Public data from the INSDC archives (NCBI SRA / EBI ENA). ENA/SRA data are freely available with no
restrictions on use, under the INSDC policy and the EMBL-EBI terms of use
(https://www.ebi.ac.uk/about/terms-of-use/, https://www.insdc.org/policy). Please cite the original study
(BioProject PRJNA849256) when you use these data beyond training purposes.
