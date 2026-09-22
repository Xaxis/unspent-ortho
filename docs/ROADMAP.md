# Roadmap

Destination: `docs/VISION.md`.

## DECIDED (owner, 2026-09-22: "Keep the held z camera ... You decide all of it")

The owner kept the held-Z camera and delegated the rest. **The look (LANTERN) is
decided and none of these reopens it.** Detail for each stays in its section below.

1. **The held-Z lens stays, and becomes the default** (`rules.lock_lens` on) once
   a quiet re-run of its cost clears the slums and the works depot.
2. **The sky comes into frame under the lens** -- the owner asked "what's wrong
   with seeing the sky?", and nothing is: a horizon is the more beautiful picture
   and it is what `docs/VISION.md` asks of landmarks read from afar, which the
   orthographic frame caps at 11-13 tiles. Built as its own wave, not a constant:
   land to the horizon (`WorldFar`), fog that holds the world's edge, `Air`'s depth
   given a real far limit in place of today's horizon clamp, measured for cost and
   judged on frames before it is the default.
3. **Machines get out of the player's way under the orthographic camera too** --
   "a fight is never hidden" (docs/ART.md law 5) is the game's own rule.
4. **Under the lens a cottage opens when it hides the player** -- the same law.
   Only the one between the eye and the player, only round that line; the
   orthographic game keeps its 3.0 fence exactly as it is.
5. **A place's floor: `BODY_SHARE` 0.25**, its comment rewritten so its words and
   the code agree about what it divides by.
6. **A prop's model is dealt by its position**, so a world change stops
   reshuffling the island and the canon's neon frame stops moving.

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

  **And on the web, which is the path that ships.** `tools/web.sh` on main with
  all four wave B packages in, on a machine carrying another session's wave, in
  the threaded build:
    - **cold title**: code 511, world 2325, view 165, near 551, **draw 1443**,
      total 5061 ms; first frame 6.57 s after navigation.
    - **New game from that title**: code 0, world 0 (the title's page had already
      compiled the systems and made the world: `_after_lift` and `BootWorld.offer`
      are doing exactly what they were written for), view 8, near 566, start 479,
      **draw 1277**, total 2334 ms; drawn 4.04 s after the key.
    - **reload, warm browser cache**: the same title stages but **draw 97**, total
      2994 ms, first frame 4.58 s.
  So the guess above is confirmed by measurement, and sharpened: the first drawn
  frame is the biggest single stage of a cold start on the web, it is shader
  compilation, and the browser already caches it — a reload pays 97 ms where the
  first visit pays 1443. The lever is therefore to warm or ship those shaders, not
  to make worldgen faster; 9.9 MB goes over the wire (index.pck 2.3 MB br,
  index.wasm 7.5 MB br) and the player waits on the compile, not the download.
- **Nobody has proved the web build makes a sound.** `tools/web.sh` ends red on
  audio every time — "a test tone on the master bus never reached the meter",
  with 6 of 28 players reported playing, 8 buses, two outputs tapped and the
  context running. The same failure reads identically against a deployed build,
  so it is not a regression; but that is only evidence that it is CONSISTENT, not
  that it is the harness. Either headless Chromium cannot meter what it has no
  device for, or the web build is silent for players, and the two look the same
  from here. It wants one listen in a real browser with a real output, and then
  either a fix or a line in `tools/web.sh` saying why that check cannot run
  headless. Everything else on the web path is green: canvas, focus, saves kept
  across a reload (19 keys read back whole), and the frames drawn.
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
- **A swimmer is drawn over the water, not through it.** People draw after the
  outline pass (render priority 10), so depth cannot cut a figure at the
  waterline: a body in deep water is floated to the surface and reads as lying ON
  it, with `MobFx.ring` wakes doing the work of saying it is in the sea. The fix
  is a waterline clip in `person.gdshader` (discard below a world-space y, the
  cut inked the way this art inks everything else) — worth doing when somebody is
  already in that file, and the one piece of swimming that is not finished.
- Villagers and the fauna system still keep out of all water
  (`35_folk._standable`, `37_fauna._ok`), so a villager never swims and a dog
  crosses only as a fight body. The roster says the beasts can (`crosses`); their
  own systems have not been asked to.
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

**All six landed** (2026-09-17). What each made true, and what each still leaves,
is in its own section below; raids was the last in and closed the list.

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

### Wave B: what the works-and-landmarks package made true

`docs/VISION.md` §2, §3, §8. Two halves of one idea: a landscape must be worth
crossing, and the machines must be doing something in it. Proved by
`tours/works.tour` and `tours/landmarks.tour`, and by `tests/works/` and
`tests/landmarks/`.

- **A region the plan is working has a depot, and it can be put out.** One per
  REGION with room enough and a work of the plan already standing in it
  (`Works.sites`, pure and derived from the island, so it never moves and is
  never saved): a raised deck on the survey bearing with a lattice mast over it,
  bays added as the plan advances, and a lit strip along every rail. Three
  working parts hold it up, each its own walk across open ground, each opened
  under a held key with a steel edge and filed as sabotage the moment it goes.
  The third puts it dark for good: the lights out, every plan work in the yard
  spent (which is what leaves that region's keeper standing dark,
  `Sentinels.feeds`), nothing more put on the land from here, and a tuft at a
  time of the ground closing over it.
- **The region's machines come from it, and a dark yard quiets the whole
  region.** Two halves, and only the first was ever built: the yard sends one of
  its own out of the gate every `OWN_EVERY` world minutes and one on a round
  along the survey every `PATROL_EVERY`, both within thirty tiles of the player.
  Past that the coast's own rolls did not care whether the yard was lit, so a
  region dark for a week held exactly as many machines as a working one. Now a
  broken depot shuts every machine of the plan out of the rolls over its whole
  region (`Coast.also_shut`, one additive field) and leaves what lives there
  alone, so the land goes quiet and not empty. Measured in a running game
  (`tests/works/test_in_game.gd`): **40 bodies out of the yard over 6 world
  hours standing -> 0 broken**, and **11 machine kinds shut out of the region,
  1 living kind left in it**. (The old figure, "162 bodies a day", was
  `floor(24*60/14) + floor(24*60/24)` over two constants and measured nothing;
  `Works.bodies_in` has been deleted rather than left to be quoted again.)
- **Breaking one really moves the plan's file on you.** Both systems find the
  disposition system by the string `"32_disposition"`, and nothing proved the
  call landed. Measured through a held key on a real housing:
  **interference on the yard's own network 0.05 -> 0.20**.
- **Ten kinds of place worth the walk, three or four in every landscape, and
  every landscape declares its own.** A drowned lighthouse with the lens still in
  its cradle and no light in it; a relay mast leaning in standing water with one
  strip still alive; a fire tower whose bottom two flights are gone and whose
  last tenant's sacking is still on the deck; the tall stack blinking over a land
  nothing is burning under; a ring of standing stones with the fallen ones recast
  in concrete round rebar; a salt-crusted evaporator stopped with its rake down;
  a hauler the land grew a tree through; a clerk's post with its whole file out
  in the weather and still in order; and, underground, a limestone column robbed
  out and replaced with a poured one round rebar, and a sump gantry over black
  water with its float down. `BiomeDef.landmarks` is now written in all nine
  landscape files and `Landmarks.problems` fails if a landscape and a kind
  disagree about each other — the field was added to `BiomeDef` and nothing wrote
  it for a whole wave.
