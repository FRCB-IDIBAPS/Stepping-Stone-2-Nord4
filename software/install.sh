#!/bin/bash
# =============================================================================
# Static builds of the tools that Nord4 has NO module for (checked with
# `module spider`). The native approaches (1-3) put software/bin on PATH, so
# they run these exactly as they would run a module's binary.
#
# The binaries are already in git: run this only to re-download or change them.
# Run it OFF-CLUSTER (Nord4 has no internet), then copy software/ to Nord4.
#   bash software/install.sh
#
# Same versions as the Singularity images (singularity/bin/<task>.def), so
# approach 3 (native) and 4 (container) run the same tool version.
# =============================================================================
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="$here/bin"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$bin"

SEQKIT_VERSION=2.8.2
FASTP_VERSION=0.23.4

echo "seqkit $SEQKIT_VERSION (official static Go build)"
curl -fsSL -o "$tmp/seqkit.tgz" \
    "https://github.com/shenwei356/seqkit/releases/download/v$SEQKIT_VERSION/seqkit_linux_amd64.tar.gz"
tar -xzf "$tmp/seqkit.tgz" -C "$tmp"
install -m 755 "$tmp/seqkit" "$bin/seqkit"

echo "fastp $FASTP_VERSION (official static build, opengene.org)"
curl -fsSL -o "$tmp/fastp" "http://opengene.org/fastp/fastp.$FASTP_VERSION"
install -m 755 "$tmp/fastp" "$bin/fastp"

echo
"$bin/seqkit" version
"$bin/fastp" --version
echo "Installed in $bin"
