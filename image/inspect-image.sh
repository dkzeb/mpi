#!/usr/bin/env bash
set -euo pipefail

image="${1:-}"
[[ -f "$image" ]] || { echo "Usage: $0 IMAGE[.xz|.gz]" >&2; exit 2; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_parent="${MPI_BUILD_TMPDIR:-/tmp}"
tmp_dir="$(mktemp -d "$tmp_parent/mpi-station-inspect.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

case "$image" in
  *.xz) raw="$tmp_dir/image.img"; xz -dc "$image" > "$raw" ;;
  *.gz) raw="$tmp_dir/image.img"; gzip -dc "$image" > "$raw" ;;
  *) raw="$(realpath "$image")" ;;
esac

work_dir="$(dirname "$raw")"
container_image="${MPI_IMAGE_TOOL_IMAGE:-pi-gen:latest}"
docker run --rm --privileged \
  -v "$repo_root:/repo:ro" \
  -v "$work_dir:/work" \
  "$container_image" \
  /repo/image/inspect-mounted-image.sh "/work/$(basename "$raw")"