- **Every one of them stops a body.** Nothing in the package had a collider of
  any kind: a player walked into the middle of the lighthouse's stonework and
  stood there, occluded and invisible at screen centre, and the depot deck was
  walk-through, which is why "a stealth-and-fight set piece with several working
  parts under pressure" was an open field with decorative furniture. Each model
  now declares its mass as circles (`LandmarkModels.BLOCKS`,
  `WorksDepot.yard_blocks`) and `WorldQuery.set_blocks` stops a body on them —
  props and walls are kept apart on purpose, because nothing may take a wall,
  hear it or shelter under it.
- **Every landmark holds one deterministic roll off the one economy** — a
  landscape's own elite material where the landscape has one, so the same kind of
  place is worth walking to twice in two landscapes.

**What the camera can actually show, which is the thing this package was
wrong about.** `CameraRig` is 15 world units of view height at 16:9, pitched 57
degrees: **26.7 tiles across and 17.9 tiles of ground**, so nothing further than
about 13 tiles to the side or 9 tiles up the screen is ever in frame. The kinds
were written claiming `sees` of 20-34 tiles (VISION §3 asks for twenty), so every
far-read line the game said was said about a thing the player could not see, and
the only frames that showed the silhouettes were shot at twice the play camera's
zoom. Now:

- `Landmarks.read_reach(view_height, pitch_deg, aspect, high)` is the rule, and
  `tests/landmarks/test_models.gd` pins every kind's `sees` against the real rig;
- `sees` is **11-13 tiles** (was 20-34) and `FOUND_AT` is **9** (was 16);
- `tour_seen("landmark:KIND")` asks the LIVE camera whether the thing is in the
  frame, instead of "there is one within sixty tiles", which is what let every
  far frame pass;
- both tours shoot their far frames at play zoom, backing off UP the screen,
  which is the one direction where a tall thing's head carries after its base has
  gone off the bottom.

**Reading a landmark off the horizon from twenty tiles wants a camera change,
not a taller mast**: at 57 degrees a thing only buys `high * cos(pitch)` of
screen height, so the stack at 12 units tall reads no further than the lighthouse
at 8. That is M3's to decide, and it is a whole-game decision.

Gaps it leaves:

- **The twenty-tile read of VISION §3 is not met and cannot be at this camera**
  (above). The models are built to carry; the frame is not big enough.
- A landmark may not hold anything a machine carries: `Sources` walks any table
  yielding such an item back to a roster body, and a place is not a body
  (`tests/gear_economy/test_obtainable.gd`). So `axe_works` — the one piece in
  the tree with no way to it, whose own row says the landmarks own it — is still
  unreachable, and a wick in a lighthouse is still a test failure.
- The salt flats, the scrapwood and the limestone caves hold no elite material of
  their own (no raw and no machine kind of their own, `EliteStock`), so their
  landmarks pay in ordinary finds while every other landscape's pay in its own
  material.
- A broken depot's plan stage stops where it was, but nothing else in the plan
  reads `works_broken` yet: interference does not fall, and the region's other
  depots (there is one per region, so there are none) cannot take over.
- The land closing over a broken yard is proved in tests, not in a tour: it is
  four world days and a tour cannot stand still for them.
- Every landmark's cache is the same locker. The ten silhouettes differ; what a
  player's hands go into does not.
- A landmark's mass is circles, so a long thing (the evaporator, the grown hulk)
  is a chain of them and its corners are softer than its drawing. Nothing in the
  game has a real polygon collider and this package is not the place to add one.
- ~~**`tests/sky/test_lamp_pools.gd` fails about one run in three**~~ — **FIXED
  (6a9de30), and it was never a race.** The finding was right that the same 5.84
  every time meant something deterministic; the diagnosis of a race was wrong,
  and so was sending the fix to 15_lights. The lights draw the lantern down to
  nothing where another lamp already lights the ground (`night *= 1.0 - 0.9 *
  under`), on purpose, so two pools never stack into two ruled discs; `_set_light`
  refuses anything under 0.01; and the `push_front` that puts the lantern at the
  head of the list sits inside that refusal. The test planted a lamp two tiles
  from the player and then asserted the lantern comes first — the one thing the
  lights promise not to do there. Load only decided whether the planted lamp had
  been indexed yet: a slower frame lets the indexing cadence catch up inside the
  same twenty frames. Asked in the other order it is true by construction, and
  green across a 2.6x spread in wall clock.

Costs, measured on this laptop under load:

| What | Before | After |
|---|---|---|
| Every depot found in a 512-tile world (10 of them) | 0.59 ms | 0.67 ms |
| Every landmark sited in a 512-tile world, cold | 48.7 ms | 52.1 ms |
| Asking for the list again | under 1 ms | under 1 ms |
| Landmarks on seed 1, by landscape | coast 4, pinewood 3, bonelands 2, moss 3, burning 3, salt_flats 2, snowfield 2, **scrapwood 0** | coast 3, pinewood 3, bonelands 2, moss 2, burning 2, salt_flats 1, snowfield 3, **scrapwood 3** |
| Landmarks on seed 7, by landscape | 22 in all, **scrapwood 1** | 23 in all, **scrapwood 2** |

The scrapwood held nothing because regions were filled biggest-first, so the big
landscapes put their silhouettes down and the small ones came last to ground
where every tile was inside `MIN_APART` of something already standing: the
furthest tile in scrapwood region 8 on seed 1 from an existing landmark was
**23.3 tiles against a floor of 24**. The rounds now go round every region, least
room first, and a run under `Landmarks.REGION_TILES` (400) is a corner and not a
place. `tests/landmarks/test_world.gd` asks every landscape with a region that
size for at least one, which is the test that would have caught it.

### Wave B: what the A2 polish package made true

Nine things the A2 assessment left. Seven landed, one was measured and refused,
one was handed on. Proved by `tours/polish.tour` and by `tests/hazards/`,
`tests/models/`, `tests/export/`.

- **A player can survive day two.** Five landscapes out of nine could HARM a body
  wearing the best kit two days of play can reach; none can now. Three warm-kit
  recipes (`wrap_warm`, `oilskin`, `hat_brim`) were at a bench for no reason but
  the order they were written in, and shade answered glare and never thirst.
  Salt flats glare 0.70 BITE -> 0.39 felt, salt flats heat 0.85 HARM -> 0.59
  BITE, snowfield cold 0.68 -> 0.44, moss wet 0.67 -> 0.26.
  `tests/hazards/test_day_two.gd` prints the whole table and is the rule.
- **The Burning's vents are not eggs on a griddle.** Nine identical pure-white
  discs on neat octagonal collars, the only pure white in the game, are now
  broken clinker collars with plates of crust floating on the fire, so what the
  eye reads is amber SEAMS: **252 pure-white pixels in nine blobs -> 19 in six**,
  largest blob 9x7 -> 3x2. Four variants, not two.
- **The targeting tag is made of the slate, not of black.** An opaque lozenge
  behind every body on screen became two salvaged parts — torn glass at 0.55
  alpha and a rail of the bezel's phosphor. Darkest pixel inside the tag 7.2 ->
  20.4 against a frame floor of 12, and a test fails on any backing darker than
  the frame's own floor.
