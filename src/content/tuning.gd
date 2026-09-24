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
## Tiles per second.
const WALK_SPEED := 3.4
const RUN_SPEED := 5.4
const WADE_FACTOR := 0.55
## A stroke against a walk (owner, 2026-09-17: about two fifths). Running is not
## faster in deep water: there is nothing to push against, so a swim is one pace.
const SWIM_FACTOR := 0.4
