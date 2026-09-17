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
- **`a` / `d` cycle** the lock (what is on you first, then what is near, then the
  last people); **`r` sweeps** the field, the camera standing back with the field
  read in short, eight at a time and paged by the same keys, the panel saying
  which page of how many; letting go puts the camera square and the reads away.
- **A person is a subject too.** `TargetSubject` is one thing the slate can be put
  on — a fight body or a villager — and a person reads as a person: their trade,
  their village, what they carry and what they are doing, and no health, no
  signature, no working part. They carry no tag, because nothing measured a
  villager's life and nothing has noticed them. Anything else the player can look
  at (a works, a station, a sentinel) becomes readable by getting a `from_*` there.
- **A lock waits** `Targeting.LOST_GRACE` for a subject that steps out of the list,
  so a machine behind a house for a moment is still the machine being read.
- **It changes no fight.** Nothing in the package writes to the simulation, and a
  test fails if a body or the player so much as turns while the key is held.

### Gaps

- Only bodies and villagers are subjects today. A works, a station, a sentinel or
  a prop cannot be read, though the door is one `from_*` on `TargetSubject`.
- The paged sweep is proved in a tour with people (`--folk=8`), not machines: a
  field of that many hunters put down beside the player ends the run before the
  shutter falls. The mixed field (machines first, then people) is proved in tests
  and in `shots/target/`.

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

Wave A2 below closed the ones a playtest and an art review of this wave found:
saves opening a different island in silence, machines saying nothing by day, no
evening at all, the salt flats clipping to paper, marks louder than their
subjects, houses as prisms, the slate talking over its own badges, and tour
frames that did not hold what they were named for. What is listed here is what
wave A left that A2 did not take on.

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

  **Read again 2026-09-16, and what is already spent.** The start now compiles 25
  systems (22 when the budget was written), 288 scripts, 3.3 MB of GDScript, and
  wave B adds to all three. **A start number is only taken on a quiet machine**:
  `pgrep -x godot` empty and `sysctl -n vm.loadavg` under ~3. Taken under four
  builders (load 29) the same three shots read gen 2075/2163/2283 ms + view
  885/809/917 ms, and the gate's own worldgen line read 1356 ms for world 1 at
  512 against 884 ms quiet — the generator and the race stretch together, so
  numbers taken under load say only that nothing has fallen off a cliff.

  Three levers are already spent, and nobody should propose them again:
  landscape scripts are requested before everything else (`BootPage`), a title's
  page has the loader threads compile the game's systems once the title is up
  (`_after_lift`), so New game waits on none of them, and scripts export as
  compressed binary tokens (`script_export_mode=2`), so a build parses no text.
  What is left, biggest first: the shader compile on the first drawn frame of a
  cold web start (the page's `draw` stage carries a 1200 ms weight and nothing
  has ever been done about it); `view`'s props and decor per chunk; and the
  surface two-pass, which is the smallest of the three and the only one that can
  invalidate every save on disk — it must keep `tests/biome/test_parity.gd`'s
  md5s or it has changed what a seed makes, and that bumps `WorldStamp.GEN`.
- Salt Flats and Scrapwood borrow existing machine kinds (pan rakers, mirage
  decoys, recyclers and magnet swarms are named in VISION and not yet drawn).
- `BiomeDef.realms` is declared and validated; nothing reads it yet.
  (`BiomeDef.sentinel` is now the door the sentinels package comes through.)
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
  `world.gdshader` before it can follow `sky_power()`. (A2 moved the tube to the
  roof edge where the camera can see it, and put one near every village square;
  it did not give it a mark of its own, so it is now visibly steady rather than
  invisibly steady.)
- `WorldData.temperature` and `moisture` are written by worldgen and read by
  nothing.

**Wave A2** (the fix wave, integrated, 2026-09-16). One playtest and one art
review of wave A, answered by eight packages merged one at a time behind the
gate: saves, machine-read, evening, salt-and-scrap, marks-and-body, houses,
slate-hud, proofs. Every fix was measured on the reviewer's own frame where
there was one, and every package brought its own tour.