- **The sky's evening and the body's night are one curve.** `FightRules.nightfall`
  IS `Weather.night_fall`, which the hazards file had promised in a comment for
  two waves; `tests/hazards/test_hazards.gd` fails if they ever part again.
- **The loading page has deadlines**, so a boot that never draws gives up in
  seconds instead of hanging: six of six boots through at 6.2-9.7 s, against a
  run where two of five never handed over at all (36.5 and 37.4 s).
- The ruts and the scrapwood's crowns are no longer stamps (commonest turf-cut
  bar 13 px at 25.2% of crossings -> 3 px at 19.7%; tree variants 4 -> 6, no two
  sharing a crown radius), the watcher has a body (0.40 -> 0.52 of its silhouette)
  and **76% of tour frames now say what they are OF**, up from 61%.

Gaps it leaves:

- **The harvester and the hauler are still slabs end-on**, and the package said
  so rather than dressing it up: a fourth attempt (standing the spout up like a
  derrick at alert) made the measured number worse and was reverted. What landed
  instead is the measurement — `test_no_machine_is_a_filled_box_from_any_bearing`
  sweeps sixteen bearings and pins each kind where it stands (harvester 0.84 at
  yaw 3.93, hauler 0.67, sweeper 0.67, runner 0.65). Only a different hull moves
  those, which is a machine-models job and not a polish one.
- **The watcher's fill ratchet went UP**, 0.25 -> 0.30, the first time that
  number has moved the wrong way. It was deliberate: the watcher was the emptiest
  thing in the roster and unreadable at play distance. `tests/models/test_machines_mass.gd`
  is the counterweight, a per-kind FLOOR on how much of a machine is body. If
  that file is ever dropped, the ratchet comes back down with it.
- Collapse and dark have no hand-made answer: both are answered by WHERE YOU
  STAND, which `Hazards._answer_shift` already models and `test_day_two` holds to
  being real.
- The scrapwood's ground still reads brown-mauve rather than its own green-brown
  gloom, and the Burning at noon still reads chocolate brown (R-B +33). Both were
  on the A2 list and neither is in this package's ownership.

### Wave B: what the raids package made true

`m2b/raids`, merged `--no-ff` behind `tools/check.sh` (**1489 tests green**) after
works-and-landmarks and polish. `docs/VISION.md` §9.2-9.7, and `docs/DESIGN.md`
§Raids is the argument. Proved by `tours/raids.tour`, `tours/raids-dark.tour` and
`tests/raid/`.

#### What is true

- **Nothing is ever sent for a place nothing has read.** A machine that comes
  near a holding reads ONE channel off `Settlement.signature()` — the loudest it
  can hear from where it stands, weighed by `Signature.CARRY` over 34 tiles — and
  walks home with the record along the plan's survey bearing. Until it is clear
  of the yard that reading is a thing in the world: kill it, spoof it into
  nonsense, take it off the body (a `record` item, and the copper a signet is
  wound from), follow it home, or let it go. **Only a record that got home raises
  attention**, which is what makes running dark an answer rather than a delay —
  `tours/raids-dark.tour` builds out of the pieces that say nothing, lets one
  comfort give the place away, takes the reading off the body, and ends where it
  started, at nothing.
- **Attention is one 0..1 scale and the scale IS the escalation.** 0 is a place
  nothing has ever reported; 1.0 is a siege led by the region's keeper. It is
  counted in ONE FILED RECORD at full strength (`Attention.NOTICE_FULL` = 0.09),
  so twelve unanswered readings bring the keeper, and every other cause is stated
  as a share of the same thing: a machine lost in the yard 0.14, the network
  going up a level 0.07, stolen FOUND tech 0.030 per world hour, a quiet world
  hour -0.012, a record destroyed -0.05, a step paid -0.30, the keeper falling
  -1.0. `Attention.CAUSES` is the closed list, `48_raids` is the only writer, and
  `Events.attention_changed` is the only door out. **Hours alone only ever make a
  holding safer.**
- **It is read as pressure, never as a bar.** The holding app draws what a machine
  HEARS (seven channels, the loudest named, its percentage) and under it ONE WORD
  for what the plan THINKS — read, surveyed, wanted, marked, condemned. A number
  there would turn a system about reading the world into one to optimise, and
  there is no third readout.
- **Four steps, each warned by the world 25-110 world minutes first.** Survey,
  probe, raid, siege, at 0.22/0.45/0.70/1.0. The warning is a sound off along the
  survey bearing, a line on the glass, and the plan's own tag — a new FOUND model,
  `src/models/raid/raid_mark.gd` — bolted to every piece the party is coming for.
  The window is the answer: fortify, take the people off, kill the mast, fire the
  signet, leave a full store out as tribute, or be elsewhere. What turns them
  round on the road is the SIGNATURE falling, not the books.
- **The build decides the fight.** A party's trades take their targets off the
  holding's own signature — breacher to the strongest thing standing, harvester
  to whatever the slate named loudest, snatcher to whoever is at work — so the
  seven bars are a decision rather than a readout. A raider is here for the
  holding: it walks past somebody standing in their own yard, and only a blow
  turns it.
- **Walking away is not walking out.** A raid the player is not present for
  settles on exactly the same arithmetic, and one they leave halfway is settled
  the same way with whatever the party had not spent. A party body carries
  `MobState.raider` and is exempt from the coast's cull for exactly that reason.
- **Aftermath is left in the yard.** Broken pieces stay as wreckage 46 gives half
  back for, machines killed in the yard leave salvage, a razed holding keeps what
  the party could not carry, the region remembers a place razed on its ground, and
  **killing its keeper quiets the network for good**.

#### The ruling: a portal is not a raid path

Written down in `docs/DESIGN.md` §Raids as one sentence to argue with, not to
quietly widen. A machine arriving through a gate the player has never opened,
from a realm they may not have visited, is unreadable BY CONSTRUCTION: there is no
warning it could have given and nothing they could have done about it, which is
the one thing this system may not be. So attention is kept per realm — a machine
in the caves never senses a village on the surface, a step is only warned in the
realm the player is standing in, and the plan's memory of a region is keyed
`"REALM:region id"` because region and prop ids both restart at 0 in every realm's
world. **When a portal is a thing the player has opened and can shut, a raid
through one becomes the best set piece the system has, and it gets built then,
deliberately, with a warning grammar of its own.**

#### Gaps

- **None of the raid's real ANSWERS can be built.** `StructureKind` names turret,
  spoofer, decoy mast, EMP stake, mine, ditch, tower, shutters and bunker;
  `BUILDABLE` lists twelve kinds and none of them is one. `SIGNS` already carries
  mask rows for spoofer (0.5), decoy mast (0.35), netting (0.2) and shutters
  (0.15), and `Attention._mask_of` and `RaidStage.CALLED_OFF_UNDER` already read
  them — **the moment those rows become buildable the answers work with no change
  in this package.** Until then a raid has fight, hide, evacuate, pay and the gear
  signet, and no BUILT answer at all. This is the first thing to fix.
