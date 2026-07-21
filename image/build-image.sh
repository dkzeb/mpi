#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: image/build-image.sh --base BASE_IMAGE [--output OUTPUT.img]
       [--maschinepi-binary ARM64_FILE] [--password PASSWORD]
       [--release-tree DIR] [--rootfs-headroom-mb N]
       [--mixxx-library-mb N] [--samples-mb N] [--compress] [--force]

BASE_IMAGE may be an uncompressed .img or an .img.xz/.img.gz/.zip image.
MaschinePI is cross-compiled on the host unless --maschinepi-binary is supplied.
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
rootfs_headroom_mb=1024
mixxx_library_mb=2048
samples_mb=2048

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --release-tree) release_tree="$2"; shift 2 ;;
    --maschinepi-binary) maschinepi_binary="$2"; shift 2 ;;
    --password) password="$2"; shift 2 ;;
    --rootfs-headroom-mb) rootfs_headroom_mb="$2"; shift 2 ;;
    --mixxx-library-mb) mixxx_library_mb="$2"; shift 2 ;;
    --samples-mb) samples_mb="$2"; shift 2 ;;
    --compress) compress=1; shift ;;
    --force) force=1; shift ;;
    *) usage ;;
  esac
done

[[ -f "$base" ]] || usage
[[ "$rootfs_headroom_mb" =~ ^[0-9]+$ ]] || usage
[[ "$mixxx_library_mb" =~ ^[0-9]+$ && "$mixxx_library_mb" -ge 256 ]] || usage
[[ "$samples_mb" =~ ^[0-9]+$ && "$samples_mb" -ge 256 ]] || usage
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v realpath >/dev/null || { echo "realpath is required" >&2; exit 1; }

mkdir -p "$(dirname "$output")"
output="$(realpath -m "$output")"
base="$(realpath "$base")"
final_output="$output"
[[ "$compress" == 1 ]] && final_output="$output.xz"
if [[ -e "$final_output" && "$force" != 1 ]]; then
  echo "Refusing to overwrite $final_output (pass --force)" >&2
  exit 1
fi

tmp_parent="${MPI_BUILD_TMPDIR:-/tmp}"
[[ -d "$tmp_parent" ]] || { echo "Missing MPI_BUILD_TMPDIR: $tmp_parent" >&2; exit 1; }
tmp_dir="$(mktemp -d "$tmp_parent/mpi-station-image.XXXXXX")"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

if [[ -z "$release_tree" ]]; then
  release_tree="$tmp_dir/release"
  "$repo_root/scripts/export-release-tree.sh" "$release_tree"
else
  release_tree="$(realpath "$release_tree")"
fi

work_image="$tmp_dir/image.img"
echo "Creating working image $work_image"
case "$base" in
  *.xz) xz -dc "$base" > "$work_image" ;;
  *.gz) gzip -dc "$base" > "$work_image" ;;
  *.zip) unzip -p "$base" '*.img' > "$work_image" ;;
  *) cp --sparse=always "$base" "$work_image" ;;
esac
original_size_bytes="$(stat -c%s "$work_image")"
extra_mb=$((rootfs_headroom_mb + mixxx_library_mb + samples_mb))
truncate -s "+${extra_mb}M" "$work_image"

work_dir="$(dirname "$work_image")"
container_image="${MPI_IMAGE_TOOL_IMAGE:-pi-gen:latest}"
if [[ -z "$maschinepi_binary" ]]; then
  echo "Cross-compiling MaschinePI for ARM64"
  "$repo_root/scripts/build-maschinepi-arm64"
  maschinepi_binary="$repo_root/image/output/maschinepi-arm64"
fi
maschinepi_binary="$(realpath "$maschinepi_binary")"
[[ -f "$maschinepi_binary" ]] || {
  echo "Missing MaschinePI binary: $maschinepi_binary" >&2
  exit 1
}
file "$maschinepi_binary" | grep -Eq 'ARM aarch64|ARM64' || {
  echo "MaschinePI binary is not ARM64: $(file "$maschinepi_binary")" >&2
  exit 1
}
echo "Cross-compiling Mixxx MK3 helpers for ARM64"
"$repo_root/scripts/build-mixxx-tools-arm64"
echo "Cross-compiling the MK3 mode selector for ARM64"
"$repo_root/scripts/build-mode-selector-arm64"

artifacts_dir="$work_dir/artifacts"
install -d "$artifacts_dir"
install -m 755 "$maschinepi_binary" "$artifacts_dir/maschinepi"
install -m 755 "$repo_root/image/output/mixxx-tools-arm64/mk3-screen-daemon" \
  "$artifacts_dir/mk3-screen-daemon"
install -m 755 "$repo_root/image/output/mixxx-tools-arm64/mk3" \
  "$artifacts_dir/mk3"
install -m 755 "$repo_root/image/output/mk3-mode-selector-arm64" \
  "$artifacts_dir/mk3-mode-selector"

docker run --rm --privileged \
  -v "$repo_root:/repo:ro" \
  -v "$release_tree:/release:ro" \
  -v "$work_dir:/work" \
  "$container_image" \
  /repo/image/inject-image.sh "/work/$(basename "$work_image")" /release \
    /work/artifacts "$password" "$original_size_bytes" \
    "$rootfs_headroom_mb" "$mixxx_library_mb" "$samples_mb"

if [[ "$compress" == 1 ]]; then
  echo "Compressing $work_image"
  xz -T0 -6 "$work_image"
  work_image="$work_image.xz"
fi

mv -f "$work_image" "$final_output"
(cd "$(dirname "$final_output")" && \
  sha256sum "$(basename "$final_output")" > "$(basename "$final_output").sha256")
echo "Flashable image: $final_output"
echo "Checksum: $final_output.sha256"
