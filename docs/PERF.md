# PERF.md — what "smooth" means here, in numbers

The owner asked for graphics performance "at least as good as Breath of the Wild
/ Tears of the Kingdom". Taken as a framerate that is a low bar and we already
clear it: both of those target **30 fps — a 33.3 ms frame** — and this game's
median frame is **8.3 ms**, four times faster. Measured on the average, the job
was finished before it started.

The average was never what he was reacting to. He said **"laggy and jumpy"**, and
jumpy is not a speed, it is a VARIANCE: at the moment he said it the median was
8.3 ms and one frame in a hundred took **120 ms**. A player does not feel the
median. They feel the worst frame in the last second, every time it comes.

So the standard here is stated on the distribution, and the headline is chosen to
be honest about the comparison rather than flattering:

> **OUR WORST FRAME SHOULD BE NO WORSE THAN THEIR BEST.**
> BotW's target frame is 33.3 ms. No frame of this game may exceed it.

## The standard

Steady play, at `Tuning.WORLD_SIZE`, on the tier the machine actually gets,
over a run of at least 300 frames:

| | budget | why |
|---|---|---|
| `p50`  | **≤ 8.3 ms** | 120 Hz median. Headroom is what absorbs a busy moment. |
| `p95`  | **≤ 13.9 ms** | 72 fps at the 95th: the common case never touches 60. |
| `p99`  | **≤ 16.7 ms** | The hundredth frame still inside 60 Hz. |
| `max`  | **≤ 33.3 ms** | No single frame worse than BotW's *target* frame. |
| `max / p50` | **≤ 4** | Relative smoothness. A frame four times its neighbours reads as a jolt however fast the neighbours were. |

Both `max` rules apply. The absolute one stops a slow game hiding behind a slow
median; the relative one stops a fast game shipping a visible jolt.

**Warm-up is a separate promise, not an exemption.** The frames between a world
appearing and play settling may exceed these, because a player sees them once.
They are bounded instead: **no more than 12 frames over 16.7 ms, and none over
250 ms, before the run settles.** A warm-up that is not bounded is a loading
screen that lies about being over.

## How to measure it, and how not to be lied to

    tools/shot.sh shots/x.png --frames=300 --stats            # standing
    tools/shot.sh shots/x.png --walk=1,0,12 --run --frames=300 --stats

`--stats` prints the distribution and then every frame over 16.7 ms **with its
index**, because where the slow frames fall decides what kind of problem it is:
bunched at the start is warm-up, spread through the run is a hitch, and those
want opposite fixes.

Three rules for reading it, each learned the expensive way:

1. **Never judge on an average.** A 120 fps mean sat over a 150 ms stall for as
   long as anyone cared to look. Every instrument this project had reported a
   mean, which is exactly what cannot see the thing being complained about.
