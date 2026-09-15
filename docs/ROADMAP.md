# Roadmap

Destination: `docs/VISION.md`.

Milestones end in something a person can play. Work inside a milestone runs as
parallel packages, each in its own worktree with its own directories, merged
one at a time behind `tools/check.sh`.

## M0 — Foundation (done, 2026-09-15)

Godot 4.7 project; seeded coast; orthographic 640x360 pixel look with hard
shadows and ink outlines; walkable; headless tests; 2-second real-frame
screenshots; gallery; world map; the gate in ~11 s; contracts for parallel work.

## M1 — The core loop (integrated, 2026-09-15)

Goal: wake on a beautiful coast, take from it, make a better tool, meet a machine
and beat it by finding its working side, survive a night, walk into a second
country and feel the land change.

The nine packages (worldgen, landscape, sky, machines, characters, survival,
fight, ui, audio) are merged on main behind one gate, and the loop is proven by
three tours through real input: `tours/core_loop.tour`, `tours/countries.tour`
and `tours/fight.tour` (commands in CLAUDE.md).

### What is true

- **Start.** A 512-tile island, Coast in the south to the Snowfield and the
  Burning in the north. A normal new game (seed 1) wakes beside the south coast
  village's square (fire, bench, lamp) with the sea below it, in about 1.2-1.3 s
  (world gen ~0.6 s, first view and systems ~0.6 s); chunks past the first ring
  stream from a worker.
- **The land.** Contour terraces with strata walls per country, graded
  ecotones (the neighbour's plain wash first, its broken grounds near the
  border), decor and props for every kind, rivers, pools, falls, roads, cables.
  Coast steps are earth banks. The Burning lies under warm low light with glass
  clinker pools, glowing vent mouths, breathing vents and basalt walls.
- **Sky.** Day and night per the source, blue-ink night, weather drawn in ink,
  regional light, lamp and fire pools that erase hatching on land, machines,
  people and water alike; outlines turn blue at night.
- **Machines.** Twelve FOUND machines on cold, dirty violet ramps with amber
  lenses that glow; telegraph poses; parts that flare when struck.
- **People and animals.** Rimmed, unoutlined people with builds, looks, held
  tools and action animations; villagers and village animals; animal mobs
  varied by seed.
- **Survival.** Taking with tools and hardness, a strand laid by the spawn, a
  scree outcrop with iron within ~30 tiles, fires, stations, 40+ recipes,
  eating, sleeping, wetness from the weather underfoot, lamp oil. A bot makes an
  iron axe on seeds 1 and 2 inside three game days and ten real minutes.
- **Fight.** Real-time swing, dodge, wind, plate side, grip and pull, outcomes
  (downed, carried), spawning by country, ground and hour.
- **Notebook.** HUD, making and carrying pages driven by survival's own
  helpers, map, pause, title, place names lettered at each border.
- **Audio.** Beds per country and weather, machine loops, every emitted sound
  mapped, an arrival phrase per country.

### Gaps (carried into M2 unless fixed sooner)

- Diagonal roads still show small tile steps at close zoom; ground boundaries
  are chosen per lattice point from the four tiles round it.
- Some ecotones still carry a large patch of the neighbour's darker ground
  (seed 1 coast-moss); the coast-moss band on the heath reads as a blotch.
- The harvester still reads light at noon at fight zoom; the cutter reads as a
  parasol edge on; the dredger shows its legs on land.
- A hit flash swaps `material_override` for ~60 ms (no shader flash uniform on
  figures or people yet).
- Warden arrests do not move the player; linemen do not climb; land hazards and
  people threats (design-extract §8.2) are not built.
- Wool, yarn, blanket, oilcloth and the rig kit cannot be made; no salt pan;
  tide gates are off until the water visibly moves.
- Villagers vanish at night instead of going in; fauna has no pathfinding.
- Audio is judged by spectrogram only; web builds without threads get no beds
  or music.
- The map's E zoom wraps 6x to 1x; region labels can crowd on tiny countries.
- The gallery plinth is a plain box (review scene only).
- Fight moments in tours are real-time: the tours retry a missed blow (`try`),
  and a hidden macOS window can stall a single shot until its timeout.

