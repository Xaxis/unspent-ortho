#!/usr/bin/env bash
# One real rendered frame of the game. Usage:
#   tools/shot.sh shots/name.png [--seed=3 --at=120,88 --hour=21 --walk=1,0,2 ...]
# Options are BootOptions (src/boot_options.gd). Fails fast (non-zero) on any
# script error, or if no PNG appears within SHOT_TIMEOUT seconds (default 60).
set -uo pipefail
cd "$(dirname "$0")/.."
out="$1"; shift
rm -f "$out"
tools/_import.sh
. tools/_focus.sh
. tools/_slack.sh
log="$(mktemp "${TMPDIR:-/tmp}/unspent-shot.XXXXXX")"
focus_guard_start
holder="$(focus_holder)"
godot --path . --position "$(focus_position)" --audio-driver "$(focus_audio_driver)" -- --shot="$out" "$@" >"$log" 2>&1 &
pid=$!
focus_return "$holder" "$pid"
deadline=$(( $(date +%s) + $(slack_secs "${SHOT_TIMEOUT:-60}") ))
status=0
while kill -0 "$pid" 2>/dev/null; do
  if grep -qE 'SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error' "$log"; then
    sleep 0.3; kill "$pid" 2>/dev/null; status=1; break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then kill "$pid" 2>/dev/null; status=2; break; fi
  sleep 0.1
done
wait "$pid" 2>/dev/null
if [ $status -eq 1 ]; then
  grep -E 'SCRIPT ERROR|ERROR|at: ' "$log" | head -30; echo "shot FAILED: script error ($out)"; rm -f "$log"; exit 1
fi
# `gallery` too: --piece prints the numbered pieces of a model and says which one
# the frame is aimed at, and a list nobody sees is a list nobody can pick from.
grep -E '^(world|shot|gallery) ' "$log"
if [ ! -f "$out" ]; then tail -20 "$log"; echo "shot FAILED: no image ($out)"; rm -f "$log"; exit 1; fi
rm -f "$log"
