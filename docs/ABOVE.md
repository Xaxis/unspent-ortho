# GROUND ABOVE THE GROUND: geometry over the heightfield

Cave roofs, overhangs, arches; later the owner's floating islands over a crater
field. The design, and what is built of it.

## Status

- **S0 built** (world/above-s0): `WorldData.overhead`, a sparse Dictionary
  (tile index -> Vector3i(under, over, kind)), not the sorted arrays of §1: no
  content makes spans yet, so the arrays wait for S3, when sections carry them.
  Reads: `overhead_at`, `headroom_at`, `solid_at`, `set_overhead`. Asked by the
  walk (`passable`/`move_body` `tall`, `FightSim.HERO_TALL`/`tall_of`), sight
  (`Senses._solid`, a line at body middle, `SIGHT_HEIGHT`), the jump (a lid on
  the rise), the climb (room over foot and shelf) and the shoulder eye
  (`Shoulder.box_over`). tests/core/test_overhead.gd, each rule seen red alone.
- **S1 built** (world/above-s1): `TerrainMesher._spans` draws them; a dev
  staging option `--above=roof|arch` over the start (AboveStage) plants a synthetic
  span; tours/above-arch.tour, tours/above-roof.tour; tests/render/test_spans.gd.
  A span's top is flagged lifted (UV2.y +512): world.gdshader draws no ground
  wear, trampling or works on it. Cost: a 12x10 slab takes its chunk from about
  17 to 31 ms (+75%, on the worker); see S3's target.
- The owner's ruling on law 3 (§3) is still needed before S2.

The survey below (§0) was taken from main at ced92304, before S0.

## 0. What is true today (the constraint)

- **One height per tile.** `WorldData.level: PackedInt32Array`, a tile at level
  `l` stands at `l * STEP` (STEP 0.5; world_data.gd:11,20). `height_at`,
  `level_at` are the only reads. Nothing in WorldData knows about overhead.
- **The mesher is a contour-terrace heightfield** (terrain_mesher.gd:1-12):
  a warped bilinear field over levels, marching squares on a half-tile lattice
  (RES 2), terraces as flat washes, walls down between them in strata bands.
  CHUNK 32. Streamed by world_view.gd (`_wanted`, `_build_worker`).
- **The walk is flat.** world_query.gd:5-7: "walked on a flat plane in tile
  space; height is only visual. A body may step one level." No z anywhere in
  `standable`/`passable`/`move_body`. Player y = `height_at(pos)` lerped, plus
  `lift` (player.gd:180-186).
- **The camera treats everything under the drawn surface as ground, and nothing
  over it.** Shoulder.room's blocked test is `q.y < ground(q.xz) + CLEAR`
  (shoulder.gd:373); `_ground_top` bounds lookups by the max level along the
  line (41_shoulder.gd:432). `tall_cut`, `crown_cut` and the close-eye
  `sight_cone` all skip land materials 40-70 ("never the land", world.gdshader
  :1397, :1466) — LOOK law 3, "the land itself never opens".
- **Caves are a separate realm world** (limestone_caves.gd: `Realm.UNDERGROUND`,
  roofed only as light: `SkyLight.closed`), a normal terraced heightfield under
  a dark sky — which is exactly why they read as open terraces.
- **Precedents:** an interior is a separate small pocket world
  (interior_gen.gd:20, `Realm.INTERIOR`); the one walk-under structure is a
  PROP (prop_kind.gd:236, an arch: solid 0, its feet handed to
  `WorldQuery.set_blocks`).
- **Streaming (teammate2, stream/DESIGN.md):** 256² sections from a resident
  per-realm `WorldPlan`; a section never reads another section's output, only
  the plan; stable-keyed plan rows; ids `(section << 20) | ordinal`; one LRU
  byte budget (~200 MB, ~16 sections × ~6 MB resident); tiles measured at
  26 B/tile; "nothing at runtime writes a tile"; each output-moving slice bumps
  GEN and re-accepts parity; direct array readers move to a `TileWindow`.
- **Climbing, jumping and the hero's height assume nothing is overhead**
  (fight builder, src/core/climb.gd, whose header lists them): a climbable
  FACE is the step between two tiles' levels and its TOP is `level_at` of the
  next tile; `Jump.plan` plans an arc over levels alone; `FightSim.hero_level`
  is the tile's level. Under an overhang or a cave roof a climb would go up
  through the rock, and a roof's underside would count as no face at all.
- **Saves** keep seed + size and regenerate; only prop deltas are stored
  (save_core.gd:134). WorldStamp hashes GEN + TERRAIN fields of every BiomeDef.

## 1. Data model: SPANS

