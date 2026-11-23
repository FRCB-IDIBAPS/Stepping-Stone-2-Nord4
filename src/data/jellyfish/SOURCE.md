# Data source: jellyfish task (k-mer counting / genome-size histogram)

## Summary

| Field | Value |
|---|---|
| Organism | *Staphylococcus aureus* (NCBI taxon 1280) |
| Genome size | ~2.82 Mb (reference NCTC 8325, RefSeq GCF_000013425.1, 2,821,361 bp; used for the coverage figures below) |
| Study / project | BioProject PRJNA324190 (SRA SRP077575), Oxford University: "Prospective observational study evaluating the role of healthcare workers in nosocomial transmission of *Staphylococcus aureus* in an intensive care unit" |
| Platform / instrument | Illumina HiSeq 2500 |
| Library | WGS, GENOMIC, RANDOM, PAIRED (only read 1 is used here, as single-end) |
| Read length | 151 bp, every read the same length |
| Format | gzip FASTQ (Phred+33), the unmodified ENA `_1.fastq.gz` files |

## Samples

Each sample is a different clinical isolate (a different BioSample). Each file is the **complete** read-1 FASTQ of that run.

| File | Run | Experiment | BioSample | Isolate | Reads | Bases | Coverage (bases / 2.82 Mb) | Expected k-mer cov. (k=21) | Observed histogram peak | Size | md5sum |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 001.fastq.gz | SRR3728979 | SRX1885299 | SAMN05336977 | H263_M06 | 623,034 | 94,078,134 | 33.3x | 28.9 | **27** (valley at 6) | 41.1 MB | 58b98357536809420d1fef71dafabd73 |
| 002.fastq.gz | SRR3730697 | SRX1886876 | SAMN05340533 | H137_M08 | 636,223 | 96,069,673 | 34.1x | 29.6 | **27** (valley at 8) | 40.3 MB | 91359588445b6436fd6b6e5d20f9d68d |
| 003.fastq.gz | SRR3730723 | SRX1886902 | SAMN05340559 | H215_M01 | 663,034 | 100,118,134 | 35.5x | 30.8 | **30** (valley at 9) | 41.8 MB | b3a2e6ecf62fc7b265af9f2931bcdee1 |
| 004.fastq.gz | SRR3731860 | SRX1887769 | SAMN05344880 | H255_M06 | 667,055 | 100,725,305 | 35.7x | 31.0 | **29** (valley at 6) | 43.1 MB | fb73664c442b1c07694000877157081a |

Total: about 166 MB (159 MiB) for the 4 files. The md5sums match the `fastq_md5` values that ENA lists for each `_1.fastq.gz`.

Expected k-mer coverage = base coverage x (L - k + 1) / L = coverage x 131/151.
Observed peaks are slightly below this because sequencing errors move some k-mers into the error peak.
Genome size estimated from the histogram (sum of k-mers above the valley divided by the peak) is 2.86 to 3.05 Mb, which matches the ~2.8 Mb *S. aureus* genome.

## Histogram check

Checked with `singularity/images/jellyfish.sif` (jellyfish 2.3.1):

```bash
zcat 001.fastq.gz | apptainer exec --bind $TMP jellyfish.sif \
    jellyfish count -m 21 -s 100M -C -t 4 -o $TMP/001.jf /dev/stdin
apptainer exec --bind $TMP jellyfish.sif jellyfish histo $TMP/001.jf
```

Each sample gives the classic shape:

- a large error peak at 1 to 2 (about 0.86 to 0.94 M k-mers seen once);
- a deep valley at 6 to 9 (100 to 470 k-mers);
- a clear coverage peak at 27 to 30 (about 165,000 to 176,000 distinct k-mers);
- a small tail of repeat k-mers at about 2x the peak.

Excerpt for 001 (k-mer count, number of distinct k-mers): 1 857061 · 2 11791 · 6 255 (valley) · 15 17851 · 20 83929 · 25 163933 · **27 175136 (peak)** · 30 153351 · 35 81941 · 40 29460 · 50 1672 · 60 480.

Resources per sample (4 threads, local workstation): about 3 to 4 s and about 0.5 GB RSS. The `.jf` files are 19 to 28 MB. `-s 100M` is more than enough.

## Why this dataset suits the task

- Small bacterial genome (~2.8 Mb), so `-s 100M` and ~4 GB RAM per sample are plenty, and each job runs quickly.
- Each run's read 1 alone gives 33 to 36x coverage. That is in the 20 to 40x target, so the coverage peak (~27 to 30) sits well apart from the error peak.
- 4 independent isolates from one study, all sequenced the same way (same instrument, fixed 151 bp reads). The 4 samples are comparable, so runtime differences between Slurm approaches come from the approach, not the data.
- The files are the original ENA files, unmodified, so anyone can re-download them and check them by md5.

**Note on read order: do not subsample these runs with `head`.** The read order in this study's ENA FASTQs is not random. They seem to be sorted by genome position. A first attempt that took the first 600k reads of deeper runs from this study (SRR3728387, SRR3728394, SRR3728401, SRR3728414) gave a peak at about 73 instead of about 28: those reads covered only part of the genome, at full depth. So this dataset uses low-depth runs whose **whole** read-1 file gives about 30 to 40x.

## Reproduce

```bash
cd src/data/jellyfish
# metadata (URLs, read counts, md5)
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=PRJNA324190&result=read_run&fields=run_accession,sample_accession,fastq_ftp,fastq_md5,fastq_bytes,read_count,base_count,instrument_model,library_strategy,scientific_name&format=tsv&limit=0"

curl -sS -o 001.fastq.gz https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR372/009/SRR3728979/SRR3728979_1.fastq.gz
curl -sS -o 002.fastq.gz https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR373/007/SRR3730697/SRR3730697_1.fastq.gz
curl -sS -o 003.fastq.gz https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR373/003/SRR3730723/SRR3730723_1.fastq.gz
curl -sS -o 004.fastq.gz https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR373/000/SRR3731860/SRR3731860_1.fastq.gz

md5sum -c <<'EOF'
58b98357536809420d1fef71dafabd73  001.fastq.gz
91359588445b6436fd6b6e5d20f9d68d  002.fastq.gz
b3a2e6ecf62fc7b265af9f2931bcdee1  003.fastq.gz
fb73664c442b1c07694000877157081a  004.fastq.gz
EOF
```

**Verify after downloading.** ENA connections sometimes drop and leave a truncated file. Run `gzip -t` and check the md5sums above. You can also check line counts with `zcat 00N.fastq.gz | wc -l`. The expected counts are 2,492,136 / 2,544,892 / 2,652,136 / 2,668,220, which is 4 x the read counts.

## License / terms

These are public data from the European Nucleotide Archive (ENA) / NCBI SRA (INSDC). INSDC data have no restrictions on use or redistribution (see https://www.ebi.ac.uk/ena/browser/about/policies and the INSDC policy at https://www.insdc.org/policy/). Please cite BioProject PRJNA324190 and the submitting centre (Oxford University) when you use these data.
