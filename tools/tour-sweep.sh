#!/usr/bin/env bash
# Run tours on this checkout, each with its own header's options, one at a time
# through tools/heavy.sh, and print one line per tour: PASS or FAIL and where.
#   tools/tour-sweep.sh                       every tours/*.tour
#   tools/tour-sweep.sh tours/home-coast.tour tours/holdfast.tour
#   tools/tour-sweep.sh --since REF           tours changed since REF, plus the proofs
#   tools/tour-sweep.sh --smoke               tours/SMOKE, two at a time: before a branch
#                                             touching src/systems or src/core is ready
# Why: CI has no GPU, so tours never run there, and three were found failing on
# main (2026-09-29) that nobody had run in days. A tour that fails on main is a
# proof that lies.
# Exit status: the number of failed tours (0 is all green).
set -u
cd "$(dirname "$0")/.."
PROOFS="tours/home-coast.tour tours/holdfast.tour tours/across.tour"
if [ "${1:-}" = "--smoke" ]; then
  # A renamed tour must not drop out of the set unseen.
  missing=$(grep -oE '^[a-z0-9_-]+' tours/SMOKE | while read -r t; do [ -f "tours/$t.tour" ] || echo "$t"; done)
  if [ -n "$missing" ]; then echo "tour-sweep --smoke: tours/SMOKE names tours that don't exist: $missing"; exit 1; fi
  # Two at a time (a tree's share of heavy.sh; on Linux the GPU lease draws one, the
  # other waits in its slot): each prints its own line as it ends.
  # They are counted from a file of their own: teed to /dev/stderr into a log, the
  # summary wrote over the first two (Linux opens /dev/stderr afresh, at offset 0).
  # A tour that printed no line at all is counted failed, never passed unseen.
  want=$(grep -cE '^[a-z0-9_-]+' tours/SMOKE)
  res="$(mktemp "${TMPDIR:-/tmp}/unspent-smoke.XXXXXX")"
  grep -oE '^[a-z0-9_-]+' tours/SMOKE | sed 's|^|tours/|; s|$|.tour|' \
    | xargs -P 2 -I{} "$0" {} | grep --line-buffered -E '^(PASS|FAIL|SKIP)' | tee "$res"
  got=$(grep -cE '^(PASS|FAIL|SKIP)' "$res"); f=$(( $(grep -c '^FAIL' "$res") + want - got )); rm -f "$res"
  echo "tour-sweep --smoke: $f failed of $want$([ "$got" -lt "$want" ] && echo ", $((want - got)) with no result")"
  exit "$f"
elif [ "${1:-}" = "--since" ]; then
  tours=$( { git diff --name-only "$2"...HEAD -- 'tours/*.tour'; echo "$PROOFS" | tr ' ' '\n'; } | sort -u)
elif [ $# -gt 0 ]; then
  tours="$*"
else
  tours=$(ls tours/*.tour)
fi
. tools/_tour_args.sh
# On Linux each tour takes the GPU lease for itself, inside its CPU slot: waiting for
# the GPU while holding a slot costs less than the other way round.
gpu=""; [ "$(uname)" = Linux ] && gpu=tools/gpu.sh
fail=0; n=0; skipped=0
for t in $tours; do
  [ -f "$t" ] || continue
  name=$(basename "$t" .tour)
  # A tour whose header says it is not tour.sh's (`sweep: skip, WHY`) is passed
  # over by that tag, never counted as a failure by tour.sh refusing it.
  why=$(tour_header_skip "$t")
  if [ -n "$why" ]; then
    echo "SKIP $name ($why)"
    skipped=$((skipped+1))
    continue
  fi
  n=$((n+1))
  if tools/heavy.sh $gpu tools/tour.sh "$t" > /dev/null 2>&1; then
    echo "PASS $name"
  else
    shot=$(ls shots/tour/"$name"/FAILED-*.png 2>/dev/null | tail -1)
    echo "FAIL $name ${shot:-no frame} (log: shots/tour/$name/run.log)"
    fail=$((fail+1))
  fi
done
echo "tour-sweep: $((n-fail)) of $n passed$([ "$skipped" -gt 0 ] && echo ", $skipped skipped by their headers")"
exit $fail
