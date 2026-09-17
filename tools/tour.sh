#!/usr/bin/env bash
# Play a tour (src/systems/98_tour.gd) through the real game and save its frames.
#   tools/tour.sh tours/smoke.tour [BootOptions like --seed=3 --spawn=...]
# Frames land in shots/tour/<tour name>/. Fails on script errors, a bad tour
# line, or TOUR_TIMEOUT seconds (default 180).
set -uo pipefail
cd "$(dirname "$0")/.."
tour="$1"; shift
# One run of a tour at a time per checkout. shots/tour/<name>/ is a single
# directory: two runs overwrite each other's frames and both come out worthless
# with a green exit, which is the worst failure this project has, because the
# frames are the evidence. Fail loud rather than queue — a second run means two
# agents believe they own the same proof, and that is worth stopping to look at.
# cksum, not md5: md5 is BSD-only and md5sum is GNU-only, and CI is Linux.
lock="${TMPDIR:-/tmp}/unspent-tour-$(basename "$tour" .tour)-$(printf '%s' "$PWD" | cksum | cut -d' ' -f1).lock"
if [ -e "$lock" ] && kill -0 "$(cat "$lock" 2>/dev/null)" 2>/dev/null; then
  echo "tour FAILED: $(basename "$tour") is already running here (pid $(cat "$lock")); its frames would be overwritten"
  exit 3
fi
printf '%s' $$ > "$lock"
trap 'rm -f "$lock"' EXIT
tools/_import.sh
. tools/_focus.sh
. tools/_slack.sh
log="$(mktemp "${TMPDIR:-/tmp}/unspent-tour.XXXXXX")"
focus_guard_start
holder="$(focus_holder)"
godot --path . --position "$(focus_position)" --audio-driver "$(focus_audio_driver)" -- --tour="$tour" "$@" >"$log" 2>&1 &
pid=$!
focus_return "$holder" "$pid"
deadline=$(( $(date +%s) + $(slack_secs "${TOUR_TIMEOUT:-180}") ))
status=0
while kill -0 "$pid" 2>/dev/null; do
  if grep -qE 'SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error' "$log"; then sleep 0.3; kill "$pid" 2>/dev/null; status=1; break; fi
  if [ "$(date +%s)" -ge "$deadline" ]; then kill "$pid" 2>/dev/null; status=2; break; fi
  sleep 0.2
done
wait "$pid"; code=$?
grep -E '^tour|SCRIPT ERROR|ERROR|at: ' "$log" | grep -v '^tour t=' | head -60
grep -E 'done ->' "$log" | tail -1
# A tour that stopped early can still leave a zero exit (a quit racing a frame):
# the run only counts when the tour says it reached its end.
if ! grep -qE '^tour .* done ->' "$log"; then
  tail -12 "$log"; rm -f "$log"; echo "tour FAILED: never reached its end ($tour)"; exit 1
fi
rm -f "$log"
if [ $status -ne 0 ] || [ $code -ne 0 ]; then echo "tour FAILED (status $status, exit $code)"; exit 1; fi
