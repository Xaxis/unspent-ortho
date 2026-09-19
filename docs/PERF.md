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

## Where we are (2026-09-19, the day the standard was written)

    p50   8.3 ms   PASS
    p95  16.7 ms   FAIL  (budget 13.9)
    p99 ~120 ms    FAIL  (budget 16.7)
    max  150 ms    FAIL  (budget 33.3)
    max/p50  18x   FAIL  (budget 4)

One line passes. The median is not the problem and never was.

**What the hitches are NOT**, each eliminated by measurement and recorded so
nobody spends the afternoon again: movement or chunk streaming (the same spikes
land at the same frame indices standing perfectly still), the renderer (0.3 ms of
render CPU), chunk building (5 ms at worst on the main thread), the coarse far
world (switching it off makes p99 worse), the fight simulation (worst catch-up
0.6 ms in two slices — the twelve-slice cap its constants allow is never
reached), `24_holds`, music, audio or sky (all under 4 ms).

**What they are: NOT ESTABLISHED. Do not plan against this paragraph yet.**

The claim that stood here — "at a 140 ms frame, process and physics account for
44 ms, so the other ~96 ms is in no `_process` this game owns" — rests on an
instrument that reports on the step BEFORE the one being measured, which is the
exact trap this file's rule 1 exists to catch.

**`Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` lag by one frame.** They
are written at the end of a frame, so a read taken during the spike frame
describes the frame before it — a fast one. Attributing 44 ms of a 140 ms frame
from that read compares two different frames. Until the monitors are aligned
(read on frame N+1, attributed to frame N), the split is unproven in both
directions: the work may be in game script after all.

A second instrument was wrong the same way and is retracted with it. A
`frame_post_draw` probe was read as proving "the spikes are WORK, not waiting"
(work 113-145 ms against wait 1-4 ms). Its `wait` measured only post-draw to the
next process-start — the frame-pacing sleep — so the main thread *blocking on
the render thread* was counted as work. The honest residue is narrow: the time
is spent before the draw completes, and the split between script, engine and
driver is not yet known.

**Eliminated as suspects anyway**, since these were measured directly rather
than by subtraction: engine shader compilation at boot (419 variants, all
served from cache, zero compiles in `--verbose`), and MoltenVK pipeline
translation (this machine runs Godot's native **Metal** backend on an M3 Max, so
the empty `user://vulkan/` cache directory means nothing here).

The next measurement is a correctly-aligned three-way split — script, engine,
driver — on a **quiet machine**, plus a 600-frame run to see whether the spikes
stop after the first pass (which is what first-use compilation would predict and
a recurring cause would not). See task #126.

## The rule this standard exists to enforce

A frame budget is not a target to average toward. **It is a ceiling that every
frame has to fit under**, and a run is judged by its worst frame, not its typical
one — because that is the one the player feels.
