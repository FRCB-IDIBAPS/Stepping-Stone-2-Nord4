#!/bin/bash
# Build the Singularity/Apptainer images for the exercise tasks.
#
# Run this OFF-CLUSTER (on a machine with internet and fakeroot or sudo):
#   bash singularity/build.sh              # build every bin/*.def
#   bash singularity/build.sh fastqc fastp # build only these
#   FORCE=1 bash singularity/build.sh      # rebuild images that already exist
#
# Then copy the images to Nord4 through a transfer node:
#   rsync -av --progress singularity/images/*.sif \
#         <user>@transfer1.bsc.es:/gpfs/projects/idib57/Stepping_Stone/singularity/images/
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
def_dir="$here/bin"
img_dir="$here/images"
mkdir -p "$img_dir"

if command -v apptainer >/dev/null; then
    builder=apptainer
elif command -v singularity >/dev/null; then
    builder=singularity
else
    echo "ERROR: neither apptainer nor singularity is installed" >&2
    exit 1
fi

if (( $# )); then
    tasks=("$@")
else
    tasks=()
    for def in "$def_dir"/*.def; do tasks+=("$(basename "$def" .def)"); done
fi

failed=()
for task in "${tasks[@]}"; do
    def="$def_dir/$task.def"
    sif="$img_dir/$task.sif"
    if [[ ! -f $def ]]; then
        echo "ERROR: no definition file $def" >&2
        failed+=("$task")
        continue
    fi
    if [[ -f $sif && -z ${FORCE:-} ]]; then
        echo "== $task: $sif already exists (FORCE=1 to rebuild)"
        continue
    fi
    echo "== Building $sif from $def"
    if "$builder" build --fakeroot --force "$sif" "$def"; then
        echo "== $task OK ($(du -h "$sif" | cut -f1))"
    else
        failed+=("$task")
    fi
done

if (( ${#failed[@]} )); then
    echo "FAILED: ${failed[*]}" >&2
    exit 1
fi
echo "All images ready in $img_dir"