Every one of the eight reported the same red gate, and each proved independently
that it was not theirs: `test_exit` gave the loading page a 900-FRAME budget for
a world generated on a worker THREAD, so headless frames ran out seconds before
the thread finished and `quit()` then blocked on it. It is a clock scaled by
`TestCase.machine_slack()` now, and the gate is green for the whole wave — the
lesson being that a wall-clock or frame budget for threaded work is a gate that
fails on a busy laptop and teaches everybody to ignore it.

### What A2 made true

- **A save is refused, never misplaced.** A save keeps only its seed and grows
  the world again, so adding Salt Flats and Scrapwood moved a mean 9% of every
  world's tiles into another landscape and 17.7% to another height — and the
  game opened those saves in silence and stood the player in the sea. Every save
  now carries a `WorldStamp` of the registry's ordered ids and the 38 `BiomeDef`
  fields worldgen reads; a build that cannot make that island says so in the
  game's own voice, on the saves app and on the title, with the file untouched
  and its header still showing the day, the picture and the place it holds.
  `SaveCore.disagrees` is the second line for what no stamp can see into.
- **A machine can be read in daylight, before it is close enough to matter.**
  The four dispositions were not a ladder at noon — hostile was the DIMMEST of
  them. Now a wash whose strength is the disposition, a strip of lit pips on the
  deck, a lens that keeps its cold colour under the sun, and only a machine the
  plan has turned lights the ground it means to cross. The harvester also stops
  being a filled box: its unloading spout is carried out over the far flank, and
  where the arm sits is the state it is in.
- **There is an evening.** Seven in the evening was brighter than eight in the
  morning, and bluer, and the whole day ended in one cliff at half past eight.
  The night floor and the skyglow are now spent against the LIGHT the evening is
  losing rather than against the clock: the coast falls 102 → 69 without once
  turning back, its worst half hour costs 9 values instead of 39, and the dusk
  warms as it goes down. Night and noon do not move by one per cent.
- **Nothing lit reaches the page.** `neon_grade.x` is a gain and it is one number
  for the whole frame, so any pale land seen from a dark one was multiplied onto
  it: the salt flats went 18.7% flat pure white with nothing drawn in it. A
  shoulder at the top of the grade fixes it at the cause — below the knee the
  other landscapes measure identically — and the two new lands stop being dressed
  as the coast, with a second wash, a shade band, their own cracked hatch and a
  landscape's own colour for its inland water. The two packages that meet at a
  salt flat at dusk turned out to help each other: the 0.29% of the scrapwood's
  dusk that the shoulder alone could not hold was the light's own energy over an
  albedo already at the ceiling, and the evening's fall takes it to 0.00%.
  Measured on integrated main: salt flats at noon, the coast-salt border and the
  scrapwood at dusk all read 0.00% pure white, the snowfield 0.06%.
- **A mark stops shouting over the thing it is about.** A hit whited out the
  whole machine, hiding the amber part the blow was aimed at; the dash painted an
  opaque slab over the player; the grapple's line was not on screen at all; the
  scan's halo was a lattice as wide as the machine; and breath was drawn in ink,
  which on snow is soot. Each is now smaller and quieter than its subject, and
  the crouch has a silhouette a player can read from 45 degrees up.
- **A village is hand-built.** Every roof slope is a patchwork laid cell by cell
  with wavering eaves, a room added on and turf banked where the camera can
  see it; no two houses in a village share a silhouette on any seed. Two causes
  were underneath: hipped roofs were pitched from the footing corners, so three
  variants of eight had no wall-to-roof junction at all, and the turf was banked
  inside the wall line where the eave hides it. The stolen neon runs along the
  roof edge now, and every village deals a lit house nearest its square.
- **The slate says less and shows more.** A line whose subject is already a gauge
  on the glass flares that gauge instead of being written across the world; the
  one warning colour goes back to meaning level 3; the place name sits on its own
  scrap so it reads over snow at noon; the loading page is a screen of the same
  device; the survey letters its names over ground cleared outright; and the
  reads app names the work rather than the mark it left.
