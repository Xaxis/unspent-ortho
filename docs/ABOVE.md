# GROUND ABOVE THE GROUND: geometry over the heightfield

Contract for the built mass over tiles (S0-S3: the reads, drawing, the section cut, cave roofs), and the spec for overhangs, arches, islands and layers (S4-S6, unbuilt).

## Status

| Slice | What | State |
|---|---|---|
| S0 | `WorldData.overhead` and its reads, asked by walk, sight, jump, climb and the shoulder eye | built |
| S1 | `TerrainMesher._spans` draws it; `--above=arch\|roof` stages one (AboveStage) | built |
| S2 | `AboveMap` + `43_above`: the section cut from above, shade and daylight under mass | built |
| S3 | `GenAbove` roofs the limestone caves (GEN 37) | built |
| S4 | overhangs and arches on the surface | spec |
| S5 | islands, seen but not walked | spec |
| S6 | walking on a span (layers) | spec |

## 1. Data (built)

- `WorldData.overhead`: per tile, `under` and `over` levels (the same units as
  `WorldData.level`, STEP 0.5) and a kind; at most one span per tile. Stored by 256-tile
  section, three bytes a tile (`put_overhead_section`), bounded by `overhead_box`.
- Reads, the only door: `overhead_at`, `headroom_at`, `solid_at`, `has_overhead` (makes the
  unspanned world free), `overhead_tops`. Writes: `set_overhead` (staging, interiors) and
  worldgen's sections; nothing at runtime writes a span.
- Each landscape DECLARES what it grows (`BiomeDef.above`); nothing branches on a
  landscape by name. `BiomeDef.above` is a TERRAIN field in `WorldStamp`: changing it moves
  seeds and bumps GEN.
- Spans are generated, never saved. If roofs ever become destructible: a sparse delta keyed
  by tile, and `SaveCore.disagrees` must check the player's headroom on load.

## 2. Walk and collision (built, Phase A: nothing stands on a span)

- A body walks under a span only when the headroom clears its height (roster `height`;
  the player `FightSim.HERO_TALL`, crouched `HERO_CROUCH_TALL`). A low roof is a wall to a
  person and a crawlway to a runner (`WorldQuery.passable`/`move_body` `tall`).
- **Sight and lines:** `Senses` asks `solid_at` on the line at body middle
  (`SIGHT_HEIGHT` 0.9), so a roof between two bodies blocks as a wall does.
- **Jump:** the arc is tested against the lid; a jump under a low roof comes down where the
  roof stops it (`src/core/jump.gd`).
- **Climb:** a climb is only as tall as the headroom over its top; a face whose top is under
  a span with less than a body's headroom is not a climb. A span's underside is not a face:
  nothing climbs a ceiling (`src/core/climb.gd`). `FightSim.hero_level` stays the tile's.
- **Fliers:** the glide (`AbilityMotion`) is held its own height below an underside, stalls
  where the room is less, skims a top without landing, and is never set down under mass.
  The plan's traffic flies its lane over the top and drops its light there
  (`FlierView.surface`).
- Machines under roofs read roster fields, never special cases (`NavField.for_body` asks
  headroom).

## 3. Camera (built)

- **The shoulder eye** (`Shoulder.box_over`, 41_shoulder) treats mass overhead as solid: under
  a roof the eye is pulled in against the ceiling as against a wall, and the crowd rule
  frames it. The near plane never slices an underside.
- **The top view.** **RULED** (2026-09-26, through teammate1; the owner told and not
  overruling): a span is drawn as **ARCHITECTURE, not land** — the same
  language interiors already use: from above, a span over the player's region is
  drawn **cut at the section plane** (the player's level + `SECTION` ≈ 2.4 m)
  with an inked cap along the cut, exactly as a room's near walls are cut at
  `InteriorKind.cut` with an inked top. Nothing is stippled open; the roof is
  sectioned, the way a plan drawing sections a building. Outside the player's
  region the roof is drawn whole (the cave from above is a closed dark mass with
  its holes lit). Rules (43_above):
  - the section region is the span's CONNECTED COMPONENT under/around the player
    (a cave hall), not a disc — a disc through rock reads as a hole; a roof across
    plateaus is one mass;
  - the cut eases in as the player walks under, and stands down over the shoulder;
  - the mass's outline is chalked dashed on the ground under it (a plan's convention for
    what is above the cut); the shadow pass keeps the whole mass;
  - `sight_cone` and `tall_cut` stay off land; the section cut is a span rule.
  - Dropping the lens to the shoulder view under a roof is a player OPTION, never the
    default.