- `tours/raids.tour` proves the answer with `await ring` — a blow struck at the
  party, which turns it on the player — rather than a kill. A RAID party resolves
  to two haulers (life 66, plated) plus a snatcher, and one felling axe does not
  take two haulers down inside the window, so "survive a raid" is honestly
  "strike back and come out the other side of it". The reason is the gap above.
- **A snatcher resolves to a clerk or a flock**, because the roster has no body
  whose trade is carrying people off. A clerk walking somebody out of a yard reads
  oddly. `RaidRoles.score_for` picks by what a body IS, so a row with a
  `hits: {minutes, ...}` and a good dash is chosen the day it exists.
- A snatched resident is taken off the holding's books here, and its BODY let go
  through 46_settlements' private `_send_away` (guarded by `has_method`). It
  works, and it is a cross-package private call that wants a public
  `lose_person(settlement, person_id)`.
- **A holding gives no shelter from a landscape's pressures** (`52_hazards.ROOFS`
  is keyed by `PropKind`), so evacuating into your own hut does nothing against
  the weather. Named by the settlement package's own author and still true.
- A step called off during its warning emits `raid_ended(&"left")` with no
  matching `raid_began`. Nothing pairs the two yet; documented in the system
  header.
- **Nine `raid_*` sound names are aliased onto existing sheet rows** (fog_horn,
  alert_flock, arc_snap, watcher_call, relay_click, pickup, break, grip). They
  read right and nothing is silent, but none has a voice of its own: raid_horizon,
  raid_drone, raid_static, raid_keeper, raid_notice, raid_jammed, raid_record,
  raid_break, raid_snatch.
- A party paths by straight lines plus a sidestep when it stops getting nearer.
  `_march_from` proves a start point has a way in that is dry, level and clear of
  solid props and falls inward until it finds one, so a party always arrives — but
  a holding ringed by ruin gets a party that comes out nearer than the full twelve
  tiles instead of one crossing the whole field.
- The siege's keeper is put down at the party ring and adopted by 44_sentinels
  (`_adopt` takes any sentinel body and gives it its region's real health and
  phases). **No tour reaches 1.0 attention**, so that path is proven by reading
  44_sentinels rather than by playing it.
- `Attention.pressure()` returns a word and the holding app is its only reader, by
  design. If a second reader is ever wanted, that is the function — but a second
  readout would make attention a number to optimise.

### Wave B, integrated (2026-09-17)

`m2b/works-landmarks`, then `m2b/polish`, then `m2b/raids`, each merged `--no-ff`
behind `tools/check.sh`, with realms, the gear economy, settlement and the story
already on main. **1368 tests before the wave, 1432 after polish, 1489 after
raids, green.** What the integration itself had to find and fix, which is what a
seam is for:

- **A place is a way to a thing.** `Sources` walked every drop table back to the
  roster body it came off, so a landmark could hold nothing a machine carries:
  the fine axe sat in the gear tree with a note saying the landmarks owned it and
  nothing in the world holding one, and a wick in a lighthouse was a test failure
  rather than a find. A table now declares whether it is OPENED or killed, and
  where it stands (`Drops.declare_place`), and the walker answers with a fourth
  step — `find axe_works at firewatch in the coast or pinewood or scrapwood`.
  **The last `no_source` is gone and `tests/gear_economy/test_obtainable.gd` now
  allows none.** A place is the LAST answer, never the first: taking, killing and
  making are repeatable and a cache is opened once.
- **A region with nothing running it cannot hunt you.** `Events.works_broken` and
  `Events.sentinel_fell` were both emitted with nothing listening, so a player
  could put a depot out and that same region went on working itself up to hunted
  and sending bodies out of a dark yard. `Interference.lose` caps a lost
  network's file under `hostile` for good (`LOST_CEILING` 0.55, under the 0.56
  threshold, so `_dispatch` can never pick a hunter there) and cools it at
  `LOST_DECAY`. It is saved: a region stays lost for the game.
- **What a broken yard is worth to a keeper, measured instead of asserted.** The
  works package claimed breaking a depot "marks every plan work in the yard
  spent, which is exactly what leaves that region's keeper standing dark". It is
  not exactly that: a yard is `Works.YARD` (8 tiles) and a keeper feeds over
  `def.reach * FEED_SHARE` (about 21), so on seed 4 the salt flats keeper is fed
  by twelve works and breaking the depot spends four — **a third of the way to
  starving it**, with the rest to be robbed by hand. That is a better game than
  the claim, so the radius stands and the number is in
  `tests/works/test_in_game.gd`.
- **A swimmer pushed into a wall stopped dead.** `WorldQuery.move_body` falls back
  on stepping one axis at a time, and the second step was asking whether a WALKER
  could stand there — so to a swimmer every tile of deep water refused it, and a
  swimmer beside anything solid could only move east and west. Nothing caught it
  while the only walls were trunks on dry land; this wave put a drowned
  lighthouse in the water, which is where a player meets one. (The missing
  argument came in with the craft package and swimming did not thread it.)
- **The ground under your hands beats a notice across the square.** The story
  package numbered itself before survival so the most specific thing answers
  `use` first, and gave itself a generous reach (3 tiles) so a key pressed at a
  villager who has just stepped still lands. Together those meant a notice two
  tiles off outranked the driftwood the player was standing on and facing: the
  key that meant "pick this up" opened a page, and every press after it went to
  the page. `tours/core_loop.tour` died at its first `await took` because of it.
  "In front of" is not "nearer than", and only one of the three can be under your
  hands.
- **The slate can be put on a place.** Every body and every person on screen could
  be read and the two biggest things this wave put in the world could not. A
  depot says what trade it was founded on, how far the plan has got and how many
  housings are still shut; a landmark says what the place was and whether its
  cache is emptied, and only once it has been FOUND. Each system answers for its
  own (`target_rows`), so targeting still knows nothing about depots, and places
  sort below every person, which is below every body — a yard can never take the
  lock off what is coming at you.

What the wave still leaves, in the order it should be taken:

- **Six tours fail on main, and none of them is the wave's fault.** Every tour in
  `tours/` was run after the raids merge: 42 green, six red —
  `disposition` (line 31, `await theft`), `machine-read` (91, `await theft`),
  `realms` (37, `await lamp`), `slate-hud` (31, `await badge_answered`),
  `slate-polish` (64, `choose controls`) and `survival` (39, no fire laid). Each
  was re-run at `d4e4e1c`, main BEFORE m2b/raids, in a detached worktree and each
  **fails at the identical line there**, so they are older than this wave. Two
  more (`saves`, `saves-elsewhere`) went red only while three test shards were
  running beside them and pass on a quiet machine: tours step in WALL-CLOCK time,
  so CPU load changes what happens in `walk 1,0 1.5`. Anything that reads a tour
  result has to know that — a red tour on a busy machine is not yet a bug.

  **Two of the six were the use key, and they are fixed** (the integration pass,
  above): a survey post has WORDS on it and is also the plan's WORKS, so the read
  took the key and the theft could never happen. `disposition` now gets from line
  31 to line 84 and `machine-read` from 91 to 183; what stops them now is a
  stealth read and a walk to a watcher, not the key. `characters` was red only
  under load and passes on a quiet machine (its last step measures a crowd's
  render cost and waits on `frame_post_draw`, which stalls when another session
  takes the window). **Four remain**: `disposition` (84, `await read`),
  `machine-read` (183, `await machine:watcher`), `realms` (37, `await lamp`),
  `slate-hud` (31, `await badge_answered`), `slate-polish` (64, `choose
  controls`) and `survival` (39, no fire laid) — all older than the wave, and the
  lamp and the fire are worth looking at together with the key, since both are an
  action the player takes with it.
