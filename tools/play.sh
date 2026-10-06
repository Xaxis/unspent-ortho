#!/usr/bin/env bash
# Play the game from this checkout, straight into a named moment.
#   tools/play.sh              the title, as a player gets it
#   tools/play.sh coast        a new game on island 1 at 11:00
#   tools/play.sh reaper       island 1, the steel knife in hand, for the Tide Reaper
#   tools/play.sh holdfast     the start of slice 2: slice 1 lived, pick and knife in hand
#   tools/play.sh across       the start of slice 3: Vera's lead to the archive, raft makings and food in hand
#   tools/play.sh gallery      every model and prop laid out to look at
#   tools/play.sh list         these presets and the options each passes
# A game booted with options skips the title and raises the whole world first, which
# takes about 40 s on this laptop before the first frame of play; the terminal prints
# "boot ready game" when it is up. Any further words are passed to the game as more
# options (src/boot_options.gd header), e.g. `tools/play.sh reaper --hour=17`.
set -eu
cd "$(dirname "$0")/.."
preset="${1:-title}"
[ $# -gt 0 ] && shift
case "$preset" in
  title)    opts=() ;;
  coast)    opts=(--seed=1 --hour=11) ;;
  reaper)   opts=(--seed=1 --hour=11 --held=knife_shear) ;;
  holdfast) opts=(--seed=1 --hour=9 --beats=body_new,holdfast_fight,marens_lead,reaper_named,reaper_down --held=knife_shear --give=pick:1) ;;
  across)   opts=(--seed=1 --hour=9 --beats=marens_lead,reaper_named,reaper_down,built_halcyon,holdfast_hope,war_archive --chose=rook.iron=paid --give=pick:1,kit_plate:1,driftwood:6,scrap:3,rag:2,tide_iron:1,stew:4,bread:4 --holding=lean-to) ;;
  gallery)  opts=(--scene=gallery) ;;
  list)     sed -n '3,9p' "$0"; exit 0 ;;
  *)        echo "play: no preset '$preset' (tools/play.sh list)" >&2; exit 2 ;;
esac
tools/_import.sh >/dev/null 2>&1 || true
# (bash 3.2 on macOS: an empty array under set -u is "unbound", so test first.)
if [ ${#opts[@]} -eq 0 ]; then
  [ $# -eq 0 ] && exec godot --path .
  exec godot --path . -- "$@"
fi
exec godot --path . -- "${opts[@]}" "$@"
