# ENGINE — the rendering layer, audited

The owner asked (2026-09-18) for the whole rendering layer to be researched,
refined and refactored: best practice, organisation, consistency, better
graphics, better performance. Four read-only audits ran over `src/render/`,
`src/models/` and the render-facing systems — correctness, performance,
structure, and what would raise the ceiling. This file is what they found, in
the order it is worth doing, with the measurements attached.

**The standard this wave is held to is not "perfect".** Perfect is not a state
anyone can check. The standard is: every finding below is either FIXED, or
DECLINED IN WRITING with the reason. A line that is neither is unfinished work.

## The two rules the audits produced

**A SPEEDUP THAT MOVES A TILE IS NOT A SPEEDUP.** See CLAUDE.md's Conventions.
World generation is 13 s and its two biggest stages (`settle.roads` 2,408 ms,
`shape` 3,296 ms) are deliberately untouched, because every way to make them
cheaper changes where roads and land land, which moves every seed and costs a
parity re-acceptance and a re-shoot of every frame in the repository — paid to
speed up something the owner has said in writing he does not wait on.

**AN INSTRUMENT THAT CANNOT REPORT ITS OWN GAP FAILS TOWARD GREEN.** The chunk
stats line named 36 ms of a 46 ms build and looked complete, because
`Decor.build_arrays` and `bake_props` are the view's work and the mesher's
profile cannot see them. It prints `unaccounted` now. **Do that first for any
new instrument**; it is how six-of-seven stages got quoted as the whole cost.

## What the instrument says now (seed 4, M3 Max, 1920x1080, `high`)

| | 6 chunks at the coast village | 30 chunks, zoom 60 |
|---|---|---|
| build avg | 80.9 ms | 57.1 ms |
| props | **29.1** | 10.1 |
| cells | 12.0 | 11.6 |
| lattice | 10.2 | 10.2 |
| water | 10.2 | 8.5 |
| decor | 4.7 | 3.5 |
| main thread | 3.5 | 4.2 |
| unaccounted | 0.0 | 0.0 |
| verts/chunk | 17,616 | 18,506 |

`props` is spiky — it sits where the buildings are — and it was invisible until
this table existed. Do not plan against `lattice` before reading `props`.

## Done

- The coarse far world (`world_far.gd`), the chunk park, the capped reach, and
  the clip planes following the frame. See `433cf68`.
- The self-checking stats line and the dry-chunk water gate. See `fe783a4`.

## 1. Correctness — things that change a frame today

1. ~~~8 unshaded draw paths write raw sRGB into `ALBEDO`~~ — **FIXED at
   `23b4a13`, except `mob_fx`.** The lantern and every lit window pane
   (`_glow_mat`, which is a `StandardMaterial3D` and so cannot call the door —
   it gets `vertex_color_is_srgb` from `Quality.forward_plus()` instead), the
   scan beams, the working-part halos, the survival marks and the light shafts.
   `mob_fx.gd:405/:476/:508` are deliberately NOT done: they are open task #90's
   and two people fixing one file is a merge, not a fix.
   **Two things came out of it worth keeping.** First, the test named six
   shaders and all six already obeyed, so it could not fail and never did; it
   sweeps the tree now and found two more the moment it could. Second, **there
   are two doors and nobody had written down the second**: `matter_albedo()`
   converts in the fragment off `sky_linear`, and a `uniform vec3 x :
   source_color` converts when the uniform is SET, per renderer — the same
   decision made once instead of per pixel, and the better door for a colour
   constant over a draw. `rays.gdshader` uses the second correctly and is
   excused by name; the excuse is checked. `precip.gdshader` used it for its
   three colours and then mixed them toward `SKY_PAGE`, a raw palette const, so
   lit rain and snow were driven toward a page colour in the wrong space on one
   renderer. That one was found BY the new sweep, not by the audit.
2. **`found.gdshader`'s `wear_take` is documented, read, and never written.** It
   occurs twice in the whole repository, both in that file, so every FOUND
   surface wears at 1.0 and trips `matter_worn`'s `amount > 0.5` seam branch. A
   working machine is as rusted and seamed as scrap off a wreck: law 1's "a
   machine still on its round is kept" has never once been rendered. NOTE before
   starting: the FOUND material is shared per chunk, so this cannot be a uniform
   set per prop — it wants a vertex channel (`ARRAY_CUSTOM1` is free) or a
   deliberate global. That decision is the task.
