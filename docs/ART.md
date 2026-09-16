# UNSPENT — the look

**Beautifully dystopian, drawn by hand.** The mood, the art and the themes are
dystopian all the way through (owner, 2026-09-15), and that lives in **what every
landscape contains**: ruin, decay, dead infrastructure, the machines' order cut
across the land, wreckage, fences and warning signs nobody reads, poisoned water,
scorched ground, graves, and people scavenging and patching technology in the gaps.
It is drawn, not rendered: flat washes, inked contours and hatched shade pinned to
the world, the land in contour terraces, the hand against the ruler. Light, weather
and colour set the mood per landscape and hour; neon, rain-slick streets and deep
dark are **accents where they belong** (machine districts, relay lines, the
metropolis, server fields, settlements running stolen tech, storms, night), never a
filter over everything.

It must look like nothing else. **Nothing like Minecraft or any voxel game**
(owner, 2026-09-15): the tile grid belongs to the rules, never to the eye. It is
also not generic low-poly, not HD-2D, not cel-shaded anime, not 16-bit cosplay.
When in doubt, ask: *does everything in this frame say what was lost and what the
machines are doing, is it drawn by a hand, and is it haunting?*

This document is binding. The research extract (`docs/research/art-audio-extract.md`)
supplies palette values, silhouettes and lighting numbers; where it conflicts with
this page, this page wins.

---

## 1. The six laws

1. **No grid.** No square tile, no cube, no axis-aligned box read as a building
   block. Terrain edges are contours; ground types meet on ragged curving edges;
   props lean, taper and sag. A `MeshKit.box()` is allowed only as a *part* that is
   then chamfered, tapered, rotated or broken up so the silhouette is not a box.
2. **Colour is a wash; value is ink.** Surfaces are flat fills from the 16 coast
   ramps. There are no gradients on geometry. Light is two bands (lit, grazing).
   Shade is the wash shifted toward blue-violet *plus hatching*. Deep shade is
   denser hatching, never black.
3. **The hand and the ruler.** MADE things (land, plants, houses, people, tools)
   use `world.gdshader`: hatched shade, paper grain, slight irregularity, the
   hand's hatch (`Ink.HAND`). FOUND things (machines, pylons, poles, plate
   salvage, glims) use `found.gdshader`: one clean shade step, **no hatching, no
   grain, no wobble**, exact symmetry, straight members, violet ramps, amber working
   parts that glow. The FOUND never looks drawn. That contrast *is* the theme.
4. **Lines are ink, not black.** Silhouettes, terrace edges and creases get lines
   from the outline pass in `Palette.INK[0]`-ish, tinted by the sky at night.
   People are the exception (see §5).
5. **Patterns belong to the world.** Every hatch, stipple, grain and dither is a
   screen-pixel pattern pinned to the world through `world_px`. Nothing swims when
   the camera moves. Nothing is a texture file.
6. **The land turns as you walk.** Each country has its own wash family, hatch
   hand, decor vocabulary, light and weather. Borders are ecotones 12-24 tiles
   deep where washes interleave on ragged edges and hatch styles dither into each
   other. Travel must feel like turning pages into a different part of the notebook.

---

## 2. Rendering (implemented in the style core)

| Piece | File | What it does |
|---|---|---|
| Image | `project.godot` | 640x360, integer upscale, nearest |
| Camera | `camera_rig.gd` | orthographic, yaw 45°, pitch 57°, texel-snapped; publishes `world_px` |
| MADE material | `world.gdshader` | wash + second wash on ragged edge, world-space patches, paper grain, two light bands, hatched shade, lamp pools in three steps, wind sway |
| FOUND material | `found.gdshader` | wash, one hard shade step, emission for working parts, keeps some brightness at night |
| Ink | `ink.gdshaderinc` / `ink.gd` | hatch styles, stipple, ragged edge, value noise, paper |
| Sky | `sky.gdshaderinc` | the only place lit colour is tinted by time, weather, region |
| Terrain | `terrain_mesher.gd` | contour terraces via marching squares on a warped elevation field; strata walls; per-vertex ground blending |
| Sea | `water.gdshader` | chart depth bands with inked band edges, lapping foam, wave ticks |
| Outline | `outline.gdshader` | ink on depth silhouettes (terrace edges come free) |

