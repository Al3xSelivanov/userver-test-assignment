#!/usr/bin/env bash
set -Eeuo pipefail

research_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

IMG=ghcr.io/userver-framework/ubuntu-22.04-userver
DIGEST=sha256:fca9c8ac7e97b4e2b042d822facbb152aec10a9d4e09c0862e44c50640f3f303
LIMITS=(--cpus=4 --cpuset-cpus=0-3 --memory=8g --memory-swap=8g)
runs="${RUNS:-5}"
if ! [[ "$runs" =~ ^[1-9][0-9]*$ ]]; then
    echo 'RUNS must be a positive integer' >&2
    exit 2
fi

mkdir -p "$research_dir/results"
run_dir="$(mktemp -d "$research_dir/results/run-$(date -u +%Y%m%dT%H%M%SZ)-XXXX")"
echo "Only this empty directory will be writable inside the container: $run_dir"
echo "Starting a fresh container; $runs runs per proto variant, one per other scenario and variant."

docker run --rm \
    "${LIMITS[@]}" \
    -e OUTPUT_UID="$(id -u)" -e OUTPUT_GID="$(id -g)" \
    -v "$research_dir/scripts:/input/scripts:ro" \
    -v "$research_dir/vendor:/input/vendor:ro" \
    -v "$run_dir:/output" \
    -w /output \
    "$IMG@$DIGEST" bash /input/scripts/container.sh /output "$runs"

echo "Completed. Open: $run_dir/summary.md"
