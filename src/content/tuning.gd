class_name Tuning
## Game tunables. Content is code: the parser checks it, there is one copy, and
## a change is live on the next run. Numbers marked (source) come from the
## original game's content and engine (the old Unity game (../unspent)).

# --- World ---
## The square a new game is grown in. 1300 is what five continents need to be
## five WHOLE ISLANDS rather than five shares of one (GenBodies._square_for), and
## five is the least the journey is written for -- StoryPlan.SPINE walks them in
## order and has carried a `leg` per slot for weeks. A wider square would hold
## more (1477 takes six, 1666 seven), and that is exactly why the surface is now
## held at five (`GenBodies.COUNT`): the room goes to making each continent
## BIGGER, which is what the 40-frame rule asks of a landscape (docs/ROADMAP.md).
## 1840 over 1300 is 2.0x the area of each main region (measured, seed 90210),
## and it is as far as the web can go: 1,571 MB of the 2 GiB wasm heap after a
## real shaft crossing on the no-threads build (tools/web.sh prints `web heap`).
const WORLD_SIZE := 1840
## Game-world minutes per real second. 1 = a day in 24 real minutes; at 1.4 a
## day is a little over seventeen, which is what the owner asked for
## (2026-09-18: "the game time which should be configurable should be faster
## slightly"). It is a SOURCE value and `rules.clock` follows it, so the
## setting and the shipped game cannot drift apart.
const MINUTES_PER_SECOND := 1.4
const START_HOUR := 8.0

# --- Player movement ---
const PLAYER_RADIUS := 0.28
## How tall the player stands: the headroom a roof must leave (WorldQuery.passable).
const PLAYER_HEIGHT := 1.8
## How tall the player is crouched: under a roof buckled to 1.5 (a container
## warren's bay) a crouch passes and a stand does not.
const PLAYER_CROUCH_HEIGHT := 1.1
## Tiles per second.
const WALK_SPEED := 3.4
const RUN_SPEED := 5.4
const WADE_FACTOR := 0.55
## What deep water takes off the pace of an animal or a machine that swims (the
## roster's `crosses`): about two fifths of its own (owner, 2026-09-17).
const SWIM_FACTOR := 0.4
## His own swimming (owner, 2026-10-10: "far more agile and faster"): a stroke
## at SWIM_SPEED, and the run key a hard front crawl at SWIM_RUN. Both a little
## under the raft's (CraftKinds), still the faster way over and the dry one.
const SWIM_SPEED := 2.0
const SWIM_RUN := 3.0