**Vertex channels** (write them through `MeshKit` state, never by hand):
`COLOR.rgb` wash · `CUSTOM0.rgb` second wash, `.a` weight · `UV.x` hatch
styles `style + style2*16`, `UV.y` style blend · `UV2.x` sway weight, `UV2.y` sway
phase (or patchiness on rigid geometry).

**Hatch hands** (`Ink`): `NONE` water/FOUND · `WIND` coast · `STIPPLE` moss ·
`UPRIGHT` pinewood · `SPARSE` snowfield · `CROSS` bonelands · `SCRIBBLE` burning ·
`HAND` made things · `CONTOUR` rock faces and terrace walls.

---

## 3. The countries

Each row is a promise the landscape, sky, decor and audio packages keep together.

| Country | Wash family | Hatch | Line character | Decor and props | Light and weather |
|---|---|---|---|---|---|
| **Coast** | grey-green turf, heath browns, pale sand, shingle grey | `WIND`: long shallow diagonals | calm, long contours; sea cliffs as stacked strata | tufts leaning with the wind, thrift in bloom, driftwood, wrack lines, mussel rock, broadleaf trees bent landward, gorse | cool clear light, fast cloud shadows, rain in columns, fog that lifts |
| **Moss** | dark turf, peat brown, black water with green edges | `STIPPLE`: dots | soft, broken edges; few cliffs | hummocks, reeds, bog cotton, dead trees with insulators, peat banks, wisps | low green-grey light, still air, mist lying in hollows |
| **Pinewood** | needle browns, dark spruce | `UPRIGHT`: vertical strokes | tall, tight contours; shafts of clearing | tiered jagged pines (never cones), deadfall, resin pines, swept needle curves | shafts of light under canopy, early dusk, rain drip |
| **Snowfield** | the page itself: near-white washes, blue shade | `SPARSE`: few long diagonals | line-dominant, minimal fill | snow-laden pines, drifts with blue lee shadow, soot in lee, poles and the tall stack | bright flat noon, blue long evening, snow as paper flecks |
| **Bonelands** | pale limestone linen, scree slate | `CROSS`: cross-hatch | cracked, broken lines; grikes as ink cuts | clints, standing stones (some cast, with rebar), cairns, bones, drill-hole rows | hard white light, heat haze, long shadows |
| **Burning** | ash greys, clinker near-black, basalt | `SCRIBBLE`: restless broken strokes | jagged, burnt-edged | vents breathing, ember glints (unhatched orange pixels), burnt ruled paper leaves, dead trees | warm low light even at noon, ash-fall specks, glow from below |

Palette values for all of the above are in `src/render/palette.gd` (from the
extract §2). Stay on the ramps. Mix between ramps only for a named reason.

**What happened is in the land** (VISION §8). Every landscape also carries the
evidence: what people made and lost (fences, graves, barricades, shacks with
stolen neon wired in, drowned or burnt cars, beached hulls, stumps, fire towers)
and what the machines put there (warning signs, intakes, pump houses, pipelines,
relay masts, checkpoints, the tall stack, drill fields, conveyors, survey posts,
a burnt archive). `GenWorks` places it per landscape and lays every machine work
on ONE survey bearing per seed, 11-31 degrees off the tile axes, so the machines'
order reads as order; `WorksMap` bakes it into the ground (turf strips, drainage
cuts, harvester ruts, quarry benches, bore grids, scorched lobes), torn at the
rim and ruled inside. Neon belongs to the machines' works, their relay lines and
the shacks that stole it — nowhere else.

---

## 4. Shapes

- **Terrain:** contour terraces (implemented). Terrace walls are strata; high cliffs
  are several stacked ledges. Lips may carry a ragged overhang of turf or snow.