2. **A measurement under load is a measurement of the load.** Wall-clock results
   move by a factor of eight on a busy machine (CLAUDE.md, "SLACK IS FOR WAITING,
   NOT FOR COSTING"). Take a cost as the cheapest of several runs, and re-run any
   breach alone before believing it.
3. **Compare frames only when the world is still.** Two shots of a living world
   differ because people walked, not because anything changed.

## Where we are (2026-09-19)

Standing still, 400 frames, seed 1, on a BUSY machine (load 45), so the absolute
numbers are pessimistic and the comparison is the honest half:

                      before        after      budget
    p50              8.3 ms        8.3 ms      8.3    PASS
    p95             15.9 ms       12.5 ms     13.9    PASS  (was FAIL)
    p99            114.1 ms       31.0 ms     16.7    FAIL
    max            150.0 ms      142.4 ms     33.3    FAIL  (warm-up only)
    over 16.7 ms   13 frames      9 frames

`max` is now frames 0 and 1 — warm-up, which this file bounds separately rather
than exempts, and 2 frames over is well inside the 12 allowed. **Excluding
warm-up the worst frame is 36 ms, down from 150.** The periodic spike is gone.

Note the judged line still prints FAIL for `max` and `max/p50`, because
`frame_line` takes its distribution over every frame including warm-up. The
instrument does not yet make the split this document promises.

## The hitch, found

**`Chapter.ore_standing` swept every prop in the world, once per hold-keeping
region, once a second.** `24_holds._physics_process` refreshes chapters every 60
physics ticks; `Chapter.read` asks each region what ore stands in it; the answer
walked `world.props` calling `region_at` on every one. Measured per system, worst
physics tick:

    before: 24_holds.gd 224.6 ms, 30_mobs.gd 0.7, 40_fight.gd 0.2, ...
    after:  24_holds.gd  12.5 ms, 30_mobs.gd 1.2, 40_fight.gd 0.2, ...

A 320x gap between first and second place, which is the one shape machine load
cannot invent — which is why this was worth measuring even at load 45.

The fix is one sweep per world for every region at once, remembered the way
`Landmarks.sites` is, because nothing can change the answer: a prop never moves
and worldgen never adds one. Only what is TAKEN changes, and that was already
read off the small `depleted` set.

**The lesson is the scheduling, not the sweep.** An earlier fix (#122) moved this
off the per-frame path, taking the game from 5-12 fps to a healthy median with a
200 ms stall once a second. The cost was rescheduled, not removed — and that
trade turns "slow", which a player forgives, into "broken", which is what the
owner reported as *laggy and jumpy* while the median sat at 8.3 ms. Work too
expensive to run every frame is usually too expensive to run at all; ask why it
is recomputed when its inputs cannot have moved.

**AND THIS FILE SENT PEOPLE AWAY FROM IT.** `24_holds` was listed below as
eliminated, "under 4 ms". A probe had already printed `24_holds.gd saves
163.6 ms` as its top row — the right answer — and it was discarded as baseline
drift and then written up as cleared. A wrong entry on an eliminated list is
worse than no list: it is the one place nobody looks twice. **An elimination
needs the same evidence as a finding, and the reading that disagrees with your
model is the one to re-run, not the one to explain away.**

**What the hitches are NOT**, each eliminated by measurement and recorded so
nobody spends the afternoon again: movement or chunk streaming (the same spikes
land at the same frame indices standing perfectly still), the renderer (0.3 ms of
render CPU), chunk building (5 ms at worst on the main thread), the coarse far
world (switching it off makes p99 worse), the fight simulation (worst catch-up
0.6 ms in two slices — the twelve-slice cap its constants allow is never
reached), music, audio or sky (all under 4 ms). Engine shader compilation at boot
(419 variants, all served from cache, zero compiles under `--verbose`) and
MoltenVK pipeline translation (this machine runs Godot's native **Metal** backend
on an M3 Max, so an empty `user://vulkan/` cache directory means nothing here).

## Two instruments that were wrong, and how each was wrong

Both were mine, both looked conclusive, and each sent the hunt somewhere else
for hours. They are kept because the shapes recur.

**`Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` lag by one frame.** They
are written at the END of a frame, so a read taken during the spike frame
describes the frame before it — a fast one. That produced "at a 140 ms frame,
process and physics account for 44 ms, so the other ~96 ms is in no `_process`
this game owns", which is two different frames compared, and it pointed away from
game script when the whole cost was in a `_physics_process`. **Read them on frame
N+1 and attribute them to frame N**, and the line reads `total 132 = proc 29 +
phys 126` — which names the culprit immediately.

**A `frame_post_draw` probe "proved" the spikes were WORK, not waiting** (work
113-145 ms against wait 1-4 ms). Its `wait` measured only post-draw to the next
process-start — the frame-pacing sleep — so the main thread *blocking on the
render thread* was counted as work. A measurement whose name promises a
distinction it never made.

**What actually found it**: driving the systems yourself and timing each.
12_landscape calls `set_physics_process(false)` on every system whose SCRIPT
defines `_physics_process` — ask the script, not the node, because `has_method`
answers true for a virtual every Node declares — then calls them in
`game.systems` order and records each one's worst tick. Same order, same
behaviour, one number per system. **A ratio between two things measured in the
same run is worth taking even on a busy machine**, which is how a 320x gap was
read at load 45 when no absolute number would have been worth printing.

## The rule this standard exists to enforce

A frame budget is not a target to average toward. **It is a ceiling that every
frame has to fit under**, and a run is judged by its worst frame, not its typical
one — because that is the one the player feels.