3. ~~`PAN_GATE` is lit where it has no strip~~ — **FIXED at `5143320`, and it was
   far bigger than the audit found.** 142 of the 884 lit props on seed 7 were lit
   off a model that is not the one on screen: 74 houses, 47 shacks, 16 murals,
   two pump houses, two fire towers, one pan gate. THREE readers went through the
   kind-only door — the pool a machine casts, the glow quad drawn over it, and
   `_front_of`, which places a house's hearth — so all three agreed with each
   other and all three disagreed with the mesh the chunk baked, which is why it
   never looked obviously broken. And the house branch **could not see the
   variant even if it had asked**: `country` and `variant` were declared inside
   the `PLACED_SOURCES` branch and the HOUSE branch is its sibling. The cache
   keyed on kind alone, so the first prop of a kind to be indexed decided for
   every other one in the world — the bug could not be corrected per prop even
   where a caller knew better. `tests/sky/test_glow_variant.gd` now reads the
   shipped source and fails on any `glow_points(` call with fewer than three
   arguments, and the old call was put back and watched to fail before the test
   was trusted. A comment did not hold this: `15_lights` states the rule in full,
   twenty lines below the branch that broke it.
4. **Delete every `country: int = Country.COAST` default in `prop_models.gd`**
   (seven doors) and give `mesh()`/`found_surface()` the real signature. Still
   open, and finding 3 is the argument for it: the fix there was per-call-site,
   so the next kind that grows a variant-dependent glow point walks into the same
   hole. The compiler naming all ~15 call sites is what closes it for good —
   worth most right before landscapes 12-20. `52_survival_fx.gd:464`
   (`PropModels.mesh(prop.kind)`, a felled tree snapping to the coast's variant
   0) is the other live caller.
5. `salt.gd:22` declares its own cyan `STRIP` and hands it to `15_lights` as a
   light colour, where every other machine strip is `Works.STRIP` pale lilac.
   `15_lights.gd:159-163` already fixed this same inlined-cyan bug for
   `MACHINE_COLD` and left this copy standing.

## 2. The image — what `form` actually still means

**The measurement that makes the rest of this list wrong-from-the-640x360-era:**
at play zoom the frame is 26.67 world units across 1920 px = **72 px per world
unit**. A 0.02 chamfer was 0.48 px and is now 1.4. A 4-sided `strut` of radius
0.04 is a 5.8 px **square bar**.

1. **MADE geometry has ONE material row in the whole game.** `matter_of()` has 19
   rows for grounds and cliff strata and returns one default for every timber
   post, thatched roof, canvas awning, concrete slab, glass pane and rope
   lashing. Under one sun, only the mesh normal tells a roof from a wall — and
   the normals are flat facets. **This is most of what still reads as papery.**
   Spec: band 80..95 (71..79 left as a deliberate collision gap), twelve rows
   (TIMBER, THATCH, CLOTH, ROPE, CLAY, CONCRETE, GLASS, TAR, ENAMEL, HIDE, BONE,
   CUTSTONE). Three traps, each of which will otherwise waste the builder's day:
   - `matter_of().z` only SCALES a height field. With no `matter_height` branch,
     thatch at relief 0.030 gets tile-wide land lumps, not straw.
   - `matter_height` is keyed on `wp.xz` alone, so **a vertical face gets a
     smeared streak instead of a grain**. It has never shown because the land is
     near-horizontal, and a village is walls. A dominant-axis pick off
     `abs(n_world)` is part of this task, not a follow-up.
   - Glass at specular 0.90 will throw the noon sun into the lens at 57 degrees.
     Measure it the way `FOUND_MASS` was measured, on a frame.
   - Rows within 0.05 of each other are erased by `matter_worn`'s own ±0.4 and
     are not worth adding.
