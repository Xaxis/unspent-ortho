#!/usr/bin/env bash
# Every generated sound as shots/audio/<key>.wav plus a spectrogram PNG to LOOK
# at, and the mix numbers (heard dB vs its window, energy under 120 Hz, loop seam).
#   tools/audio.sh                 # everything
#   tools/audio.sh machine_        # keys containing a substring
#   tools/audio.sh step_ --no-png  # numbers and wavs only
#   tools/audio.sh --mix --seed=1 --at=120,88 --hour=21 --weather=rain:0.8 --secs=20 --name=rain
#   tools/audio.sh --mix --seed=1 --at=100,120 --cross --name=border   # walk over a border
#   tools/audio.sh --mix --machine=harvester:24:2 --name=harvester     # a machine coming on
#                                  # what the player hears -> shots/audio/mix_<name>.wav/png
# Fails (non-zero) on any script error.
set -uo pipefail
cd "$(dirname "$0")/.."
tools/_import.sh
log="$(mktemp -t unspent-audio)"
godot --headless --path . -s tools/gd/audio_dump.gd -- "$@" >"$log" 2>&1
code=$?
if grep -qE 'SCRIPT ERROR|Parse Error|Compile Error' "$log"; then
  grep -E 'SCRIPT ERROR|ERROR|at: ' "$log" | head -20
  echo "audio FAILED: script error"
  rm -f "$log"; exit 1
fi
grep -vE '^(Godot Engine|$)' "$log"
rm -f "$log"
exit $code