- **A tour frame says what it is of.** `shot NAME with SUBJECT` is asked again at
  the instant the shutter falls, and a frame that fails is deleted rather than
  left on disk looking like evidence. Twenty-one frames across nine tours were
  named for a body that was not in them — including the machines tour's opening
  portrait, where the keeper had arrested the player and walked off before the
  picture was taken. `tests/tours/test_tour_claims.gd` reads the whole of
  `tours/` and holds every tour in it to five rules, so a tour written next wave
  meets them too.
- **Running all thirty-five together found what running one at a time could
  not.** Continuing a saved game could crash: `main.gd`'s ready line checked its
  scene was alive, awaited a drawn frame, then read the scene's name — and the
  title frees itself the instant it hands over to a loaded game. `await game`
  meant "the systems are wired", which is true while the loading page still
  covers the screen, so a tour continuing a save photographed the page at 98% and
  called it the world that came back; on a quieter machine it would have passed
  and the frame would have been a picture of a progress bar. `ground KIND` meant
  "a tile of this kind", and in a spawn village the houses work made busier the
  nearest grass had a bench 1.6 tiles off, so `use` answered "bench - make" and
  the fire the tour came to lay was never laid. And `pixels:` asked for the flat
  palette value of a neon tube, which emission never delivers — three frames with
  the tube plainly in them were being thrown away as frames that only claimed
  one.

### The canon, re-accepted deliberately (2026-09-16)

All eighteen frames moved, and each was looked at beside the one it replaced
before the set was taken. What the numbers say, accepted-to-now:

- **The day stops being blue.** Warmth (mean R−B) goes from strongly negative to
  about neutral on every daylight frame — spawn-morning −17.6 → +2.6, coast −10.0
  → +8.3, moss −22.5 → −6.3, pinewood −14.6 → +2.3, coast-moss −19.7 → −2.9. That
  is the old low-light term, which read a warm tint as a dark one and laid the
  night's blue floor over a morning.
- **12-spawn-dusk is the wave in one frame**: 118.0 → 83.2 luminance and −26.3 →
  +8.5 warmth, so half past seven no longer reads brighter and bluer than eight in
  the morning. It is also the clearest picture of the houses: patchwork slate, an
  added-on room, a wavering ridge and a stolen tube where there were seven ruled
  prisms.
- **09-eco-pinewood-snowfield loses 2.50% → 0.01% pure white** — the single
  biggest thing the grade's shoulder bought back. That snow now carries contours,
  blue shadow and stipple where it was flat paper.
- **The night is untouched, as promised**: spawn-night 65.8 → 66.3, night-lamp
  66.8 → 67.1, village-wet-night 56.8 → 57.4, all under 1%, and only ~20% of their
  pixels differ at all — the houses and their stolen neon, nothing else.
- **16-burning-dusk** loses three pressure lines written across the world and its
  alarm-orange badges, and gains a lit ground under every vent.
- **18-stolen-neon-close finally holds stolen neon**: 1128 tube pixels against 0
  at any tolerance in the frame it replaces, which was a coast at night with no
  tube anywhere in it. The frame had been lying about its own subject.

### Gaps A2 leaves

- The Burning's vent core is still a solid pure-white disc about 10 px across
  (art finding 16). It wants a two-step amber/white read and a broken circle, and
  it reads WORSE than before now that the ground under it is lit. It is in
  `src/models/props/`, which no A2 package owned.
- The hauler is the next machine at the silhouette bar (0.73 alert against 0.75),
  and the harvester and hauler seen END-ON fill 0.69 and 0.68 of their boxes.
  Both are slabs; getting either under 0.6 means rebuilding the body rather than
  adding to it. Three cheap routes were tried on the harvester and every one made
  the end-on fill worse; the numbers are in the test so nobody repeats them.
