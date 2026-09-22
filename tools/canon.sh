#!/usr/bin/env bash
# The canon: a fixed set of frames that say what the game looks like. After any
# change that could touch the look, run it and read the one contact sheet.
#   tools/canon.sh            shoot tours/canon.tour, compare with the accepted set
#   tools/canon.sh --accept   make the frames just shot the accepted set
#   tools/canon.sh --web      the same eighteen places on the desktop and inside a real
#                             exported web build, side by side (docs/LOOK.md: "the same
#                             place, on a worse night")
# Frames: shots/canon/now/, accepted: shots/canon/accepted/, sheet: shots/canon/sheet.png
#
# THE BASELINE STATES HOW OLD IT IS. `shots/` is gitignored, so the accepted
# frames are a folder in ONE checkout: an accept used to change nothing anybody
# else could see, and the baseline sat 531 commits stale with nothing saying so.
# Now `--accept` writes tests/canon/accepted.txt (tracked): the commit the frames
# were shot at, when, and a sha256 per frame -- commit it, and the accept is a
# commit anyone can see. Every run then prints the baseline's commit and how many
# commits ago it was, and checks this checkout's accepted/ against the record, so
# another worktree's stale or missing copy says so instead of being compared
# against quietly. The images are not versioned: that is a size and history cost
# the owner has not chosen, and a versioned baseline four days old is still four
# days old -- what was missing was the telling.
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
RECORD=tests/canon/accepted.txt
# What this checkout holds, one "sha256  name" line per accepted frame.
hashes() { (cd "$1" && shasum -a 256 *.png) 2>/dev/null; }
if [ "${1:-}" = "--accept" ]; then
  test -d shots/canon/now || { echo "canon: nothing shot yet"; exit 1; }
  rm -rf shots/canon/accepted && cp -R shots/canon/now shots/canon/accepted
  # A record cannot name the commit that holds it, so it names the commit the
  # frames were SHOT at, and says when the tree held more than that commit did --
  # a baseline from uncommitted code is one nobody else can reproduce.
  dirty=""
  [ -n "$(git status --porcelain -- src tours tests configs project.godot 2>/dev/null)" ] && dirty=" (plus uncommitted changes -- commit the code before accepting)"
  mkdir -p "$(dirname "$RECORD")"
  { echo "# The canon's accepted set. shots/canon/accepted/ is gitignored, so this is the"
    echo "# record of what was accepted and when. Written by tools/canon.sh --accept."
    echo "commit $(git rev-parse --short HEAD)$dirty"
    echo "date $(date -u '+%Y-%m-%dT%H:%MZ')"
    hashes shots/canon/accepted; } > "$RECORD"
  echo "canon: accepted $(ls shots/canon/accepted | wc -l | tr -d ' ') frames at $(git rev-parse --short HEAD)$dirty"
  echo "canon: now commit $RECORD, or nobody else can see this accept"
  exit 0
fi
# Every run says what it is comparing against, before comparing.
baseline() {
  if [ ! -f "$RECORD" ]; then
    echo "canon: NO RECORD of an accepted set ($RECORD) -- the baseline's age is unknown"
    return
  fi
  local sha when n bad total
  sha=$(awk '$1=="commit"{print $2; exit}' "$RECORD")
  when=$(awk '$1=="date"{print $2; exit}' "$RECORD")
  n=$(git rev-list --count "$sha..HEAD" 2>/dev/null || echo "?")
  echo "canon: baseline accepted at $sha ($when), $n commits ago"
  total=$(grep -cE '^[0-9a-f]{64}  ' "$RECORD")
  if [ ! -d shots/canon/accepted ]; then
    echo "canon: this checkout has NO shots/canon/accepted/ -- there is nothing here to compare against"
    return
  fi
  bad=$(diff <(grep -E '^[0-9a-f]{64}  ' "$RECORD" | sort) <(hashes shots/canon/accepted | sort) | grep -c '^>' || true)
  if [ "$bad" != "0" ]; then
    echo "canon: YOUR shots/canon/accepted/ IS NOT THE ACCEPTED SET -- $bad of its frames differ from $RECORD ($total recorded)"
  fi
}
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
baseline
rm -rf shots/tour/canon shots/canon/now
tools/tour.sh tours/canon.tour --seed="${CANON_SEED:-7}" || exit 1
mkdir -p shots/canon && mv shots/tour/canon shots/canon/now
prev=""
[ -d shots/canon/accepted ] && prev="--prev=shots/canon/accepted"
godot --headless --path . -s tools/gd/sheet.gd -- --now=shots/canon/now $prev --out=shots/canon/sheet.png 2>&1 | grep -E '^sheet|ERROR'
