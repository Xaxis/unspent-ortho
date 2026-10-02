#!/usr/bin/env bash
# Rebuild tests/shard_times.txt, the table tests/run.gd shards the gate by, from
# a finished gate run's own logs: every `file-time PATH MS` line of every shard,
# its costs and its played tests, summed per file. Then print the shards the new
# table makes and what each would take.
#   tools/shard-times.sh RUN_ID          a gate run on GitHub (needs gh)
#   tools/shard-times.sh --logs F...     job logs already on disk
# Why: shards by file index took 14 to 75 minutes on 1430cd50, and one added
# file reshuffled them all. Refresh after a run whose shards came out uneven.
set -uo pipefail
cd "$(dirname "$0")/.."
out=tests/shard_times.txt
shards=8
tmp="$(mktemp -d "${TMPDIR:-/tmp}/unspent-shard-times.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
if [ "${1:-}" = "--logs" ]; then
  shift
  cat "$@" >"$tmp/all.log"
elif [ -n "${1:-}" ]; then
  jobs="$(env -u GITHUB_TOKEN gh run view "$1" --json jobs --jq '.jobs[] | select(.name | startswith("tests (shard")) | .databaseId')"
  [ -n "$jobs" ] || { echo "shard-times: run $1 has no shard jobs"; exit 1; }
  # By job, so a shard's log can be read before the whole run has finished.
  for j in $jobs; do env -u GITHUB_TOKEN gh api --allow-escape-sequences "repos/{owner}/{repo}/actions/jobs/$j/logs" >>"$tmp/all.log" || exit 1; done
else
  sed -n 2,7p "$0"; exit 1
fi
# A job log line is `timestamp file-time PATH MS`.
grep -oE 'file-time [^ ]+ [0-9]+' "$tmp/all.log" \
  | awk '{ s[$2] += $3 } END { for (p in s) printf "%s %d\n", p, (s[p] + 999) / 1000 }' \
  | sort >"$tmp/table"
n="$(wc -l <"$tmp/table" | tr -d ' ')"
[ "$n" -gt 0 ] || { echo "shard-times: no file-time lines in those logs"; exit 1; }
{
  echo "# Seconds each test file takes in the gate: its run in a shard plus its costs"
  echo "# and played tests run again after (tools/check.sh). tests/run.gd shards by"
  echo "# it, longest first onto the lightest shard. Written by tools/shard-times.sh."
  cat "$tmp/table"
} >"$out"
echo "shard-times: $n files, $(awk '{ t += $2 } END { printf "%d", t / 60 }' "$tmp/table") min in all, written to $out"
# The shards it makes, as run.gd makes them (shard_of): longest first, lightest
# shard, ties to the lowest; a file not timed weighs the median.
find tests -name 'test_*.gd' ! -name test_case.gd | sort >"$tmp/files"
awk -v shards="$shards" '
  NR == FNR { t[$1] = $2; next }
  { files[++m] = $1 }
  END {
    k = 0; for (p in t) v[++k] = t[p]
    for (i = 2; i <= k; i++) { x = v[i]; for (j = i - 1; j >= 1 && v[j] > x; j--) v[j + 1] = v[j]; v[j + 1] = x }
    med = k ? v[int(k / 2) + 1] : 1
    for (i = 1; i <= m; i++) w[i] = (files[i] in t) ? t[files[i]] : med
    for (i = 1; i <= m; i++) { o[i] = i }
    for (i = 2; i <= m; i++) { x = o[i]; for (j = i - 1; j >= 1 && (w[o[j]] < w[x] || (w[o[j]] == w[x] && files[o[j]] > files[x])); j--) o[j + 1] = o[j]; o[j + 1] = x }
    for (s = 0; s < shards; s++) load[s] = 0
    for (i = 1; i <= m; i++) { b = 0; for (s = 1; s < shards; s++) if (load[s] < load[b]) b = s; load[b] += w[o[i]] }
    for (s = 0; s < shards; s++) printf "shard %d: %d min\n", s, load[s] / 60
  }' "$tmp/table" "$tmp/files"