- **`tours/wild.tour` fails about one run in three, and it is not this wave's
  doing.** It is the one tour of unscripted emergent play — three minutes of a new
  seed-1 game, nothing spawned or teleported — and it runs with `--fail-downed`.
  After `await mob` it stands still for 13.6 s taking eight frames of a runner
  "on its round, not yet noticing", and sometimes the runner notices and downs a
  player who is doing nothing. Measured over six runs: four through, two downed,
  the downing always during the passive watch and never in the fight block after
  it. NOT an A2 regression — `src/core/fight`, `src/core/mobs` and
  `tuning.gd` are untouched by the whole wave, `Senses` reads
  `FightRules.nightfall`, which is also untouched, and the tour runs in daylight
  where that term is zero. It was left alone rather than quietly trimmed, because
  a tour is not weakened to make it pass: either the passive watch should end when
  the machine notices instead of running a fixed 13.6 s, or being downed while
  standing still in front of a hunter is correct and the tour should not claim
  otherwise.
- **The sky's evening and the body's night are two different curves.** A2 widened
  the look of dusk to 18:30-21:00, but `FightRules.nightfall` — which
  `Hazards._hour_shift` rides, and with it cold, dark, heat, glare, magnetism and
  thirst, and which `Survival.in_the_dark` also reads — is still flat zero until
  20:00. So at seven in the evening a player now stands in a visibly deep dusk on
  a snowfield whose cold is behaving exactly as it does at noon: measured on seed
  1, the snowfield place is at level 3, so its declared 0.7 cold is worth 0.434
  against a BITE of 0.55 and cannot bite until about 20:20. The hazards file's
  own docstring promises "a snowfield at noon is felt; the same snowfield at dusk
  bites", and that promise is now false for the hour a player reads as dusk.
  Whoever owns the night's feel should put the two on one curve; it was left
  alone here because `FightRules.nightfall` also drives fights, stealth and the
  dark hand's reach, and that is a feel change with its own wave.
- A residual 5-10% rise at 20:30 survives in the burning, the moss and the
  snowfield. The floor and the skyglow together are worth about three quarters of
  a dark wash, and the arithmetic limit for a monotone evening is 0.78 — the test
  walks the same ten minutes and says so. Closing it properly means bringing
  `SKY_NIGHT_FLOOR` down, which retunes the night.
- Daylight BEFORE noon is 8-15% darker and much warmer across the canon landscape
  frames. That is the night's blue floor and the skyglow no longer being laid
  over a morning by a low-light term that read a warm tint as a dark one. It
  reads as morning and it is warmer, which is what ART asks of a low sun, but it
  is a real change to every daylight frame.
- The crouched player is still one of the brightest things on screen (body-box
  mean 124 against a frame mean of 84). A2 fixed the silhouette, which is what
  the art finding asked; the dressing and the lighting belong to `PersonLook`.
- Home (`ui_pause_screen.gd`) is the other half of the empty-glass finding and is
  untouched, and the reads app's replacement sub-panel is still ~75% glass by the
  8px-cell metric — its instrument is a circular sweep, so most of that pane is
  glass by construction.
- `WorldStamp.GEN` is a hand lever: nothing can see into `GenShape` or
  `GenRelief`, so a worldgen stage that changes what a seed makes must bump it by
  hand, and `SaveCore.disagrees` only checks the one tile the player stood on.
  The stamp also cannot digest the BODIES of a landscape's surface and scatter
  recipes, only the method and file they came from.
- **Every save on every player's disk today is invalidated by this wave.** The
  island genuinely differs, so the data has nowhere valid to land. That is the
  design and not a shortfall, but it is said out loud.
- `SkyLight.MAX_LAMPS` is still 8, and that budget is now shared by lamps,
  windows, fires, kilns, vents AND live machines: in the Burning at night the
  nearest eight win and the rest lay nothing.
- The scrapwood's ground still reads brown-mauve rather than the green-brown
  gloom its own file promises, and its scrap trees are dense enough at play zoom
  that the ruled bar across every crown is a repeated motif.
- `tests/render/test_ground_washes.gd` is scoped to the two new landscapes. The
  unscoped rule fails on all six M1 types; most are benign, but pinewood's gravel
  (118 against its own brightest 87) and the bonelands' limestone (192 against
  141) look like real minor faults.

