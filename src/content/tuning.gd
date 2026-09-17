class_name Tuning
## Game tunables. Content is code: the parser checks it, there is one copy, and
## a change is live on the next run. Numbers marked (source) come from the
## original game's content and engine (docs/research/design-extract.md).

# --- World ---
const WORLD_SIZE := 512
## Game-world minutes per real second. 1 = a day in 24 real minutes. (source)
const MINUTES_PER_SECOND := 1.0
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