- **Plants:** clusters and tiers with jagged silhouettes. A pine is 3-5 offset,
  irregular star-shaped tiers, each drooping, never a smooth cone. Broadleaf crowns
  are lumpy clusters of faceted clumps, underside hatched. Sway on crowns and tufts.
- **Rocks:** faceted, leaning, split; never a sphere, never a cube.
- **Houses (MADE):** irregular footprints, leaning walls, sagging ridges, roofs
  patched in FOUND plate (use `found.gdshader` for plate patches only), chimneys off
  true, turf banked at the foot, the struck-through enamel plate on the wall.
- **People:** chunky, about 4.6 heads, big readable head and hands, tapered 6-8
  sided limbs, coats and hems that swing. No box limbs.
- **Machines (FOUND):** exact. Chamfered, symmetric, straight members, rivet rows,
  downward streaks, one rubbed edge, per-kind violet ramp, amber working part with
  a small glow, a cold visor slit on plated faces. Their gaits are perfectly regular.
  They carry cold built-in lamps that mean state (a status lamp blinking what the
  machine thinks of you, eyes that lock when it has seen you, work lamps on the
  side it is working), a stipple scan beam or a work wash drawn as loose
  world-pinned pixels, and ruled wear: plates cut off other machines, grime in
  straight runs, spliced cable, and MADE trophies of their trade. The amber part
  stays the only warm read on them.
- **Animals:** the hand's shapes, varied by seed, readable silhouettes (wedge dog,
  brick sheep, barrel bull).

## 5. Readability rules

- The player and every machine must read against any ground at any hour, at 640x360.
- **People** get no black outline. Their silhouette is held by a one-pixel rim one
  step lighter on the side toward the light and one step darker opposite (or their
  own darkest ramp step as a line). They are the only warm moving thing on screen.
- **Working parts** are the brightest warm pixels in a frame except fire and lamps.
- Hatching never covers a face or a working part.
- UI is the quietest layer, and it is a device: see §9, the slate.

## 6. Light, night, weather

The mood core (`sky.gdshaderinc` neon_*, `outline.gdshader` halo, `sky_light.gd`
`neon_grade_at`, `15_lights.gd`):

- **The grade** is light: a bleak desaturation and a slight cool, per landscape and
  hour (`SkyLight.NEON_COUNTRY`). Day stays day and every landscape stays readable
  and distinct. Emission never passes through it.
