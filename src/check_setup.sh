#!/bin/bash
# =============================================================================
# INSTRUCTORS - check that everything the exercise needs is in place.
# Run on a Nord4 login node before the course:   bash src/check_setup.sh
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

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

echo "Software per task (modules for approaches 1-3, images for approach 4)"
for task in $(available_tasks); do
    # subshell: each task's modules are loaded in isolation
    report=$(
        load_task "$task"
        # shellcheck disable=SC2086
        if module load $TASK_MODULES &>/dev/null && command -v ${TASK_TOOLS%% *} >/dev/null; then
            echo "  [ OK ] $task: module load $TASK_MODULES"
        else
            echo "  [FAIL] $task: module load $TASK_MODULES (edit TASK_MODULES in src/tasks/$task.sh)"
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
scontrol show reservation curso &>/dev/null && ok "reservation 'curso' exists" ||
    fail "reservation 'curso' not found (yet?)"

echo
(( problems == 0 )) && echo "All good." || echo "$problems problem(s) found."
