#!/usr/bin/env bash
# Export the web build and prove it runs in a real browser (headless Chromium).
#   tools/web.sh                     threaded build: title, loading page, new game, resize, reload
#   tools/web.sh --nothreads         the same for the no-threads fallback build
#   tools/web.sh --no-export         use what is already in build/
#   tools/web.sh --quick             title only (no new game, no resize, no reload)
#   tools/web.sh --swiftshader       render on the CPU (no GPU on the host; very slow)
#   tools/web.sh --config=NAME       export from configs/NAME.json (tools/export.sh); a tool run in
#                                    it (a tour) still needs --args=--config=NAME to open dev mode
# Anything else goes to tools/web/web.mjs (e.g. --args=--seed=3, --after=6, --headed).
# Frames land in shots/export/ (web_*.png, web-nothreads_*.png). Prints load time
# to first frame and fails on console or page errors, a blank or non-integer-scaled
# canvas, lost focus, silent audio or a save IndexedDB did not keep.
set -uo pipefail
cd "$(dirname "$0")/.."
target=web
do_export=1
quick=0
config=()
pass=()
for a in "$@"; do
  case "$a" in
    --nothreads) target=web-nothreads ;;
    --no-export) do_export=0 ;;
    --quick) quick=1 ;;
    --config=*) config=("$a") ;;
    *) pass+=("$a") ;;
  esac
done
if [ ! -d tools/web/node_modules/playwright ]; then
  echo "== installing the browser harness (tools/web/node_modules)"
  npm install --prefix tools/web --no-audit --no-fund >/dev/null || { echo "web FAILED: npm install"; exit 1; }
  npx --prefix tools/web playwright install chromium-headless-shell >/dev/null 2>&1 || true
fi
if [ $do_export -eq 1 ]; then
  tools/export.sh "$target" ${config[@]+"${config[@]}"} || exit 1
fi
mkdir -p shots/export
flow=(--play --resize=1500x860 --reload)
[ $quick -eq 1 ] && flow=()
node tools/web/web.mjs --dir="build/$target" --out="shots/export/$target" ${flow[@]+"${flow[@]}"} ${pass[@]+"${pass[@]}"}
