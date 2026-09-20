#!/usr/bin/env bash
# The whole gate. Run before every commit. Target: about 30 seconds.
#   1. every script and shader loads; every test passes (headless)
#   2. canonical screenshots render with no script errors (real GPU frames)
# Shots land in shots/check/ — LOOK at the ones your change affects.
#   tools/check.sh --web   also export both web builds and boot them in a browser (tools/web.sh, ~2 min)
set -uo pipefail
web=0
for a in "$@"; do [ "$a" = "--web" ] && web=1; done
cd "$(dirname "$0")/.."

# A MACHINE-WIDE limit on how many gates run at once, because the gate measures
# time and time is the one thing a busy machine takes away.
#
# Measured, with seven builders working: load average 80 on 14 cores, 13 godot
# processes. CLAUDE.md already says past ~20 nobody goes faster and the
# clock-watching tests start lying -- but nothing stopped seven worktrees from
# gating simultaneously, so every one of those runs was measuring the others.
# A gate that is wrong is worse than a gate that is late: a red one gets re-run
# until it is green, which is how a real regression ships.
#
# This WAITS rather than refusing, which is the opposite of tools/tour.sh's lock
# and deliberately so. Two tour runs in one checkout overwrite each other's
# frames, so the second must die; two gates do not corrupt each other's output
# at all, they only corrupt each other's timings. Refusing would throw away work
# somebody legitimately needs done. Waiting just puts it in a queue.
#
# The slots live in TMPDIR and are keyed to the MACHINE, not the checkout --
# every worktree holds its own copy of this script, and limiting each copy
# separately would limit nothing. `mkdir` is the lock because it is atomic on
# every POSIX filesystem; the pid inside lets a slot whose holder was killed be
# reclaimed instead of wedging the queue forever.
#
# Two slots by default: a gate is three test shards plus four shot processes,
# about seven, against fourteen cores here. UNSPENT_GATE_SLOTS overrides it, and
# 0 disables the queue entirely for anyone who wants the old behaviour.
gate_slot=""
gate_slots="${UNSPENT_GATE_SLOTS:-2}"
# `rm -r`, not `rmdir`: the slot holds a pid file, so rmdir fails on a non-empty
# directory and the slot is never given back. Caught by a test that ran two gates
# through one slot and found it still held afterwards -- left as it was, every
# slot would have leaked on first use and the queue wedged for good.
release_slot() { [ -n "$gate_slot" ] && rm -rf "$gate_slot" 2>/dev/null; }
if [ "$gate_slots" -gt 0 ]; then
  trap release_slot EXIT INT TERM
  waited=0
  while [ -z "$gate_slot" ]; do
    freed=0
    for s in $(seq 1 "$gate_slots"); do
      d="${TMPDIR:-/tmp}/unspent-gate-$s.lock"
      if mkdir "$d" 2>/dev/null; then
        echo $$ > "$d/pid"; gate_slot="$d"; break
      fi
      # Reclaim a slot whose holder is gone (killed run, crashed shell).
      holder="$(cat "$d/pid" 2>/dev/null || echo 0)"
      if [ "$holder" -gt 0 ] 2>/dev/null && ! kill -0 "$holder" 2>/dev/null; then
        rm -rf "$d" 2>/dev/null; freed=1
      fi
    done
    [ -n "$gate_slot" ] && break
    # A slot we just reclaimed is free NOW, so take it rather than serving a
    # ten-second sentence for somebody else's crashed run.
    [ "$freed" -eq 1 ] && continue
    # A gate that never runs is worse than one that runs noisy, so give up
    # waiting eventually and say loudly that the numbers are suspect.
    if [ "$waited" -ge 1800 ]; then
      echo "== gate queue: waited 30 min for a slot, running anyway -- TIMINGS ARE SUSPECT"
      break
    fi
    [ "$waited" -eq 0 ] && echo "== gate queue: $gate_slots slots busy, waiting (load $(sysctl -n vm.loadavg 2>/dev/null || uptime))"
    sleep 10; waited=$((waited + 10))
  done
fi
t0=$(date +%s)
tools/_import.sh
fail=0

# EVERY TRACKED SCRIPT CARRIES ITS TRACKED `.uid`, and this is checked first
# because it costs nothing and fails silently everywhere else.
#
# Godot mints a `.uid` beside each script on import and resolves `class_name` and
# `preload` through it. If the script is committed and the uid is not, a FRESH
# CLONE mints its own — different ids than the tree that made them — and the two
# trees disagree about identity in a way no test here can see, because on this
# machine the file is present and untracked and everything works.
#
# Found 2026-09-20 by counting `git ls-files` .gd against .uid after eight cast
# scripts went in without theirs; caught by hand, not by anything failing. A
# thing found by luck once is worth two lines so it cannot be found by luck
# twice.
missing="$(comm -23 <(git ls-files '*.gd' | sed 's/$/.uid/' | sort) <(git ls-files '*.gd.uid' | sort))"
if [ -n "$missing" ]; then
  echo "TRACKED SCRIPTS WITH NO TRACKED .uid -- git add them:"
  echo "$missing" | sed 's/\.uid$//; s/^/  /'
  fail=1
fi

