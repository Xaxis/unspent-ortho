# UNSPENT — the look: LANTERN

**The world is lit, not drawn.** No ink, wash, hatch, paper or filter between
the player and the place: geometry, material and light, in a dark world where
a light is something a person carries. The owner chose it after rejecting
twelve directions as "papery": *"ONE right one, unique and amazing."*

## What it must never be

- **Nothing like Minecraft or any voxel game** (owner). The tile grid belongs to
  the rules, never to the eye: no square tile, no cube, no box read as a
  building block. Terrain is contour terraces; grounds meet on ragged curves.
- Not generic low-poly, HD-2D, cel-shaded anime or 16-bit cosplay.
- Ask of any frame: *does it say what was lost and what the machines are
  doing, and is it haunting?*

## Dystopia lives in the content

- Every landscape shows ruin: dead infrastructure, the machines' order cut
  across the land, wreckage, warning signs nobody reads, poisoned water,
  graves, people patching technology in the gaps.
- **Neon, rain-slick streets and deep dark are accents where they belong**
  (machine districts, relay lines, the metropolis, shacks running stolen neon,
  storms, night), never a filter over everything (owner's correction). In more
  rural settings we see abandoned high tech implements at times, everything is
  a type of ruin though high-tech does still exist in places.

## The three laws

1. **Matter is honest.** A surface is what it is made of and what happened to
   it. Wear builds up by world position, so the same machine rusts down its
   flanks in the bog and blooms white in its seams on the salt.
2. **Light is the author.** A real sun that casts, many local lights, volumetric
   air, bounce, wet ground that mirrors. **Night is really dark**, which is
   what makes a lantern matter. The machines' light is cold, exact, ruled and
   aimed; a person's is warm, small and unsteady. That contrast is the
   signature.
3. **The world has thickness.** Things pass between the camera and the player;
   fog lies between planes; weather falls at several depths; distance is air,
   not haze. **Nothing in front may hide what the player must see.** Crowns,
   foreground pieces and anything built above 3 units are cut where they draw
   over the player, as a stipple, never a fade. The land itself never opens.

## Two materials, and where they meet

- **MADE** (`world.gdshader`): land, plants, houses, people, tools. Timber,
  mud, thatch, cloth, turf: rough, matte, nothing quite straight.
- **FOUND** (`found.gdshader`): machines, pylons, plate. Panelled, ruled metal
  with real specular and seams that catch the light; exact, symmetric, violet.
- **MENDED** is where they meet, and it is most of the tech a person uses:
  FOUND parts bound to a MADE frame with cord, strap and pitch. Both halves show
  in the silhouette and each keeps its own material. The join is the drawing:
  never hide it, compose on it.

## Shapes

- **Terrain:** contour terraces with strata walls.
- **Plants:** jagged clusters and tiers. A pine is 3–5 drooping, offset tiers,
  never a cone. Wind moves each with its own phase, never in unison.
- **Rocks:** faceted, leaning, split; never a sphere or a cube.
- **Houses:** leaning walls, sagging ridges, plate-patched roofs. The same kind
  built twice is not the same shape. Some enclaves of houses are seemingly more
  modern depending on landscape and region.
- **People:** chunky, about 4.6 heads, big head and hands, hems that swing.
- **Machines:** exact and perfectly regular in gait. Cold built-in lamps show
  state: what it thinks of you, eyes that lock when it has seen you.
- **Aliens:** though rare, are variants of the species imagined by humans:
  grays, repitillian, more alien machines perhaps.

## Readability

- **A fight is never hidden.** The player and every machine read against any
  ground, at any hour, under any wear.
- **A machine is a dark mass by day.** Its body sits below the turf in value,
  and the amber lens is the only saturated thing on it. Frost and salt may
  brighten what faces the sky; the flanks and the silhouette keep their mass.
- **People** have no black outline. A rim holds their silhouette, and it is
  the only outline in the game. They are the only warm moving thing on screen.
- Working parts are the brightest warm pixels except fire and lamps.
- Nothing is written over a fight unless the player asked for it.

## What the player builds and wears

- A holding is **crooked, patched, growing and cared for** against ruler-straight
  wreckage. It moves from MADE, to MENDED, to stolen FOUND pieces, and those are
  what a machine comes for.
- A place shows its state before any readout does (smoke, lit windows).
  **Dusk is when a settlement is most beautiful.**
- Damage is shown in the shape, never a tint. Defences look hand-made.
- Gear shows on the body. Rarity reads as strangeness, never sparkle or a
  rarity colour. Elite materials keep their landscape's colour.

## The slate

- Every screen is an app on one tablet hacked from spare parts: a display
  stolen from a machine (FOUND, violet) in a patched bezel (MADE: tape, solder).
- Honest about being salvaged (dead pixel columns, a shimmer on waking), never
  at the cost of legibility.
- Phosphor text on dark glass with one warning colour. Machine data shows in
  the module's violet. A body's tag has no words: pips and one glyph.
- Drawn in the 1920x1080 base's own pixels, whole numbers of `UiBase.PITCH`,
  never filtered. The scan drops hue, so meaning rides on shape, not colour.

## Desktop and web

- Forward+ on desktop; Compatibility on the web. **The web is the same place on
  a worse night**, not a diagram of it. The expensive parts are approximated:
  depth fog stands in for volumetrics and a blur for near depth of field.
- A quality tier spends render scale, never window size.

## Rules a shader must keep

- Every colour reaches `ALBEDO` through `matter_albedo()`, and emission through
  `matter_light()` (`src/render/matter.gdshaderinc`).
- No lit shader has a `light()`: it says what the surface is and the renderer
  lights it.
- Transparent world geometry needs a deliberate `render_priority`: at 0 it is
  painted over. Prefer a discard stipple in the opaque pass.

## Review, every visible change

Look at the pictures at noon, dusk and night; for FOUND work, also in the
gallery under two landscapes' wear (`--scene=gallery --wear=coast,snowfield`).
Hunt for square edges, pure black, and neon or rain out of place.
