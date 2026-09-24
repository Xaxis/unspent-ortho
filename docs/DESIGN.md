# UNSPENT — design

How the game plays today. Destination `docs/VISION.md`, fiction `docs/STORY.md`,
look `docs/LOOK.md`, next steps `docs/ROADMAP.md`. Code wins over this file.

## World generation

- Deterministic per seed (`Rng.hash01`, `Rng.make`; never `randf`).
- `GenBodies.plan` lays bodies first: the surface at `Tuning.WORLD_SIZE` (1840)
  has 5 continents; `--size` is a ceiling, and 512 or less gives one body.
- 22 landscapes, one file each in `src/content/biomes/` (21 surface, 1
  underground). A landscape with `spread.x >= 1` is guaranteed and dealt to the
  home continent first (coast, moss, frost sea).
- **A landscape is immense**: it lies on ONE continent (`MOST_BODIES`), each
  continent carries four or five, and each landscape has one heart per
  continent, so it stands there whole. Measure with
  `tools/gd/probe_regions.gd` (frames, core crossing, ecotone depth, what the
  eye sees from the shoulder at the core, what there is to walk to).
- A big enough run of one landscape is a REGION (`WorldData.regions`, global
  ids); keepers, depots, chapters and interference key on its id.
- Borders are ecotones: `country2`/`blend` fade from 0.5 over a share of the
  place's width (12-24 tiles on a test island, 24-64 on a continent).
- Content is counted per area: sites (`GenScatter.TILES_PER_SITE`), landmarks
  (`Landmarks.wanted_in`, one per 7,000 tiles of a region, 3 to 16) and
  villages (`GenSettle.village_want`, a landscape's `villages` per 25,000 tiles
  of its land), so a bigger place is fuller, not emptier.
- A save keeps only the seed. `WorldStamp` refuses a save from a world that grows
  differently (`&"elsewhere"`); a recipe body change bumps `WorldStamp.GEN` by hand.

## World content

- `BiomeDef` is the authority for what a landscape holds: ground recipes
  (`surface`, `scatter`), props and ore, sites, pools, villages, landmarks,
  keeper, roster, hazards, weather, night and sound bed.
- `BiomeDressing` is what its objects are made of; `BiomeForms` what its people
  build.
- Sites scale with region area (`GenScatter.TILES_PER_SITE`).
- Each landscape has three or more landmark kinds; a cache opens once.
- A village green is a haven: hunters keep 14 tiles off it, beasts 10
  (`Haven`, roster `where.green_min`), and the player wakes beside village 0.

## Core play

- **Clock**: 1.4 world minutes a real second; sleep, work, downed and carried
  skip time.
- **Moving**: walk 3.4, run 5.4 tiles/s. A body steps one level; two is a cliff.
- **Jumping**: up 2 levels, across 2 tiles, down 3 (`Jump`). The arc is planned
  at the press; a deeper drop is replanned as a wall, except into deep water (a
  dive). Costs wind; no swing or dodge in the air.
- **Swimming**: deep water at 0.4 of a walk, no running, no swing (dodge
  allowed), soaks you, nothing drowns. Roster `crosses` says which bodies follow
  (`&"swim"`) or fly over (`&"fly"`).
- **Stealth**: `StealthQuery` is the one door for every sense: crouch, cover,
  dark (a lit lamp undoes it), spoofing, role cones, loudness by ground.
- **Targeting**: hold Z to lock the nearest threat, A/D cycle, R sweeps the
  field eight at a time. Read-only on the fight. People and places read too.
- **Fighting**: `FightSim`, fixed 8 ms slices. Blows have windup, active and
  recovery; a dodge has i-frames. A machine has a working part on one side;
  plate takes nothing. A grip is broken by pulling. Outcomes: won, away, downed
  (hours lost) or carried (a shift of forced work).
- **Taking**: `use` works the nearest prop with the held tool. `Harvest.target`
  is the key's own answer and drives the mark. A consuming take works the thing
  DOWN in five steps, never shrinks it. Tools: wood < iron < steel < crucible <
  found; an edge wears, never breaks.
- **Survival**: health, wind, hunger, wet, load, lamp oil. A landscape's hazards
  (16 ids) are felt at 0.25, bite the legs at 0.55, harm at 0.75 and drain only
  to 1 health. Stations: fire, bench, kiln (built); wheel and loom (in houses).
- **Gear**: slots head, body, hands, back, tool, craft; tiers made, mended, found.
  Abilities dash, glide, grapple, scan, spoof, plus the innate jump. A grade buys
  sockets, not numbers.
