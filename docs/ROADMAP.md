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
- Warden arrests do not move the player; linemen do not climb; people threats
  (design-extract §8.2) are not built.
- Wool, yarn, blanket, oilcloth and the rig kit cannot be made; tide gates are
  off until the water visibly moves. (Pressures, the MENDED sketch and the salt
  pan moved to M2 wave A; what is left of them is listed there.)
- Villagers vanish at night instead of going in; fauna has no pathfinding.
- Audio is judged by spectrogram only; web builds without threads get no beds
  or music.
- The map's E zoom wraps 6x to 1x; region labels can crowd on tiny countries.
- The gallery plinth is a plain box (review scene only).
- Fight moments in tours are real-time: the tours retry a missed blow (`try`),
  and a hidden macOS window can stall a single shot until its timeout.

## M2.0 — A dystopian world (first)

The owner's look for the whole game: beautifully dystopian in mood, art, themes and
every element of every landscape (VISION §8), with haunting evolving synth ambient
music. It comes before new landscape content, so every type is born in it.

1. **Mood core** (lead, done): a light bleak grade per landscape and hour, skyglow,
   wet reflections where wet, stippled halos, situational light (warm people, lit
   machine order, stolen neon where someone wired it in).
2. **Wave N** (integrated, 2026-09-15): landscape, sky, machines, characters,
   score, slate, saves, export, merged one at a time behind `tools/check.sh` and
   proved by their own tours.

### What is true

- **The land says what happened.** 25 new prop kinds of evidence: fences, graves,
  barricades, shacks (one in two with stolen neon wired in), drowned and burnt
  cars, beached hulls, stumps, fire towers, and the machines' own works: warning
  signs, intakes, pump houses, pipelines, relay masts, checkpoints, the tall
  stack, drill fields, conveyors, survey posts, a burnt archive. `GenWorks` lays
  every machine work on ONE survey bearing per seed, and `WorksMap` cuts turf
  strips, drains, ruts, quarry benches, bore grids and scorched lobes into the
  ground. All of it can be salvaged: plate off debris, cars and barricades, wood
  off fences and stumps. Chunk props bake on the worker (3 ms a chunk on the main
  thread, down from 16).
- **Weather and light per landscape.** Squalls and rain on the coast, drizzle and
  dawn mist in the moss, steady rain under the pines, snow squalls and whiteouts
  on the snowfield, glare, dust devils and dry lightning over the bonelands, heat,
  ash fall and furnace haze in the burning, each with its own hour-by-hour mood.
  Lightning rolls through the cloud and stutters the machines' power; up to twelve
  lights near the camera are mirrored in wet ground and throw shafts in fog.
- **Machines tell their state.** Blinking status lamps (what it thinks of you),
  eyes that lock when it has seen you, a part that runs hot before it strikes,
  lights that go out in order as it dies; scan beams and work washes; years of
  wear and a trophy of its trade on every kind. Each machine draws in 2-6 calls
  instead of 13-25. **And by day, with nothing on them lit** (wave A): the twelve
  ramps run the violet arc by role so a worker, a keeper and a hunter are told
  apart at a glance, the body fill sits below the ground it stands on, and every
  mark on a plate is budgeted in screen pixels — plates at neighbouring ramp
  values, shadowed recesses, grime in straight runs. Every pose a fight asks a
  player to read differs in silhouette, the windup's tell hangs over the working
  part and points down at it, and a dead machine settles into a cold hulk in the
  moonlight instead of vanishing with its own light.
- **The last people.** Dressed by their land's hazards and their trade (oilskins,
  fur, respirators, goggles, salvage packs, a machine plate on the chest), thinned
  by hunger, patched where worn; a village crowd costs ~0.02-0.13 ms a person.
  Dogs, sheep and gulls have lived through the ruin too.
- **The score.** A streaming synth score per landscape (drone, pad, pulse,
  texture, grid, dissonance, phrases) driven by one conductor from the hour, the
  weather, the danger and the installations near you, over beds of wind in
  wreckage, transformer hum, gutters and rain split over the surfaces it falls on.
- **The slate.** Every screen is one hacked tablet: carrying, making, the survey,
  home, gear, machine reads and saves, with the HUD as its edge readouts and the
  title waking on its glass. The notebook is gone.
