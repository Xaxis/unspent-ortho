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

## Where we are (2026-09-20, after the owner played it)

**THE MEASUREMENT BELOW IS THE ONE THAT COUNTS, AND EVERY EARLIER ONE IN THIS
FILE WAS TAKEN THE WRONG WAY.** The owner booted the game and said "every second
of running causes a small lurch, nothing is smooth" while this document reported
p99 10 ms and no frame over budget. Both were true. They were about different
things: every number here had been taken from a `tools/shot.sh` run — standing
still, empty world, default zoom, quiet machine. **A shot never spawns anything**,
so it could not see the cost of a body walking into view at any load.

Measure walking a POPULATED world (`--walk=1,0,12 --run --folk=8 --fauna=gull:3`),
because that is what playing is:

                        reported       really was     now      budget
    30_mobs worst tick    --            145.6 ms      0.7
    worst frame           16.0 ms       139 ms        20.6     33.3   PASS
    p95                    8.3          17.1          11.3     13.9   PASS
    p99                   10.0          24.9          13.8     16.7   PASS
    worst / p50            1.9x         12.5x         2.2x     4      PASS
    frames over 16.7       0 (0%)       32 (5%)       2 (0%)

Every line passes except `p50` at 9.3 against its 8.3 — the 120 Hz median, the
most aggressive row in the table, left failing rather than adjusted.

**What the bug was, and it is the fourth of its family today**: a body built its
figure on the main thread the first time its kind walked into view — 94 ms for
the script load, first mesh and first material, then 8.5 ms for every body after.
Bodies arrive in GROUPS, so a patrol of eight cost 68 ms in the frame it
appeared. Every kind is warmed at load now, and the rest is spread over frames
with a 4 ms budget.

**THE RULE THIS BUYS, AND IT IS ABOUT THE HARNESS AND NOT THE GAME: A SHOT IS
NOT PLAY.** A shot holds still in an empty world; play walks through a populated
one. Any claim about frame cost has to say which it measured, and a claim that
does not is about the empty case whether or not it says so.

### The p50 gap, and what was actually in it

`15_lights` was the worst process node in that run (18.4 ms), and the first
guess was wrong in the usual direction: `_index_sources` LOOKS like the cost
because it walks all 63,641 props, but it is called from `setup()` and finishes
there, so it is loading time and never a frame. **The thing that looked like the
bug was the one piece of that file that could not be it.**

Timed properly — a probe on each of the four calls, walking seed 4 at 21:00:

                     before      after
    _index_sources     0.00        0.00     (done at setup)
    _assign            1.6  / 3.2   0.17 / 0.29
    _update_glows      0.7  / 1.8   0.13 / 0.23
    _gather_glints     1.2  / 3.6   0.08 / 0.15
    the tick           3.3  / 8.5   0.35 / 0.55     typical / worst

`sources` is every light in the WORLD — 1,865 of them — and all three passes
walked the whole array, each one's first act being a distance test to throw
almost all of it away. One tick was three full sweeps; they fire TOGETHER, four
times a second, so a worst tick put 8.5 ms into a single frame against an 8.3 ms
median budget: **one frame in fifteen given over entirely to light.** That is the
owner's "every second of running causes a small lurch" in a different costume
from the mobs one.

A prop never moves and worldgen never adds one, so which cell a source is in is
fixed for the life of a world. Bucketed once at index time; each pass reads the
cells its own reach covers. Ten-fold, and the frames are pixel-identical.

**And the file had no `realm_changed`**, which the realms row of CLAUDE.md names
`light index` as its example of. Across a portal `sources` still described the
world just left, so the new world's lights were never read and the old world's
went on lighting ground they were not standing on. Found only because the grid
had to be thrown away somewhere, and there was nowhere to throw it away from.
`tests/render/test_light_index.gd` holds all three halves, each proved to fail
on its own break.

## Where we were (2026-09-19, end of the hitch work)

