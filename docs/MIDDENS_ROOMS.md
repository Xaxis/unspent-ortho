# THE MIDDENS' ROOMS: doors in the slot faces (design, cb, 2026-09-26)

Two interiors for the middens, cut into the walls of the GEN 34 slot labyrinth
(the lands builder's `GenSlots`, branch world/gen34-slots). Designed now against
the prototype; built once GEN 34 lands. Nothing here moves a seed: both are
derived from the finished world, as every door is.

## What the middens are, and what their rooms must say

"Miles of cyber refuse cut into slot canyons, so narrow in places that the sky
is a line" (the_middens.gd). The walls you walk between ARE the refuse: seventy
years of what the machines tip, sorted by the plan before it dumped it and
banded by what it is (`STRATA_REFUSE`). What they tip here is ours, never
theirs: "phones, drives, paper. Anything that ever had words in it"
(`words_tipped`). It is the one place that is a maze, and the danger is not
knowing the way out.

So the middens' rooms speak in two registers the rest of the game does not:
- **Buried things.** The plan poured the heaps over what stood here: shipping
  containers, vaults, a sorting office's own lockers. People dug into the faces
  and found rooms already there.
- **Words, kept.** Everything that ever had words in it ends up here. The people
  who live here are the ones who read it.

Nothing here answers anything the story gates (STORY.md). The middens are
colour, never load.

## The door in the face (shared with the mesas)

A slot face is a sheer one-tile riser of six levels (three units) between a
floor and the plateau (`test_slot_walls_stand_as_one_face`). No door today sits
on one: every Threshold is a house prop, a depot hatch or a landmark hatch, and
the mesas' cliff room is a HOUSE that draws its own cliff (`cut_room`).

**`Threshold.of_face(at, out, kind, land)`**: a door set flush in a riser. It
has `host` on the face line, `out` along the floor away from the wall, and
`door = host + out * 0.4`. Its key is `face@x,y` to a quarter tile. The door
model is part of the room's own model, drawn as a frame set INTO the face: a
container's end doors for the warren, a cut and timbered mouth for the
settlement. So the land's strata stand round it, not a house front.

**Siting, from the plan, not the tiles.** `GenSlots.plan(seed, size)` is
deterministic and its lattice regular (PITCH 12), so the sites are re-derived,
never stored:
- **Warren doors** stand at BLIND-ALLEY ENDS (the `east_stub`/`south_stub` dead
  ends): the alley runs into the heap and stops at a door. That is the
  labyrinth's own logic, since a dead end is where you find what someone buried.
  Share: 1 in 3 stubs, by `Rng.hash01(seed, node, STUB_SALT)`.
- **Settlements** stand in a JUNCTION ROOM (`degree >= 3`, the widest floors),
  in the wall between its two nearest exits. At most one per 5x5 maze block,
  at the block's highest-degree room.
- **Windowed.** `GenSlots` needs a `node(seed, size, i, j)` read that works out
  one node and its edges without the whole plan (the lattice is regular and the
  block maze is per block), so `Interiors.thresholds` asks only the nodes near
  a section. **An ask to the lands builder:** expose that, or tell me the
  plan's cost per block and I will cache per block.
- **The mesas** could move `cut_room` onto `of_face` against their own
  scarps, where the land has them. Proposed, not in this slice.

## 1. THE CONTAINER WARREN (`container_warren`)

**What it is.** Shipping containers and a vault or two, poured over when the
heap was raised, found by diggers and joined: a stack of steel rooms inside
the wall, entered by a container's own end doors at a dead end.

**Plan.** Three to six containers (each 2.4 x 6 tiles) and at most one vault
(4 x 4, poured concrete, a round door hung open or shut). The pocket world is a
heightfield, and the top camera sees down, so a STACK is drawn STEPPED:
- each container a floor at its own level, 2, 7 or 12 (a container's height,
  2.5 units, is five levels);
- a higher one set back over the lower one's far end;
- joined by LADDERS at each step (a `ladder` thing on the riser; `Climb.face`
  already climbs a rock face one level a second, and a ladder is a face that
  says so: `Climb` learns a thing kind that makes any riser climbable, with a
  faster rate).
- From above it reads as a terraced heap of steel boxes, each cut at its own
  wall height (`cut` per floor). Over the shoulder the ladders read as the way.

**Plans, by hash:** `line` (end to end, one level), `step` (two levels, one
ladder), `tower` (three levels, two ladders, the vault at the top). `dressing`
follows who lives here now: `dug` (nobody: sealed ones, the doors cut with a
torch), `kept` (a scavenger's store), `sorted` (the plan's own: see hooks).

**Stealth and reward.**
- **The floor rings.** Container steel is the loudest floor in the game:
  `Ground.STEEL_FLOOR`, loudness 1.6 against the room floor's 1.15 (StealthNoise).
  Walking is heard two containers away. Crouch, or pay.
- **A sorter on shift** (`sorted` dressing): the middens' own machine works the
  warren as a store on SHIFT hours (`InteriorKind.shift`), docked and ASLEEP
  off shift (the saw hall's rule). Take from a `sorted` warren at night on
  soft feet, or by day under the noise of its work.
- **The vault's strongbox:** `LOOT[container_warren]` holds salvage the machines
  sort for (cells, boards, copper) and, rarely, a DRIVE (an item whose words the
  story-wright may write; it is only ever colour).
- **Collapse** (the middens' 0.45 hazard): a container's roof is buckled. A
  `buckled` thing lowers the headroom over one bay (S0's `headroom_at` works
  indoors), so a person crawls through it: crouch-only.
- **The way out is not the way in.** A `tower` warren's top container opens on
  the PLATEAU (a crawl exit up through the heap, `exit` → `_back_of`, onto the
  plateau over the door): the one way up out of the maze there is, besides the
  ramps. A known warren is a shortcut, and that is its reward.

**Look.** Corrugated walls lit by one lamp; stencilled numbers under paint;
the heap's strata pressing in where a wall has rusted through (the land's own
`STRATA_REFUSE`, drawn on the hole's edge); a bedroll in a `kept` warren; in a
`sorted` one, bins in rows and a conveyor.

## 2. THE FACE SETTLEMENT (`face_hold`)

**What it is.** The people of the middens live IN the walls at a junction:
rooms cut back into the refuse, their mouths along the face, joined inside.
Cliff-dwelling logic: the face is the street, the wall is the town. It is the
middens' village (the middens have `villages = 0`: this is why).

**Plan.** One way in at floor level: a timbered mouth in the junction's wall.
Behind it a SHARED ROOM, the sort, with a long table where what is dug out is
read and sorted. Off it:
- two to four family CELLS (the world/homes middens households: sorter,
  wirer, and a proposed third, the READER, who keeps what has words in it);
- a WORDS ROOM: the settlement's store of everything with writing on it,
  shelved;
- a LOOKOUT a level up by a ladder, with a slit in the face looking along the
  slot (a window, `closed` low there).

**Hooks.** Friendly, not a heist:
- **Rest and trade.** A hearth (a `brazier`, smoke let out through the plateau
  above) and a keeper who trades (56_economy), the middens' goods at the
  middens' prices.
- **The string.** The settlement sells the way out: a `string` item that
  marks the route from here to the nearest ramp on the survey (the map app).
  It is the maze's own answer to the maze, and the reward for finding them.
- **Stealth:** none against them. From the lookout, the slot below is seen
  a long way both ways, and a `sorter` passing on its round is watched go by.
  The settlement stops talking when one passes (a hush here that is a
  people's own, not the crags').

**Look.** Mouths hung with cloth and cable. Inside, the strata of the heap
are the walls, shored with doors and signs. The words room is shelves of
phones, drives and paper, each labelled in chalk. The sort table is lit by a
hooded lamp (the wirer's `home_wirer_hood`).

## Slot keys for the story-wright

All `lands: ["the_middens"]`. The households are for the settlement's cells.

**container_warren**
- `wall:manifest`: a container's stencilled manifest, under paint, about what
  it held when it was sealed.
- `desk:vault_ledger`: a ledger in the vault, the last entries in a different
  hand from the first.
- `wall:tally_marks`: marks scratched inside a container, by whoever lived in it.
- `wall:do_not`: a container never opened, and what is chalked on its doors.
- `terminal:vault_panel` (if a terminal slot is wanted): the vault's panel, still
  asking for a code.

**face_hold**
- `desk:the_sort`: the sort table, and what is on it today.
- `wall:words_room`: the words room's labels, what they keep and why they keep it.
- `wall:the_string`: the way-out map, a string route pinned to a wall.
- `wall:lookout`: what is scratched beside the lookout slit.
- `desk:reader` (household `reader`): the reader's desk.
- `wall:sorter` / `wall:wirer` (households): each family's piece, as homes have.

Words must keep to the middens' two registers (buried things, words kept),
never name what the story gates, and never have a machine speak here except
by what it tipped.

## Slices (after GEN 34 lands)

1. **`of_face` and the siting** (mine), plus the `GenSlots.node` read (the
   lands builder, or me with their say). Test: every door stands on a sheer
   riser, opens onto a floor tile the walk reaches from a ramp, and none sits on
   a ramp or in a junction's middle; the keys are stable.
2. **The warren** (mine): plans, containers, ladders (`Climb` learns
   `ladder`), steel floor loudness, the sorter on shift and asleep, the vault
   strongbox and LOOT, the buckled bay, the top crawl exit. Tests like the saw
   hall's and the squat's; tours from above and over the shoulder, up a ladder.
3. **The settlement** (mine): plan, households (the reader added to
   world/homes' middens row), brazier, keeper and trade, the string item, the
   lookout. Tests: rooms reachable, trade stocked, the string route leads to a
   ramp.
4. **Words** (the story-wright) against the keys above, any time after slice 2.

Neither room changes what a seed makes, so no GEN bump past 34. test_rooms
grows for both kinds.

## Open questions

- A third household, the `reader`: yours or the story-wright's call.
- Should the string be sold, or earned (a favour, the saw hall's way)?
- Is the steel floor's loudness too cruel against a sorter asleep? A number
  for the fight builder to check against StealthNoise.