A **span** is solid mass hanging over a tile: from an underside level `under`
up to a top level `over` (`under < over`), in the same level units as
`WorldData.level`. At most **one span per tile** (enough for a cave roof, an
overhang, an arch, an island; two stacked masses over one tile are a later
problem and nobody has asked for one).

```
WorldData (per section when streamed)
  span_tiles: PackedInt32Array   # tile index, sorted, for binary search
  span_under: PackedByteArray    # levels, relative to a per-section base
  span_over:  PackedByteArray
  span_kind:  PackedByteArray    # ROOF, OVERHANG, ARCH, ISLAND (+ material row)
  span_key:   PackedInt32Array   # the plan row it came from (stable), -1 none
```

Sparse, sorted by tile: 11 B per spanned tile. A cave realm roofed over 60% of
a section is 39k spans ≈ 430 KB — about 7% of a section's 6 MB; a surface
section with a few arches and overhangs is a few KB. Well inside the budget.

**Reads (the only door):**
- `span_at(x, y) -> Vector3i` (under, over, kind), or (−1, −1, 0) for none.
- `clear_at(x, y) -> int` — levels of headroom over the ground: `under − level`,
  or a large number with no span.
- `solid_at(p: Vector2, y: float) -> bool` — under the ground, or inside a span.
  This is what the camera, sight and projectiles ask.
All three go through the `TileWindow` facade the streaming design introduces,
so a probe never reaches into arrays directly.

**Shapes, not tiles, are what is planned.** Spans are generated from plan rows,
each with a stable key, rasterised per section:
- `ROOF` — a realm-wide lid at `roof_level(x, y)` (a smooth field over the
  floor, e.g. floor + 6..14 levels), minus **holes** (plan rows: where daylight
  falls, where a shaft comes down). Caves.
- `OVERHANG` — a cliff lip extended out over the terrace below by 1-3 tiles,
  from the terrace boundary the mesher already finds; `over` = the upper
  terrace, `under` = `over − thickness`.
- `ARCH` — a plan polyline between two anchors on high ground; the span's band
  along it, underside a catenary between the anchors.
- `ISLAND` — a plan disc/blob over a region (crater field), underside a
  rounded keel, top a terraced field of its own.

Each landscape DECLARES what it grows (`BiomeDef.above = {&"roof": {...},
&"overhang": {...}}`), read by a new worldgen stage `GenAbove`; nothing
branches on a landscape by name. Rasterising a shape is a pure function of
(plan row, tile), so a section with a margin computes the spans of a shape that
crosses its edge exactly as its neighbour does — the streaming invariant holds.

## 2. Walk and collision

**Phase A — nothing stands on a span (roofs, overhangs, arches):**
- A body walks under a span when the headroom clears it:
  `clear_at(tile) * STEP >= height(body)` (roster `height`; player 1.8 → 4
  levels). A tile whose headroom is short of that is **not passable** to that
  body — a low roof is a wall to a person and a crawlway to a runner.
- `WorldQuery.passable` gains the headroom test (one sparse lookup, only when
  the tile is spanned — the bitset of spanned tiles makes the common case free).
- **Fliers** are held under a span: their altitude is capped at
  `under * STEP − clearance`; a flier cannot cross a span it cannot fit under.
- **Projectiles and sight** (FightSim lines, `Senses.line_clear`, `Shoulder.sees`)
  ask `solid_at` along the line, so a roof between two bodies at different
  heights blocks as a wall does.
- **Gear:** the glide/grapple `lift` (54_gear) is capped by headroom: you
  cannot glide up through a roof.

**Climbing and jumping (S0, with the walk):**
- `Climb.face` stops at the first solid overhead: a climb up a face is only as
  tall as the headroom over its top, and a face whose top is under a span with
  less than a body's headroom is not a climb at all.
- The TOP of a climb is a surface the geometry declares: the next tile's level
  in Phase A (a span's top is never a place to stand yet); in Phase B, a span's
  `over` where the span marks its rim climbable.
- A span's underside is not a face: nothing climbs a ceiling.
- `Jump.plan`'s arc is tested against `solid_at` along its path, so a jump
  under a roof comes down where the roof stops it, not through it.
- `FightSim.hero_level` stays the tile's level in Phase A (the body is under
  the span); in Phase B it is the level of the body's layer.

**Phase B — standing on a span (arch tops, island tops):** bodies gain a
**layer** (`0` the ground, `1` the span top). `pos` stays 2D; `WorldQuery`
functions take the layer; a body's height is `level` or `span.over` by layer.
Transitions are explicit tiles: a **ramp** (a span edge within one level of the
ground it meets), a **ladder/rope/lift** (a prop that swaps layer), a grapple
(54_gear) or a craft. AI pathing learns layers. This is the big one and gets its
own review before any code (§7, S6).

