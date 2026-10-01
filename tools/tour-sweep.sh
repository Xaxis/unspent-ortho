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
PROOFS="tours/home-coast.tour tours/holdfast.tour"
if [ "${1:-}" = "--smoke" ]; then
  # A renamed tour must not drop out of the set unseen.
  missing=$(grep -oE '^[a-z0-9_-]+' tours/SMOKE | while read -r t; do [ -f "tours/$t.tour" ] || echo "$t"; done)
  if [ -n "$missing" ]; then echo "tour-sweep --smoke: tours/SMOKE names tours that don't exist: $missing"; exit 1; fi
  # Two at a time (a tree's share of heavy.sh): each prints its own line.
  grep -oE '^[a-z0-9_-]+' tours/SMOKE | sed 's|^|tours/|; s|$|.tour|' \
    | xargs -P 2 -I{} "$0" {} | grep -E '^(PASS|FAIL)' | tee /dev/stderr | grep -c '^FAIL' > /tmp/unspent-smoke.$$ || true
  f=$(cat /tmp/unspent-smoke.$$); rm -f /tmp/unspent-smoke.$$
  echo "tour-sweep --smoke: $f failed"
  exit "$f"
elif [ "${1:-}" = "--since" ]; then
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