- **Saving.** Every system registers its own state; slots, autosave, Continue on
  the title, and a loading page that draws the island while a world is made.
- **It ships.** Web (threads and no threads) and macOS builds; `tools/web.sh`
  boots the build in headless Chromium, walks it with real keys, reloads it and
  proves a real save file comes back from IndexedDB.

### Gaps (what wave A did not close)

Fixed in wave A: the lantern's noon disc, the status lamp a live machine blinks,
the empty gear and reads apps, the location caption.

- The stolen neon marks drawn into the ground by `world.gdshader` (lamp codes)
  still do not follow `sky_power()`, so a tube burns steady while its pool and
  its wet-ground glint stutter. It needs a mark id of its own.
- Gulls work tips, wrecks and beached hulls; the debris the land leaves round
  every village is not refuse they will go to.
- World generation is still one blocking step on the no-threads web build, and
  it costs more since the registry landed; `Game.setup` runs its systems in one
  go, and the first frame of a world stalls while its shaders compile.
- The score has been judged by spectrograms, levels and tests, and by one listen
  on the tour; it has not had an owner's listen. Sound beds on the no-threads web
  build still need the disk cache.
- The browser check's audio test needs an audio device: on a machine whose
  headless Chromium has none it reports silence.

## Dev mode (integrated, 2026-09-16)

`docs/DEV.md`. The slate's service mode, reachable in any build whose master
configuration allows it, the web included, and proved by `tours/dev.tour` and by
a stamped web build driven in Chromium (the chord, a refusal, the readout, a note
kept in IndexedDB).

### What is true

- **Feedback and testing anywhere.** Warp to any landscape, village or landmark;
  set the hour and hold the weather; mend, feed, hide and shelter the body; give
  anything and fit gear; put any roster body down, clear the land, step a
  region's file; zoom, hide the slate's edge, take a clean picture. A readout on
  the glass's edge, and notes that keep the frame from before the slate woke, the
  state, the build, and the `tools/shot.sh` line that stages the moment again;
  restaged in-game, copied out as JSON, or downloaded on the web.
- **Master configurations.** `configs/dev`, `playtest` and `release`: identity and
  channel, dev access, the island, how a new game starts, the kit and gear, and
  live rules (clock rate, harm taken, whether bodies come, the guide), edited on
  the slate, kept to the repository, copied between copies of the game.
- **Builds on this machine.** `tools/export.sh --config=NAME` stamps what a build
  is into its pack and beside it; the slate makes builds of a configuration's
  targets in the background after reading the machine's load, keeps a shelf,
  plays a web build in the browser (`web.mjs --serve`) or the app, proves it, and
  deploys a preview or production (asked twice), recorded in its `build.json`.
  The gate, the tests, the canon sheet and every tour run from the slate with
  their frames shown.

Closed since: a configuration can fix the title to its island; hunger pace and
how many bodies come are live rules; a direction tapped and let go inside one
frame moves every app on the slate (it was lost in a game, and a browser delivers
quick taps that way).

### Gaps

- Autosave and hazard strength want rows, but `05_save` and `52_hazards` are open
  on the a2 wave's branches (saves, salt-and-scrap): added after those merge, so
  the two do not collide.
- `world.landscapes` (a build narrowed to some landscapes) needs worldgen to prove
  every subset still makes a whole island; `BiomeRegistry.mute_to` is only
  trusted by tests today.

## Targeting and the enemy read (integrated, 2026-09-16)

`docs/DESIGN.md` §Targeting. The owner's ruling that a fight may be read in
words — but only while the player asks. Proved by `tours/targeting.tour`, which
locks, cycles, sweeps, fights with the key held and lets go, and by
`tests/target/`.

### What is true

- **Every body carries a wordless tag**: health in pips and one glyph for how far
  it has got with the player (nothing, stirring, sure, coming). A machine's is
  the stolen module's violet, a creature's the slate's phosphor, both on dead
  glass so they hold over grass at noon and snow at dusk.
- **Hold `z`** and the nearest threat is locked: the camera leans in behind the
  player (yaw toward the body, a lower pitch, closer in, the frame biased between
  the two), the body is bracketed with a ring on the ground, and the slate reads
  it — health, blow, tell, speed, working part, senses, what it can do to you,
  what it has noticed and what it is thinking, all of it off the simulation.
