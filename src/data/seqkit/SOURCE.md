# seqkit task input data

Input for the `seqkit stats --all` exercise: four gzip-compressed single-end FASTQ
files, each holding the first 500,000 reads of a different public sequencing run.

## Origin

- **Organism:** *Escherichia coli* B str. REL606 and evolved clones from the Lenski
  Long-Term Evolution Experiment (LTEE)
- **Study:** "E. coli genome evolution over 50,000 generations"
  (Tenaillon et al., *Nature* 536:165-170, 2016, doi:10.1038/nature18959)
- **BioProject / ENA study:** PRJNA295606 (SRA study SRP064605)
- **Library:** genomic DNA, WGS, Illumina
- **Archive:** ENA / NCBI SRA, first public 2016-01-15

| File | Run accession | Sample (clone) | Instrument | Original layout | Read used | Read length | Reads in file | Size (bytes) |
|------|---------------|----------------|------------|-----------------|-----------|-------------|---------------|--------------|
| 001.fastq.gz | SRR2584408 | REL768A | Illumina Genome Analyzer IIx | SINGLE | all | 36 bp | 500,000 | 18,515,709 |
| 002.fastq.gz | SRR2584864 | REL11364 | Illumina Genome Analyzer IIx | SINGLE | all | 75 bp | 500,000 | 32,347,044 |
| 003.fastq.gz | SRR2584853 | REL764B | Illumina HiSeq 2000 | PAIRED | read 1 only | 101 bp | 500,000 | 43,519,221 |
| 004.fastq.gz | SRR2584863 | REL7179B | Illumina HiSeq 2500 | PAIRED | read 1 only | 150 bp | 500,000 | 58,831,539 |

The total is about 147 MB. Each file holds the first 500,000 reads of its run. They
are not random subsamples. Quality scores use Phred+33, as ENA serves them.

## Why this dataset suits the task

`seqkit stats --all` is very fast and limited by I/O, so this exercise is about
scheduler overhead rather than compute. The four runs come from one study and one
organism, but they were sequenced on three instrument generations. Because of that,
the statistics differ between files:

- **Read length / N50:** 36, 75, 101 and 150 bp, so `sum_len` ranges from 18 Mb to
  75 Mb for the same number of reads. This also means each job reads a different
  amount of data.
- **Quality:** the 36 bp GAIIx run is clearly worse (Q30 about 75%, N content about
  0.25%) than the newer runs (Q30 about 88-91%).
- **GC:** all files are about 50%, as expected for *E. coli*. This is a useful
  sanity check.

Reference values, computed with awk. `seqkit stats --all` should give the same or
very close numbers.

| File | num_seqs | sum_len | min/avg/max len | GC% | Q20% | Q30% | N% |
|------|----------|---------|-----------------|-----|------|------|----|
| 001 | 500,000 | 18,000,000 | 36/36/36 | 51.32 | 84.67 | 74.68 | 0.251 |
| 002 | 500,000 | 37,500,000 | 75/75/75 | 49.56 | 95.35 | 90.54 | 0.007 |
| 003 | 500,000 | 50,500,000 | 101/101/101 | 49.86 | 95.60 | 89.00 | 0.008 |
| 004 | 500,000 | 75,000,000 | 150/150/150 | 50.62 | 94.87 | 88.30 | 0.009 |

Sample 004 (SRR2584863) is also one of the runs used in the Data Carpentry
"Data Wrangling and Processing for Genomics" lessons, which participants may already
know.

## Reproduce

Find the FASTQ URLs:

```bash
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=PRJNA295606&result=read_run&fields=run_accession,fastq_ftp,read_count,base_count,instrument_model,library_layout,library_strategy,scientific_name,sample_alias&format=tsv"
```

Stream only the first 500,000 reads. Ignore curl error 23 / broken pipe caused by
`head`. If you get transient `SSL_ERROR_SYSCALL` errors, retry and check that each
file has 2,000,000 lines.

```bash
B=https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR258
N=500000
curl -s $B/008/SRR2584408/SRR2584408.fastq.gz   | zcat | head -n $((4*N)) | gzip -9 > 001.fastq.gz
curl -s $B/004/SRR2584864/SRR2584864.fastq.gz   | zcat | head -n $((4*N)) | gzip -9 > 002.fastq.gz
curl -s $B/003/SRR2584853/SRR2584853_1.fastq.gz | zcat | head -n $((4*N)) | gzip -9 > 003.fastq.gz
curl -s $B/003/SRR2584863/SRR2584863_1.fastq.gz | zcat | head -n $((4*N)) | gzip -9 > 004.fastq.gz
```

The decompressed content can be reproduced exactly. The `.gz` bytes, and so the md5
checksums, can differ if another gzip version or level is used.

## License / terms

These are public data from the European Nucleotide Archive (ENA) and NCBI SRA,
distributed under the INSDC policy: free and unrestricted access, with no use
restrictions (https://www.ebi.ac.uk/ena/browser/about/policies). Please cite the
original study (Tenaillon et al. 2016, PRJNA295606) when you use the data.

## md5sum

```
9806e31ee687c349370ada7acc8df511  001.fastq.gz
1edf1d98d92230cca6c40f1b492d9a6e  002.fastq.gz
820b3511ea7ffadc6062c0cb6eac02dd  003.fastq.gz
85a6041e616d4fccb62c9030e5c60779  004.fastq.gz
```