## 4. Rendering (built)

- **Mesher** (`TerrainMesher._spans`, on the worker, only for chunks with spans): the span
  mask contoured through the terrace warp (less of it, so a drawn edge never puts a head
  through rock): never a tile-stepped block. Top (lifted, UV2.y +512: no wear, trampling or
  works), banded rim, darker underside (drips are world.gdshader `hung_rock`, not geometry).
- **Core runs:** where a tile's three by three is one level mass, cells are drawn in merged
  runs and only edges are marched, so a chunk wholly under one mass is one top, underside
  and section (`tests/render/test_spans.gd` `HALL_BAR`).
- **AboveMap** (`src/core/above_map.gd`, its header is the texture layout): one texel a tile
  over the spans' box (a window of 96 round the player in a cave, rebuilt on a worker), with
  the day's glow off the nearest open sky, 0 by `BOUNCE_REACH` 12 tiles in. World.gdshader
  shades the ground under mass (`ABOVE_SHADE`) and cuts the mass the player is under.
- **Under the lid the hall is still seen** (`BiomeDef.cave_light`): the ground and walls near
  the player read, cold seams glint, the far hall is dark.
- **Far land** (`world_far.gd`): a roofed tile is its roof's top out there
  (`overhead_tops`, painted the landscape's plain ground), roof out to the horizon.

## 5. Cave roofs (built, S3)

`GenAbove` (`src/core/worldgen/gen_above.gd`), the last worldgen stage, roofs a landscape that
declares `above.roof` (the limestone caves: `room 6, clear 3, step 4, thick 4, tear 3.0,
shaft 3.5`):
- the underside is the highest floor within `clear` tiles (by 4x4 blocks) plus `room`
  levels, rounded UP to a multiple of `step`, `thick` levels deep;
- **the roof is TERRACED**, level plateaus, never a smooth field: a roof whose height changes
  everywhere has no core and takes the slow mesher path on every chunk;
- open over the dome's tears (the daylight columns 11_dome draws) and every shaft's mouth;
- every roofed tile stands at least `room` levels over its own floor, so a person walks
  everywhere they walked before, and every portal stays reachable.

## 6. Spec: what is not built

- **Shapes still to grow**, each a plan row with a stable key, rasterised as a pure function
  of (row, tile) so both sections of an edge agree:
  - `OVERHANG`: a cliff lip out 1-3 tiles over the terrace below; `over` the upper
    terrace, `under` = `over` minus thickness.
  - `ARCH`: a polyline between two anchors on high ground; underside a catenary.
  - `ISLAND`: a disc or blob over a region (the owner's crater field), underside a rounded
    keel, top a terraced field of its own.
- **S4, overhangs and arches** (crags, mesas, declared per landscape). GEN bump. Proof:
  parity; tours under an overhang and an arch, both views; a test that no overhang closes a
  path the terraces left open (headroom of a person on every overhang tile beside a
  walkable one, or the tile was already a cliff).
- **S5, islands, seen but not walked.** GEN bump. Islands and arches on the horizon need a
  far impostor with an underside (a lid on the heightfield cannot draw the gap). Proof:
  frames from the ground (keels overhead, shadow on the field) and from the horizon.
- **S6, layers (Phase B).** Bodies gain a layer (0 ground, 1 span top); `pos` stays 2D,
  `WorldQuery` takes the layer. Transitions are explicit: a ramp (a span edge within one
  level of the ground), a ladder, rope or lift prop, a grapple, a craft. A climb may top out
  on a span's `over` where its rim is marked climbable. Pathing, the shoulder probe and
  saves learn layers. Design review before any code. Proof: a ramp onto an island top and
  back, a machine following, save and load up there.
- **Risks:** one span per tile forbids a roof under an island (fine until asked); every
  content slice needs a reachability test, or headroom can seal a region.

## Proof

Recipes: `.claude/skills/verify/features/world-look.md`, 43_above.
