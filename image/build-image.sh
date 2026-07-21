#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: image/build-image.sh --base BASE_IMAGE [--output OUTPUT.img]
       [--maschinepi-binary ARM64_FILE] [--password PASSWORD]
       [--release-tree DIR] [--compress] [--force]

BASE_IMAGE may be an uncompressed .img or an .img.xz/.img.gz/.zip image.
The default container helper is pi-gen:latest; override MPI_IMAGE_TOOL_IMAGE.
EOF
  exit 2
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
base=""
output="$repo_root/image/output/mpi-station-$(date +%Y%m%d).img"
release_tree=""
maschinepi_binary=""
password="maschinepi"
compress=0
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --release-tree) release_tree="$2"; shift 2 ;;
    --maschinepi-binary) maschinepi_binary="$2"; shift 2 ;;
    --password) password="$2"; shift 2 ;;
    --compress) compress=1; shift ;;
    --force) force=1; shift ;;
    *) usage ;;
  esac
done

[[ -f "$base" ]] || usage
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v realpath >/dev/null || { echo "realpath is required" >&2; exit 1; }

mkdir -p "$(dirname "$output")"
output="$(realpath -m "$output")"
base="$(realpath "$base")"
if [[ -e "$output" && "$force" != 1 ]]; then
  echo "Refusing to overwrite $output (pass --force)" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

if [[ -z "$release_tree" ]]; then
  release_tree="$tmp_dir/release"
  "$repo_root/scripts/export-release-tree.sh" "$release_tree"
else
  release_tree="$(realpath "$release_tree")"
fi

echo "Creating working image $output"
case "$base" in
  *.xz) xz -dc "$base" > "$output" ;;
  *.gz) gzip -dc "$base" > "$output" ;;
  *.zip) unzip -p "$base" '*.img' > "$output" ;;
  *) cp --sparse=always "$base" "$output" ;;
esac

work_dir="$(dirname "$output")"
container_image="${MPI_IMAGE_TOOL_IMAGE:-pi-gen:latest}"
binary_in_container=""
if [[ -n "$maschinepi_binary" ]]; then
  maschinepi_binary="$(realpath "$maschinepi_binary")"
  cp "$maschinepi_binary" "$work_dir/.mpi-station-maschinepi"
  binary_in_container=/work/.mpi-station-maschinepi
fi

docker run --rm --privileged \
  -v "$repo_root:/repo:ro" \
  -v "$release_tree:/release:ro" \
  -v "$work_dir:/work" \
  "$container_image" \
  /repo/image/inject-image.sh "/work/$(basename "$output")" /release \
    "$binary_in_container" "$password"

rm -f "$work_dir/.mpi-station-maschinepi"

if [[ "$compress" == 1 ]]; then
  echo "Compressing $output"
  xz -T0 -6 "$output"
  output="$output.xz"
fi

sha256sum "$output" > "$output.sha256"
echo "Flashable image: $output"
echo "Checksum: $output.sha256"
