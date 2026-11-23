# Stepping Stone 2 — Practical exercise on Nord4

Run the same bioinformatics tasks with **four different Slurm approaches**, record
how each run behaved (time, CPUs, nodes, queue priority) and compare which
approach fits each task best.

## Quick start (participants)

Run everything from the repository folder on a Nord4 login node:

```bash
cd /gpfs/projects/idib57/Stepping_Stone

bash src/submit.sh 1 fastqc        # approach 1 with FastQC
bash src/submit.sh all fastqc      # the 4 approaches with FastQC
squeue --me                        # follow your jobs
bash src/collect_results.sh --mine # compare your runs once they finish
```

`submit.sh` runs `sbatch` for you (it prints the exact command) and also
records your job's **priority and position in the queue** right after
submission. You can still use plain `sbatch src/1_JOB_SIMPLE.sh fastqc`, but then
the queue position is not recorded.

## The four approaches

| Script | Approach | Resources | How the samples run |
|---|---|---|---|
| `src/1_JOB_SIMPLE.sh` | Sequential | 1 job × 1 CPU | one after the other |
| `src/2_JOB_ARRAY.sh` | Job array | 4 jobs × 2 CPUs | one array element per sample, scheduled independently |
| `src/3_JOB_THREADS.sh` | Tasks + threads | 1 job, 4 tasks × 2 CPUs | one `srun` step per sample, all at once |
| `src/4_JOB_CONTAINER.sh` | Tasks + threads + Singularity | same as 3 | same as 3, with the tool inside `<task>.sif` |

Approaches 2, 3 and 4 use the same total CPUs (8). That makes it possible to
compare *how* the resources are requested, not *how many*.

## The five tasks

| Task | Tool | Dataset (`src/data/<task>/`, 4 samples) | What it shows |
|---|---|---|---|
| `fastqc` | FastQC | Human airway RNA-seq (PRJNA229998), 500k × 63 bp | Uses one thread per file, so extra threads per sample are wasted (low CPU efficiency) |
| `seqkit` | SeqKit stats | *E. coli* LTEE runs from 3 Illumina generations (PRJNA295606), 500k × 36–150 bp | Takes seconds: queueing and start-up overhead dominate. Is parallelising worth it? |
| `fastp` | fastp trimming | Human serum miRNA-seq (PRJNA849256), 1M × 76 bp, >90% reads with adapter | CPU bound, scales with threads |
| `jellyfish` | Jellyfish k-mer counting | *S. aureus* WGS isolates (PRJNA324190), whole runs of ~650k × 151 bp, ~34x, k-mer peak ~28 | CPU **and** memory hungry. On Nord4, RAM comes with CPUs (~2 GB/CPU) |
| `bowtie2` | Bowtie2 + SAMtools | *E. coli* K-12 MG1655 WGS (PRJNA1133223) + reference NC_000913.3, 500k × 151 bp | Heaviest task, scales very well with threads. Needs a reference index |

Each dataset folder has a `SOURCE.md` with accessions, why the dataset was
chosen, licence (public INSDC data) and how it was produced.

Each task is a small file in `src/tasks/` that defines its modules, its image
and a `task_run` function for **one** sample. To add a task, copy one of them
and put its FASTQ files in `src/data/<task>/`.

## What is recorded

| When | File | Contents |
|---|---|---|
| every job, at the end (also on failure) | `results/jobs/<job_id>.tsv` | user, approach, task, nodes, node names, tasks, CPUs, partition/QOS/reservation, priority, submit/start/end time, queue wait, elapsed, exit code |
| right after `submit.sh` | `results/submissions/<job_id>.tsv` | priority and its factors (`sprio`: age, fairshare, job size, partition, QOS), rank among the pending jobs in the same partition and reservation, estimated start |
| `collect_results.sh` | `results/sacct/<job_id>.tsv` | CPU time actually used and peak memory (`sacct`) |

`bash src/collect_results.sh` merges these into:

- `results/runs.tsv`: one line per run (a whole array counts as one run)
- `results/summary.tsv`: averages per **task × approach**, successful runs only

The key columns are `queue_wait_s`, `compute_s`, `turnaround_s` (submit to
last job finished), `cpu_h` (CPU-hours reserved, i.e. the cost), `cpu_eff_%`
(CPU used / CPU reserved), `priority` and `rank`. With `--mine`, the tables
contain only your runs and are written to `output/<user>/`.

`sacct` only shows you your own jobs, so **ask everyone to run
`bash src/collect_results.sh --mine` at the end**. That caches their CPU data so
the instructors' full summary includes it.

Outputs are written to `output/<user>/<approach>/<task>/`, so participants
never overwrite each other. Logs go to `bin/out/` and `bin/err/`.

## Instructor setup (before the course)

1. **Data**: the FASTQ files are not in git (~600 MB). Download them
   off-cluster, since Nord4 has no internet, and copy them over:
   ```bash
   bash src/data/download.sh                    # all tasks (or: download.sh fastp bowtie2)
   rsync -av --progress src/data/ \
       <user>@transfer1.bsc.es:/gpfs/projects/idib57/Stepping_Stone/src/data/
   ```
   The script streams only the first reads of each public run. It retries
   dropped connections and keeps a file only if it has exactly the expected
   number of reads. Run it again to finish any failed files.
2. **Images**: build them off-cluster and copy them over:
   ```bash
   bash singularity/build.sh                    # needs apptainer/singularity + fakeroot
   rsync -av --progress singularity/images/*.sif \
       <user>@transfer1.bsc.es:/gpfs/projects/idib57/Stepping_Stone/singularity/images/
   ```
   Definition files are in `singularity/bin/<task>.def` (micromamba + pinned
   bioconda versions, each with a `%test` section).
3. **Reference index** (only for `bowtie2`): `sbatch src/prepare_reference.sh`
   builds it from `src/data/bowtie2/reference/genome.fa` into
   `reference/bowtie2/`. Add `--export=ALL,EXEC_MODE=container` to use the image
   instead of the module.
4. **Modules**: approaches 1–3 use `module load`. Check that the module names
   in `src/tasks/*.sh` (`TASK_MODULES`) exist on Nord4.
5. **Check**: `bash src/check_setup.sh` verifies the data, writable folders,
   modules, images, reference index and the `curso` reservation.

All paths are set in `src/config.sh`, and any of them can be overridden from
the environment. If you change `LOG_DIR`, also update the `#SBATCH --output/--error`
lines, because Slurm cannot read variables there.

## Layout

```
src/
  1_JOB_SIMPLE.sh 2_JOB_ARRAY.sh 3_JOB_THREADS.sh 4_JOB_CONTAINER.sh   the four approaches
  submit.sh             sbatch + queue priority/rank snapshot
  collect_results.sh    comparison tables
  run_sample.sh         processes one sample with one task (used by every approach)
  tasks/<task>.sh       task definitions
  data/<task>/          input FASTQs (not in git) + SOURCE.md
  data/download.sh      fetch all datasets
  config.sh             paths
  check_setup.sh  prepare_reference.sh                                  instructor tools
  lib/common.sh         shared helpers (records, modules/containers, logging)
singularity/
  bin/<task>.def        Singularity definition files
  images/<task>.sif     built images (not in git)
  build.sh              build the images
```