- **The canon's accepted set is stale, and the sheet's own metric is too coarse
  to say so.** `04-pinewood` now has a works depot standing in the corner and a
  "Corridor works, pinewood" read under it — a whole building, 41,764 pixels away
  from the accepted frame — and `tools/canon.sh` scored it 3.0 and reported "0
  changed". It is NOT the raids merge: shot at `d4e4e1c` and on main, that frame
  differs by 124-272 pixels, so the depot came in with works-and-landmarks and
  the baseline simply predates it. Measured while checking: two runs of the canon
  at the SAME commit differ by up to 20,976 strong pixels on
  `17-village-wet-night` and the sheet called one frame changed between them, so
  the night, lamp and wet-ground frames carry more run-to-run variance than most
  real changes would. Re-accepting is a deliberate, frame-by-frame job for
  whoever owns the works and polish frames; raids moved nothing and accepted
  nothing.

  **Re-accepted deliberately (2026-09-17, the integration pass.)** Two frames
  moved and both moved for one reason: the machines' depot now stands in the
  landscape. `04-pinewood` (3.1) has its plate deck in the bottom-left corner
  with "Corridor works, pinewood — Three housings hold this yard up" under it,
  and `10-eco-bonelands-burning` (2.3, under the threshold) has one coming in at
  the top-left. The land under both is untouched: what changed is that the plan
  is VISIBLE in a landscape frame, which is the whole point of the wave, and the
  FOUND deck reads instantly as not of this world against the hand-drawn wood.
  The other sixteen are the same pictures. The variance warning above stands —
  the night frames' threshold still cannot be trusted, and that is M3's to fix.
- ~~**`tests/sky/test_lamp_pools.gd` fails about one run in three**~~ — **FIXED
  (6a9de30).** This note had the mechanism exactly right and still drew the wrong
  conclusion from it: the lantern IS push_front'ed only when `_set_light` turns
  the light on, and a world lamp covering the player IS what stops it. That is not
  a race and not something for 15_lights to decide — it is the lights working as
  designed, and a test that staged the opposite of what it asserted. Fixed by
  asking the lantern before planting a lamp beside it. Worth remembering as a
  pattern: a failure that reports the SAME number every time is not noise, and it
  is usually not a race either — it is an assumption that is false under some
  orderings and true under others.
- **The 20-tile read of VISION §3 is still not met and cannot be at this camera**
  (the arithmetic is above). M3's to decide, and a whole-game decision.
- A depot whose yard holds no plan work strips nothing, so on seed 1 the coast
  keeper cannot be starved by breaking the coast depot at all. That is the
  island's business rather than a broken seam, and only two landscapes have a
  keeper to starve.
- `axe_works` is reachable but nothing else in the tree is found at a place: the
  salt flats and the scrapwood still have no elite material of their own, so
  their landmarks pay in ordinary finds.

## LANTERN — the look, rebuilt (integrated, 2026-09-17)

The owner was shown twelve art directions and rejected all twelve: they all read
"papery", and the reason was that they all inherited the same floor. `docs/LOOK.md`
is the direction of record and outranks `docs/ART.md` where they conflict. The
direction is **the world is lit, not drawn**.

Six packages, merged one at a time behind the gate: `floor`, `lit`, then `form`,
`depth` and `slate` in parallel, then `degrade`. Two follow-ups the wave raised
itself landed after: `foliage` (snow) and `nights` (per-landscape night, the moss).

### What is true

- **No ink, no hatch, no paper grain, no screen-space outline pass, and no
  `light()` in any lit shader.** A shader says what a surface IS — albedo,
  roughness, specular, metallic, a normal bent by the material's own relief — and
  the renderer lights it, against a real sun with real penumbra, a sky that colours
  the shade, many local lights that cast, volumetric air and one tonemapper over
  the finished image.
- **The base is 1920x1080**, `stretch/mode="viewport"`, `forward_plus` on the
  desktop and `gl_compatibility` on the web through a `.web` override, proved in a
  real exported build. A tier spends render scale, never window size.
- **Wear accumulates by world position**, so the same machine rusts in the bog and
  blooms on the salt.
- **The web is the same place on a worse night**, measured: mean absolute channel
  difference over the eighteen canon places **44.4 -> 10.5**.

### The numbers

| | before | after |
|---|---|---|
| Whole frame, 24 villagers | 31.0 ms | 12.0 ms (at 9x the pixels) |
| Landscapes told apart (mean pairwise Lab dE) | 14.86 | 22.73 |
| Moss against pinewood (Lab dE) | 2.61 | 7.09 |
| Night, unlit, share under luma 24 | 2.3% | 23.6% |
| A machine's value against the turf | +10.4 | -13.0 |
| Web against desktop (mean channels) | 44.4 | 10.5 |

### What the wave actually taught

**In every package the visible symptom was not the problem.** Papery was the
floor. Washed out was two renderers disagreeing about what a value in `ALBEDO`
means. Faceted was flat normals. Flat was fog tuned to the wrong depth range.
Coarse UI was hiding an unreadable machine tag. The web being darker was a casting
sun drawn in a pass that added ambient and emission a second time — turning its
shadow ON brightened the frame. And the moss reading as one flat teal sheet was
not night at all: `FEN` carried specular 0.68 on relief 0.010, and a level face's
normal is taken to exactly vertical, so every pixel of a bog answered the light
identically. It was a mirror.

Three methods paid, and are written up in `docs/LOOK.md`: draw the measurement
before guessing; toggle a layer inside ONE run rather than across runs; print
`UNMEASURED` rather than a fake `0.00 ms`.

### Gaps

- **The evening falls off a cliff.** `tours/evening.tour` fails on the coast at
  19:00->19:30 (0.0859 against a 0.075 tolerance): the sun goes under the horizon
  and takes every cast shadow with it in one half-hour step, and the frame
  flattens. Proven independent of the per-landscape night. Because it fails at
  line 70, the moss half of that tour has never run to completion.
- **87 FOUND pieces across 26 models draw from no bearing** —
  `tests/render/test_found_drawn.gd` lists them in `HIDDEN_ALREADY`. A shack's
  whole plate roof, lean-to roofs on four house variants, a standing stone's spall
  face inside its own casting, the conveyor's rollers. Built, baked into every
  chunk, never seen.
- **`07-burning` by day is the web's worst frame** (13.7 luma darker): the
  desktop's volumetric air scatters light around every cold vent and the depth fog
  standing in for it scatters nothing. The moss fails the same way.
- Snow on a laden pine reads as stipple at a close zoom; not established whether
  that is the snow or the leaf shader's own discard cut.
- A save's photo is captured at 160x90 and the title now draws it at 288x162 — a
  non-integer resample where it used to be an exact 3x. The lever is the capture
  size, not the draw rect. Owner's call.

## PROJECTIONS — the camera is the constraint on "detailed and beautiful" (open, 2026-09-22)