# THE TWO HALVES RUN ONE AFTER THE OTHER, AND THEY USED TO RUN "SIDE BY SIDE".
#
# Three headless shards and four WINDOWED shots launched together is seven Godot
# processes, four of them holding a Metal context, and on this machine every one
# of the shots then printed its banner and produced NOTHING for its whole
# deadline -- no `world N gen`, no error, no script error -- leaving
# `shots/check/` empty. Measured twice, 2026-09-20, on a quiet machine and a busy
# one, at two different commits. The same four shots run concurrently with each
# other but WITHOUT the shards all pass and write their frames.
#
# So the gate was exiting 1 with a test half that read "no change against the
# standing set", and the picture half -- the half that exists because a green
# test says nothing about how the game looks -- had not been judged at all.
# Nobody was told the frames were missing; the directory was just empty.
#
# The shots go FIRST because they are the cheap half (about a minute against the
# shards' nine) and because a broken frame is worth knowing about before you wait
# out the suite. Total cost of the change is roughly that minute.
echo "== shots"
mkdir -p shots/check
pids=()
tools/shot.sh shots/check/spawn.png --seed=1 & pids+=($!)
tools/shot.sh shots/check/dusk.png --seed=2 --hour=19.5 --walk=1,-1,1.5 & pids+=($!)
tools/shot.sh shots/check/night.png --seed=3 --hour=23 & pids+=($!)
tools/shot.sh shots/check/gallery.png --scene=gallery & pids+=($!)
for p in "${pids[@]}"; do wait "$p" || fail=1; done
# An absent frame is not a silent pass: the loop above sets `fail`, but say it
# in words too, because an empty directory reads like a gate that had nothing to
# look at rather than one that could not look.
for f in spawn dusk night gallery; do
  [ -f "shots/check/$f.png" ] || { echo "MISSING FRAME: shots/check/$f.png was never written"; fail=1; }
done

echo "== tests (3 shards)"
logs=()
tpids=()
for i in 0 1 2; do
  log="$(mktemp "${TMPDIR:-/tmp}/unspent-test.XXXXXX")"; logs+=("$log")
  godot --headless --path . -s tests/run.gd -- "--shard=$i/3" >"$log" 2>&1 & tpids+=($!)
done
# The shards' own failures, gathered before they are judged, so the run can be
# compared against what this tree is KNOWN to carry (tests/standing.txt).
ran="$(mktemp "${TMPDIR:-/tmp}/unspent-ran.XXXXXX")"
for i in 0 1 2; do
  wait "${tpids[$i]}" || true
  grep -E "FAIL|^\s{7}|LOAD FAIL|SCRIPT ERROR|at: " "${logs[$i]}"
  grep -E 'passed,' "${logs[$i]}"
  grep -E '^\s*FAIL ' "${logs[$i]}" | sed -E 's/^ *FAIL //; s/ \([0-9]+ ms\)$//' >>"$ran"
  # A test that hits a script error stops where it was and the runner counts
  # it passed if it had recorded no failed check: the error itself fails the gate.
  if grep -qE "SCRIPT ERROR" "${logs[$i]}"; then echo "script error in shard $i"; fail=1; fi
  rm -f "${logs[$i]}"
done
# WHICH OF THESE ARE YOURS. A gate that has been red for weeks has an exit code
# that means nothing, and a real regression sits in the pile unseen (#124). So
# the run is diffed against the standing list and only the DIFFERENCE decides the
# gate: a failure nobody has seen before fails it however red the tree already
# was, and a standing failure that has started passing is reported so the list
# cannot quietly drift upward and stop being able to fail.
standing="$(dirname "$0")/../tests/standing.txt"
if [ -f "$standing" ]; then
  sort -u "$ran" >"$ran.s"
  grep -vE '^\s*(#|$)' "$standing" | sort -u >"$ran.k"
  new="$(comm -23 "$ran.s" "$ran.k")"
  fixed="$(comm -13 "$ran.s" "$ran.k")"
  echo "== failures: $(wc -l <"$ran.s" | tr -d ' ') ran, $(wc -l <"$ran.k" | tr -d ' ') standing"
  if [ -n "$new" ]; then
    echo "NEW FAILURES (not in tests/standing.txt) -- these are the ones to look at:"
    echo "$new" | sed 's/^/  /'
    fail=1
  fi
  if [ -n "$fixed" ]; then
    echo "NOW PASSING (take these OUT of tests/standing.txt in this commit):"
    echo "$fixed" | sed 's/^/  /'
  fi
  [ -z "$new" ] && [ -z "$fixed" ] && echo "   no change against the standing set"
  rm -f "$ran.s" "$ran.k"
else
  # No list is not the same as nothing to say: without it the gate is back to an
  # exit code nobody can read, and it should say so rather than pass quietly.
  echo "tests/standing.txt is missing: cannot tell new failures from standing ones"
  [ -s "$ran" ] && fail=1
fi
rm -f "$ran"
if [ $web -eq 1 ]; then
  echo "== web (threads, full) and web (no threads, title)"
  tools/web.sh || fail=1
  tools/web.sh --nothreads --quick || fail=1
fi
echo "== $(( $(date +%s) - t0 ))s total"
if [ $fail -ne 0 ]; then echo "CHECK FAILED"; exit 1; fi
echo "CHECK OK"