- **`a` / `d` cycle** the lock (what is on you first, then what is near); **`r`
  sweeps** the field, the camera standing back with every body read in short;
  letting go puts the camera square and the reads away.
- **It changes no fight.** Nothing in the package writes to the simulation, and a
  test fails if a body or the player so much as turns while the key is held.

### Gaps

- A sweep reads at most eight bodies; a field bigger than that is read nearest first.
- People (villagers) carry no tag: they are not in the fight's list of bodies.
- The lock does not survive a body going out of reach for a moment — it takes the
  next one instead of waiting for it to come back.

## M2 — Foundations of an immense world

Build the spines that twenty landscapes, realms, sentinels and crafts hang on, so
content never needs a rewrite.

**Wave A** (integrated, 2026-09-15; slate, saves and export were built in wave N).
Eight packages merged one at a time behind `tools/check.sh`, each proved by its
own tour: biomes, hazards, disposition, landscape-polish, sky-polish,
machines-day, slate-polish, score-blend.

### What is true

- **A landscape is one file.** `src/content/biomes/<id>.gd` declares everything
  about a landscape — where it lies, its relief, grounds, decor, props, ore,
  sites, villages, weather, hazards, roster, sound bed and motif — and
  `BiomeRegistry` discovers it. Nothing in worldgen, the mesher, the decor, the
  sky, the sound, the spawner, the music or the map knows a landscape by name.
  Six-country parity with M1 is proved by md5, not asserted
  (`tests/biome/test_parity.gd`). **Salt Flats and Scrapwood** are the proof:
  two landscapes end to end — grounds, strata, ink marks, five prop kinds,
  machine works of their own, hazards, rosters, beds — each added as a file.
  Every connected run of a type is a REGION in `WorldData.regions`, which is
  what a plan network, and later a sentinel or a save, keys on.
- **A place presses on a body.** Sixteen pressures; a landscape declares its
  worst and the hour, the weather, the height, a roof and a fire decide how much
  is on you now. Felt first (a gauge, breath in the cold, a cough at fumes),
  then in the legs, then a slow drain that never takes the last point of health.
  Six gear slots with sockets and modules answer them, and five abilities hang
  off that gear — dash, glide, scan, grapple, signature spoof — each a real key
  with a real mark. Everything a landscape presses with has something a player
  can wear against it, so no place is a wall.
- **Machines have a place in the plan.** Every kind has a role (worker, keeper,
  watcher, hunter, recycler) and most of them do not care about a person walking
  past. What you do to them turns them: rob a relay and everything wired to it
  stops working and comes. The plan keeps a file on you per REGION, felt rather
  than read — watchers turn, a horn goes off at a works, and at the top of the
  scale the network sends a hunter. Crouch, cover, noise and a stolen signet are
  how you get past, and a machine shows it is wondering by the light on its
  working part.
- **The land reads at the zoom it is played at.** Wear, a walked line, what was
  spilt and litter in drifts on every ground; the bonelands pavement bends and
  opens instead of repeating; props are cast as well as turned; no house is a
  box and every wall is weathered with salvage against it; crowns thin over the
  player; the sea stopped foaming in the moss; and nothing in the world — the
  outline pen included — is drawn pure black.
- **Weather reads as weather.** One gloom term shared by the shader and the
  lights, so a lamp lit at noon lights nothing and its pool at night is the
  LIGHT'S colour on the ground. Hard-edged wet, a whiteout paler than the snow
  it falls on, ash that is a dark speck and snow that is a pale one, a halo that
  spills into the air at night and is only an object at noon.
- **Machines read in daylight.** Marks budgeted in screen pixels, real plates and
  recessed wells, twelve ramps on one violet arc by role, every body fill below
  the turf it stands on. Poses differ in silhouette, the tell points down at the
  working part, hit marks leave what they hit showing, and a dead machine settles
  into a cold hulk instead of a hole.
- **The slate names every key it has.** Home is a tab, the ping never strikes out
  its own letters, the landscape under the player is said the instant they are
  somewhere else, and the gear and reads apps carry this wave's own numbers.
