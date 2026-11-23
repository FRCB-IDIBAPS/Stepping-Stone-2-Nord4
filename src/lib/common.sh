# =============================================================================
# Shared helpers for the Stepping Stone exercise.
# Sourced by the job scripts, run_sample.sh, submit.sh and collect_results.sh.
# You do not need to read this file to do the exercise.
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_DIR/src/config.sh"

# Files we create are group-writable: results/ is shared by all participants.
umask 002

EXEC_MODE="${EXEC_MODE:-native}"     # native = module load | container = singularity exec

# ---------------------------------------------------------------- utilities --
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# 3725 -> 01:02:05
fmt_duration() {
    local s=$1
    printf '%02d:%02d:%02d' $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

# Value of KEY in one-line "KEY=value KEY2=value2" output (scontrol -o)
kv_get() { awk -v k="$1" '{ for (i = 1; i <= NF; i++) if (index($i, k "=") == 1) { print substr($i, length(k) + 2); exit } }'; }

# "2026-11-20T10:00:00" -> epoch seconds (empty if Unknown/None)
to_epoch() { [[ -n $1 && $1 != Unknown && $1 != None && $1 != N/A ]] && date -d "$1" +%s 2>/dev/null || true; }

# -------------------------------------------------------------------- tasks --
available_tasks() {
    local f
    for f in "$REPO_DIR"/src/tasks/*.sh; do basename "$f" .sh; done
}

# Defines TASK_MODULES, TASK_TOOLS, TASK_IMAGE and the task_run() function.
load_task() {
    TASK="$1"
    local f="$REPO_DIR/src/tasks/$TASK.sh"
    [[ -n $TASK && -f $f ]] || die "Unknown task '$TASK'. Available tasks: $(available_tasks | xargs)"
    source "$f"
    SIF="$SIF_DIR/$TASK_IMAGE"
    TASK_DATA_DIR="${DATA_DIR:-$DATA_ROOT/$TASK}"
}

# ------------------------------------------------------------------ samples --
# Fills the SAMPLES array with every FASTQ of the task's data folder (sorted)
load_samples() {
    shopt -s nullglob
    SAMPLES=("$TASK_DATA_DIR"/$SAMPLE_GLOB)
    shopt -u nullglob
    (( ${#SAMPLES[@]} > 0 )) || die "No input files matching $TASK_DATA_DIR/$SAMPLE_GLOB"
}

# /path/001.fastq.gz -> 001
sample_name() {
    local b
    b="$(basename "$1")"
    b="${b%.gz}"; b="${b%.fastq}"; b="${b%.fq}"
    echo "$b"
}

# ----------------------------------------------------------------- software --
# native:    module load <TASK_MODULES>
# container: module load singularity + check that the task image exists
load_software() {
    local tool
    if [[ $EXEC_MODE == container ]]; then
        command -v singularity >/dev/null || module load singularity \
            || die "Could not load the singularity module"
        [[ -f $SIF ]] || die "Image not found: $SIF (build it with singularity/build.sh)"
        log "Software: $(basename "$SIF") ($(singularity --version))"
    else
        # shellcheck disable=SC2086  # TASK_MODULES is a space-separated list
        module load $TASK_MODULES || die "Could not load modules: $TASK_MODULES"
        for tool in $TASK_TOOLS; do
            command -v "$tool" >/dev/null || die "'$tool' not found after 'module load $TASK_MODULES'"
        done
        log "Software: module load $TASK_MODULES"
    fi
}

# Folders the container needs to see (data, outputs, reference)
bind_paths() {
    local p out="$BASE_DIR"
    for p in "${TASK_DATA_DIR:-$DATA_ROOT}" "$OUTPUT_ROOT" "$(dirname "$BOWTIE2_INDEX")"; do
        [[ -d $p && $p != "$BASE_DIR"* ]] && out+=",$p"
    done
    echo "$out"
}

# Prefix for every tool call inside a task: runs natively or inside the image.
#   run fastqc file.fastq.gz   ->   fastqc file.fastq.gz
#                              ->   singularity exec ... fastqc.sif fastqc file.fastq.gz
run() {
    if [[ $EXEC_MODE == container ]]; then
        singularity exec --cleanenv --bind "$(bind_paths)" "$SIF" "$@"
    else
        "$@"
    fi
}

# --------------------------------------------------------------- job steps --
# Memory option for one `srun` step when several steps share a job.
# Without it a step may claim ALL the job's memory and the other steps wait
# ("Job step creation temporarily disabled"), silently making the job serial.
# (Nord4 forbids --mem in sbatch, but this only splits the memory we already got.)
step_mem_option() {
    local info m
    if [[ -n ${SLURM_MEM_PER_CPU:-} ]]; then
        echo "--mem-per-cpu=${SLURM_MEM_PER_CPU}M"; return
    fi
    info=$(scontrol show job -o "${SLURM_JOB_ID:-}" 2>/dev/null | head -n 1)
    m=$(kv_get MinMemoryCPU <<<"$info")
    [[ -n $m ]] && echo "--mem-per-cpu=$m"
    return 0
}

# ------------------------------------------------------------- run records --
# Every job writes one line to $RESULTS_DIR/jobs/<job_id>.tsv when it ends
# (even when it fails). collect_results.sh turns these into comparison tables.
#
# Columns: run_id job_id user approach task exec_mode n_samples nodes node_list
#          ntasks cpus_per_task alloc_cpus partition qos reservation priority
#          submit_epoch start_epoch end_epoch queue_wait_s elapsed_s exit_code

# Usage: job_record_start <approach> <n_samples>
job_record_start() {
    JOB_APPROACH="$1"
    JOB_N_SAMPLES="$2"
    JOB_START=$(date +%s)
    trap 'job_record_end $?' EXIT

    log "================================================================"
    log "Approach : $JOB_APPROACH"
    log "Task     : $TASK ($EXEC_MODE)"
    log "Samples  : $JOB_N_SAMPLES"
    log "Job      : ${SLURM_JOB_ID:-local}${SLURM_ARRAY_TASK_ID:+ (array ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID})}"
    log "Resources: ${SLURM_JOB_NUM_NODES:-1} node(s) [${SLURM_JOB_NODELIST:-$(hostname)}]," \
        "${SLURM_NTASKS:-1} task(s) x ${SLURM_CPUS_PER_TASK:-1} cpu(s)"
    log "================================================================"
}

job_record_end() {
    local rc=$1 end info=""
    end=$(date +%s)
    trap - EXIT
    # We are exiting anyway: a failing scontrol must not stop the record being written
    set +e +o pipefail

    local job_id="${SLURM_JOB_ID:-local$$}"
    local run_id="${SLURM_ARRAY_JOB_ID:-$job_id}"
    local ntasks="${SLURM_NTASKS:-1}" cpt="${SLURM_CPUS_PER_TASK:-1}"
    local nodes="${SLURM_JOB_NUM_NODES:-1}" node_list
    node_list=$(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null | paste -sd, -)
    [[ -n $node_list ]] || node_list=$(hostname -s)

    # Scheduler view of this job: priority, submit/start times, allocated CPUs...
    [[ -n ${SLURM_JOB_ID:-} ]] && info=$(scontrol show job -o "$SLURM_JOB_ID" 2>/dev/null | head -n 1)
    local alloc_cpus priority partition qos reservation submit start
    alloc_cpus=$(kv_get NumCPUs <<<"$info");    alloc_cpus=${alloc_cpus:-$((ntasks * cpt))}
    priority=$(kv_get Priority <<<"$info")
    partition=$(kv_get Partition <<<"$info")
    qos=$(kv_get QOS <<<"$info")
    reservation=$(kv_get Reservation <<<"$info")
    submit=$(to_epoch "$(kv_get SubmitTime <<<"$info")"); submit=${submit:-$JOB_START}
    start=$(to_epoch "$(kv_get StartTime <<<"$info")");   start=${start:-$JOB_START}

    local wait=$((start - submit)) elapsed=$((end - JOB_START))

    local dir="$RESULTS_DIR/jobs"
    if mkdir -p "$dir" 2>/dev/null; then
        printf '%s\t' "$run_id" "$job_id" "${USER:-unknown}" "$JOB_APPROACH" "$TASK" "$EXEC_MODE" \
            "$JOB_N_SAMPLES" "$nodes" "$node_list" "$ntasks" "$cpt" "$alloc_cpus" \
            "${partition:--}" "${qos:--}" "${reservation:--}" "${priority:--}" \
            "$submit" "$start" "$end" "$wait" "$elapsed" >"$dir/.$job_id.tmp"
        printf '%s\n' "$rc" >>"$dir/.$job_id.tmp"
        mv "$dir/.$job_id.tmp" "$dir/$job_id.tsv"
    else
        log "WARNING: cannot write run record to $dir"
    fi

    log "================================================================"
    log "Status       : $([[ $rc == 0 ]] && echo OK || echo "FAILED (exit $rc)")"
    log "Queue wait   : $(fmt_duration "$wait")"
    log "Elapsed time : $(fmt_duration "$elapsed")"
    log "CPUs x nodes : $alloc_cpus x $nodes   priority: ${priority:--}"
    log "Run record   : $dir/$job_id.tsv"
    log "================================================================"
    exit "$rc"
}