Quiet machine, 300 frames, seed 1, warm-up split out of the distribution:

    standing   p50 8.3   p95  9.1   p99 13.2   worst 25.4   1 frame  over (0%)
    standing   p50 8.3   p95  8.9   p99 16.7   worst 40.3   3 frames      (1%)
    walking    p50 8.3   p95 11.5   p99 17.6   worst 33.2   4 frames      (1%)
    budget     p50 8.3   p95 13.9   p99 16.7   worst 33.3

**p95 and p99 are inside budget and the worst steady frame is under BotW's own
target.** Against where this started — p95 15.9, p99 114, worst 150, a 140 ms
stall once a second — the hitch is gone and what is left is ordinary variance.

The one line still failing is `p50`, sitting exactly ON its 8.3 ms budget, which
is the most aggressive row in the table (120 Hz). It is left failing on purpose.
**Tuning a judge until it reports a pass is the only move in this whole document
that cannot be undone by a later measurement**, because after it the instrument
is worth nothing in either direction.

What the four fixes were, in the order they were found: the region's standing ore
swept per region per second (`Chapter.ore_standing`), the chapter refresh on a
1 Hz timer rather than on its events (`24_holds`, df), the story's places re-cast
twice every 0.2 s (`StoryPlan.cast`), and a footprint's textures built under the
walking player instead of when the world was made (`TrackMarks`). Three of the
four are the same bug: **a pure derived thing, recomputed because nobody had
cached it.** The fourth is its twin — cached, but filled too late.

## Where we were (earlier the same day)

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

### Measuring on a machine you do not control

That reading was taken at load 45 and could not be repeated: the machine sat
between 55 and 155 for the rest of the evening and never came back down, so
every absolute number after it was a number about the machine. **Best-of-N does
not rescue this** — the runs themselves add load, and the floor keeps moving
under them.

What does survive is an **A/B alternated under the same conditions**: run the
old code and the new code turn about, so drift lands on both arms equally, and
read the DIFFERENCE rather than either number. Four runs, 300 frames each,
alternating, at load ~60-70:

              p50      p95      p99
    before   10.2     69.0    141.5
    after    10.3     51.1     93.4
    before   10.1     63.7    136.8
    after     9.7     36.5     79.4

**p95 down 26-43%, p99 down 34-42%, p50 unchanged.** A median that does not move
while the tail collapses is the exact signature of removing a periodic stall, as
against making everything faster — which is what the fix claims to have done, and
is the shape to look for when judging any hitch fix.

It also says plainly that **the hitch is not finished**: p99 is still 79-93 ms
here. Those are inflated by the load, but the remaining spikes are real and they
are proc-side now that physics tops out at 4 ms.

#### The gate cannot run its own two halves at once on this machine

`tools/check.sh` launches three headless test shards and four windowed shots
together, "side by side". Measured 2026-09-20, twice, on a quiet machine and a
busy one alike: **all four shots failed together** with `shot FAILED: no image`
and an empty `shots/check/`, while the test half came back clean at exactly the
standing eighteen.

What the logs say, and it is not a timeout in the ordinary sense: each shot's
godot printed its banner and the Metal line and then produced NOTHING for the
whole deadline — no `world N gen`, no error, no script error. The same four
shots, run concurrently with each other but WITHOUT the three shards, all four
succeed and write their PNGs. So it takes the seven together (plus whatever
other sessions are holding, here an eleven-hour `stability_probe`), and the
windowed half is what dies.

That is task #93 — nothing limits how many gates run at once — reaching the
gate's own internals rather than two gates on one laptop. Until it is fixed, a
gate whose test half says "no change against the standing set" and whose shots
are all absent has not judged the shots at all: **run the two halves separately
and read them together.**

Three things this cost, all of them instrument errors rather than game bugs, and
all the same shape as the ones this document already records:

- The gate was piped through `tail -30`, which CLAUDE.md forbids. It hid the exit
  code AND the four `shot FAILED` lines, so the first run looked like a test
  failure for an hour.
- "All four failed, therefore load" was assumed, not measured. The re-run on a
  quiet machine failed identically.
- A "single shot by hand" that reproduced the failure was run WHILE THE GATE WAS
  STILL UP, so it proved only that the gate was still up.

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
