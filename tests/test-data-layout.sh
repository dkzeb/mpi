#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
planner="$repo_root/scripts/mpi-prepare-data-partitions"

# A 32,021,856,256-byte card with the data area starting at sector 8,000,000.
disk_sectors=62542688
data_start=8000000
read -r p3_start p3_size p4_start p4_size < <(
  "$planner" --plan "$disk_sectors" "$data_start"
)

[[ "$p3_start" -eq "$data_start" ]]
[[ "$p4_start" -eq $((p3_start + p3_size)) ]]
[[ $((p4_start + p4_size)) -eq "$disk_sectors" ]]
[[ $((p3_size % 2048)) -eq 0 ]]
difference=$((p4_size - p3_size))
[[ "$difference" -ge 0 && "$difference" -lt 4096 ]]

if "$planner" --plan 100000 90000 >/dev/null 2>&1; then
  echo "Planner accepted a card without enough data capacity" >&2
  exit 1
fi

p4_update_line="$(grep -n -- '-N 4' "$planner" | cut -d: -f1)"
p3_update_line="$(grep -n -- '-N 3' "$planner" | cut -d: -f1)"
if [[ -z "$p4_update_line" || -z "$p3_update_line" ||
      "$p4_update_line" -ge "$p3_update_line" ]]; then
  echo "Partition 4 must move before partition 3 grows" >&2
  exit 1
fi

echo "equal remainder data layout: PASS"