- **The score crosses a border.** Equal-power per-layer crossfades on the world's
  own blend, sharpened or widened by how far apart two landscapes' keys are; it
  never collapses where its stems are not baked, bakes what is ahead before the
  border, and reaches full voice in 25 seconds instead of 86.

### Gaps (carried into wave B unless fixed sooner)

- **Start budget: 2.53 s against a 2.5 s target, with no headroom.** Measured on
  a quiet machine, one shot at a time: gen 1774 ms + view 752 ms, against
  1.65-1.9 s before the wave. Broken down, on the same machine in the same
  minute:
    - `BootWorld.world(1, 512)` on its own is **884 ms**, against 808 ms before
      the registry — only +9%. Worldgen itself is not where the time went.
    - The other ~890 ms of what a real start reports as "gen" is the twenty-two
      system scripts compiling on loader threads WHILE the generator runs
      (`game.gd`), and this wave added four systems and some forty scripts to
      that race. The loading page overlaps them on purpose; they now cost more
      than the thing they were overlapping.
    - `view` grew 565-704 ms -> 752 ms: more props and decor per chunk.
  So the lever named by the biomes package — generating the surface in two
  passes, one deciding the recipe per tile and one running each recipe over its
  own tile list, so the dispatch happens per RUN instead of per tile — is worth
  perhaps 80 ms of the 884. The bigger one, untouched and unmeasured, is what to
  do about script compilation racing world generation on a cold start.
- Salt Flats and Scrapwood borrow existing machine kinds (pan rakers, mirage
  decoys, recyclers and magnet swarms are named in VISION and not yet drawn).
- `BiomeDef.sentinel` and `BiomeDef.realms` are declared and validated; nothing
  reads either yet.
- `src/models/props/{houses,remains,rocks,shore,works,built}.gd` still switch on
  `Country` for per-landscape dressing, so a landscape added after the M1 six is
  dressed as the coast until they read the registry. `trees.gd` is the pattern
  (`BiomeDef.tree_tints`).
- No landscape declares radiation, resonance, EM, vacuum, pressure or time-shear
  yet: the gear that answers those is worn for landscapes still to come.
- Hazard and ability cues borrow sounds the world already has (`SoundNames`
  ALIAS), and so does the works' horn. Each wants its own voice on the sheet.
- Hazards never touch mobs: a machine standing in the burning feels nothing.
- No roster kind is a recycler yet, so the role has a rule and no body.
- The gear page fits a slot with one key and cannot choose WHICH module goes in a
  socket; `UiSketch.render` takes one `found` flag, so a MENDED thing cannot be
  sketched half by hand and half by rule.
- Ambience beds still do not play on the no-threads web build (a bed is a
  whole-buffer chain that cannot stop and resume); the score itself is fine, but
  time to full voice there is minutes.
- The bore cap and survey post still read as dark discs at 640x360 in the
  bonelands and the snowfield: above the ink floor now, but wanting a drawn
  interior and a lighter lip.
- A stolen neon tube still burns steady while its pool and its wet-ground glint
  stutter with the machines' power: the tube is a `lamp` ground mark, the same
  group as hearths and windows, and needs a mark id of its own in
  `world.gdshader` before it can follow `sky_power()`.
- `WorldData.temperature` and `moisture` are written by worldgen and read by
  nothing.

**Wave B** (parallel, on top of A):
- **realms**: realms and portals; the first underground type (Limestone Caves,
  drawn as scratchboard); the first era (The Before, drawn in watercolour) with
  edits that carry into the present.
- **sentinels**: the boss spine, plus the Coast and Salt Flats sentinels, each beatable
  three ways.
- **crafts**: the vehicle spine; raft, hover sled, walker rig.
- **gear**: the MENDED tech tree (20+ implements, 15+ modules) **plus the economy that
  places it** (VISION §6.1): five rarity grades, elite materials that exist in one or
  two landscapes or drop from one enemy or sentinel, craft difficulty by station tier,
  and modifiers that change decisions, combine, conflict, and can be re-socketed.
- **settlement**: building at world scale (VISION §9) — shelter, power, food and water,
  work stations, defence, and people who staff them; production, upkeep and repair that
  run while the player is away.
- **raids**: why and when machines come for a settlement — signature, notice as a
  playable encounter, attention, the readable escalation from survey to siege, roles in
  the raid itself, destruction, aftermath and reclaiming.
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