2. **Welding reaches 4 call sites out of 64 model files, and zero machines.**
   `smooth_begin`/`smooth_end` — which `mesh_kit.gd:186-193` and CLAUDE.md both
   present as THE API — have **no callers anywhere**. Every lathe, loft, disc,
   tbar and cbox on every machine and sentinel is flat-shaded. Two auditors found
   this independently. `MeshKit.build` passes normals straight through,
   `sway_by_height` writes uv2s only, and `Broken.work_down` rebuilds normals
   itself — so the existing `smooth_range` is CORRECT and the job is to call it.
   **The caveat that makes it a wave and not an afternoon:** `smooth_range` welds
   within `[from, to)`, i.e. per shape. A hull emitted as eight `cbox` calls
   still has eight hard seams. Deciding whether to bracket an assembly or each
   call is a judgement about where creases belong, per model.
   Add a test that fails on a builder emitting one position with 3+ distinct
   normals and no crease, or this silently reverts.
3. **96 of 167 `strut` calls pass n=4; 18 pass n=3.** `Kit.hoop` hard-codes 4,
   `Kit.cable` hard-codes 3, and no shared side-count constant exists. Triangles
   are not the wall — a dozen machines at 3600 is 43k, a fifth of one terrain
   chunk — but re-check each model against the 3600 cap.
4. Audit `cbox` call sites passing `ch = 0`. A chamfer is 1.4 px now and catches
   a specular line on every edge: the cheapest metal cue there is.
5. **Nothing hangs LOW.** `fore_kinds.gd:59-79` lifts every piece 1.9-6.0 units,
   all overhead, so the bottom edge of the frame is where the world stops. A near
   occluder at the bottom is the strongest read this camera has, and `near_focus`
   already blurs it. Same machinery, new lift band, two shapes.

## 3. Frame and build cost — same output, less time

Ranked; all counted off the source, milliseconds unmeasured except where noted.

1. `_vtop` (`terrain_mesher.gd:1380-1392`): per vertex, one method call, **six
   `append()` MethodBind calls** and four object constructions. Two of the six
   write constants (`_tn` is always UP for tops; `_tuv2.x` is always 0). Write by
   index against a high-water-mark `resize`. Same mistake in `_water_quad`
   (`:2037-2052`), twelve appends per quad.
2. `ARRAY_CUSTOM0` (`:1341`): `_tc0.to_byte_array().to_float32_array()` is two
   full copies of the colour array per chunk plus a `Color()` per vertex. Make
   `_tc0` a `PackedFloat32Array` and write four floats by index — the bytes
   handed to `add_surface_from_arrays` are identical.
3. `_water_arrays` (`:1352-1355`) allocates and fills a whole normal array with
   one constant per chunk. Keep one reusable buffer at a high-water mark.
4. Two distance fields recomputed per chunk over an immutable world (6.0 ms
   combined): `_shore_window` computes a 56x56 window to serve 36x36 and adjacent
   chunks recompute the overlap; `Transitions.fill` does a 68x68 for a 36x36 ring
   with a `w.in_bounds()` method call per output tile. Both are pure functions of
   a frozen world — verified nothing outside `src/core/worldgen/` writes
   `level`/`ground`/`country`/`country2`/`blend`. Compute once per 128-tile block.
5. Per frame: `Survival.use_target()` runs **4x** (`15_lights.gd:297` and `:301`,
   `90_ui.gd:443`, `51_harvest.gd:61`), each a ~49-cell scan with 3 sqrt per
   candidate and a fresh Callable per candidate. `_update_glints`
   (`15_lights.gd:810-866`) escaped the 0.25 s throttle its sibling sits behind
   and allocates ~40 Dictionaries a frame. `get_nodes_in_group(&"mobs")` runs 4x.
   `46_settlements.gd:1002` and `47_defences.gd:58` build a string key per piece
   per physics tick. `sky_light.gd:520-522` writes ~30 globals with no dirty
   check and computes `tint_at(hour)` twice.
6. Draw calls, same pixels: `holo_view.gd:197-203` is 10 nodes on one shared
   additive material; `flier_view.gd:183-201` is 2 nodes per flier over two
   cached meshes. Both are exact MultiMesh candidates.
7. **Nothing holds people to a draw budget** while machines are capped at 6.
   A person is 3 draws; the Slums declares 30 street folk — 90 draws and 60
   shadow draws from people alone.

