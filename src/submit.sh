#!/bin/bash
# =============================================================================
# Submit an approach for a task AND record where the job landed in the queue
# (priority, its components and your rank among the pending jobs).
# Those numbers only exist while the job is pending, so we take them right
# after sbatch.
#
# Usage: bash src/submit.sh <approach> <task> [extra sbatch options]
#   approach : 1|simple  2|array  3|threads  4|container  all
#   task     : fastqc seqkit fastp jellyfish bowtie2       all
# Examples:
#   bash src/submit.sh 1 fastqc
#   bash src/submit.sh all fastp                   # the 4 approaches, same task
#   bash src/submit.sh 3 jellyfish --time=00:30:00 # extra options go to sbatch
# =============================================================================
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '8,14s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; exit 1; }

# approach argument -> "<script> <label used in the run records>"
approach_info() {
    case $1 in
        1 | simple)    echo "1_JOB_SIMPLE.sh 1_simple" ;;
        2 | array)     echo "2_JOB_ARRAY.sh 2_array" ;;
        3 | threads)   echo "3_JOB_THREADS.sh 3_threads" ;;
        4 | container) echo "4_JOB_CONTAINER.sh 4_container" ;;
        *) return 1 ;;
    esac
}

# Rank of our job among the PENDING jobs that compete for the same resources
# (same partition and reservation), by priority. Prints "rank|pending_jobs".
# Pending arrays count as one entry. Rank 0 = our job is not pending any more.
queue_rank() {
    local job_id=$1 partition=$2 reservation=$3
    squeue -h -t PD -o '%i|%Q|%P|%v' 2>/dev/null | awk -F'|' \
        -v id="$job_id" -v part="$partition" -v resv="$reservation" '
        $3 == part && $4 == resv {
            n++; jid = $1; sub(/_.*/, "", jid)
            ids[n] = jid; prio[n] = $2 + 0
            if (jid == id) mine = $2 + 0
        }
        END {
            if (mine == "") { print "0|" n + 0; exit }
            rank = 1
            for (i = 1; i <= n; i++) if (ids[i] != id && prio[i] > mine) rank++
            print rank "|" n
        }'
}

# Usage: snapshot <job_id> <approach> <task>
snapshot() {
    local job_id=$1 approach=$2 task=$3 line="" sp="" i
    # Give the scheduler a moment to register the job and compute its priority
    for i in 1 2 3 4 5; do
        line=$(squeue -h -j "$job_id" -o '%T|%Q|%P|%v|%S' 2>/dev/null | head -n 1)
        [[ -n $line ]] && break
        sleep 1
    done
    local state priority partition reservation est_start
    IFS='|' read -r state priority partition reservation est_start <<<"$line"

    # Priority = sum of weighted factors: age + fairshare + job size + partition + QOS
    sp=$(sprio -h -j "$job_id" -o '%Y|%A|%F|%J|%P|%Q' 2>/dev/null | head -n 1 | tr -d ' ')
    local p_total p_age p_fs p_size p_part p_qos
    IFS='|' read -r p_total p_age p_fs p_size p_part p_qos <<<"$sp"

    local rank pending
    IFS='|' read -r rank pending <<<"$(queue_rank "$job_id" "$partition" "$reservation")"

    mkdir -p "$RESULTS_DIR/submissions"
    # run_id user approach task submit_epoch state priority age fairshare jobsize
    # partition_prio qos_prio rank pending est_start
    printf '%s\t' "$job_id" "$USER" "$approach" "$task" "$(date +%s)" "${state:--}" \
        "${priority:--}" "${p_age:--}" "${p_fs:--}" "${p_size:--}" "${p_part:--}" "${p_qos:--}" \
        "${rank:-0}" "${pending:-0}" >"$RESULTS_DIR/submissions/$job_id.tsv"
    printf '%s\n' "${est_start:--}" >>"$RESULTS_DIR/submissions/$job_id.tsv"

    echo "   state      : ${state:-unknown}"
    echo "   priority   : ${priority:--}  (age ${p_age:--} + fairshare ${p_fs:--} + jobsize ${p_size:--} + partition ${p_part:--} + qos ${p_qos:--})"
    if [[ ${rank:-0} == 0 ]]; then
        echo "   queue rank : not pending (already started?)"
    else
        echo "   queue rank : $rank of $pending pending jobs in partition $partition / reservation $reservation"
    fi
    echo "   est. start : ${est_start:--}"
}

submit_one() {
    local approach=$1 task=$2; shift 2
    local info script label name
    info=$(approach_info "$approach") || die "Unknown approach '$approach' (1-4, simple, array, threads, container)"
    read -r script label <<<"$info"
    load_task "$task"
    load_samples # fails early if the task has no input; sizes the array
    name="${script#?_}"; name="${name%.sh}_$task" # JOB_SIMPLE_fastqc

    # Log paths from LOG_DIR (they override the #SBATCH lines, which cannot use variables)
    local logs="%x_%j"
    [[ $script == 2_* ]] && logs="%x_%A_%a"
    local args=(--parsable --job-name="$name" --export="ALL,REPO_DIR=$REPO_DIR"
        --output="$LOG_DIR/out/$logs.out" --error="$LOG_DIR/err/$logs.err")
    [[ $script == 2_* ]] && args+=(--array="1-${#SAMPLES[@]}")

    echo "-> sbatch ${args[*]:1} $* src/$script $task"
    local out job_id
    out=$(cd "$REPO_DIR" && sbatch "${args[@]}" "$@" "src/$script" "$task") || die "sbatch failed"
    job_id="${out%%;*}"
    echo "   job id     : $job_id"
    snapshot "$job_id" "$label" "$task"
    echo
}

(( $# >= 2 )) || usage
approach_arg=$1 task_arg=$2; shift 2

command -v sbatch >/dev/null || die "sbatch not found: run this on a Nord4 login node"
mkdir -p "$LOG_DIR/out" "$LOG_DIR/err" # Slurm cannot create the log folders itself

approaches=("$approach_arg"); [[ $approach_arg == all ]] && approaches=(1 2 3 4)
tasks=("$task_arg");          [[ $task_arg == all ]] && mapfile -t tasks < <(available_tasks)

for t in "${tasks[@]}"; do
    for a in "${approaches[@]}"; do
        submit_one "$a" "$t" "$@"
    done
done
echo "Follow your jobs with:   squeue --me"
echo "Compare when finished:   sbatch src/collect_results.sh --mine"
