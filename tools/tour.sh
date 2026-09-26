#!/usr/bin/env bash
# Play a tour (src/systems/98_tour.gd) through the real game and save its frames.
#   tools/tour.sh tours/smoke.tour [BootOptions like --seed=3 --spawn=...]
# Given no BootOptions, it runs with the ones the tour's own header gives
# (`#   tools/tour.sh tours/<name>.tour --seed=...`, tools/_tour_args.sh); any
# given on the command line are used instead, all of them. Either way it says
# which it booted with.
# Frames land in shots/tour/<tour name>/. Fails on script errors, a bad tour
# line, or TOUR_TIMEOUT seconds (default 180).
# A FAILED run also keeps the whole godot log beside its frames, at
# shots/tour/<tour name>/run.log. A green run keeps nothing.
set -uo pipefail
cd "$(dirname "$0")/.."
tour="$1"; shift
. tools/_tour_args.sh
if [ $# -eq 0 ]; then
  while IFS= read -r opt; do
    [ -n "$opt" ] && set -- "$@" "$opt"
  done < <(tour_header_args "$tour")
  echo "tour options: ${*:-(none)} (from its header)"
else
  echo "tour options: $* (from the command line)"
fi
# One run of a tour at a time per checkout. shots/tour/<name>/ is a single
# directory: two runs overwrite each other's frames and both come out worthless
# with a green exit, which is the worst failure this project has, because the
# frames are the evidence. Fail loud rather than queue — a second run means two
# agents believe they own the same proof, and that is worth stopping to look at.
# cksum, not md5: md5 is BSD-only and md5sum is GNU-only, and CI is Linux.
name="$(basename "$tour" .tour)"
lock="${TMPDIR:-/tmp}/unspent-tour-$name-$(printf '%s' "$PWD" | cksum | cut -d' ' -f1).lock"
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
# TOUR_FIXED_FPS makes a run step in SIMULATED time instead of wall-clock time.
#
# A tour's `wait` is a real-time timer (create_timer) while the game simulates in
# _physics_process, so how much WORLD happens before the shutter falls depends on
# how busy the machine is: villagers walk on, the sea's waves move, a hint fires
# or does not. Two canon runs at ONE commit came out 4.00 and 5.99 apart on their
# night frames (mean 1.69 over eighteen, against a sheet tolerance of 3) purely
# from that. `--fixed-fps` hands every frame the same delta whatever the frame
# really cost, so `wait 0.4` is the same 24 ticks of world on a quiet machine and
# on a loaded one. Measured across runs at load 31 and load 40: those two frames
# came down to 0.13 and 0.47 and the mean to 0.63.
#
# It is OPT-IN, and deliberately so. A tour that proves something about timing --
# a fight, a raid arriving, anything measured in seconds a player would feel --
# should keep running against the real clock, and a tour that merely has to be
# comparable with ITSELF should not. tools/canon.sh turns it on.
godot --path . --position "$(focus_position)" --audio-driver "$(focus_audio_driver)" \
  ${TOUR_FIXED_FPS:+--fixed-fps "$TOUR_FIXED_FPS"} -- --tour="$tour" "$@" >"$log" 2>&1 &
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
# The WHOLE log, kept on failure and only on failure, beside the frames the run
# did manage to save. Everything printed below this samples the log: the grep
# takes matching lines, the tail takes the last twelve, and the middle — which is
# exactly where a crash puts its C++ backtrace — used to go in the bin with the
# mktemp file. One abort in this repo was diagnosed no further than "a worker
# died somewhere inside the sketch bake" because frames 0 to 17 of its backtrace
# were in that gap, and nobody could get it to happen again. A log is cheap; a
# crash you cannot reproduce and have no stack for costs days.
keep_log() {
  mkdir -p "shots/tour/$name"
  if mv "$log" "shots/tour/$name/run.log" 2>/dev/null; then
    echo "tour log kept: shots/tour/$name/run.log"
  fi
}
# EVERY matching line. `head -60` used to sit here and dropped the rest in
# silence -- including the `pixels:` counts the runner prints, which is the whole
# reason four measured claim floors could not be checked from a tour's own output
# and one of them stood 246 times under what its frame really holds. CLAUDE.md's
# rule is that a run is never piped through head or tail in a way that hides what
# it said, and this was the tool itself breaking it, in the same file and the
# same week as the backtrace that fell down the gap between a grep and a tail.
# If the summary is ever long enough to cut, the log is KEPT even on a pass:
# a sample nobody can go back to is the same bug in a smaller box.
summary=$(grep -E '^tour|SCRIPT ERROR|ERROR|at: ' "$log" | grep -v '^tour t=')
printf '%s\n' "$summary" | head -400
cut_summary=0
if [ "$(printf '%s\n' "$summary" | wc -l | tr -d ' ')" -gt 400 ]; then
  cut_summary=1
  echo "tour summary cut at 400 lines; the whole log is kept below"
fi
grep -E 'done ->' "$log" | tail -1
# A tour that stopped early can still leave a zero exit (a quit racing a frame):
# the run only counts when the tour says it reached its end.
if ! grep -qE '^tour .* done ->' "$log"; then
  tail -12 "$log"; keep_log; echo "tour FAILED: never reached its end ($tour)"; exit 1
fi
if [ $status -ne 0 ] || [ $code -ne 0 ]; then keep_log; echo "tour FAILED (status $status, exit $code)"; exit 1; fi
# A PASS whose summary was cut keeps its log too. This is the half that actually
# bit: the run was green, the counts past line 60 were never printed, and the log
# holding them was deleted on the next line -- so the evidence existed, was
# thrown away, and the tour reported success.
if [ "$cut_summary" -eq 1 ]; then keep_log; else rm -f "$log"; fi
