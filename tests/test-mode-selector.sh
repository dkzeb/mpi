#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cmake -S "$repo_root/mode-selector" -B "$tmp_dir/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=OFF >/dev/null
cmake --build "$tmp_dir/build" --target mk3-mode-selector >/dev/null
selector="$tmp_dir/build/mk3-mode-selector"
config="$tmp_dir/config"
cp "$repo_root/config/mk3-mode.conf" "$config"

output="$($selector --config "$config" --dry-run --select mixxx)"
[[ "$output" == 'systemctl --no-block isolate mixxx.target' ]]

"$selector" --config "$config" --set-default mixxx
grep -qx 'default_mode=mixxx' "$config"
grep -qx 'slot1=maschinepi.target|MaschinePI' "$config"
grep -qx 'slot2=mixxx.target|MixxxDJ' "$config"

output="$($selector --config "$config" --dry-run --poll-ms 0)"
[[ "$output" == 'systemctl --no-block isolate mixxx.target' ]]

if "$selector" --config "$config" --dry-run --select '../bad' 2>/dev/null; then
  echo "Unsafe selector target was accepted" >&2
  exit 1
fi

echo "mode selector behavior: PASS"