## 3. Camera

**The shoulder eye (41_shoulder, Shoulder.room/clear_along/sees):** replace the
`ground` callable with `solid(p: Vector2, y: float) -> bool` = under the ground
or inside a span. Two consequences, both wanted:
- under a roof the eye is pulled in against the **ceiling** as it is against a
  wall — the crowd rule (side step, tip) already handles a pressed eye;
- `_ground_top` (the cheap bound that skips lookups) becomes "the highest
  solid along the line": max of level and span.over within 2 tiles.
The near plane's width (`NEAR_REACH`) is asked of spans too, so the near plane
never slices a roof's underside.

**The top view (the lens):** a roof over the player hides the player — and the
shaders' cuts deliberately never open land (law 3). Proposed, **for the owner
to rule on**: a span is drawn as **ARCHITECTURE, not land** — the same
language interiors already use: from above, a span over the player's region is
drawn **cut at the section plane** (the player's level + `SECTION` ≈ 2.4 m)
with an inked cap along the cut, exactly as a room's near walls are cut at
`InteriorKind.cut` with an inked top. Nothing is stippled open; the roof is
sectioned, the way a plan drawing sections a building. Outside the player's
region the roof is drawn whole (the cave from above is a closed dark mass with
its holes lit). Rules:
- the section region is the span's CONNECTED COMPONENT under/around the player
  (a cave hall), not a disc — a disc through rock reads as a hole;
- the cut eases in over `BLEND_SECS` when the player walks under, as the
  shoulder glide does;
- the close-eye `sight_cone` and `tall_cut` stay off land; spans carry their own
  mark range (`M_SPAN_*`, coordinate with the lands builder's mark refactor in
  matter.gdshaderinc) so the section cut is a span rule, not a land rule.
If the owner rules law 3 covers spans too, the fallback is: under a roof the
lens drops to the shoulder view (a roof is where the shoulder view is for).

**Near focus:** `_near_focus` is orthographic DOF only and off under the lens;
nothing to do. The shafts pass (light through holes) reads the span texture (§4).

## 4. Rendering

- **Mesher, second pass per chunk:** the span mask contoured on the same
  half-tile lattice with the same warped field (so a roof edge wanders like a
  terrace edge — never a tile-stepped block, never Minecraft). Emits:
  underside (faces down, at `under`, with the rock's strata and drip relief),
  rim walls (from `under` to `over`, banded as cliffs), top (at `over`, a wash
  like a terrace). Built on the worker with the terrace pass; one extra mesh
  per chunk only where the chunk has spans.
- **Light under a span:** the sun's shadow does the direct light. The SKY's
  ambient must drop too, or a cave under a lid is lit from nowhere: a per-realm
  **span occlusion texture** (R8, one texel per tile, like `sky_wear`), sampled
  in world.gdshader/found/leaf: ambient × (1 − roofed), softened at edges and
  holes. Holes and overhang lips get light shafts from the existing shafts pass
  (sky.gdshaderinc), fed hole positions from the plan.
- **Section cut from above** (§3): a discard against the section plane within
  the component mask (sampled from the same span texture, component id in G),
  and an inked cap drawn along the cut line by the mesher's lip strip
  (`_lip_strip` already inks terrace lips).
- **Far land** (world_far.gd): islands and arches over the horizon need a
  far-mesh impostor (their silhouette is the point); roofs never do.

## 5. Streaming

- Spans are **L0**: produced by `WorldGen.section()` from plan rows, never
  written at runtime. They ride in the section's arrays and its digest.
- Plan rows: `above` shapes (holes, arch polylines, island blobs) are plan
  rows with stable keys and bounding boxes, so a section asks the plan only
  for shapes overlapping section + margin.
- The span occlusion texture is per section (256² R8G8 = 128 KB), uploaded when
  a section becomes resident, dropped with it; counted in the byte budget.
- `TileWindow` gains the three reads (§1) so every probe keeps going through
  the one facade.

## 6. Save and GEN

- **Save:** spans are generated; nothing is saved. If roofs ever become
  destructible, a sparse delta list keyed by tile (like `depleted`), and
  `SaveCore.disagrees` must also check the player's headroom on load (a save
  under a roof that no longer exists / now exists).
- **WorldStamp:** `BiomeDef.above` is a **TERRAIN** field (it changes what a
  seed makes), hashed with the rest; `span_*` arrays join the parity digests.
- **GEN:** S0-S2 add the layer and its rendering with **no landscape declaring
  any `above`** — output unchanged, no bump. Each content slice (S3, S4, S5)
  bumps GEN once, coordinated with the GEN owner, re-accepts test_parity with
  the frames looked at, per the streaming design's rule.

## 7. Slices, each with its proof

- **S0 — the layer and its reads, no content.** WorldData span arrays +
  `span_at`/`clear_at`/`solid_at` (+ TileWindow); `WorldQuery.passable`
  headroom; `Shoulder` `solid` callable; `Senses.line_clear` and FightSim lines
  ask `solid_at`. PROOF (headless, red first): a synthetic world with a roof at
  +6 and one at +2 — a person walks under the first and is stopped at the
  second, a runner passes both; a flier is capped under it; a shot between two
  bodies through the roof is blocked; the shoulder eye stops under the ceiling
  (Shoulder.room share < 1 with a roof, 1 without); a climb up a face under an
  overhang is refused where the headroom is short and allowed where it is not;
  a jump under a low roof lands short of where it would in the open;
  `hero_level` under a span is the ground's. Probe cost measured (spanned
  tiles only; the unspanned path unchanged, timed).
