#!/usr/bin/env bash
# Run a heavy job (a tour, shot, render, web export or browser run) only when the
# box can take it:
#   tools/heavy.sh tools/tour.sh tours/x.tour ...
# At most HEAVY_SLOTS (default 2) run box-wide. A slot opens when more than 32000
# pages (500 MB) are free on three readings 10 s apart and fewer than HEAVY_SLOTS
# godot processes are running. Why: with several builders running godot at once the
# box fell to ~57 MB free (2026-09-28) and the owner's own apps began failing writes;
# with one slot, one hour-long proof tour stalled every other job behind it.
# Only a godot binary counts as a running job, matched by process name: a waiter
# whose own command line mentions godot must not count itself. Other projects'
# browsers (soniq's playwright checks, Rider's cef) cycle all day; our own browser
# runs take a slot, and the memory floor covers everyone else's load.
# HEAVY_ALONE=1 waits for a quiet box (no godot at all) and takes every slot: for
# timings that other jobs would spoil (web A/B, perf).
# Gives up after HEAVY_WAIT seconds (default 10800) with exit 2.
set -u
slots=${HEAVY_SLOTS:-2}
end=$(( $(date +%s) + ${HEAVY_WAIT:-10800} ))
lock=""
free_pages() { vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}'; }
running() { pgrep -ix godot | wc -l | tr -d ' '; }
# Slot i is the directory /tmp/unspent-heavy.lock[.i]; a slot whose holder is gone
# (killed shell) is reclaimed.
take() {
  local i d holder
  for i in $(seq 0 $((slots - 1))); do
    d=/tmp/unspent-heavy.lock; [ "$i" = 0 ] || d="$d.$i"
    if mkdir "$d" 2>/dev/null; then echo $$ > "$d/pid"; lock=$d; return 0; fi
    holder=$(cat "$d/pid" 2>/dev/null || echo 0)
    if [ "$holder" -gt 0 ] 2>/dev/null && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$d"; mkdir "$d" 2>/dev/null && echo $$ > "$d/pid" && lock=$d && return 0
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
  pgrep -ix godot | while read -r p; do
    [ "$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')" = 1 ] || continue
    [ "$(ps -o etime= -p "$p" | awk -F'[-:]' '{print (NF>2)?1:0}')" = 1 ] || continue
    ps -o pid=,etime=,command= -p "$p" | cut -c1-140
  done
}
ok=0; n=0
while :; do
  if [ "$(date +%s)" -ge "$end" ]; then echo "heavy: never clear (pages $(free_pages), $(running) godot)" >&2; exit 2; fi
  n=$((n+1))
  if [ $((n % 30)) = 1 ]; then s=$(stale); [ -n "$s" ] && echo "heavy: an orphan godot up 1 h+ holds a slot (kill it if it is yours): $s" >&2; fi
  if [ "${HEAVY_ALONE:-0}" = 1 ]; then
    if [ "$(free_pages)" -gt 32000 ] && [ "$(running)" -eq 0 ]; then ok=$((ok+1)); else ok=0; fi
    if [ "$ok" -ge 3 ] && take_all; then break; fi
  else
    if [ "$(free_pages)" -gt 32000 ] && [ "$(running)" -lt "$slots" ]; then ok=$((ok+1)); else ok=0; fi
    if [ "$ok" -ge 3 ] && take; then break; fi
  fi
  sleep 10
done
trap 'rm -rf $lock' EXIT
echo "heavy: clear in $lock, $(free_pages) pages free at $(date +%T)" >&2
"$@"
