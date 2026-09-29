#!/usr/bin/env bash
# Run tours on this checkout, each with its own header's options, one at a time
# through tools/heavy.sh, and print one line per tour: PASS or FAIL and where.
#   tools/tour-sweep.sh                       every tours/*.tour
#   tools/tour-sweep.sh tours/home-coast.tour tours/holdfast.tour
#   tools/tour-sweep.sh --since REF           tours changed since REF, plus the proofs
# Why: CI has no GPU, so tours never run there, and three were found failing on
# main (2026-09-29) that nobody had run in days. A tour that fails on main is a
# proof that lies.
# Exit status: the number of failed tours (0 is all green).
set -u
cd "$(dirname "$0")/.."
PROOFS="tours/home-coast.tour tours/holdfast.tour"
if [ "${1:-}" = "--since" ]; then
  tours=$( { git diff --name-only "$2"...HEAD -- 'tours/*.tour'; echo "$PROOFS" | tr ' ' '\n'; } | sort -u)
elif [ $# -gt 0 ]; then
  tours="$*"
else
  tours=$(ls tours/*.tour)
fi
fail=0; n=0
for t in $tours; do
  [ -f "$t" ] || continue
  n=$((n+1))
  name=$(basename "$t" .tour)
  if tools/heavy.sh tools/tour.sh "$t" > /dev/null 2>&1; then
    echo "PASS $name"
  else
    shot=$(ls shots/tour/"$name"/FAILED-*.png 2>/dev/null | tail -1)
    echo "FAIL $name ${shot:-no frame} (log: shots/tour/$name/run.log)"
    fail=$((fail+1))
  fi
done
echo "tour-sweep: $((n-fail)) of $n passed"
exit $fail