- **S1 — drawing a span. BUILT** (see Status; the chunk-cost bar below was
  +10%, and was wrong: a span is a second land over its part of the chunk). Mesher second pass (underside, rims, top) on the
  lattice; a dev staging option (`--above=arch` / `roof` over the `--place` start, stage by
  name) that plants a synthetic span without touching worldgen. PROOF: frames
  from above and over the shoulder under an arch and under a roof edge, read
  for "not a block" (contoured edge, strata on the rims, dark underside);
  canon unchanged; chunk build time within 10% on a spanned chunk.
- **S2 — light and the section cut.** Span occlusion texture, ambient under a
  span, shafts through holes; the section cut from above with its inked cap,
  component-masked, eased in. OWNER RULING needed first (law 3 vs spans as
  architecture). PROOF: a tour walking under a synthetic roof: frame outside
  (roof whole), frame under (section cut, player readable, cap inked), frame
  under a hole (a shaft of light); the same under the shoulder view (ceiling
  close, crowd rule framing).
- **S3 — cave roofs (limestone caves).** `GenAbove` ROOF + holes;
  limestone_caves declares `above.roof`. GEN bump. COST TARGET, before any cave
  is roofed: a roofed cave chunk within +25% of the same chunk bare. The span
  pass runs on the chunk worker only for chunks with spans (as now), keeps its
  lattice samples per chunk so a rebuild does not redo the warp, and draws the
  wholly-roofed interior of a hall as merged runs top and bottom (only its
  edge cells marched), with the drips moved into the shader. Measured on a
  cave chunk with test_spans' method before and after. PROOF: parity re-accepted;
  the caves tour: halls read as halls (a roof, dark, shafts through holes),
  from above and over the shoulder; walk tests: every portal/shaft reachable
  under the roof (no hall sealed by low headroom).
- **S4 — overhangs and arches on the surface** (crags, mesas: declared per
  landscape). GEN bump. PROOF: parity; tours standing under an overhang and
  under an arch, both views; a test that no overhang closes a path the terraces
  left open (headroom ≥ person on every overhang tile adjacent to a walkable
  one, or the tile was already a cliff).
- **S5 — islands, seen but not walked.** ISLAND plan rows over a crater field
  (the owner's landscape idea), far impostors. GEN bump. PROOF: frames from the
  ground (the underside keels overhead, shadow on the field) and from the
  horizon (silhouettes).
- **S6 — walking on a span (layers).** Separate design review first: body
  layer, WorldQuery per layer, transitions (ramps, ladders, grapple, crafts),
  AI pathing, the shoulder probe per layer, saves storing the player's layer.
  PROOF: walk tests across a ramp onto an island top and back, a machine
  following the player up, save/load on an island top.

## 8. Risks and open questions

- **Law 3 (the land never opens)** vs a roof over the player seen from above —
  the owner's ruling decides S2 (section-cut as architecture, or the lens drops
  to the shoulder under a roof).
- **One span per tile** forbids a cave roof under an island; fine until asked.
- **Headroom closes paths:** every content slice needs a reachability test, or
  a roof can seal a region (as the niche gap did in the maintenance bay).
- **Every direct `level` reader** (FightSim lines and `hero_level`, Climb,
  Jump.plan, spawners, colossus treads, crafts' decks, the ground-top bounds) must move to `TileWindow` before S0 is
  done — the streaming slice that introduces it should land first.
- **Machines' behaviour under roofs** (a harvester's reach, a flier's patrol
  height) needs roster fields, not special cases.