- **Crafts**: B boards, launches, leaves, strips. Raft (by hand, crosses deep
  water), hover sled, walker rig (bench). A craft changes what ground means and
  the pace, not how the body moves. Worn out it wrecks into salvage (a float
  sinks in deep water).
- **Tracks**: soft grounds keep prints a while; weather fills them. Not saved.

## Progression and world systems

- **Keepers**: one per region with room, eight designs. Each design can be taken
  three of four ways (`SentinelWay`): force (always), founder, starve, spoof.
  Only force and founder kill; a spoofed keeper stands down.
- **Depots**: one per region with a plan work and 900+ tiles. It sends its own
  machines and patrols until broken: three parts, each a held `use` with a steel
  edge. Broken, the yard goes dark and the plan's machines stop coming there.
- **Interference**: 0..1 per region, calm/wary/hostile/hunted at 0.26/0.56/0.84,
  raised by theft, sabotage, kills, filing, trespass. Hunted sends hunters, two at
  most. A lost region (depot broken or keeper down) is capped under hostile.
- **Chapters**: a region is answered when explored, mined and defended; road
  holds on the way out lift when it is, or can be broken or walked round.
- **Settlements**: H opens the holding app. 17 buildable pieces; the first founds
  a holding. It settles by catching up in 30-minute slices, never by ticking.
  Beds cap residents. `Settlement.signature()` is seven channels (light, noise,
  smoke, radio, power, found tech, traffic), loudest piece each.
- **Raids**: no raid timer. A machine reads one channel and must carry the
  record home; kill it first and nothing is filed. Attention climbs in units of
  one record (0.09); 1.0 is a siege led by the keeper. Steps survey, probe, raid,
  siege, each warned 25-110 minutes ahead; dropping the signature turns them
  round. The app shows what machines hear and one word, never a bar. Per realm.
- **Realms**: surface, underground, orbital, era. Shafts (up to four a body) are
  entered with `use`; a crossing rebinds the world, not a new game. The era is
  the surface's own land in 2029.
- **Loot**: all non-recipe spoils go through `Drops` (a body or a place); every
  item has a path back to the world (`Sources.path_to`).

## Story delivery

- Nothing speaks because you walked onto a tile. Story comes through `use` on a
  person or a readable thing (`49_story`, before survival), a machine read
  (testimony), or what was done to the player (witnessed beats, once each).
- The story names kinds of place; `StoryPlan.cast(world)` binds them to this
  world, pure and never saved. A required slot may name only a guaranteed
  landscape.
- A readable thing's words are `StoryFragments.held_by(world, prop)`, pure.
- Talks draw over the running world.
- Each region raises a sub-arc from its own state, said by a local; the world
  answers it, only the telling is saved.
- The ledger writes the player down: people half a day late, machines at once.
- One revelation at a time: after a `reveal` beat, replies and people that would
  land another wait 240 world minutes. A page read is never held.
- Named people stand near their slot; four gates into 2029 open on beats.
- The journal (N) only reads. Story state saves under `story`, outside
  `WorldStamp`.

## Menus and controls

- Every screen is the slate: carry, make, map, home, gear, reads, saves,
  journal, holding, settings, character.
- Keys: WASD, Shift run and dodge, Space jump, J swing, K dodge, E use, C make,
  I carry, M map, F lamp, Ctrl/Q crouch, Z target, B ride, H holding, N journal,
  X drop, Esc pause. Every key shown is asked of the live `InputMap`.
- Settings (sound, picture, playing, keys) are the player's. Dev mode (`` ` ``,
  `src/dev/`) is open, chord (three strikes in 1.5 s) or off per build config.

## Audio

- All sound is synthesised in code. Every emitted name maps through
  `sound_names.gd`; a test fails on an unmapped one.
- Each landscape has a score (`ScoreLandscapes.SPECS`, else composed from its
  id) and a sound bed; borders crossfade at equal power on `blend`.
- The score tenses when an aware hostile machine is near.

## Performance budgets held by tests

- A machine: at most 6 draw calls and 3600 triangles. A person: 1300 triangles.
  A landmark: 10 draws. A depot yard: 4, each part: 5.
- Forty villagers on a street: under 1 ms a frame; one builds in under 12 ms.
- Siting every landmark in a 512 world: under 90 ms; every depot: under 5 ms.
- The `--stats` judge: p50 120 Hz, p95 72, p99 60, worst 30, over 300+ frames,
  warm-up at most 12 frames, none over 250 ms. Only the judge is tested.