- **Skyglow** keeps shapes readable in dusk, storms and night; nothing is pure black.
- **The evening falls and never turns back.** From half six to nine the light goes
  and the dark fills in, and the dark is spent AGAINST the light: every term that
  keeps a dark frame readable (the blue floor under the washes, the skyglow, a
  landscape's own mood) arrives no faster than the light it is filling in for, so
  no half hour of a dusk is ever brighter than the one before it. From nine a
  landscape's own light does not move again until the morning. It is measured on
  the composed picture, not on any one term (`SkyLight.frame_level`,
  `tests/sky/test_night_readable.gd`, `tours/evening.tour`), because each term
  works on a different part of the frame. A LANDSCAPE'S DUSK IS WHEN IT FALLS AND
  WHAT COLOUR IT GOES, never how far below its own night it dips.
- **Wet** where the land is wet (the moss, rain, a storm): wet flat ground is a step
  darker and mirrors lights as broken streaks. Dry landscapes stay dry.
- **Artificial light is situational and means something.** People's lamps, windows
  and fires are warm. The machines' order lights itself: beacons on the grid, strip
  lights on machines and arrays, lit districts. Stolen neon shows up where people
  wired machine light into their lives, in some houses and not all. Bright saturated
  light throws a stippled halo into rain and haze: never a smooth bloom.
- Key light from the upper left of the screen; the sun swings, never flips.
- Weather is drawn: rain as short slanted strokes, snow as flecks, ash as dark
  specks, fog as haze that softens lines and spreads halos, lightning as a flash.
- Cloud shadows drift over the land as soft-edged patches of hatch.

## 7. Motion

- Wind moves tufts, reeds and crowns with per-instance phase, never in unison.
- Water laps; wave ticks come and go on a slow beat.
- Machines move with perfect regularity; people and animals are humanised.
- Hit feedback is drawn too: a short ink burst, dust as stipple puffs, sparks off
  plate as 2-3 bright pixels. No particles that look like a physics engine.

## 8. Review checklist (every visible change)

1. Any visible square, cube or tile edge? Fix it.
2. Any gradient on a surface, smooth bloom, glossy highlight or pure black? Fix it.
3. MADE in `world.gdshader`, FOUND in `found.gdshader`, nothing mixed?
4. Does the hatch hand match the country or thing?
5. Readable at 640x360: player, machines, working parts, props that can be taken?
6. At noon, dusk and night?
7. Is it dystopian in its content (ruin, machine order, scavenged tech, what was lost),
   is the light and weather right for this landscape and hour, is it hauntingly
   beautiful? Neon and rain only where they belong.

## 9. The slate: every screen is a hacked tablet

(owner, 2026-09-15) The interface is not paper. It is a **tablet the player hacked
together from spare parts**: a display module stolen from a machine, a bezel
patched from two others, hand-soldered wiring, tape, a cracked corner that never
got fixed. The world is post-apocalyptic and still full of technology, some
scavenged and some stolen from the machines. The slate is the most personal
piece of it.

- **One device, every screen.** The HUD, carrying, making, map, pause, title,
  loadout, trade and saves are apps or overlays of the same slate. They share its
  frame, glass, type and sounds. Nothing in the UI may look like it came from
  elsewhere.
- **Two idioms in one object.** The stolen display is FOUND: exact pixels,
  machine-violet chrome, a cold light. The repairs are MADE: tape, solder blobs,
  a mismatched knob, a scratched label in the pixel font. Both show at once, like
  every mended thing.
- **The screen is honest about being salvaged.** It has a few dead pixel columns,
  a faint scan shimmer when it wakes, a slightly off-colour sub-panel where a
  replacement module sits, and brightness that dips when the lamp oil or charge is
  low. Every one is subtle and never hurts legibility.
- **The HUD is the slate's edge overlay.** Small, quiet readouts clipped to the
  corners, as if the slate were strapped to a wrist or projected on a salvaged
  lens. There is no text in a fight beyond what the readouts already show.
- **Type and colour.** Keep the crisp pixel font. Text is a phosphor tone on dark
  glass (amber or cold green; pick one and keep it), with a single warning colour.
  Machine-sourced data (scans, interference, sentinel reads) shows in the stolen
  module's violet.
- **640x360 pixel-perfect**, integer sizes only, and the same menu standard
  (up/down, enter, esc).

## 10. What the player builds (docs/VISION.md §9)

A settlement is the one place in the world made by hands rather than by the
machines or by what is left of the old world, and it has to look it. Against a
landscape of ruler-straight FOUND wreckage and slumped ruin, the player's town is
**crooked, patched, growing and cared for**.

- **Built things carry their idiom, and it shows what a place has been through.**
  A first shelter is all MADE: rough timber, lashings, thatch, hand-cut edges that
  do not meet. A holding that has salvaged well is MENDED: machine plate lashed to
  timber, a door cut from a hull, hoses and cable run along the outside of the
  walls, the seams visible and proud. A settlement running stolen technology has
  FOUND pieces in it, exact and humming and out of place, and they are the parts a
  machine will come for.
- **Nothing is prefabricated.** The same kind built twice is not the same drawing:
  pieces lean, patch differently, weather differently and grow additions. A wall is
  a run of what was to hand, not a repeated tile.
- **A place shows its state before any readout does.** Smoke says the hearth is
  lit; a spinning wind spinner and lit windows say there is power; plots show the
  season and whether anyone is tending them; open shutters mean the place is not
  afraid tonight. A player should be able to read their own signature (VISION §9.4)
  from a hillside, before opening the slate.
- **Dusk is when a settlement is most beautiful**, and the lit town must be worth
  defending: lamps and hearth light pooled on wet ground and on faces, warm against
  the cold machine violet, the one honest light in the landscape. That beauty is
  the whole point of the raid system: it is what the player stands to lose.
- **Damage is drawn, not tinted.** A struck wall loses pieces, leans and shows
  what it is made of; a burnt plot is black stalks; a ruined piece stays where it
  fell. After a raid the yard tells the story: wrecked machines, scorched ground,
  scattered stores, the gap where a piece used to stand. Mending is visible too,
  so a place that has survived three raids looks like it.
- **Defences are obviously hand-made and obviously desperate**: sharpened stakes,
  a ditch, netting strung on poles, a turret bodged from a machine's own arm and
  fed by cable from the battery stack. Nothing looks issued.

## 11. Gear the player made, worn where it can be seen (docs/VISION.md §6.1)

- **A build is visible on the body.** Every piece of gear and every modifier that
  matters is drawn on the player: a cooling loop is coiled tube across the back, a
  capacitor bank is three stolen cells strapped at the hip, a phase coil glows
  faintly through a coat. Someone watching should be able to guess what the player
  is built for.
- **Rarity reads as strangeness, not as sparkle.** There are no glowing rarity
  colours and no outlines. A prime piece looks like something that came out of a
  place other people do not go; a relic looks wrong, exact and older or newer than
  everything around it. The clue is the idiom and the finish, never a tint.
- **Elite materials keep their landscape's colour and hand**, so a piece carries
  where it came from: bone glass is pale and translucent, tide iron is pitted and
  rust-bled, fulgurite is black glass with a lightning grain, foundry alloy is cold
  and perfect. A player should recognise the land in the tool.
- **Mended is the default, and it must never look tidy.** FOUND parts bound with
  MADE cord, mismatched fixings, a hand-scratched mark where the maker checked it.

## 12. MENDED: the third idiom

Law 3 sets the hand against the ruler. **Mended** things are where they meet, and
they are most of the high tech a person actually uses (VISION §6): FOUND parts a
human cut down, drilled and bound to a MADE frame with cord, strap and pitch. A
mended thing is never one material: **both idioms are in the silhouette at
once**, and a frame must be able to tell you which half is which.

- **The found half keeps its rules.** Panels and housings are `found.gdshader`:
  exact, symmetric, chamfered, unhatched, straight-edged, in the violet PLATE
  ramps, any working part amber. Cut edges are ruled, and a plate cut off a
  bigger machine still carries the rivet rows it was cut through.
- **The made half keeps its rules.** Spars, hafts, straps, lashings and patches
  are `world.gdshader` with `Ink.HAND`: hatched, slightly crooked, in earth, sand
  and linen washes. Where a cord crosses a panel it sits a little off true.
- **The join is the drawing.** The reason to look at a mended thing is the seam:
  lashing over a straight edge, a strap through a drilled hole, pitch at the foot
  of a spar. Never hide the join; compose on it.
- **Nothing hatched on the plate, nothing ruled on the cord.** If the two halves
  share one material override, it is wrong.
- **On the slate** a mended item's icon uses both palettes in one 9x9: the body
  in machine violet, the binding and haft in phosphor (`UiIcons.colours_for`).
  MADE items stay wholly phosphor, FOUND wholly violet.
- The tier lives in the data: `Items` field `tier` = `made | mended | found`, read
  through `Gear.is_mended`. The first mended things are the glide wing (drawn in
  the world by `src/models/gear/glide_wing_model.gd`, open and folded in the
  gallery: `tools/shot.sh shots/g.png --scene=gallery --filter=wing`), the
  heat-sink vest, rebreather, magnet boots,
  scanner lens, the spring coil and the foil lining.

The slate is the same idiom at interface scale (§9, "two idioms in one object"):
a stolen display in a patched bezel.