### FOUR DECISIONS THAT ARE THE OWNER'S, WAITING ON HIS WORD (2026-09-22)

None of these is an art-direction question. **THE LOOK (LANTERN) IS DECIDED AND
IS NOT REOPENED BY ANY OF THIS.** These are four narrow consequences of a second
projection existing, each already built so the answer costs a sentence and not a
wave. Frames are in `shots/lens/`.

1. **Does the game ship a second projection at all**, or is `--lens=persp` a tool
   for seeing what the world contains? `village_ortho.png` against
   `village_lens.png`, same seed, same hour, same weather: the lens holds about
   twice the village. Measured separately over 112 standpoints, 14 landscapes and
   3 seeds, a walking player sees **1.07 buildings per screen under the
   orthographic frame and 5.18 under the lens — 4.8x**. The buildings were always
   laid; the frame did not reach them. The probe that measured it is
   `tests/render/test_density_probe.gd` on branch `m3/broken` (`10a24c3`), kept
   OFF main on purpose: it answered a one-time question, grows three worlds and
   costs about 15 s, which is a poor trade on every gate. Its header predates the
   depth-view guards on main, so read it as a record of that evening.
   **The second projection can now be PLAYED, not only shot (`d7cd9a7`).** A held Z
   takes the lens and letting go gives the flat camera back, behind the master
   configuration row `rules.lock_lens`, OFF by default so this stays his decision:
   `--config=held-z`, or flip "held Z lens" on dev mode's rules page, and press Z.
   The switch is matched (subject size x1.0000 at the focal plane) and continuous
   in pitch. Frames: `tools/tour.sh tours/held_z.tour --seed=1 --hour=11
   --weather=clear:0 --folk=8 --config=held-z`.
2. **The horizon fork.** `fov/2 < pitch` keeps sky out of frame. It stands at
   27.5 < 40, with 12.5 degrees of margin. Crossing it is a different game and
   nobody should cross it by widening a fov for a prettier frame.
3. **Should FOUND geometry get out of the player's way in the ORTHOGRAPHIC game
   too?** It does not today and never has: a pylon, mast or lamppost stands
   straight through the player, which is a gap against docs/ART.md law 5. The
   capability is built and is INERT under ortho, so this costs only the word.
   `works_lens.png` against `works_lens_nocut.png` is the same frame with the cut
   on and off.
4. **Should a COTTAGE open when it stands between the eye and the player?** At a
   flatter pitch one genuinely does hide you. The fence (3.0) says do not open it,
   and law 5 says a fight is never hidden. Both cannot be true. The fence is
   currently held, which is why no building dissolves in `village_lens.png`.

### A FIFTH DECISION FOR THE OWNER: HOW BIG A PLACE MUST BE, NOW THAT CONTINENTS ARE DEALT (2026-09-22)

**This one is his number, verified**: `GenCountries.BODY_SHARE` 0.35 is marked
"(owner, 2026-09-19, chosen from measurement rather than taste)", and his rule is
that a run of one landscape is a PLACE -- a region, with a keeper, a depot, a
landmark and a sub-arc -- when it holds at least 0.35 of *"body tiles / how many
landscapes share THAT body"*.

**The rule and the code have drifted apart.** When he set it any landscape could
reach any continent, so "how many share that body" was all 21, which is what the
code divides by. Since `abd628f` each continent holds only what it was DEALT, so
his words, read literally, now mean the dealt count -- and the code still divides
by 21. Nobody can make the two agree without choosing one.

**What moved:** seed 7's land in some region went from 0.9105 to 0.8993, under the
test's 0.9 bar (`test_regions`, on `tests/standing.txt` with this cause). Not
allocation -- every dealt landscape holds more than 2.5x its floor in TOTAL -- but
FRAGMENTATION: its land lies in several runs, each just under the floor, so about
7,000 more tiles are land nothing claims. The world is unchanged until he rules.

Measured on seeds 1 / 42 / 90210 / 7 (a5, on `ec5bd55`'s world):

```
                                   coverage                      regions
as today (divide by 21)            0.925 0.902 0.914 0.899       64 71 71 67
(3) his rule read literally        0.910 0.860 0.859 0.866       60 62 59 60
(4) fold fragments into neighbour  0.983 0.979 0.975 0.976       63 68 68 66
(5) BODY_SHARE 0.25                0.947 0.936 0.946 0.933       72 83 83 79
(5) BODY_SHARE 0.18                0.965 0.953 0.967 0.964       81 91 93 94
```

- **(3)** is what his words say, and loses the most.
- **(4)** keeps every region one landscape but repaints 7-10% of all land into its
  neighbour's landscape, whole islands included (10,095 tiles of moss became crags
  on seed 90210). `a5`'s before/after at seed 7: a ruined-metropolis fragment in
  the orchards -- standing walls, a paved slab, rubble -- becomes plain orchard turf
  with one shack. The detail his bar asks for is exactly what it deletes.
- **(5)** keeps every patch and makes the fragments places. The smallest region is
  unchanged (440-653 tiles), no region falls under a keeper's 240, every region
  still holds a landmark (one exception at 0.18), and keepers rise from about 8 to
  10-15 per world. It lowers his number.

