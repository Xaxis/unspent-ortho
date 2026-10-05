#!/usr/bin/env bash
# Run a heavy job (a tour, shot, render, web export or browser run) only when the
# box can take it:
#   tools/heavy.sh tools/tour.sh tours/x.tour ...
# At most HEAVY_SLOTS run box-wide (default one per six cores, at least 2: two on
# the 14-core laptop, four on the 24-core Linux box). A slot opens when more than
# 500 MB is free on three readings 10 s apart and fewer than HEAVY_SLOTS of this
# game's godot processes are running. Why: with several builders running godot at once the
# box fell to ~57 MB free (2026-09-28) and the owner's own apps began failing writes;
# with one slot, one hour-long proof tour stalled every other job behind it.
# Only a godot binary counts as a running job, matched by process name: a waiter
# whose own command line mentions godot must not count itself. Other projects'
# browsers (soniq's playwright checks, Rider's cef) cycle all day; our own browser
# runs take a slot, and the memory floor covers everyone else's load.
# HEAVY_ALONE=1 waits for a quiet box (no godot at all) and takes every slot: for
# timings that other jobs would spoil (web A/B, perf).
# Gives up after HEAVY_WAIT seconds (default 10800) with exit 2; a HEAVY_ALONE claim
# after HEAVY_ALONE_WAIT (default 600) with exit 3.
set -u
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 12)
slots=${HEAVY_SLOTS:-$(( cores / 6 > 2 ? cores / 6 : 2 ))}
end=$(( $(date +%s) + ${HEAVY_WAIT:-10800} ))
lock=""
# Free memory in MB: what Linux can hand out without swapping, or macOS's free pages.
free_mb() {
  if [ -r /proc/meminfo ]; then awk '/^MemAvailable:/ {print int($2 / 1024)}' /proc/meminfo
  else vm_stat | awk '/page size of/ {ps = $8} /Pages free/ {gsub("\\.", "", $3); print int($3 * ps / 1048576)}'; fi
}
# The working directory of a process, on Linux and on macOS.
cwd_of() {
  if [ -e "/proc/$1/cwd" ]; then readlink "/proc/$1/cwd" 2>/dev/null
  else lsof -a -d cwd -p "$1" -Fn 2>/dev/null | sed -n 's/^n//p'; fi
}
# Ours: a godot whose working directory is a checkout of this game (every tool
# runs it with --path . from the tree's root). Another project's editor and
# imports (Reelwright's cycled all day, 2026-09-30) held six of our jobs 40 min
# with no slot taken; their memory is the floor's business, not a slot's.
ours() {
  pgrep -ix godot | while read -r p; do
    c=$(cwd_of "$p")
    [ -n "$c" ] && [ -f "$c/tools/heavy.sh" ] && [ -f "$c/src/main.tscn" ] && echo "$p"
  done
}
running() { ours | wc -l | tr -d ' '; }
# Slot i is the directory /tmp/unspent-heavy.lock[.i]; a slot whose holder is gone
# (killed shell) is reclaimed.
reserve=/tmp/unspent-heavy.reserve
reserved_by_other() {
  local holder; holder=$(cat "$reserve" 2>/dev/null || echo 0)
  [ "$holder" -gt 0 ] 2>/dev/null || return 1
  [ "$holder" = $$ ] && return 1
  kill -0 "$holder" 2>/dev/null && return 0
  rm -f "$reserve"; return 1
}
# One tree may hold at most HEAVY_PER_TREE slots (default half of them), so one
# builder's batch of probes can't queue every other builder behind it: on
# 2026-09-30 one worktree held three of four slots for half an hour, twice, after
# being asked to hold two. A tree is the checkout a job was started from.
per_tree=${HEAVY_PER_TREE:-$(( slots / 2 > 1 ? slots / 2 : 1 ))}
tree=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
held_by_tree() {
  local d holder n=0
  for d in /tmp/unspent-heavy.lock /tmp/unspent-heavy.lock.*; do
    [ -f "$d/tree" ] || continue
    holder=$(cat "$d/pid" 2>/dev/null || echo 0)
    kill -0 "$holder" 2>/dev/null || continue
    [ "$(cat "$d/tree")" = "$tree" ] && n=$((n + 1))
  done
  echo "$n"
}
# Waiters take a ticket and are served first come, first served. Without it a
# slot went to whichever waiter happened to look the moment it freed: on
# 2026-09-30 one tour waited an hour at load 57 while later jobs kept winning.
# A waiter whose tree already holds its share does not hold up those behind it.
queue=/tmp/unspent-heavy.queue
ticket=""
ahead() {
  local f pid t n=0
  for f in $(ls "$queue" 2>/dev/null | sort); do
    [ "$queue/$f" = "$ticket" ] && break
    pid=${f##*-}
    if ! kill -0 "$pid" 2>/dev/null; then rm -f "$queue/$f"; continue; fi
    t=$(cat "$queue/$f" 2>/dev/null)
    [ "$(tree="$t" held_by_tree)" -ge "$per_tree" ] && continue
    n=$((n + 1))
  done
  echo "$n"
}
take() {
  local i d holder
  reserved_by_other && return 1
  [ "$(held_by_tree)" -ge "$per_tree" ] && return 1
  for i in $(seq 0 $((slots - 1))); do
    d=/tmp/unspent-heavy.lock; [ "$i" = 0 ] || d="$d.$i"
    if mkdir "$d" 2>/dev/null; then echo $$ > "$d/pid"; echo "$tree" > "$d/tree"; lock=$d; return 0; fi
    holder=$(cat "$d/pid" 2>/dev/null || echo 0)
    if [ "$holder" -gt 0 ] 2>/dev/null && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$d"; mkdir "$d" 2>/dev/null && echo $$ > "$d/pid" && echo "$tree" > "$d/tree" && lock=$d && return 0
    fi
  done
  return 1
}
# HEAVY_ALONE=1: a measurement that needs a quiet box (web timings, A/B runs) takes
# every slot and waits until no godot at all is running, so nothing starts beside it.
take_all() {
  local i d holder got=""
  for i in $(seq 0 $((slots - 1))); do
    d=/tmp/unspent-heavy.lock; [ "$i" = 0 ] || d="$d.$i"
    holder=$(cat "$d/pid" 2>/dev/null || echo 0)
    if [ -d "$d" ] && [ "$holder" -gt 0 ] 2>/dev/null && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$d"; fi
    if mkdir "$d" 2>/dev/null; then echo $$ > "$d/pid"; got="$got $d"; else
      [ -n "$got" ] && rm -rf $got; return 1; fi
  done
  lock=$got; return 0
}
# A godot up an hour or more with no parent (a probe that errored and never quit)
# holds a slot for ever; name it so its owner kills it rather than waits on it.
stale() {
  ours | while read -r p; do
    [ "$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')" = 1 ] || continue
    [ "$(ps -o etime= -p "$p" | awk -F'[-:]' '{print (NF>2)?1:0}')" = 1 ] || continue
    ps -o pid=,etime=,command= -p "$p" | cut -c1-140
  done
}
ok=0; n=0
if [ "${HEAVY_ALONE:-0}" != 1 ]; then
  mkdir -p "$queue"; ticket="$queue/$(date +%s%N)-$$"; echo "$tree" > "$ticket"
fi
trap 'rm -f "$ticket"' EXIT
# A HEAVY_ALONE job claims the box while it waits, so ordinary jobs stop starting and
# the running ones drain; without it, a steady stream of short jobs starves it.
# A claim is held at most HEAVY_ALONE_WAIT seconds (default 600). Waiting for a quiet
# box stops every other job from starting, so a long wait wastes the whole box: on
# 2026-09-30 a timing run held it 33 minutes, at load 11, behind one long suite.
# Past the limit it lets go and exits 3; a timing run then waits for a quiet window.
alone_end=$(( $(date +%s) + ${HEAVY_ALONE_WAIT:-600} ))
if [ "${HEAVY_ALONE:-0}" = 1 ]; then
  if ! reserved_by_other; then echo $$ > "$reserve"; fi
fi
while :; do
  if [ "$(date +%s)" -ge "$end" ]; then echo "heavy: never clear ($(free_mb) MB free, $(running) godot)" >&2; exit 2; fi
  n=$((n+1))
  if [ $((n % 30)) = 1 ]; then s=$(stale); [ -n "$s" ] && echo "heavy: an orphan godot up 1 h+ holds a slot (kill it if it is yours): $s" >&2; fi
  if [ "${HEAVY_ALONE:-0}" = 1 ]; then
    if [ "$(date +%s)" -ge "$alone_end" ]; then
      [ "$(cat "$reserve" 2>/dev/null)" = $$ ] && rm -f "$reserve"
      echo "heavy: the box was not quiet within ${HEAVY_ALONE_WAIT:-600} s ($(running) godot); run this timing in a quiet window" >&2
      exit 3
    fi
    if [ "$(free_mb)" -gt 500 ] && [ "$(running)" -eq 0 ]; then ok=$((ok+1)); else ok=0; fi
    if [ "$ok" -ge 3 ] && take_all; then break; fi
  else
    r=$(running)
    if [ "$(free_mb)" -gt 500 ] && [ "$r" -lt "$slots" ] && [ "$(ahead)" -lt $((slots - r)) ]; then ok=$((ok+1)); else ok=0; fi
    if [ "$ok" -ge 3 ] && take; then break; fi
  fi
  sleep 10
done
rm -f "$ticket"
trap 'rm -rf $lock; [ "$(cat "$reserve" 2>/dev/null)" = $$ ] && rm -f "$reserve"' EXIT
echo "heavy: clear in $lock, $(free_mb) MB free at $(date +%T)" >&2
# The job and everything it starts run in this slot: a serial tool whose own
# heavy step comes after its other work (preflight's shaders) reads this and takes
# the slot it is already in, instead of holding it idle while it waits for another.
export HEAVY_HELD="$lock"
"$@"
