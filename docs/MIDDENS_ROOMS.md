# THE MIDDENS' ROOMS: doors in the slot faces

Contract for the two built middens interiors, the container warren and the face settlement, cut into the slot labyrinth's walls. Nothing here moves a seed: both are derived from the finished world, as every door is.

## Rulings (teammate1, 2026-09-26, the design approved)

- **The READER household: yes.** The people who keep the words the refuse
  brings in. cb builds the household; the story-wright writes its words with
  the other slots.
- **The string is EARNED, never sold.** A face_hold household gives it after a
  deed: help them, or bring back a buried thing they want. Gear comes from a
  place or a deed.
- **Steel at 1.6 stands only if a careful player can pass.** The warren slice
  carries a test: a crouched walk past a docked sorter goes unnoticed, and a
  standing walk wakes it (the saw hall's rule). The number is tuned until that
  holds.
- The `GenSlots.node` read is asked of the lands builder through teammate1.
- Built after GEN 34 lands, in the slices below.

## What the rooms must say

The walls are what the machines tip, and what they tip is ours: "phones, drives, paper.
Anything that ever had words in it" (the_middens.gd `words_tipped`). The danger is not
knowing the way out. The rooms speak in two registers the rest of the game does not:
**buried things** (containers, vaults, lockers the heaps were poured over) and **words,
kept** (the people here are the ones who read it).

Nothing here answers anything the story gates (STORY.md). The middens are colour, never
load. Words keep to the two registers, never name what the story gates, and no machine
speaks here except by what it tipped.

## The door in the face

`Threshold.of_face(at, out, kind, land)`: a door flush in a sheer riser, `door = host + out *
0.4`, keyed `face@x,y` to a quarter tile. Its model is a frame set INTO the face (a
container's end, a timbered mouth), so the land's strata stand round it.

## Recipes against the labyrinth as built

Siting is `SlotDoors` (`src/core/interior/slot_doors.gd`), from the seed's slot plan and the
finished land:
- **A face is found on the TILES, not the plan:** the warp moves the land under the plan.
  A door needs a face of `FACE_LEVELS` 5+ at its own host (a container door is 2.5 units),
  checked per door, never assumed, and every host tile is checked for
  `country == the_middens`.
- **Warrens:** EVERY blind alley whose end meets a face of 5+ levels gets one. From 3 tiles
  short of the alley's planned end, walk on along it to the first step of 4+ levels; `host`
  is that tile, `out` points back down the alley. An alley end with no face gets no door.
- **A tower's crawl exit comes up BESIDE the alley** (`exit_beside`: `EXIT_SIDE` 3.5 tiles
  off the axis at the face's top, onto plateau running `EXIT_RUN` 4+ tiles), never straight
  behind the door, where the next node's floor is. A warren with neither side is `line` or
  `step`, never `tower`.
- **Settlements:** in junction rooms (degree 3+) with a 5+ face in reach, the mouth on a
  degree-3 room's closed side or a degree-4 room's diagonal. **At most one per 4 x 4 blocks**
  (`CELL`), at the highest-degree, then widest, candidate: a village's share, so each is a
  find (one per 3 x 3 outweighed a landscape's villages).
- `SlotDoors` caches `GenSlots.plan` per world because `GenSlots.node` does not answer
  blind alleys; the ask to lands is for `node()` to answer them so siting stays windowed.
- **The string's route** (`src/core/interior/slot_route.gd`) is a BFS over `node()` answers
  from the settlement's room, bounded at 64 nodes, to the nearest ramp's top (centre plus
  centre minus its one open neighbour's centre, x 0.7).

## 1. THE CONTAINER WARREN (`container_warren`)

`src/content/interiors/container_warren.gd`, `src/models/interior/warren_model.gd`.
- **What:** containers (and a vault) poured over and joined by diggers: a run of steel boxes
  inside the wall, entered by the first one's own end doors.
- **Plans, by hash:** `line` (one level), `step` (climbs once, a container's 5 levels, up a
  ladder), `tower` (twice, the vault at the top, a crawl up through the heap onto the
  plateau: a known tower is the one way up out of the maze besides the ramps). A stepped run
  reads from above as a terraced heap of steel. Each rise has a `ladder` thing that Climb
  takes up and down at a ladder's rate.
- **Dressing, by hash:** `dug` (nobody; sealed, doors torch-cut), `kept` (a scavenger's
  store, bedroll and lamp), `sorted` (the plan's own: the middens' sorter works it on the
  shift, `InteriorKind.shift`, and at the curfew docks ASLEEP, blind but hearing).
- **The floor rings:** `Ground.STEEL_FLOOR`, loudness 1.6 (`StealthNoise`), the loudest in the
  game. The sorter's dock is further from the way than a crouched step on steel is heard and
  well inside a walked one, so crouching past it is a way and walking is not.
- **Collapse** (the middens' `collapse` share): one container's roof buckled over a bay, a
  `buckled` thing handed to the pocket as mass overhead; a crouched body passes, a standing
  one does not, nor a machine taller than the room. Never the first container nor the last.
- **The vault's strongbox:** `Interiors.LOOT` `container_warren`, salvage the machines sort
  for and rarely a drive (its words only ever colour).
- **Look:** corrugated walls by one lamp, stencils under paint, the heap's strata through
  rust holes, grey day down each (`&"seep"` lights).

## 2. THE FACE SETTLEMENT (`face_hold`)

`src/content/interiors/face_hold.gd`, `src/models/interior/face_hold_model.gd`, the mouth
`face_hold_hatch_model.gd`. The middens' village, and the only one (`villages = 0`).
- **Plan:** a timbered mouth in a junction's wall; behind it the SORT (a long table where
  what is dug out is read, a brazier at its back, smoke out through the plateau); a back row
  of two family CELLS and the WORDS ROOM between them; by hash, more cells (`two` to `four`);
  the LOOKOUT up a ladder with one slit in the face along the slot.
- **Households** are the middens' own (`BiomeDef.home`: sorter, wirer, reader); the READER
  is always among them, at home by their desk as a DWELLER (21_doors) the use key talks to.
- **The string:** the reader wants a filed record (what the warrens' boxes keep); brought
  one, they take it and give a ball of string once per settlement (21_doors `dweller_deed`).
  While carried, the map draws its route to the nearest ramp; a save keeps it. Never sold.
- **No stealth against them.** From the lookout a passing sorter is watched go by, and the
  settlement stops talking when one passes (`src/core/interior/door_hush.gd`): the room's
  beds fall away, its lamps dip, and each machine is heard by its own weight's footfalls.
- **What it keeps** is theirs (`InteriorKind.seats`), on the words room's shelves (KeptBy),
  given once to a stranger on good terms (GEAR.md §7).
- **Look:** mouths hung with cloth and cable; strata shored with doors and signs; shelves
  of phones, drives and paper, chalk-labelled; the sort under a hooded lamp.

## Story slots

All `lands: ["the_middens"]`, each opened only where words are written for it
(`StoryRooms.words_for`).
- **container_warren:** `wall:manifest`, `desk:vault_ledger` (the last entries in another
  hand), `wall:tally_marks`, `wall:do_not` (a container never opened), `terminal:vault_panel`
  (still asking for a code).
- **face_hold:** `desk:the_sort`, `wall:words_room`, `wall:the_string` (the way-out map),
  `wall:lookout`, `desk:reader`, `wall:sorter` / `wall:wirer`.

## Proof

Recipes: `.claude/skills/verify/features/world-places.md`, 21_doors.