## M2.0 — Ink & Neon (first)

The owner's look for the whole game: beautifully dystopian, dark rain-slicked
neon-lit wastelands, cyberpunk landscapes of ordered chaos and mystery, with haunting
evolving synth ambient music (VISION §8). It comes before new landscape content, so
every type is born in it.

1. **Style core** (lead): palette v2 (dark wet ramps plus neon families), wet sheen and
   rain-slick reflection streaks, neon light pools that erase hatching, haze and light
   shafts, a night-first sky, and ART.md rewritten as Ink & Neon.
2. **Wave N** (parallel, on the core):
   - **landscape-neon**: the six landscapes relit and re-dressed with neon props.
   - **sky-rain**: rain-first weather, puddles, runoff, shafts, lightning.
   - **machines-neon**: strip lights, scanners, beacons, working parts as neon.
   - **characters-neon**: rain gear, stolen tech worn, light rims.
   - **score**: generative evolving synth ambient music and a new sound bed per
     landscape.
   - **slate**: the hacked-tablet UI.
   - **saves**.
   - **export**.

## M2 — Foundations of an immense world

Build the spines that twenty landscapes, realms, sentinels and crafts hang on, so
content never needs a rewrite.

**Wave A** (parallel, after M2.0; slate, saves and export already moved into wave N):
- **biomes**: the landscape-type registry; the six countries become data with no
  regression; worldgen composes regions from types; two new types, Salt Flats and
  Scrapwood, as proof.
- **saves**: a registry where every system saves itself; slots, autosave, Continue.
- **hazards**: one pressure model, resistances from modular gear, abilities through
  one interface; five abilities; the MENDED idiom.
- **disposition**: machine roles, indifference, interference per region, and stealth
  read on the machine itself.
- **slate**: every UI screen and the HUD rebuilt as one hacked tablet made from spare
  parts (ART.md §9), replacing the notebook pages one for one.
- **export**: web (threads and no-threads) and macOS; loading page; `tools/web.sh`
  boot check.

**Wave B** (parallel, on top of A):
- **realms**: realms and portals; the first underground type (Limestone Caves,
  drawn as scratchboard); the first era (The Before, drawn in watercolour) with
  edits that carry into the present.
- **sentinels**: the boss spine, plus the Coast and Salt Flats sentinels, each beatable
  three ways.
- **crafts**: the vehicle spine; raft, hover sled, walker rig.
- **tech**: the mended tech tree, with 20+ implements and 15+ modules.
- **works**: machine depots that feed patrols, can be broken and let a region recover.
- **landmarks**: 3-5 kinds per type, worth the walk.

## M3 — The landscapes

Grow to at least 20 landscape types, each with its own props, decor, life, weather,
light, hazards, enemies, landmarks and **sentinel**, and fill every realm.

- **Surface families**, built in parallel:
  - wet: Drowned City, Frost Sea
  - dry: Glass Desert, Mesas
  - machine-made: Server Fields, Grey Orchards
  - urban: **Ruined Metropolis** (towers, tiered highways, living machine districts
    beside dead ones), with the Undercroft beneath it
- **Underground:** Crystal Hollows, the Adits, Magma Vaults, Rootways, Undercroft.
- **Orbital realm:** Tether Station, the Foundry, the Ring (graphite on black paper),
  reached by the climber craft.
- **The After:** the cyanotype era.
- **Crafts:** glider wings, drill crawler, submersible, climber.
- **Sentinels** for every new type.

## M4 — The plan and the people

- **Story:** the words, written from nothing. What the machines' ultimate plan is,
  why, and how it ends.
- **The plan:** its stages as world state, and the subarc generator (goals, methods,
  consequences).
- **People:** villages that live, barter, ask and remember; homes to claim and mend;
  interiors; the carried-off to rescue.
- **Endings:** reached through many different paths.

## M5 — Ship

Balance, performance on web, settings and accessibility, gamepad, Steam build,
the owner's release.
