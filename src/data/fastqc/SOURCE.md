# FastQC input data: "airway" RNA-seq subsets

## Dataset

- **Organism:** *Homo sapiens*, primary human airway smooth muscle cells
- **Study:** Himes et al. (2014), *PLoS ONE* 9(6):e99625, "RNA-Seq transcriptome profiling identifies CRISPLD2 as a glucocorticoid responsive gene that modulates cytokine function in airway smooth muscle cells"
- **Accessions:** BioProject **PRJNA229998** / SRA study **SRP033351** / GEO **GSE52778**
  (Bioconductor also ships this study as the `airway` package.)
- **Platform:** Illumina HiSeq 2000
- **Library:** RNA-Seq (TRANSCRIPTOMIC, cDNA, poly-A), paired-end 2x63 bp, TruSeq indexed adapters. **Only read 1 (`_1.fastq.gz`) is used here**, so the data is single-end.
- **Read length:** 63 bp (all reads)
- **Reads per sample:** 500,000. These are the first 500,000 reads of each run's read-1 file, so they come from the first tiles of lane 1.
- **Quality encoding:** Phred+33 (Sanger / Illumina 1.8+)

| File | Run | Experiment | Sample | Condition | Flowcell (from header) | md5sum | Size |
|------|-----|-----------|--------|-----------|------------------------|--------|------|
| 001.fastq.gz | SRR1039508 | SRX384345 | SAMN02422669 | N61311 untreated  | C0TECACXX lane 1 | `377901646716a38544d20ff8d1e1fad1` | 25.7 MB |
| 002.fastq.gz | SRR1039509 | SRX384346 | SAMN02422675 | N61311 dexamethasone | C0TECACXX lane 1 | `2189c37f08e9e0e86fbd2e572ca9ce08` | 25.7 MB |
| 003.fastq.gz | SRR1039512 | SRX384349 | SAMN02422678 | N052611 untreated | C12K6ACXX lane 1 | `93dc29ee208f7fd4f023757ba25cf290` | 26.9 MB |
| 004.fastq.gz | SRR1039513 | SRX384350 | SAMN02422670 | N052611 dexamethasone | n/a (header stripped by SRA) | `fd0f16ed41ff93328d1a5b65ad3f5cd8` | 26.1 MB |

Total size is about 100 MB.

## Why this dataset suits a FastQC exercise

This is real, widely used data that is not perfect, so the FastQC reports have something to discuss:

- **Per-base quality falls toward the 3' end.** Mean Phred is about 40 at positions 2 to 30 and drops to about 32 to 35 at position 63. The drop is larger in 003 and 004.
- **Overrepresented sequences / adapter dimers.** The most common read in every sample is a TruSeq index adapter (`...ACACGTCTGAACTCCAGTCAC<index>ATCTCGTATGCCGTCTTCTGCTT`). It makes up about 0.37% of reads in 001 and about 0.9% in 002, so FastQC should flag it as "TruSeq Adapter, Index N". In 003 and 004 it is only about 0.03%, which gives a useful comparison between samples.
- **Per-base N content.** 001 and 002 contain a block of `N` calls at positions about 16 to 23 in reads from the first tile, a typical instrument artefact. It is barely visible in 003 and 004.
- **Typical RNA-seq warnings.** Expect per-base sequence content bias in the first ~10 bp (random-hexamer priming) and high sequence-duplication levels (highly expressed transcripts). Both are normal for RNA-seq, which makes them good discussion points.
- **Two flowcells.** 001 and 002 come from flowcell C0TECACXX and 003 and 004 from C12K6ACXX, so batch differences show up in the reports.
- GC content is about 49 to 50%.

## Reproduce

The URLs come from the ENA portal API:

```bash
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRP033351&result=read_run&fields=run_accession,fastq_ftp,read_count,base_count,instrument_platform,library_strategy,scientific_name&format=tsv"
```

Stream only the first 500,000 reads of each read-1 file. head ends the pipe early, so curl reports "broken pipe" / exit 23, which is expected:

```bash
N=500000
i=1
for u in SRR103/008/SRR1039508/SRR1039508_1 \
         SRR103/009/SRR1039509/SRR1039509_1 \
         SRR103/002/SRR1039512/SRR1039512_1 \
         SRR103/003/SRR1039513/SRR1039513_1; do
  out=$(printf "%03d" $i).fastq.gz
  curl -sS "https://ftp.sra.ebi.ac.uk/vol1/fastq/$u.fastq.gz" 2>/dev/null \
    | zcat 2>/dev/null | head -n $((4*N)) | gzip -9 > "$out"
  i=$((i+1))
done
md5sum 00?.fastq.gz
```

Because the files are recompressed locally, the md5sums can differ with another gzip version. The decompressed content is the same.

Validation done: `gzip -t` OK, 2,000,000 lines (a multiple of 4), all header lines start with `@`, all separator lines start with `+`, 500,000 reads of 63 bp per file.

## License / terms

These are public data from the INSDC archives (NCBI SRA / EBI ENA). ENA and SRA data are released without restrictions on use, under the INSDC policy (https://www.insdc.org/policy). Please cite the original study, Himes et al. 2014, PLoS ONE 9:e99625 (doi:10.1371/journal.pone.0099625), and the archive accessions above.