**Recommendation (fc's, not his): (5) at 0.25.** It is the only option that clears
0.9 on every seed WITHOUT deleting variety, the fragments it promotes all hold a
landmark, and it is the smallest move of his number that does. Whichever he picks,
the rule's comment should be rewritten to say which count it divides by, so the
words and the code agree again. It moves the world: `GEN` bump, re-probe, canon
re-accept.

### A SIXTH, SMALLER DECISION: EVERY WORLDGEN CHANGE RESHUFFLES EVERY PROP'S MODEL (2026-09-22)

Measured by 57 re-shooting the canon after the river fix (`2452b75`): 14 of 18
frames changed and **not one change was a river**. Every changed pixel was on a
PROP. Dumped per canon place on seed 7, before and after: 0 props moved, but most
got a new id and a different DEALT model -- the pinewood 105 of 145 new ids and 79
different variants, 30 tiles from any river.

The cause is by design, not a bug: `PropModels.variant_of` hashes the prop's ID,
and ids are dealt in placement order, so a change that adds or drops ONE prop
anywhere (the river fix added 70) renumbers every prop after it and re-deals most
of the island's models. Nobody chose any of it: which pine stands where changed
three times today.

Two costs. The canon cannot show what a worldgen change did, because every frame
differs; and the look of a place is reshuffled by unrelated work.

**Proposal, not done:** deal a prop's model by its POSITION and kind rather than
its id. Then a worldgen change re-deals only props it actually moved, and canon
diffs mean something again. It is one door (`variant_of`, which lights and neon
already read), so what is drawn and what is lit cannot disagree. Its cost is one
last reshuffle of which variant stands where -- no model, colour or light changes,
only the arrangement -- and it sits in `src/models/`, frozen to the look, which is
why it waits for the owner rather than landing quietly.

**And it now blocks the canon, not just its diffs** (measured the same day, after
`c55195f`). `GenWorks` records the stolen-light shack as the FIRST shack whose id
hash says lit, so when ids renumber, frame 18's subject moves to a different
shack. It moved into the MOSS, and there the mist carries the tube to the screen
darker than its colour -- brightest pixel (104,176,80), grass green -- so the
pixel claim refuses a frame that plainly holds a burning tube. Loosening the
matcher to accept a darker tube would accept the moss turf, so it cannot be the
fix. Until models are dealt by position, the canon's neon frame changes subject
with every worldgen change.

### THE RETIRED FLOOR IS STILL SPELLED IN THREE LIVE PIXEL BUDGETS (2026-09-22)

CLAUDE.md warns about pixel budgets never re-derived after the floor moved from
640x360 to 1920x1080, and says to search for a pixel count in a comment before
trusting it. Searched. **There is already a correct, projection-aware door --
`CameraRig.units_per_pixel_of(cam, rows)` -- with five call sites in four files**:
`sky_light.gd` (the sky texel), `holo_view.gd` twice (the hologram's width and
its street cache key), `flier_view.gd`, and `40_fight.gd` through the instance
wrapper, which feeds `MobFx.texel`. It is load-bearing, not spare.

(This paragraph first said "exactly ONE caller", which was not grepped -- it was
inferred from the single call site I had happened to read while looking at
something else. An UNDERCOUNT here is the dangerous direction: a door that reads
as unused invites the next person to rework or delete it. The three findings
below were grepped and are unaffected.)

Three sites still spell the retired floor, and all three are live paths rather
than fallbacks:

```
truth today                 15.0 / 1080 = 0.01389 world units per screen pixel

found_kit     a FIXED world size, 14/360 = 0.0389 units: 2.8 real px at view 15,
              and it scales with zoom like the geometry it is (1.6 at 26, 5.3 at 8)
52, fire      n x (LIVE view height) / 360: the height divides back out, so every
              n is exactly 3.00 real px at every zoom -- a screen-constant mark

src/models/machines/found_kit.gd:23   const PX := 14.0 / 360.0     26 uses
src/systems/52_survival_fx.gd:307     n * h / 360.0                hit marks
src/systems/survival_fx/fire_model.gd:127  n * h / 360.0 / SIZE    smoke, sparks
```

`found_kit.gd` is the consequential one: `PX` is a const with no live path, its
header says "14 world units over 360 px" in as many words, and **every mark in
the FOUND daylight vocabulary is budgeted in it** -- so every machine in the game
is drawn with its scribing three times the width its own file claims. That
header's worked example ("a 0.02-wide scribed line ... is also half a pixel") is
now false twice over: 0.02 world units at 72 px per unit is 1.44 pixels.

Two further sites spell the same number but only as a FALLBACK, with a correct
live path beside them, so they are cosmetic: `weather_view.gd:182` and
`sky_light.gd:605`.

**And the obvious fix is the wrong one.** "Three times too large" invites
correcting the divisor. Measured, over all 31 budgeted marks in `found_kit.gd`:

```
one authored "px" is drawn today at      2.80 real pixels
as drawn today                           2.2 .. 14.0 real px
after a literal correction               0.8 .. 5.0 real px
   under one pixel                       1 of 31   -- would shimmer or vanish
   1.0 .. 1.5 px                         5 of 31   -- hairlines
```

The machines as they are drawn TODAY are part of the look the owner approved
(LANTERN). So the geometry is not the error -- the HEADER is: it has claimed
half-pixel marks since the floor moved while the file drew them at 2.8x, and a
reader who believes it will "fix" the number and quietly redraw every machine in
the game. **Recommended: correct the comment, not the constant** -- say that `PX`
is a fixed world-unit budget that happens to be named after a retired screen, and
state what it draws at now. The same reasoning covers the hit marks and the fire:
leave the numbers, fix the words, and re-author only if a gallery sheet shows a
mark that fails. That is still the owner's call, but it is now a much smaller one.

**The sheet was shot and it agrees (2026-09-22).** Four machines (harvester,
watcher, hauler, sweeper) at the play camera's 72 px per unit, before and after
`PX = 15/1080`, `found_kit.gd` restored byte for byte afterwards. Pixels changed
by more than 12/255: harvester 1336, watcher 428, sweeper 345, hauler 5 -- an
upper bound, since the grass stipple differs between processes and some of each
count is that. Every change is on a scribed mark (deck seams, hazard stripes,
head-plate seams, an outline); silhouette, lamps, colour and mass are unchanged
and no mark disappears. So the constant stays and `found_kit.gd`'s header now
says what `PX` really is (`98de606`). Frames: `shots/fk/diff_closeup.png`
(untracked). Not examined: a band across each model where the gallery drew a
name tag, although `machine_gallery.gd`'s header promises that frame unlabelled
-- a comment stating something the code does not do.

### WHAT THE LENS FOUND IN THE EXISTING CODE (all fixed unless marked)

A second projection is an instrument for finding orthographic assumptions, and it
found eight. Six are fixed: five `cam.size` readers plus a sixth spelled as a
ratio, a hologram cache key that could never invalidate on zoom, `tall_cut`'s
whole-screen shear (a parallel-ray intersection used per fragment), two depth
views counting what is BEHIND the camera, and the cut's floor scaling with pitch
(which would have stippled away every cottage in the game). **The three this
section used to list as still open are closed (2026-09-22)**, and it said so here
for a while after they were, which is how a list like this sends the next session
to redo landed work: `Air`'s frame depth is measured for the lens it is under
(`02fa0bd`, the derived span agreeing with the one measured off the camera's
edges to 0.01, clamped as an angle at the horizon fork); `render_probe.gd`'s quad
is sized from the frame it measures (`51fe7b9`); and `fire_model.gd`'s budget
keeps its number and says what it is (`b1e30fa`: 3 real pixels per `n` at every
zoom, and its 14.0 is taken by every perspective camera, not only a missing one).
Two more the lens made necessary are on main too: the spawner asks the camera
under the lens instead of a box (`5c2c8e8`, the #120 blocker), and `CameraRig.lens`
became the one writer of `projection` (`d7cd9a7`). CLAUDE.md's contracts table
has the rules as "The camera's two projections".


The owner's words are that this is not the detailed, beautiful open world with
multiple projections we set out to build. Measured, the camera is most of why,
and the finding reorders the work rather than adding to it.

**The case, against a real Camera3D** (`tests/render/test_read_reach.gd`, which
asks `unproject_position` rather than deriving):

- the orthographic play frame holds 26.67 x 17.9 tiles of ground, and only
  **8.95 tiles AHEAD of the player**, whatever a thing's height
- a pitched orthographic camera has **no horizon**, so backing away from a tower
  loses its **top** first and its feet last. Height never buys view distance; it
  only buys more of the thing being cut off
- exactly: a face is seen from some bearing only while
  `cos(p) * hypot(n.x, n.z) + sin(p) * n.y > 0`, and a thing whose foot is
  `f` units up is in frame ahead only to `(half - f * cos p) / sin p`

So a `spire` (16.3) and a `tower` (14.3) can never stand whole in the frame; a
flier at 19-26 units is never overhead; a hologram over a tall roof is off the
top at every distance ahead. Those are not bugs in those features. They are the
frame.

**The proof.** One instant of one seed, shot both ways, nothing added between:

| | orthographic | `--lens=persp` |
|---|---|---|
| slums, seed 7, 23:00 | no people at all; two buildings clipped at the top edge | a crowd of about twelve at a lit stall, buildings with interiors and shelves, a workbench, scaffolding, a forge, signage, a wet street |
| coast, seed 1, 08:00 | the flat green sheet the owner called ugly | a village: houses, a fire under its frame, a water tower, villagers, terraced land to trees, gulls over the beach |

**The crowd was always standing there.** The world is already more detailed than
any picture ever taken of it.

**THE ART DIRECTION IS DECIDED AND IS NOT REOPENED BY ANY OF THIS.** LANTERN is
the answer, the owner has ruled, and the twelve rejected directions are closed
history. An earlier draft of this section read the finding as a licence to
re-judge the art record and it was wrong to: "a frame showed more than we
thought" is a fact about the CAMERA, not an argument about the direction drawn
with it. What follows is correctness work — quantities that are meaningless
under a projection they were not derived for — and nothing in it is a reason to
revisit a settled look.

### What landed

`0738a51` — `CameraRig.lens` (`&"ortho"` default, `&"persp"`), `--lens=ortho|persp`,
`_apply` branching to `_apply_lens`. Shares the focus, yaw, smoothing and lean;
does NOT share the texel snap, which is an orthographic device (`size` is world
units per screen height and a perspective frame has none). Near blur off under
the lens for the same reason — `near_plane` is `_back - frame_depth(size, pitch)`
and every number in it is orthographic. The first lens shot was that mistake.

`f43adeb` — `tall_floor` is the CAMERA's number now, a uniform defaulting to 3.0.
Not derived from the live lean, which was the obvious move and is wrong:
`42_target.LOCK_PITCH` is -4.5, so a lock flattens the ortho camera to 52.5 and a
lean-derived floor would fall under the steading's 2.8 and stipple a village the
moment the player held Z.

### What the lens has already found, which was never wrong before

Every one of these is an orthographic assumption that was correct until there was
a second projection. Expect more; this is the shape of the work.

- **The spawner puts machines on screen.** `Spawner.in_view` is a SYMMETRIC box
  (`|d.right| <= 13.33+m`, `|d.up|*sin(pitch) <= 7.5+m`). Under ortho the frame
  reaches 8.94 tiles either way and the spawn ring is 11-18, so every ring tile is
  outside it — correct by construction, which is why it has never broken. Under
  the lens (fov 55, pitch 30, back 9) the top edge sits 2.5 degrees below the
  horizon and meets the ground about **95 tiles ahead**, so the whole ring is
  visible and machines materialise in full view, every time. A symmetric box has
  no meaning against a frustum; this wants a projection test, not a new constant.
  **This is the blocker on wiring the lens to a held Z.**
- **Nothing fails loudly**, because both ortho numbers stay live-looking: under
  the lens `cam.size` still reads 15.0 and `cam.pitch_deg` still reads 57.0. Five
  sites and everything downstream get a confident wrong answer rather than a null.
- **`WorldView.view_half_extent()`** requires `PROJECTION_ORTHOGONAL` and falls
  back to `vh 15 / pitch 57`, so the streamer asks for the ortho footprint while
  the frame reaches far past it — the same symptom `camera_rig`'s clip-plane
  comment records as the world drawn "as a BAND across the middle of the frame".
- **`cam.size` is two questions wearing one number.** World-units-per-pixel at a
  plane is real under both projections and wants one door; "is this in frame" is a
  PREDICATE and the codebase already has the right idiom — `flier_view._in_frame`
  and `17_holo` ask `camera.unproject_position()`, which survives a zoom, a lean
  and a projection change for free.
- **FOUND geometry never stipples.** `found.gdshader` has no `tall_cut`, no
  `crown_cut` and no stipple of any kind, so a pole, a pylon or a machine can
  stand through the player forever. `flier_view.gd`'s header says `tall_cut`
  "opens anything BUILT above 3.0 that would cover the player"; that is MADE only.
- `spawner.gd:28` bakes `view_height := 14.0` under a comment reading
  "(CameraRig defaults)", and the rig says 15.0.

### Staging

1. done — the lens exists, opt-in, default byte-identical
2. make the rig the single source: the frustum questions above, the two `cam.size`
   questions split, the bakers found
3. answer a held Z with it (the owner's #120: Zelda-like for close combat,
   Diablo-style orthographic for open battle). The easing is already there and
   `42_target` already drives `lean_yaw/pitch/zoom` on lock. Note the projection
   **cannot be lerped** — ORTHOGONAL to PERSPECTIVE is a discrete switch, so the
   crossover wants fov and distance chosen to match the subject's projected size
   and hide the pop
4. the density and form work, judged with a camera that can show what it is
   judging — the LOOK is settled, the question is only how much world there is

### Open, for the owner

- `LENS_PITCH` 30, `LENS_BACK` 9, `fov` 55 are a first guess, not a tuned answer
- is the lens for combat only, or a mode the player chooses?
- a lamppost stands through the player in every slums frame (see FOUND, above)


## M3 — The landscapes

Grow to at least 20 landscape types, each with its own props, decor, life, weather,
light, hazards, enemies, landmarks and **sentinel**, and fill every realm.

**Blocked on one thing first:** what a landscape's OBJECTS are made of is still
hard-coded — `src/models/props/{houses,remains,rocks,shore,works,trees,built}.gd`
still `match` on `Country`, so a new landscape's houses, boulders, wrecks, signs
and shore dressing fall back to the coast's. A new landscape added today is
dressed as the coast. Make those files read the registry before the landscape
wave, or every new type looks borrowed.

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

### The city wave, in flight (2026-09-18)

The Slums is the first urban landscape and the owner's direction for it is a
Blade Runner city: decayed and thriving at once, high tech, holograms and
advertising and technology everywhere, skyscrapers, flying machines, crowds.
What it was a day ago was eight one-storey huts. Three things had been built for
it and never claimed, which is the pattern this project keeps finding: `built`
(the city declares `BiomeForms.RAISED` and a street plan now), `street_folk`
(thirty people rather than a village's six) and the whole foreground layer.

What has landed: the lid stopped dimming the moon and the engine stopped being
held to seven lamps, so the city lights itself; `BiomeForms` split the PACK of
shapes from the COUNT of buildings, so a settlement can be bigger than the six
silhouettes it owns (17-25 buildings on three lanes); and the foreground layer
asks a building's FORM rather than its prop kind, so the city hangs walkways and
lit sign arms over its street instead of a cottage eave.

**The thing that decides the rest is the camera, and it is worth stating plainly
because it is not obvious**: the play camera is ORTHOGRAPHIC, so nothing far away
is smaller. There is no skyline to put on a horizon — a tower thirty tiles off is
not distant, it is off the picture, which is the same arithmetic
`Landmarks.read_reach` already found. So a city's height can only ever be read
from INSIDE the canyon, which makes what crosses over the street, and what
happens to geometry between the camera and the player, the whole of the problem
rather than a polish item. See #96.

Still open: real height (the tallest form is 9.6 units, five times a person),
density read against the frame (16.4 tiles between street centres against a
26.7-tile frame is one street and the backs of two others), holograms as light in
the air rather than boards on brackets, and **flying machines — nothing in this
game flies at all**, though the roster's vocabulary already has `crosses: &"fly"`
waiting for something to use it.

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
