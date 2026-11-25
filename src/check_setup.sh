#!/bin/bash
# =============================================================================
# INSTRUCTORS - check that everything the exercise needs is in place.
# Run it before the course, from the workspace folder, as a small job:
#   sbatch src/check_setup.sh        # report in bin/out/CHECK_SETUP_<job_id>.out
# (bash src/check_setup.sh also works: it only lists files and loads modules)
# =============================================================================
#SBATCH --job-name=CHECK_SETUP
#SBATCH --output=bin/out/%x_%j.out
#SBATCH --error=bin/err/%x_%j.err
#SBATCH --account=idib57
#SBATCH --qos=cli
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00

# sbatch runs a COPY of this script, so find the repository from the submit folder
for d in "${REPO_DIR:-}" "${SLURM_SUBMIT_DIR:-$PWD}" "${SLURM_SUBMIT_DIR:-$PWD}/.." "$(dirname "$0")/.."; do
    [[ -f $d/src/lib/common.sh ]] && { source "$d/src/lib/common.sh"; break; }
done
type load_task &>/dev/null || { echo "ERROR: submit from the repository folder" >&2; exit 1; }
echo "Workspace: $BASE_DIR"

problems=0
ok()   { printf '  [ OK ] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; problems=$((problems + 1)); }

echo "Input data per task"
for task in $(available_tasks); do
    data_dir="${DATA_DIR:-$DATA_ROOT/$task}"
    shopt -s nullglob
    files=("$data_dir"/$SAMPLE_GLOB)
    shopt -u nullglob
    (( ${#files[@]} )) && ok "$task: ${#files[@]} input files in $data_dir" ||
        fail "$task: no $SAMPLE_GLOB files in $data_dir"
done

echo "Folders"
for d in "$LOG_DIR/out" "$LOG_DIR/err" "$OUTPUT_ROOT" "$RESULTS_DIR"; do
    if mkdir -p "$d" 2>/dev/null && [[ -w $d ]]; then
        chmod g+rwxs "$d" 2>/dev/null || true # participants share these folders
        ok "writable $d"
    else
        fail "cannot write $d"
    fi
done

echo "Software per task (modules or software/bin for approaches 1-3, images for approach 4)"
for task in $(available_tasks); do
    # subshell: each task's modules are loaded in isolation
    report=$(
        load_task "$task"
        if native_setup &>/dev/null; then
            echo "  [ OK ] $task: $(native_source) -> $(command -v ${TASK_TOOLS%% *})"
        else
            echo "  [FAIL] $task: $(native_source), tools: $TASK_TOOLS (edit TASK_MODULES in src/tasks/$task.sh)"
        fi
        [[ -f $SIF ]] && echo "  [ OK ] $task: $SIF" || echo "  [FAIL] $task: missing $SIF"
    )
    echo "$report"
    [[ $report == *FAIL* ]] && problems=$((problems + 1))
done

echo "Reference for bowtie2"
[[ -f $BOWTIE2_INDEX.1.bt2 || -f $BOWTIE2_INDEX.1.bt2l ]] && ok "index $BOWTIE2_INDEX" ||
    fail "no index at $BOWTIE2_INDEX (sbatch src/prepare_reference.sh)"

echo "Slurm"
command -v sbatch >/dev/null && ok "sbatch available" || fail "sbatch not found"

echo
(( problems == 0 )) && echo "All good." || echo "$problems problem(s) found."
