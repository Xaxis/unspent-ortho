#!/usr/bin/env bash
# Every shader the game draws with, compiled and drawn by the real renderer
# (tools/gd/shaders.gd). Fails on any SHADER ERROR, script error or timeout.
# Usage: tools/heavy.sh tools/shaders.sh   (it draws, so it takes a heavy slot)
# Why: the gate's tests run on the dummy renderer, which compiles no shader, so
# an include that broke every sky_apply shader passed every gate (2026-10-01).
set -uo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
. tools/_focus.sh
. tools/_slack.sh
log="$(mktemp "${TMPDIR:-/tmp}/unspent-shaders.XXXXXX")"
focus_guard_start
holder="$(focus_holder)"
godot --path . --position "$(focus_position)" --audio-driver "$(focus_audio_driver)" $(focus_frame_flags) -s tools/gd/shaders.gd >"$log" 2>&1 &
pid=$!
focus_return "$holder" "$pid"
budget=$(slack_secs "${SHADERS_TIMEOUT:-300}")
deadline=$(( $(date +%s) + budget ))
status=0
while kill -0 "$pid" 2>/dev/null; do
  if [ "$(date +%s)" -ge "$deadline" ]; then kill "$pid" 2>/dev/null; status=2; break; fi
  sleep 0.2
done
wait "$pid" 2>/dev/null
if [ $status -eq 2 ]; then
  tail -20 "$log"; echo "shaders FAILED: timed out after ${budget}s"; rm -f "$log"; exit 1
fi
if grep -qE 'SHADER ERROR|SCRIPT ERROR|Parse Error|Compile Error' "$log"; then
  grep -E -A3 'SHADER ERROR|SCRIPT ERROR|Parse Error|Compile Error' "$log" | head -40
  echo "shaders FAILED: a shader does not compile"; rm -f "$log"; exit 1
fi
if ! grep -qE '^shaders: [0-9]+ built' "$log"; then
  tail -20 "$log"; echo "shaders FAILED: the run never drew"; rm -f "$log"; exit 1
fi
grep -E '^shaders: ' "$log"
rm -f "$log"