## 4. Measurements to run before building anything

- `perf foliage` — `props_leaf` casts shadows and **nobody ever decided that**
  (`world_view.gd:709-717` sets no `cast_shadow` while both its neighbours do).
  The material is `cull_disabled` and alpha-`discard`, so the shadow pass runs a
  full alpha-tested fragment shader over both faces of every leaf card in every
  loaded chunk. The finding is that it was never chosen, not that it is wrong.
- **Compatibility draws ≤8 omni + 8 spot PER MESH RESOURCE**, and a 32-tile chunk
  bakes its props into ONE mesh while `web` gives `lamps: 8`. `quality.gd:46-53`
  already records "the coast greens have eleven sources within fourteen tiles".
  Lights may be silently dropping on the web today. Get a frame before building
  anything for the city.
- SSAO is listed as supported on Compatibility and is OFF on `web` and `low`.
  LOOK.md records it moving the web frame -3 luma with "cost unmeasured".
- Do the fore layer's shadows land? `fore_view.gd` casts out to REACH 22.0 tiles
  while the sun has ONE split sized for ~15 units.
- `directional_shadow_max_distance = 50` is set once at `_ready` and never
  re-derived, while `--zoom` writes `view_height` directly — so past about
  `--zoom=62` the far edge of the frame stops casting. That one is a bug.

## 5. Declined, with reasons

