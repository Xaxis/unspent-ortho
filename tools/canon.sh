#!/usr/bin/env bash
# The canon: a fixed set of frames that say what the game looks like. After any
# change that could touch the look, run it and read the one contact sheet.
#   tools/canon.sh            shoot tours/canon.tour, compare with the accepted set
#   tools/canon.sh --accept   make the frames just shot the accepted set
# Frames: shots/canon/now/, accepted: shots/canon/accepted/, sheet: shots/canon/sheet.png
set -uo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" = "--accept" ]; then
  test -d shots/canon/now || { echo "canon: nothing shot yet"; exit 1; }
  rm -rf shots/canon/accepted && cp -R shots/canon/now shots/canon/accepted
  echo "canon: accepted $(ls shots/canon/accepted | wc -l | tr -d ' ') frames"
  exit 0
fi
rm -rf shots/tour/canon shots/canon/now
tools/tour.sh tours/canon.tour --seed="${CANON_SEED:-7}" || exit 1
mkdir -p shots/canon && mv shots/tour/canon shots/canon/now
prev=""
[ -d shots/canon/accepted ] && prev="--prev=shots/canon/accepted"
godot --headless --path . -s tools/gd/sheet.gd -- --now=shots/canon/now $prev --out=shots/canon/sheet.png 2>&1 | grep -E '^sheet|ERROR'
