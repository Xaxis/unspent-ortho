#!/usr/bin/env bash
# Run one heavy job (a tour, shot, render, web export or browser run) only when the
# box can take it, one at a time box-wide:
#   tools/heavy.sh tools/tour.sh tours/x.tour ...
# Waits until more than 32000 pages (500 MB) are free on three readings 10 s apart,
# no other godot is running, and it holds the box lock. Why:
# with several builders running godot at once the box fell to ~57 MB free
# (2026-09-28) and the owner's own apps began failing writes.
# Only godot counts as busy: other projects' browsers (soniq's playwright checks,
# Rider's cef) cycle all day and would hold the gate for ever. Our own browser runs
# take the lock, and the memory floor covers everyone else's load.
# Gives up after HEAVY_WAIT seconds (default 10800) with exit 2.
set -u
lock=/tmp/unspent-heavy.lock
end=$(( $(date +%s) + ${HEAVY_WAIT:-10800} ))
free_pages() { vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}'; }
busy() { pgrep -f 'godot' >/dev/null; }
take() {
  if mkdir "$lock" 2>/dev/null; then echo $$ > "$lock/pid"; return 0; fi
  # A lock whose holder is gone (killed shell) is reclaimed.
  local holder; holder=$(cat "$lock/pid" 2>/dev/null || echo 0)
  if [ "$holder" -gt 0 ] 2>/dev/null && ! kill -0 "$holder" 2>/dev/null; then
    rm -rf "$lock"; mkdir "$lock" 2>/dev/null && echo $$ > "$lock/pid" && return 0
  fi
  return 1
}
# A godot up an hour or more with no parent (a probe that errored and never quit) holds
# every waiter for ever; name it so its owner kills it rather than waits on it.
stale() {
  pgrep -f 'godot' | while read -r p; do
    [ "$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')" = 1 ] || continue
    [ "$(ps -o etime= -p "$p" | awk -F'[-:]' '{print (NF>2)?1:0}')" = 1 ] || continue
    ps -o pid=,etime=,command= -p "$p" | cut -c1-140
  done
}
ok=0; n=0
while :; do
  if [ "$(date +%s)" -ge "$end" ]; then echo "heavy: never clear (pages $(free_pages))" >&2; exit 2; fi
  n=$((n+1))
  if [ $((n % 30)) = 1 ] && busy; then s=$(stale); [ -n "$s" ] && echo "heavy: waiting on an orphan idle 1 h+ (kill it if it is yours): $s" >&2; fi
  if [ "$(free_pages)" -gt 32000 ] && ! busy; then ok=$((ok+1)); else ok=0; fi
  if [ "$ok" -ge 3 ] && take; then break; fi
  sleep 10
done
trap 'rm -rf "$lock"' EXIT
echo "heavy: clear, $(free_pages) pages free at $(date +%T)" >&2
"$@"