**Wave B**, replanned 2026-09-16 after taking stock. Two of the packages this
list used to name are already built and on main — **sentinels** (the spine and
two designs) and **crafts** (the spine and its rides) — and a second session has
since built dev mode, master configurations and stamped builds, which was M5 work
arriving early. What is left is the world's reach, its economy, and the thing the
owner asked for that nothing yet does:

- **realms**: realms and portals; the first underground type (Limestone Caves,
  scratchboard); the first era (The Before, watercolour) with edits that carry
  into the present. The largest gap in VISION and the last of its spines.
- **gear**: the MENDED tech tree and the economy that places it (VISION §6.1) on
  the contract already on main (`src/core/loot/`): rarity, elite materials tied to
  one or two landscapes or to one enemy, craft difficulty, and modifiers that
  change decisions. Sentinels now exist to drop from.
- **settlement**: building at world scale (VISION §9) on the contract already on
  main (`src/core/settlement/`): shelter, power, food and water, work, defence,
  and people who staff them.
- **raids**: why and when the machines come for it — signature, notice as a
  playable encounter, attention, and the readable escalation to a siege.
- **works and landmarks**: the depots that feed the patrols and can be broken,
  and the places worth the walk that feed the economy its materials.
- **polish**: what A2 left, listed in "Gaps A2 leaves" — the Burning's vents
  (the ugliest thing in the build), the targeting tag standing in the world, a
  machine with no mass at play distance, the ruts stamped five to a frame,
  survivable day two, and a loading page with no deadline.

Then **M3** grows the landscape types (Ruined Metropolis and its Undercroft
first), each with its own sentinel and landmarks on the spines that now exist;
**M4** is the plan, the people and the story; **M5** is ship, already part-built
by dev mode's configurations and builds.

### Sentinels (wave B, built)

`docs/VISION.md` §3. A landscape's keeper is one file under
`src/core/sentinel/designs/`, claimed by name in that landscape's own file
(`BiomeDef.sentinel`), and every REGION of that type grows its own instance from
it. Proved by `tours/sentinels.tour` and `tests/sentinel/`.

#### What is true

- **A keeper stands at the work it keeps.** One per region above
  `Sentinels.MIN_TILES`, at the first of the design's own station landmarks
  (`intake`, `sea_wall`, `pans`, `brine_house`…) that its region holds, and never
  within `Sentinels.CLEAR_OF_HOME` of where the player wakes. Deterministic, so
  it can be walked to twice. Its body comes out when the player is near and is
  culled by the coast when they leave; what has been done to it — its health, the
  phase it reached, whether it fell and how — lives in `SentinelState` and is saved.
- **A phase is a roster row.** Entering one rewrites the live body's own copy of
  its row (part, guarded, bite, speeds, turn), so the fight, the senses, the poses
  and the enemy read under `z` all tell the truth about what it is NOW without
  knowing what a sentinel is. The side a player has to be on moves as it comes
  apart, and nothing says so but the body (`second_act`, drawn by 40_fight).
- **Three ways each, and none of them is trading hits** (`SentinelWay`, pure
  rules over a `SentinelLook`): force (its working part, opening by opening),
  founder (ground that will not carry it — the coast's tide flats, the flats' own
  pans), starve (its works robbed until it stands dark) and spoof (inside its
  guard with a signature it reads as one of its own; it stands down and is never
  killed). The reaper offers force, founder and starve; the rake force, founder
  and spoof.
- **Its fall changes the region.** It stops holding its ground, the score's motif
  stops with its beacon, its table is rolled into the player's hands once and for
  good (`src/core/loot`), and a keeper that was killed leaves a hulk where it fell
  that is saved with the world. `Events.sentinel_woke/phase/fell` is the door for
  whatever else the plan should make of a region whose keeper has gone.
- **Two drawings**: the reaper, an arch on two tracks with a drum of amber under
  the front (the one silhouette on the coast with daylight through it), and the
  rake, a delta on four stilts under a mirror. Both on the keeper's ramp, both in
  the gallery (`--filter=sentinel`, `--filter=sentinel_beside` for scale).

#### Gaps