- **World generation** (13.6 s) — see the rule at the top.
- **SSR** — broken under orthographic projection in Godot (godot#79002, #11841)
  and absent from Compatibility. Consequence worth saying out loud: LOOK law 2's
  "wet ground that mirrors" is undeliverable without changing the camera.
- **SDFGI / VoxelGI / LightmapGI** — Forward+ only, or want a bake; the world is
  generated per seed at boot, so there is nothing to bake ahead of time.
- **TAA / FSR2** — the occlusion language is a world-pinned stipple resolved with
  `discard`, chosen OVER a fade deliberately; TAA smears it into the fade that
  was refused, and the sway is vertex animation with no motion vectors.
- **Decals** — not supported on Compatibility.
- **Occlusion culling** — at 57 degrees from above with 4-9 chunks live, nothing
  occludes anything.
- **LOD / visibility ranges** — available and pointless: under ortho everything
  in frame sits within ~10 units of the same depth. The chunk/`WorldFar` split is
  the only LOD with any range to act over, and it exists.
- **GPU particles** — Compatibility has no compute shaders, so `GPUParticles3D`
  silently does not render there. `CPUParticles3D` is correct and must stay.
- **MultiMesh for chunk props** — `bake_props` already collapses a chunk to 6
  draws; it would help bake time and memory, not the image.
- **Contact shadows** — not in 4.7; they land in 4.8 (godot#118045). For a camera
  whose whole subject is where things meet the ground this is the highest-value
  thing on the horizon. Plan for it; do not build it.
- **HDR output** — every canon frame and every `same A B TOL` is SDR, so turning
  it on changes what a screenshot MEANS. Owner's call, not a wave's.
- **MSAA** — keep, and try 2x on `web` (currently 0). It is the only AA the web
  can have and it will not touch the stipple, because `discard` kills all samples
  of a fragment. Leave alpha-to-coverage alone (broken in Compatibility,
  godot#98173, and `test_depth.gd:246-258` fails on ALPHA there on purpose).

## 6. The one question only the owner can answer

**Under orthographic projection there is no motion parallax at all.** Near and
far translate on screen at exactly the same rate as the camera follows the
player. That is the real reason the world reads as one plane, and no number of
hanging boughs fixes it — which is why the depth wave's answer (occlusion, aerial
perspective, shadow, depth of field) was the correct one, and the game now has
all four.

If he wants real parallax AND wet ground that mirrors, there is exactly one
lever: a very narrow-FOV perspective camera (8-12 degrees at a proportionally
larger distance) reads as orthographic at this framing but restores parallax,
real DOF falloff and working SSR. The cost lands in frozen code — `fore_cut`,
`tall_cut` and `crown_cut` all assume a constant lean of `1/tan(pitch)` that
becomes position-dependent under perspective, and `CameraRig._apply`'s texel
snapping assumes an ortho basis. **Get a side-by-side frame in front of him
before anyone commits to it.**

## 7. Structure — what to refactor, and what it prevents

Ranked by future breakage prevented. Full inventory of all 113 files, with split
seams for everything over 800 lines, is in the audit transcript.

1. The `PropModels` defaults (see Correctness 4) — the only one that converts a
   silent bug into a compile error.
2. `Kit` / `Parts.hand/ruled` / `FoundKit` are three parallel MADE-vs-FOUND
   idioms and **CLAUDE.md names the one used by the fewest files**. `Kit` is the
   right shape (the only one that carries leaves); move it to `src/models/kit.gd`
   with a `class_name`, fold `Parts.hand/ruled` into it, fix the CLAUDE.md line.
3. `face`/`slab`/`plate`/`cable` exist on both `Kit` and `FoundKit` meaning
   different things. Rename the FOUND four.
4. The ground colour table is built three times (`GroundColors._ensure`,
   `TerrainMesher._init`, `WorldFar.tables`) and the far world added two more
   hand copies (the 0.03 parity step, the sea colour). Expose `packed_wash()`
   and `hands()` from `GroundColors`; put the sea colour beside `WATER_Y`.
5. **The ink outlived the ink.** 14 landscapes set `d.hatch = Ink.SPARSE`, which
   is now a MATERIAL ROW index chosen through a constant whose doc comment reads
   "the page does the work". Rename `BiomeDef.hatch` → `ground_style`, `Ink` →
   `GroundStyle`; split `ink.gdshaderinc` into `noise.gdshaderinc` (the 13 lit
   shaders use only `ink_hash`/`ink_vnoise`) and `map_ink.gdshaderinc`; delete
   `ink_style`, `ink_edge`, `paper` (zero callers).
6. Dead, proven zero references: `smooth_begin`/`smooth_end`,
   `RealmGate.glow_points`, `EraGate.glow_points` (which spells the key "colour"
   where every other spells "color" — second-order proof nothing read it),
   `GroundColors.morph`, `WorldView.water_material`, `weather_view._texel`,
   `fore_kinds.M_ROCK`, `machine_model.cold_mesh`, `skin_rig.bone_global`,
   `person_model.stature`. Six dead helpers in `sky.gdshaderinc` plus their
   constants, and two dead uniforms (`ink_tint`, `shade_tint` in two files).
7. `src/core` reaches into `src/render` at seven places, one of them
   `save_core.gd:222` calling the PRIVATE `WorldView._key_of` from the pure
   headless save module. Move it to `WorldData.chunk_of(p)`.
8. `PX` claims to be one screen pixel and is 2.8 of them, in four copies, and its
   numerator is 14 where `VIEW_HEIGHT` is 15. Every rivet, seam and scribed line
   in the FOUND vocabulary is budgeted in it. One `CameraRig.world_px()`.
9. `world.gdshader` is two shaders sharing a name: ~1060 lines of ground-mark
   pattern library that only fires for the ground band 40..70, and ~530 lines of
   MADE material that draws every prop, house and built piece. Every prop pays
   the parse and branch cost. Split `ground_marks.gdshaderinc`.
10. Ten hand-rolled static caches, two with locks, and the invariant that keeps
    that correct is written in exactly one comment. One `ModelCache` helper.

## 8. Stale contracts found (fix as you pass)

- `mesh_kit.gd:3` and `:24-27` — the file a form builder reads FIRST still says
  "flat normals" and calls `style`/`style2` "Ink channels — Hatch style ids".
- CLAUDE.md Figures row: "people draw after the outline pass". There is no
  outline pass. Same in the Realms row ("hatch, night ink").
- `docs/LOOK.md:110-112` — the machine budget is 3600, not 2000.
- Three `src/render/weather/` headers describe a pen-and-notebook pipeline that
  no longer exists; only `bolt_draw.gd`'s is still true.
- `15_lights.gd:7` carries the lamp count that the comment six lines below it
  corrected.
- `Quality` tier `low` has `near_focus` false AND `near_stand_in` false, so a
  foreground bough is razor sharp there — exactly the failure the `web` row's
  own comment was written to prevent. Looks like an oversight, not a choice.
