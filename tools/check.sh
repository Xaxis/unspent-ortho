#!/usr/bin/env bash
# The whole gate. Run before every commit. Target: about 30 seconds.
#   1. every script and shader loads; every test passes (headless)
#   2. canonical screenshots render with no script errors (real GPU frames)
# Shots land in shots/check/ — LOOK at the ones your change affects.
set -uo pipefail
cd "$(dirname "$0")/.."
t0=$(date +%s)
tools/_import.sh
fail=0
echo "== tests (3 shards) and shots, side by side"
logs=()
tpids=()
for i in 0 1 2; do
  log="$(mktemp -t unspent-test)"; logs+=("$log")
  godot --headless --path . -s tests/run.gd -- "--shard=$i/3" >"$log" 2>&1 & tpids+=($!)
done
mkdir -p shots/check
pids=()
tools/shot.sh shots/check/spawn.png --seed=1 & pids+=($!)
tools/shot.sh shots/check/dusk.png --seed=2 --hour=19.5 --walk=1,-1,1.5 & pids+=($!)
tools/shot.sh shots/check/night.png --seed=3 --hour=23 & pids+=($!)
tools/shot.sh shots/check/gallery.png --scene=gallery & pids+=($!)
for p in "${pids[@]}"; do wait "$p" || fail=1; done
for i in 0 1 2; do
  wait "${tpids[$i]}" || fail=1
  grep -E "FAIL|^\s{7}|LOAD FAIL|SCRIPT ERROR|at: " "${logs[$i]}"
  grep -E 'passed,' "${logs[$i]}"
  rm -f "${logs[$i]}"
done
echo "== $(( $(date +%s) - t0 ))s total"
if [ $fail -ne 0 ]; then echo "CHECK FAILED"; exit 1; fi
echo "CHECK OK"