- A keeper has no machine loop of its own: `SoundMachines.RACKET` is keyed by the
  tail of a roster id, and `sentinel.coast` has none, so it is heard through the
  score's motif and `Racket`'s line but makes no sound of its own.
- Its drop table names a core (`reaper_core`, `rake_core`) declared in `Materials`
  as coming from it and nowhere else, but there is no item row to carry one yet:
  `src/content/items.gd` belongs to the gear package this wave, so the core is a
  promise on the table until that lands.
- The tour proves the fight and the phases; it does not kill it. Five or six more
  of the same pass against a boss measures the runner, not the game, so the death,
  the phases, the openings and what a fall changes are proved headless in
  `tests/sentinel/test_fight.gd`.
- A keeper standing on the only work that feeds it cannot be starved, and a region
  with no tide flat inside its reach cannot founder one: some ways are open in
  some regions, which is VISION's own "the more a player understands the
  landscape, the more ways they see" — but nothing yet tells a player which.
- Nothing lowers a region's interference when its keeper falls (VISION §9.7):
  `sentinel_fell` is emitted and the disposition package has still to listen.
- A keeper that stood down keeps blinking its role's disposition: 32_disposition
  writes every live body's lamps from role and interference, four times a second.

### Wave B: what the realms package made true

- **A realm is a world of its own** (`src/core/realm/`). `BiomeDef.realms` is read
  at last: `GenContext` lays only the landscape types registered in the realm its
  world is being grown for, so a surface island is exactly the island it was and
  nothing under the world can appear on it. Each realm's world is grown from the
  game's one seed with the realm's own salt (`Realm.seed_for`), raised once and
  kept (`RealmWorlds`), and the game holds one of them at a time.
- **`Realm` is the authority over its own light, sky, weather and sound**, and a
  landscape declares them THROUGH it: `limestone_caves.gd` takes `Realm.light`,
  `Realm.lift`, `Realm.airs` and `Realm.bed` and colours inside them. The one
  thing no landscape file can say is that the HOUR has stopped mattering, so
  `SkyLight.closed` reads a roofed realm as night at any time of day — the blue
  floor, the hatch, the night ink, the lamp's pool and no cast shadows.
- **A portal is a place** (`Portals`, `RealmGate`): a shaft the machines sank at a
  cliff foot, inland, clear of the villages and of where the player wakes, laid
  deterministically per REGION and paired with the shaft of the same number on the
  far side. It is a hole in the ground with a headframe over it and a ladder
  somebody hung in it, it is in `WorldData.landmarks` so the map and a tour can
  find it by name, and it is entered by standing on it and pressing `use`.
- **A crossing does not make a new game** (`src/systems/20_realms.gd`): the world,
  the query, the body, its simulation and the view are pointed at the other realm,
  which is why the score, the sound, the clock and what is carried all survive it
  (`tours/realms.tour` awaits `score_unbroken` across both crossings).
- **Limestone Caves**, drawn as scratchboard: a near-black page of wet limestone,
  pale calcite flowstone massing on the rises and along the water, terrace walls
  bedded in calcite, black sumps that are still a chart, and the machines' drills,
  pipe runs and graves. `--realm=underground` opens a shot or a tour in it.

Gaps it leaves for the rest of the wave:

- The map, the explored ground and the lights' source index are not rebuilt on a
  crossing: `20_realms` calls `realm_changed(from, to)` on every system that has
  it, and none does yet (90_ui and 15_lights are the two that want it).
- The core save's world state is ONE realm's. What each realm had TAKEN out of it
  comes back (the realms key carries it); what was BUILT in another realm does not.
- The flooded bottom of a cave system is still drawn as the sea, with surf and a
  pale shore: `sea.gd` is one type shared by every realm.
- `src/models/props/rocks.gd` puts turf at the foot of every boulder in every
  landscape, which underground is the one thing that says "outside".
- The caves have no sentinel and no blind crawlers; they borrow the bonelands'
  cutters and haulers, and no works network of their own.
- Orbital and era realms are declared in the table and hold no landscape: their
  pages are not drawn, and `tests/realm` refuses a landscape registered into one.

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
