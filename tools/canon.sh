#!/usr/bin/env bash
# The canon: a fixed set of frames that say what the game looks like. After any
# change that could touch the look, run it and read the one contact sheet.
#   tools/canon.sh            shoot tours/canon.tour, compare with the accepted set
#   tools/canon.sh --accept   make the frames just shot the accepted set
#   tools/canon.sh --web      the same eighteen places on the desktop and inside a real
#                             exported web build, side by side (docs/LOOK.md: "the same
#                             place, on a worse night")
# Frames: shots/canon/now/, accepted: shots/canon/accepted/, sheet: shots/canon/sheet.png
# --web: shots/degrade/desktop/ and shots/degrade/web/, the sheet shots/degrade/sheet.png,
# and each pair at the size a player sees it in shots/degrade/pairs/. The distance and
# the two lumas per place are printed; `CompatTrim` (src/render/degrade/) is fitted
# against the desktop frames this leaves (tours/degrade_fit.tour).
set -uo pipefail
cd "$(dirname "$0")/.."
# The canon is the one set of frames whose whole job is to be comparable with
# ITSELF, so it steps in simulated time and not in wall-clock time. Without this
# two runs at one commit differed by a mean of 1.69 and by as much as 5.99 on a
# single frame, against a tolerance of 3 -- not because anything had changed but
# because a loaded machine simulates a different amount of world before each
# shutter falls. tools/tour.sh says what the flag does and what it costs.
export TOUR_FIXED_FPS="${TOUR_FIXED_FPS:-60}"
if [ "${1:-}" = "--accept" ]; then
  test -d shots/canon/now || { echo "canon: nothing shot yet"; exit 1; }
  rm -rf shots/canon/accepted && cp -R shots/canon/now shots/canon/accepted
  echo "canon: accepted $(ls shots/canon/accepted | wc -l | tr -d ' ') frames"
  exit 0
fi
if [ "${1:-}" = "--web" ]; then
  seed="${CANON_SEED:-7}"
  rm -rf shots/tour/canon
  tools/tour.sh tours/canon.tour --seed="$seed" || exit 1
  mkdir -p shots/degrade && rm -rf shots/degrade/desktop && mv shots/tour/canon shots/degrade/desktop
  tools/web.sh --quick --tour=tours/canon.tour --args=--seed="$seed" || exit 1
  rm -rf shots/degrade/web shots/degrade/pairs && cp -R shots/export/tour/canon shots/degrade/web
  rm -f shots/degrade/web/console.log
  godot --headless --path . -s tools/gd/sheet.gd -- --prev=shots/degrade/desktop --now=shots/degrade/web \
    --out=shots/degrade/sheet.png --w=640 --label-prev="desktop  Forward+ high" --label-now="web  Compatibility" \
    --pairs=shots/degrade/pairs 2>&1 | grep -E '^sheet|ERROR'
  exit 0
fi
rm -rf shots/tour/canon shots/canon/now
tools/tour.sh tours/canon.tour --seed="${CANON_SEED:-7}" || exit 1
mkdir -p shots/canon && mv shots/tour/canon shots/canon/now
prev=""
[ -d shots/canon/accepted ] && prev="--prev=shots/canon/accepted"
godot --headless --path . -s tools/gd/sheet.gd -- --now=shots/canon/now $prev --out=shots/canon/sheet.png 2>&1 | grep -E '^sheet|ERROR'
