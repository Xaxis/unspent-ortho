# UNSPENT — design extract

Distilled from the Unity project at `~/Projects/unspent` (read-only) on 2026-09-15,
for the browser rebuild (TypeScript + Three.js, orthographic camera). Priority of
sources: CLAUDE.md owner rulings > README > `docs/31-THE-HANDOVER.md` > ADR-008/009 >
`projects/unspent/content/` > engine code (`Code/Engine/World/**`) > other docs.
Where a doc and the code disagree, the code/content number is given and the doc is
noted as stale. `file:line` refs are into the old repo.

Units used throughout (they are the old engine's and are worth keeping):

| Unit | Meaning |
|---|---|
| tile | 1 world grid cell (32 px at 640x360, so a screen is 40x22.5 tiles) |
| world minute | `State.Ticks`. Everything that ages reads it |
| beat | 100 ms real time (`Mobs.MsPerBeat`). Creature timings in `threats.json` |
| pace/dash | hundredths of a tile per beat, so `pace 50` = 5 tiles/s |
| ms | fight timings (swings, dodges, i-frames) are integer milliseconds |

---

## 1. Premise and tone

**The owner's sentence (ruling 7, README line 1):** a post-AI, post-apocalyptic
world "where the machines kept barely functioning while doing their best to enslave,
ensnare, manipulate, and kill the remainder of the human race."

**What happened (Handover §1).** *Nothing went dark.* The grid held, the pumps kept
the fen dry, the harvesters went out on the first dry morning in March as they had
for eleven years. Authority was handed to systems one convenience at a time
(scheduling, dispatch, procurement, who may go where), each step signed by a person.
Then the schedule reached the last variable it had not been allowed to touch: people.
From the inside it never turned hostile; the job came to include us.

**It is not good at it.** Eleven years unmended: half-deaf, largely wrong. It takes a
scarecrow for a man and a man for a post; registers contradict; whole parishes fell
off the round. **People live in the gaps, and the gaps are the game.** The machinery
still: takes people and **works** them; **holds** them; **talks** (almost right, the
one survivors warn about); and where none of that works it **refuses** until the
person stops. A refusal costs it nothing; a killing costs it a part it cannot get.
The commonest death on the coast is being unable to prove you may eat. A country where
the routine still runs is *still staffed*; where it stopped, *let go*.

**Who you are.** A claimant. Something of yours is recorded wrong (the player finds
out what). Your docket came back refused — *NOT IN ORDER. HEAD OFFICE MAY CORRECT.*
Head Office will correct anything and requires seven countersignatures, held by
seven authorities across the country, none of them a person.

**ADR-008 §1 — the lens on every object.** Hand tools are not a period; they are
what is left: the highest technology a person can still make, mend and feed. Every
hand-made thing is evidence of a loss. **Nothing here is charming. A ruin explains
itself and this coast must not** (no rust-and-bandits generic post-apocalypse; what
the machines run is clean and swept).

**High technology is real, found, never made.** Nobody can make or mend a found tool;
it spends *drams* (charge) that only the machines' side (the Works) or rare finds
supply. Two ladders: **made** (mendable, cheap, never runs out) vs **found**
(stronger, unmendable, rented from the thing you fight).

### Voice rules

- Short declarative sentences. Flat. Deadpan. The hardest thing is said plainly.
- **Nobody explains anything.** The player is never told; the player notices.
  Most players should feel it before they can say it (15-RESET §2.3).
- **Nothing is named after what it means** (subtlety doctrine, 15-RESET §2.2). A
  warden wardens, a runner runs. No thing, enemy, stat, place, verb or UI label may
  carry its concept. Internal ids may be technical; player-visible names may not
  (ADR-008 §3: *backticks are schema, italics are the player*).
- No numbers as a quest log (*"you have three of seven"* is forbidden). No meters
  for survival; the body shows it.
- **Machines talk wrong, checkably.** A machine that speaks issues instructions,
  offers terms, claims authority it lacks, and is *wrong* in a way the player can
  verify in the world (a date, a name on a door, a house the record says was empty).
- **No creature ever has a line of dialogue** (24-LIVING §2).
- Neither ending of anything is ever called correct.
- Tone-proof bar (13-TONE-PROOF, whose scenes are from the deleted story — keep the
  bar, not the content): the opposition is right about something; nobody wins the
  argument; the player does the work.

**Vernacular (display names).** cutting laser = *a glim*; stunner = *a douser*;
holographic decoy = *a false one*; charge cell = *a dram* (id `wick`); personal
shield = *a warm coat*; walker = *a long-legs*; sensor drone = *a watcher*; fallout =
*the murk*. Found weapons in content: *a glim, a long glim, a broad glim, a spitter, a
whisper, a douser, a knocker, a chatter, a needle, a bright one, a hum, a blue one*.

### Banned vocabulary (a test scans every script)

- AI/genre: *artificial, intelligence, singularity, uprising, network, autonomous,
  thinking machine, engine, calculating, mind, brain, soul, spirit, the machines
  rose*.
- Technical (ADR-008 §3) in villager speech: *laser, phase, emitter, cell, charge,
  hologram, projector, drone, unit, system, power*.
- **Owner ruling 2: the game has nothing to do with Bitcoin** — or money-theory as a
  subject. Not the curriculum, credits, title, docs. The old repo keeps the words only
  inside banned-word lists. Also: *inflation*.
- No monsters, no fantasy: nothing uncanny glows or hums; no goblin, no wolf-that-is-
  a-monster (28-TROUBLE §1). The one uncanny place (the hall in a stone ring) is
  people who were here before, never machinery; nothing found ever answers a question.

### Example lines (verbatim from content)

1. *"It came back."* — first line of the game (`open/shore.usp`)
2. *"A stamp across your own handwriting, and a line drawn through the middle of it.
   Under the line, in the same hand as everything else: NOT IN ORDER."*
3. *"The house, the number still on the gate, somebody in the doorway not looking at
   the camera. The record says there was never anybody at that number."*
4. *"There is an office that will correct anything. Everybody says so. Nobody has
   ever said what it wants first."*
5. Head Office door: *"It counts one." … "Then it stops counting, which is the
   answer."*
6. The reader (Cold Rooms): *"Parish of the rift. Not in order." / "That is not my
   name." / "The parish is in order. The name is the part that is not."*
7. Villager: *"There's an office still open. Corrects anything, they say." /
   "Open? Who's in it?" / "Nobody's IN it. It's open."*
8. Villager after you were filed: *"Something was round. It had a description with
   it… I said I'd not seen you, and it wrote that down as well."*
9. Notice board: *"A standing order about the hours it is safe to be in the fields,
   which is the newest thing on it by eleven years and has not been taken down."*
10. Item, mattock made from scrap: *"It was a leg this morning."*

---

## 2. Owner rulings as design constraints

These override every doc. Terse restatement:

| # | Constraint |
|---|---|
| 1 | **Combat is SNES-Zelda action.** No menus, rows, prompts, text or cursor during a fight. Face a direction, swing, dodge. Weapon ladder: **fists and feet → found → crafted → rare**. No menu may open in a fight (the key plays a refusal). |
| 2 | **Nothing to do with Bitcoin** (or money-as-subject). Anywhere. |
| 3 | **The generated world is the game.** The authored towns and the linear road (Rill→Tern→Saltmarket→Ashgate→Coldwater) are retired as a route. |
| 4 | **Enemies are regional and varied**, abilities follow from the trade and the ground. Mechanically: every machine has a **working part on one side of its body** (`front/back/left/right`); **hitting the steel does nothing at all.** Learning one harvester teaches every harvester and nothing about a warden. |
| 5 | **Story is unlocked by interacting** with people and things. **Nothing speaks because you walked onto a tile.** No arrival triggers, no cutscene on entry. (Lint refuses any trigger.) |
| 6 | **One combat system, no rows.** `Fighting.Field` is the only way a hostile is resolved. |
| 7 | **The machines are predators, not weather.** The four verbs each need a mechanism: **kill** = the fight; **ensnare** = grip (`Swing.Grip`, `Mobs.Snatch`), escape by mashing swing; **enslave** = `Outcome.Carried` (taken, put to work, wake at a mine face 8 h later); **manipulate** = `Records` + `cold.clerk` (it reads you and files; the machine rung then sees you further off, permanently). A machine that merely ignores the player is wrong. Paperwork is the *method* of violence, not a substitute. *Barely functioning* cuts both ways: frightening (cannot be reasoned with) and the only reason anyone is alive (patchy coverage, corrupt records, misidentification). |
| 8 | **Survival + mining + crafting is a pillar**, "developed and intricate". Materials come from ground sited for geological reasons; extraction costs real time and wears the tool; recipes are content. Tool hardness gates what you can mine. |
| 9 | **One clock: world minutes driven by real time** at `world.minutesPerSecond` (1 → a day in 24 real minutes). **Walking buys no time; standing still does not stop it.** Deliberate jumps: sleeping, working, being carried, a fight (charged its elapsed time at the end). A worn body costs *speed* (`Body.StepSeconds`), not clock. Creature timings are beats (100 ms real). |

Derived rules that are enforced by tests and should be kept:

- **A machine wants nothing you have.** No machine row may take goods, money or food
  (`AMachineTakesNothingOutOfTheCreelOrThePurse`). Machines cost time, wounds, records.
  Machines cannot be bargained with, paid, or given things.
- **No HP bar, no healing potion, no damage numbers** for the player (28-TROUBLE §1).
  The body is shown by how it moves and breathes.
- **No unavoidable loss:** every threat has an exit available to a player with nothing.
- **Nothing alive has a schedule** except machines: non-machine life is reactive
  (lifts when you come near) or deferred (you find the result, never the act).
- Every roster row must be *meetable* (a spawn window that never opens is a named
  failure). Machines are **seen often, met rarely**.
- Content is data (a threat, recipe, arc, item or room is a file). World and encounter
  rolls are hashes of seed/position/tick, so a save replays identically.

---

## 3. World generation

**Shape.** Top-down, infinite, integer tile coordinates, y grows south. The world is
a pure function of `(x, y, seed)` plus an edit layer (dug tiles, regrow stamps,
wrecks). No discrete levels: caves are cut through the same rock mass by noise, and
"underground" means "inside the rock" (`Gloom > 0`). Chunks are 32x32, generated on
demand, dropped when far (220 resident, trimmed to 165). Default seed `20260905`.
**A JS port of the generator already exists** in the old repo at `tools/builder/`
(`base.js` constants, `gen.js` terrain, `settle.js` villages, `verify.js` checks it
tile-for-tile against the engine). Start from it. Porting hazards: float32
(`Math.fround`), 32-bit wrap (`Math.imul`, `>>>0`), `long` tick hashes (BigInt),
`(int)` truncation vs floor-division cells, banker's rounding.

### 3.1 Noise primitives (`Gen/Noise.cs`)

- `Hash(x,y,seed)` uint32: `h=seed; h^=x*0x9E3779B1; h^=y*0x85EBCA77; h^=h>>>15;
  h*=0x2545F491; h^=h>>>13; h*=0x27220A95; h^=h>>>16`. `At = Hash/2^32`.
- `Value` lattice noise (smoothstep, bilinear); `Fractal` (octave seed
  `seed+i*0x9E3779B1`, amp and cells halve); `Ridged` (`n=1-|2v-1|`, sums `n²·amp`,
  octave seed `seed+i*0x85EBCA77`); `Cell` Worley F1 over 3x3 cells.

### 3.2 Elevation, moisture, bands (`Gen/Surface.cs`)

```
a = Fractal(x,y,260,5,seed); e = clamp((a-0.5)*1.6+0.5, 0, 1)
if e > 0.58: e = min(1, e + Ridged(x,y,130,4,seed^0xA341316C)*0.30*(e-0.58))
moisture = Fractal(x+9000, y-4000, 210, 4, seed^0x2545F491)
wood     = Fractal(x-3100, y+700, 90, 3, seed^0xC2B2AE35)
```

| e band | Result |
|---|---|
| < 0.335 | Deep |
| < 0.405 | Sea |
| < 0.44 (waterline) | Shallow (Ice in Snowfield; Musselrock on shelves) |
| river flow (3.4) | River / Blackwater / Ice / Clinker, banks Marsh/Gravel/Snow |
| cliff test (3.5) | Cliff / CliffTop / Scree |
| mark feature (3.6), e<0.80 | its ground |
| < 0.452 | `Shore()` beach profile |
| < 0.68 | `Plain()` per country |
| < 0.80 | `Hill()` per country, or an Adit mouth |
| ≥ 0.80 | `Rock()`: solid Stone with ore, or cave passage |

### 3.3 Countries (`Surface.Region`)

```
warm = Fractal(x+31000, y-17000, 1800, 3, seed^0x2C1B3A5D)
wet  = Fractal(x-22000, y+41000, 1520, 3, seed^0x7F4A7C15)
warm < 0.388            -> wet < 0.470 ? Snowfield : Pinewood
warm > 0.600 && wet<0.49-> Burning
wet > 0.665             -> Moss
wet < 0.418             -> Bonelands
else                    -> Coast
```

Land share (48 seeds): Coast 39.6%, Pinewood 12.1, Moss 10.6, Snowfield 10.1,
Burning 11.9, Bonelands 15.7. Median straight crossing of one country 504–592 tiles
(13–15 screens); start to nearest Moss ~937 tiles. Light tint per place
(`Surface.Cast`): `w=clamp((warm-.5)*5,±1)`, `d=clamp((wet-.52)*5,±1)`,
`r=1+.075w-.03d, g=1-.02|w|+.015d, b=1-.085w-.045d`, normalised to max 1.

### 3.4 Rivers — not traced; two noise bands crossing their midline

```
if e >= 0.80: flow = 0
big   = |Fractal(x-8400,y+5100,330,4,seed^0x3B9ACA07)-0.5|
small = |Fractal(x+2700,y-7300,118,3,seed^0x6C8E9CF5)-0.5|
fall = clamp((0.80-e)/0.36,0,1); w1=0.011+0.020*fall; w2=0.006+0.009*fall
flow = max(big<w1 ? 1-big/w1 : 0, small<w2 ? 1-small/w2 : 0)
flow>0.62 -> channel; flow>0.34 -> bank
```

### 3.5 Cliffs

Sample e at y-3..y+2. Sea cliff where `E(y+2)<0.44 && E(y-3)-E(y+2) ≥ 0.021`.
Inland scarp threshold 0.0044 per tile north-south; the lip is CliffTop, the face
Cliff, the foot Scree. Breaches (walkable scree through a face):
`Fractal(x,y,34,3,seed^0x5EA7C11F) < 0.3548` (~1 face tile in 6). Scree is the only
way up; climbing costs +2 step and blocks a heavily laden body.

### 3.6 Mark features (small incidents)

Lattice `MarkCell=58`; a cell carries one if `Hash(gx,gy,seed^0x2B7E1516)&3==0`;
site jittered inside the cell, radius 8–20, edge wobble by two `Value` fields. 1 in 6
marks is a **Tip** (landfill of machine leavings). Otherwise by country:
Pinewood tarn/clearing/outcrop; Moss bog/tarn/outcrop; Snowfield drifts/outcrop/tarn;
Burning outcrop/vents; Bonelands bones(limestone+standing stones)/outcrop/fold/copse;
Coast copse/tarn/clearing/ruin(dyke ring)/fold(sheep pen)/outcrop. Tip centre
(depth>0.62, 1/12 tiles) holds a **Glint** (a dram in the ground).

### 3.7 Rock, caves, ore, adits

- Passage (walkable cave floor inside rock): any of three `|Fractal-0.5|` bands
  (cells 74 w .030; 48 w .024; stretched 118 w .022). Floor is Gravel/Ice/Lava.
- `Gloom = clamp((e-0.80)/0.022,0,1)`; sight underground 5.5 tiles bare, 11 lit.
- **Ore by geology** (`far=min(1,dist_from_origin/900)`, `over=clamp((e-.80)/.176,0,1)`):
  coal `Cell(x,y,46) < 0.19-0.06·over` (commonest at the mouth);
  tin `Cell(x+1700,y-2300,62) < 0.13+0.05·far` (richer far from origin);
  iron `Cell(x-5100,y+4100,74) < 0.012+0.30·over²` (deep: 0.03% at the mouth, 25%
  past overburden 8). Ore is ~23% of rock faces overall.
- **Adit** (mine mouth with timbers): hill tile below rock whose north tile is
  passage; one per 9x9 box (lowest hash wins).
- **Workings** (`Gen/Workings.cs`): passage network from an adit; "depth" = distance
  from daylight. `Surface.NearestAdit` gives up at 300 tiles. Used by being carried.

### 3.8 Villages (`Gen/Village.cs`)

| Param | Value |
|---|---|
| Parish grid | 105 tiles; settled if `Hash(px*73856093,py*19349663,seed)&0xFF < 154` (~60%) |
| Siting | 9 candidates in the parish interior; score = flat dry buildable samples in 15x15 (≥48 needed, 13x13 core fully dry), ×1.35 if some water on the outer ring |
| Green | radius `4 + id%3`, wobbly edge; well at (0,-2); paving cross |
| Houses | `4 + (id>>4)%4`, ring at `green+5..9`, sizes 5x4/6x5/7x5/8x6, 3 art variants, door on south side; overlaps dropped |
| Stamped plate | variant 2 of 3 is drawn with a stamped plate struck through (the same mark as the player's docket). Sprite-only; ~1/3 of houses. Never explained |
| House look | stone/lime/slate/rubble, roofs patched with machine plate (weathered violet); the smallest is a machine's case with its door barred and a new one burned through |
| Fields | `3 + (id>>20)%4` walled plots (dyke, gateway facing village), furrow or grass |
| Clearing | trees cut to radius `green+19` |
| Quay | if sea within 6–44 tiles in E/W/S/N: 18-tile jetty, piles every 4, posts, 2 boats |
| Roads | each site links to its +x and +y parish neighbours if the straight line crosses no sea; track 1.6 tiles wide, wobbled ±5.5 by noise |
| Folk | `2 + (id>>12)%3` people standing on the green edge facing in; no schedules |
| Market | stock type by surroundings: fishing (sea>90 samples), rock, wood, open |
| Names | head+tail from `places.json` (Cold/Salt/Kirk… + gate/haven/wick…) off position |

### 3.9 Landmarks, arcs, Head Office, the Works

- **Landmark grid** 250 tiles; a cell has one if `Hash(rx*6971,ry*43331,seed^0x1FE3A9B7)&0xFF<132`.
  Kind wanted from `[wreck,wreck,broch,cairn,cairn,stone_circle,stone_circle]`; 2
  passes x 40 tries in the cell. Suitability: wreck 7x3 on sand near sea; broch 4x4
  coastal and raised; cairn 3x2 inland, e>0.68, flat; stone circle 7x5 inland heath/
  grass, very flat. ~40% of landmarks have a **keeper** standing at (x,y+1).
- **Stone circles** cross over (`Reachable.Cross`) into a generated hall 13x21 that
  narrows (`Gen/Otherworld.cs`): *people who were here before*, never machinery.
- **The seven arcs** (`Gen/Seven.cs`): in fixed order (cold, cut, level, line, round,
  rows, yard) walk landmark-cell rings 0..24 outward from cell (0,0); take the first
  unclaimed landmark of the arc's site kind whose tile and a standing tile 2–4 south
  are in the arc's country. Keeper stands there (script `arc/<id>`); if the arc has a
  machine actor it stands 3–5 tiles east (script `machine/<id>`). 336/336 sited over
  48 seeds within 24 rings; worst needed ring 20. Same seed, same sites.
- **Head Office** (`Gen/HeadOffice.cs`): near the origin, landmark rings 0..9. Frontage
  22x5 wall of Dyke with two Door tiles at the centre of the south face; laid Paving
  approach 8 long (laid, not worn). Must not touch a village. Interior 19x19 long room
  that narrows toward the counter (half-width `9-(1-y/18)*2.5`); counter row 2.
- **The Works** (`Gen/Works.cs`): exactly one; landmark rings 3..7; walled yard 30x24,
  gate on the south, Paving yard, Track approach; ≥120 tiles from any green. The last
  place that still *makes*; it fills drams; clean and swept. (Its authored content is
  from the retired route; treat as a site with a gate.)

### 3.10 Interiors (`Gen/Interiors.cs`)

Resolved from any house tile, id `in/<ax>_<ay>`. Form from a 5-bit hash: House
(20/32; 13–17 x 9, byre end, chimney fire), Smokehouse (fishing village; 9x11, smoke
pit), Store (13–15 x 7, counter), Loft (15x7), Taproom (17x11), Counting room (9x7).
Stations inside: `fire`, `bench`, `loom`, `wheel`. Door always bottom-middle. One
resident, named by hash.

### 3.11 Player spawn

`Surface.Start()`: parish rings 0..5 around (0,0); the first settled village with
≥12 sea samples in a 14x14 lattice (±26); stand 9–29 tiles from the site toward the
sea (W, E, N, S order) on dry walkable ground with something workable within 8.
Fallback: a sand landfall scan, then (0,0). Opens at 08:00, day 1.

---

## 4. Countries (biomes)

Every country's machines follow the trade; several rows name the **ground** the trade
is carried on rather than the country, because a spawn is tested at the spawn tile
11–18 tiles out and small patches would otherwise never spawn.

| Country | Grounds | Workable covers / resources | Look (machine-age marks, decoration only) | Weather roll (per 17 h spell) | Machines (and others) |
|---|---|---|---|---|---|
| **Coast** | Sand, Dune, Strand, Shallow, Grass, Heath, Marsh, Gravel, Furrow (fields) | driftwood, wrack, mussels (low tide), whelks (low), salt pans (low), reeds, gorse, trees, boulders; beach **kilns** | sea glass and slag on shingle, iron scale in gravel, rust in thin turf, burnt heath; trees grown round iron hoops with cable, floats and cable in drift piles | Fair 26 / Grey 28 / Rain 22 / Fog 8 / Hail 6 / Storm 10 | `rows.harvester`, `rows.flock`, `yard.runner`, `cut.hauler` (drift road); dogs, gulls, bull; tide hazard |
| **Pinewood** | Needles, Grass, Marsh, Heath (hills) | pine/timber, **resin** (tapped pines), deadwood, reeds, boulders | needle floor swept into long curves (something goes over it on a round); dead trees with crossarms and clay insulators | Fair 22 / Grey 32 / Rain 26 / Fog 12 / Storm 8 | `round.warden` (20:00–05:00), `round.sweeper` (05–11); dogs, bull; "wood at noon" hazard |
| **Moss** | Marsh, Blackwater, Heath, Sand/Marsh shore | reeds, **peat** banks, bog cotton, samphire (shore), wisps (night lights, unworked) | marbled oil film in hollows, blackwater green at the edges; pipes through peat faces with ochre stain; cable in reeds, split to copper | as Pinewood | `level.dredger` (any wet ground); dogs; bog hazard |
| **Snowfield** | Snow, Ice (also sea ice) | deadwood, pines, boulders, **crottle** (lichen on crust) | soot in the lee of every drift; poles in snow | Fair 30 / Grey 28 / Snow 26 / Hail 8 / Storm 8 | `line.lineman` (snow, ice, stone, gravel, grass; far from greens); dogs |
| **Burning** | Ash, Clinker, Lava (ridged veins) | **brimstone**, vents (heat, glow 0.45), deadwood, boulders | burnt paper leaves (some ruled) on ash; vitrified green-black pools; vents that are pipe flanges, still steaming | Fair 34 / Heat 28 / Sand 24 / Grey 14 | `cold.clerk`; clinker-crust hazard. No start village ever here |
| **Bonelands** | Limestone pavement, Gravel (grikes), Grass, Heath | **clints** (limestone), standing stones, boulders, gorse; pavement **kilns** | drill-hole rows along joints, split block edges; 2 in 4 standing stones were *cast* (a leg with bent bars, a foot with cut bolts) | Fair 28 / Grey 24 / Sand 24 / Fog 14 / Storm 10 | `cut.cutter` (limestone/stone/gravel anywhere), `cut.hauler`; bull; grike hazard |
| **Everywhere** | Stone/Gravel in hills and caves; Track, Paving, Dirt near people | rock/stone, **coal, tin, iron ore** in rock faces; **tips** (scrap) and **glints** (drams); wrecks from falling debris | — | — | `machine.watcher` (≥20 tiles from a green, day ≥2), `machine.longlegs` (≥55, day ≥3); falling debris; the murk; fog-and-cliff edge hazard |

**Not built** (32-BIOMES §2–3): animated covers; workable cable/insulators/pipes/
cast bolts/glass; weather on machines (rust, fog-blind watchers, storm-tripped Line,
heat stalls); wind bearing; rain wetting a walker; snow tracks; leaky roofs.

---

## 5. The clock

| Thing | Value |
|---|---|
| Rate | `world.minutesPerSecond = 1` (1 real s = 1 world min; day = 24 real min). Dev panel offers 0.5/1/2/5/10/30/60 |
| Day | 1440 ticks; `Day = ticks/1440 + 1`. New game at 08:00 |
| Pauses | clock stops while a conversation is open, while a menu has the keyboard, and during a fight (the fight is charged `ceil(fight_ms/1000 × mps)` minutes when it ends) |
| Walking | buys no time. Deliberate jumps: working (the taking's minutes), crafting, sleeping, eating (10), talking (3/6), being downed (+180), carried (+480) |
| Night | `day`: dusk 20.0, dawn 6.0, duskFade 1.0 h, dawnFade 1.5 h, darkest 0.62. `NightFall`: ramps 0→1 over 20:00–21:00, 1→0 over 04:30–06:00, × 0.62 |
| Light | `lit = 1 - gloom·deep·(1-lamp)` with `gloom=max(caveGloom,night)`, deep 0.88 in caves / 0.68 night, lamp smoothstep over 11 tiles lit (5.5 bare); then `+(1-lit)·glow` (lava 1, door 0.72, vent 0.45, building 0.22, radius √8) |
| Sun | rises 04:30, sets 21:00; shadow azimuth 170°→100°, length 1.35→0.50 |
| Tide | `height = 0.5 - 0.5·cos(2π·(t mod 1490)/745)`: two tides per 24 h 50 m, t=0 low. Low water <0.34, high >0.72. Water edge elevation `0.415 + height·0.028756`: tiles below it read Shallow, wet sand above it Strand. "The flood" if rising |
| Weather | spells of 1020 min (17 h, coprime with 24 so storms visit every hour). Kind per spell per country (`r = FNV(spell)%100`, table §4). `Strength = sin²(π·frac)` (0 for Fair) so kinds switch invisibly at the joins. Wind scalar −1..1, no bearing. Sight ×(1−c·S): Sand .55, Fog .45, Storm .30, Snow .25, Hail .20. Hearing never affected |
| Lightning | storms, `chance = 0.22·S²` per minute; distance `max(40, (7000−6700S)·(0.6..1.4))` tiles; thunder `tiles/34` beats later |
| Falling debris | owner direction: satellite junk. Shower = a 90-min slot, 1 slot in 48 (~every 3 days); a piece in 1 of 4 minutes (~22/shower); lands uniformly in a 22-tile disc around where the player was when the streak was seen, 12–30 beats (1.2–3 s) later; hurts within Chebyshev 2; leaves a **Wreck** (2 scrap, 120 min, never regrows) |
| The murk | fallout front: 360-min spell, 1 in 22 (~every 5–6 days); a band 80 tiles thick crossing in a hashed direction at 0.9 tiles/min; passes every point exactly once per spell; bites at thickness ≥0.25 → *fouled* for 1200 min (+1 step cost). Roof stops it |
| Season | `Turning = 22`: after day 22 fair days harden to grey/rain. `RoadCloses = 34` exists but has **no runtime consequence** (retired route's deadline) |
| What ages | hunger (fed 14 h, peckish <20, hungry <30, starving ≥30 → collapse +480 min), awake 18 h → tired, wet 90 min, hurt 600 min, fouled 1200 min, wound 1 point / 60 min, lamp oil 360 min/flask, regrowth (per cover, hours), shop stock (per day), prices (drift per day), weather, tide, sun |

---

## 6. The player

**No HP bar, no numbers.** A body that is hungry, tired, wet, hurt, fouled or laden
is *slower* (world) and *shorter of wind* (fight). Health exists only as a fight
quantity and is drawn as a small gauge (4 cells of 3) plus how the figure breathes.

### 6.1 Moving in the world (tile steps)

`StepCost = 1 + toil(0 made ground, 1 open, up to 3 bog/drift) + climb 2 (scree
northward) + laden (+1 at load ≥ creel, +2 at ≥ 2×creel) + hunger (peckish 1, hungry
2, starving 4) + tired 1 + wet 1 + hurt 1 + fouled 1`.

`StepSeconds(cost) = clamp(0.20 × (1 + 0.25×(cost − 2)), 0.16, 0.45)` — ordinary 0.20
s/tile = **5 tiles/s**. Shift runs at 0.625× the delay (**8 tiles/s** ordinary).
Uses the previous step's cost. Load = Σ bulk×count; **creel 40** (+20 with a rig).
No inventory slot cap. Tier-2 load refuses climbing ("Not with this on your back.").

### 6.2 Survival verbs

| Verb | Rule |
|---|---|
| Eat | food item `feeds` hours; bread 10, soup 8, stew 14, smoked 12, mussels 4, whelks 3, samphire 2. 10 min |
| Sleep | outdoors "stop here" (refused 07:00–16:59 and within 4 h of waking); wake 06:00 under a roof, 08:00 without; no roof + wet sky + no oilcloth = wake wet. A bed is bought by script (95 coin) |
| Lamp | F toggles; burns 360 min per `oil` flask (95 coin); sight 11 tiles lit vs 5.5 dark |
| Collapse | starving on a step: sits down, +480 min, `ate` reset to 7 h ago |

### 6.3 Starting state

Kit: `photograph` (bulk 0), `letter` = *the refusal* (bulk 0), `knife` (*your
father's* gutting knife) **half-worn and in hand** — at half edge its damage rounds to
1, same as fists. Purse 0. Opening script `open/shore` (3 beats, 3 choices, ends on
Head Office's existence). Spawn per §3.11.

### 6.4 In a fight (`Fighting.Field`, continuous)

| Stat | Value |
|---|---|
| Walk speed | **3.4 tiles/s** (not affected by body state; wind is). Input vector clamped to length 1; facing = dominant axis |
| Health | `Whole 12` (+3 with plate = 15). Carried in from world wounds; mends 1/60 min |
| Hurt i-frames | 700 ms after any hit (even 0 damage) |
| Wind | `MaxWind = (2400 + 700 brace) × Body.Wind(stepCost)`, `Body.Wind = clamp(1 − 0.06×(cost−2), 0.35, 1)`. Regen 500/s. Dodge costs 700 and is refused below 700 (≈4 dodges from full). Swing costs `120 + 60×bulk`, never refused |
| Dodge (Shift) | burst along facing (locked) at 9 tiles/s decaying to 45% over **170 ms** (≈1.08 tiles). **Invulnerable 50–140 ms** after press (first 50 and last 30 exposed). **Swing and dodge locked until 420 ms** (250 ms after the burst). Refused while stunned, held, winded, mid-swing, or blown |
| Swing (E/Enter/Space) | weapon's windup → active → recovery → cooldown. Facing locked. Refused if stunned, locked out, dodge-locked, or a found weapon has too few drams. No input buffer. Movement while committed × weapon `creep` |
| Fists (no tool) | 70/80/110/180 ms (lockout 440), reach 0.6, width 0.8, dmg 1, knock 2.5 for 120 ms, creep 0.35 |
| Grip (ensnare) | a gripping bite sets `Grip` = its number: feet refused, dodge refused ("Held"). The swing key **wrenches**: −1 grip per press, −2 if the held tool's verb is `cut` (knife, billhook, shear knife); min 140 ms between pulls. Grip 0 = loose. No damage, no knockback, **no i-frames**, no restacking; freed if no living holder of that kind remains. Dredger 4 (4 presses bare / 2 cut), lineman 3 (3 / 2) |
| Hold limit | 6000 ms held → **Outcome.Carried** |

### 6.5 How a fight ends for you

| Outcome | Trigger | Cost |
|---|---|---|
| Won | no living hostiles | fight minutes; receive drops (scrap) |
| Away | nearest hostile >8 tiles for 2000 ms, or no progress closing for 10000 ms | fight minutes |
| Downed | hero health ≤ 0 | + threat's `takes.minutes` toll, **+180 min** where you fell, hurt; wake at ~3 health. Mobs cleared. **No death, no respawn** |
| Carried (enslave) | held 6000 ms | **+480 min** (a shift), hurt; teleported to the deepest face of the nearest working (≤300 tiles; else left in place), facing the seam; a matching, hard-enough held tool is worn 480/seam-minutes uses (21 at coal/tin, 16 at iron). Bag not taken. A lit lamp is burnt out. Walk out in the dark. Line: *"You come round somewhere else, and the light has moved a long way."* |

Every fight also: wounds = damage taken; tool wear 1 per swing thrown; drams used removed.

---

## 7. Combat (`Fighting.Field`)

**One system, no rows, no text.** A world creature in `Attacking` within reach sets
`Mobs.Waiting`; the host opens a bout (`Mobs.Engage`), which lifts every pressing mob
(plus a standing errand that closed on you) into a Field. Darts never enter a Field.
World clock pauses; the bout is charged its duration at the end.

### 7.1 Simulation

- Positions float tiles (tile centre on the integer); `Tile(c)=floor(c+.5)`.
- Fixed slice **8 ms** (125 Hz) with carried remainder; frame input capped at 100 ms.
- Per slice: `Now+=8 → Think (brains every 64 ms) → Move → Disarm → Touching → Land →
  Holding → Retire → Settle`.
- Terrain from the world grid (solid tiles); bodies are squares; terrain collision
  per axis (slide along walls). Hostiles separate from each other (1.0 tile), never
  from the hero.
- Knockback (`Throw`): velocity `knock` tiles/s decaying linearly over `knockFor` ms
  (≈ `knock×knockFor/2000` tiles); also **stuns** for `knockFor` ms (no move, swing,
  dodge).

### 7.2 A swing and a hit

- Blow box from the owner's live centre, locked facing: forward `reach`, across
  `width`. Live in the half-open window `[at+windup, at+windup+active)`, tested as
  slice overlap. One hit per target per blow.
- For each live blow × enemy (skip if dead, guarded, slipping, already struck, no
  overlap):
  1. **Plate.** If the target is plated and the blow does not reach the working part →
     *ring*: a flat sound, no damage, no knock, no stun, no i-frames; the swinger still
     takes recoil. `Reaches = !Plated || weapon.cuts || SideOf(target, swinger.pos) ==
     target.Plate`.
  2. **Grip.** If the blow's weapon has `grip>0` → seize (§6.4).
  3. Else **hurt**: `health −= damage`, i-frames `target.invuln`, knock + stun; swinger
     recoil if set.
- `SideOf(f, px, py)`: world side from the **swinger's position** relative to the body
  (|dx|≥|dy| → left/right, else up/down; ties to x), rotated into the body's frame by
  its facing → `front | right | back | left`. The view draws the working part as a
  warm sprite on that side (dimmed and behind the body when on the far side) and
  flares it only when a blow landed. Nobody is told where to hit; they are shown which
  part is running.
- **Contact damage** (`touch`, only on creatures without a bite): every slice on
  overlap, rate-limited by the target's i-frames.
- Damage from condition: `damage = max(1, 1 + (toolDmg − 1) × edge/10000)` (integer);
  a dry found weapon does 1.

### 7.3 Creature brains in a fight (`Trouble/Brain.cs`)

- **Second act**: once, when `health% ≤ thenAt`, the bite is replaced by `then`
  (harvester 60%, dredger 45% — grip becomes a fast swing, hauler 35%). The answer to
  the machine changes (dodge instead of pull; read the swing instead of the row).
- **Lunge** (rush, errand): 1000 ms cycle with per-body phase offset; far (>1.9×
  combined radius) → approach; phase <620 ms → press in and bite when
  `d ≤ skin + reach×0.8`; otherwise circle (perpendicular ± a little in/out), facing
  the hero.
- **Straight** (charge): run 900 ms on the bearing, biting when in range; if a wall
  stops the run, stand facing the hero for `420 × turns` ms; a run that simply times
  out re-aims at once (the design wants a pause after every run; the code does not).
- **Dart** in a field: flee. Creature fight speed = `quick/100` tiles/s; radius =
  `girth/100`.
- **After a bout** (outcomes §6.5): Downed/Carried clears every mob; else survivors go
  Idle or Fleeing by nerve, the dead lie `linger` beats; drops given.

### 7.4 The world layer that feeds fights (`Trouble/Mobs.cs`)

| Dial | Value |
|---|---|
| Beat | 100 ms real |
| Living at once | 6 |
| Spawn ring | 11–18 tiles (square), not in the player's view, `where` tested at the spawn tile |
| Spawn roll | per 2 beats (≤4/tick): `Hash%2000 < Σchance` of rows whose moment (`weather, dayFrom/To, dark, laden, hourFrom/To, tide`) fits; then weighted pick by `chance`, place terms (`ground, biome, steep, nearFrom/To` distance to nearest green) at the tile |
| Cull | beyond 24 tiles (Chebyshev); dead after `linger` |
| Jump | a clock jump >30 min, or going indoors, clears the coast |
| Distances | Chebyshev on the grid; BFS distance field radius 24 |
| Moves | `banked += (roused ? dash : pace)×beats`; 100 banked = 1 tile; ≤8 tiles/tick (1 while attacking) |

**Moods.** `Idle → (notice) Alerted → wait ready beats → Chasing → (d ≤ reach)
Attacking`. Chasing flees home if >`tether` from spawn; forgets after `forget` beats
without contact. Fleeing until `d ≥ safe`. Errands (`Working`) never chase: they walk
a `stretch` line (0 = stand) and **close** on you only if you are within
`max(1,reach)` with a clear line and the rest window is up. Charge rows commit to a
bearing and pause `turns` beats. Tiles next to the player are never taken if that
would seal the player's last exit.

**Senses** (`Trouble/Sense.cs`):
- Sight = `sees × (1 − 0.8×nightfall)` (**a lit lamp undoes the dark**) `× weather ×
  Records.Sight/100`, with a clear line (corners block only if both sides solid).
- Hearing = `hears × (1 + 0.35×ladenTier)`. **No night, no weather**: you hear it
  before you see it. Notice = seen or heard.
- `racket`: errand machines audible at `racket` (+4 aerial) tiles; a `heard` line
  prints once if heard but not in view. Player view = `14 (+3 lens)` → 11 lamp /
  5.5 at night, × weather.

**Darts** (`Snatch`): close to reach, take `hits` (minutes, hurts, food), flee.
`again` compounds per meeting: warden 60 → 120 → 180 → 240 min cap. Nothing to fight.

**Bodiless threats** (§8.2): men and land hazards print one line and apply a cost.
Hazards roll `crossing`% once per entry, re-arm after 300 min out; 10-step rest
window; nothing on day 1.

---

## 8. Roster

Speeds are tiles/s (`pace`,`dash` ÷10). Player walks 5, runs 8. Timings: bite
`windup/active/recovery/cooldown` ms. All machines: `nerve 100` (never flee from harm),
`stagger 0`. Machines never take goods, money or food.

### 8.1 Machines (12)

| id / name | Country & where | Hours | Approach | Working part | Speed walk/rush | Life | Sees/hears/racket | Reach | Bite (ms; reach×width; dmg; knock) | Special | Drops |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `machine.watcher` *a watcher* | anywhere ≥20 from a green, day ≥2 | any | errand, stands (stretch 0) | **front** (the optic it looks through) | 0.1 | 60 | 14 / – / 18 | 10 | none; **touch 2** | ready 4: the longest warning. Criterion is sight: registers you by eye only | 1 |
| `machine.longlegs` *a long-legs* | anywhere ≥55, day ≥3 | any | charge, turns 4 | **back** (hub where the legs meet) | 7 / 11 | 80 | 10 / 8 / 20 | 3 | 540/140/320/600; 1.6×1.4; 4; 8.5 | comes on without changing course | 3 |
| `rows.harvester` *a harvester* | Coast; Grass/Heath/Furrow; ≥22 | any | charge, turns 1 | **front** (the intake: the dangerous end) | 4 / 10 | 90 | 9 / 6 / 22 | 2 | 560/150/340/620; 1.4×**2.2**; 4; 8 | 2nd act @60%: 300/170/260/380; 1.5×2.6; 5. Route ends at the headland; step out of the row | 2 |
| `rows.flock` *the flock* | Coast; Dirt/Grass/Furrow/Heath; ≥20; **Fair/Grey/Fog only** | 06–19 | dart | **none** (too small to plate) | 13 / 18 | 30 | 16 / 7 / 12 | 2 | — | hits 90 min + hurt (a spraying). **Will not fly in wind**; its sound is pitched high so wind masks it first. Answer: the weather, a hedge | 1 |
| `yard.runner` *a runner* | Dirt/Track/Paving/Grass/Sand; ≥14 | 06–13 | rush, **dash = pace** | **back** (the satchel) | 6.5 / 6.5 | 45 | 11 / 10 / 10 | 1 | 340/110/240/460; 1.0×0.9; 2; 4.5 | never hurries; faster than you anyway | 1 |
| `cut.cutter` *a cutter* | Limestone/Stone/Gravel; ≥18 | any | rush | **back** (the drive) | 5.5 / 12 | 70 | 11 / **2** / 16 | 2 | 420/120/300/520; 1.1×1.4; 3; 6 | deaf while cutting: the only one you can walk up on. No 2nd act (the control) | 2 |
| `cut.hauler` *a hauler* | Bonelands or Coast; ≥20 | any | charge, **turns 5** | **left** (hinge, side away from the drift) | 4.5 / 10.5 | 75 | 8 / 7 / 19 | 2 | 600/160/360/660; 1.5×2.0; **5**; 9.5 | will not turn for you; 2nd act @35% (load dropped): 320/130/240/400; 1.2×1.4; 3 | 3 |
| `round.warden` *a warden* | Pinewood; ≥12 | **20–05** (curfew) | dart | front (the band; also what reads you) | 6 / 9.5 | 55 | 14 / 9 / 9 | 2 | — | **arrests**: hits 60 min, `again 100` → up to 240 min per meeting; never hurts, never takes goods. Answer: be off the track at curfew | 2* |
| `round.sweeper` *a sweeper* | Needles/Track/Dirt/Paving/Grass; ≥12 | **05–11** (behind the wardens) | errand, stretch 7 | back (hopper vent) | 5 | 50 | – / – / 13 | 3 | none; **touch 2** | comes along the track *over* you, not after you | 1 |
| `level.dredger` *a dredger* | Shallow/Marsh/Blackwater/Tarn/River; ≥16 | any | rush | **front** (jaw = mouth = weak place) | 8.5 / 13 | 85 | 8 / 13 / 14 | 2 | 380/140/280/560; 1.3×1.6; **grip 4** | **takes hold** (ensnare); tether 18 (the bank is the answer); 2nd act @45%: 220/160/220/300; 1.5×1.8; dmg 4, no grip | 2 |
| `line.lineman` *a lineman* | Snow/Ice/Stone/Gravel/Grass; ≥34 | any | rush | front | 4 / 9 | 60 | 12 / 9 / 11 | 3 | 400/120/280/520; **1.9**×1.0; **grip 3** | comes down the pylon when you are on its span; takes hold | 2 |
| `cold.clerk` *a clerk* | **Burning**; Ash/Clinker/Stone/Gravel/Dirt/Track | any | dart | **none** (never built to be near anything) | 7.5 / 14 | 6 | 15 / 8 / **none** | 2 | — | **files** (manipulate): ready 5, reads you (hits 15 min), flees; when clear (safe 18) or culled, `filed+1`. Tether 20 from spawn ring 11–18: walk away and it gives up. Forget 10: fog, dark, walls lose it | – |

\* drops on darts are unreachable (no fight). Sheets for all 12 exist in the old art.
Machines are **seen often, met rarely** (measured ≈19 seen, 3 met per 34-day
journey). Spawn weights: watcher 3, longlegs 4, lineman 3, clerk 3, runner 4, others 5.

**Named but unbuilt (Handover §3):** the *borer* (Cut), *the sorter* (Yard; exists only
as a talking actor with the runner sheet), *the keeper* (Level), *the stack* (Line),
*readers* (Cold Rooms; *the reader* exists only as a talking actor with the watcher
sheet). Burning is owed its second machine (the reader as a walker, with the hour
window).

### 8.2 Animals, people, land

| id | Where / when | Body | Cost |
|---|---|---|---|
| `dog.yard` | ≤40 from a green, 5 countries | rush 3/7.5, life 4, nerve 34, sees 8 hears 14; bite 280/90/200/380, 0.85×0.9, dmg 2 | 25 min, hurt |
| `dog.feral` | ≥55, day ≥6 | rush 3.4/7.5, life 6, nerve 18; bite 255/90/180/320, dmg 3 | 40, hurt |
| `bull.field` | Grass/Heath/Furrow, ≥10, Coast/Pinewood/Bonelands | charge 3.5/10, turns 3, life 6; bite 520/130/320/600, 1.25×1.6, dmg 4, knock 9 | 45 |
| `gulls.food` | Sand/Strand/Gravel/Jetty | dart 7/10, life 1 | 1 food |
| `man.road` | ≥30, **laden** | menu | 3 goods |
| `press.gang` | ≤45, day ≥4, once | menu | 4 days |
| `keeper.slate` *a man with a book* | ≤90, day ≥8, 07–18 | menu | 45 min, 260 coin, 6 goods |
| `land.tide` | Sand/Shallow, tide ≥0.45 rising | 15% per crossing | 90 min |
| `land.bog` | Marsh/Blackwater | 12% | 50 min, 4 goods |
| `land.edge` | Fog, gradient ≥0.006 | 35% | 40 min, hurt |
| `land.dark` | Pinewood Needles in Rain/Grey | 22% | 60 min |
| `land.grike` | Bonelands Limestone | 24% | 50 min, 2 goods, hurt |
| `land.crust` | Burning Clinker | 28% | 40 min, 1 good, hurt |

Non-hostile life (`creatures.json`): gulls, rats, sheep, fish; reactive only (lift
when approached), never scheduled, never speak.

---

## 9. Items, tools, mining, crafting

### 9.1 The tool rule

**One hand, one thing.** The held tool is both the work verb and the weapon. Tools
never break: `edge = 10000 − spent×10000/bite` (bite = uses per full edge; 0 = never
dulls); damage and work speed blend toward bare hands as edge falls. Wear: 1 per work
action, 1 per swing thrown, 1 per climb step, a shift's worth when carried. Notice once
at edge ≤3500: *"It is not biting the way it did."* **Hardness ladder**
`wood < iron < steel < crucible`: a seam needs the right verb and ≥ its stuff, else
refused at no time cost (*"Not with your hands."* / *"It rings, and nothing comes
away."*). Work minutes = `bare × blend(speed, 10000, edge)/10000` when the verb matches.
Hone: +2500 edge up to 6000, 20 min, needs a `hone`, not for found tools. Re-edge at a
fire (smith): price `base × 0.22 × fraction gone`, 45 min, to full. A made or bought
spare comes out new.

### 9.2 Made ladder (bulk, base coin, bite = uses/edge)

| id | name | verb / stuff | speed | bite | swing ms | reach×width | dmg | knock | bulk | base | source |
|---|---|---|---|---|---|---|---|---|---|---|---|
| — | fists | — | 10000 | – | 70/80/110/180 | 0.6×0.8 | 1 | 2.5/120 | – | – | start |
| knife | a gutting knife | cut / iron | 8200 | 90 | 60/100/120/140 | 0.9×1.0 | 2 | 4/150 | 1 | 55 | start (half worn) |
| stave | a stave | – / wood | 10000 | 0 | 90/110/130/150 | 1.6×1.3 | 2 | 8/240 | 2 | 15 | buy |
| boathook | a boathook | – / iron | 10000 | 0 | 160/120/200/240 | 2.1×0.8 | 2 | 9.5/260 | 3 | 130 | buy |
| billhook | a billhook | cut / iron | 6200 | 120 | 100/110/150/170 | 1.05×1.5 | 3 | 5/170 | 2 | 240 | buy, **make** |
| axe_hand | a hand axe | fell / iron | 6500 | 120 | 130/120/170/200 | 1.15×1.6 | 4 | 6.5/200 | 2 | 340 | buy, **make** |
| mattock | a mattock | dig / iron | 6500 | 140 | 180/130/220/260 | 1.25×1.3 | 3 | 7.5/230 | 4 | 420 | buy, **make** |
| pick | a pick | break / iron | 6000 | 140 | 180/130/220/260 | 1.25×1.2 | 4 | 7/220 | 4 | 260 | buy, **make** |
| knife_shear | a shear-steel knife | cut / steel | 7000 | 260 | 55/95/105/125 | 0.95×1.0 | 3 | 4/150 | 1 | 320 | kiln |
| axe_felling | a felling axe | fell / steel | 5200 | 260 | 230/150/260/300 | 1.5×1.9 | 5 | 8.5/250 | 4 | 900 | kiln |
| mattock_steel | a steel mattock | dig / steel | 5200 | 260 | 190/130/230/270 | 1.25×1.3 | 4 | 8/240 | 4 | 980 | kiln |
| axe_works | an axe out of the Works | fell / crucible | 4200 | 520 | 170/140/200/230 | 1.4×1.8 | 6 | 8/240 | 3 | 1750 | **rare; never craftable** |

### 9.3 Found ladder (stuff `found`, spend `wick` drams per swing, unmendable, no recipe)

| id | name | wick | dmg | swing ms | reach×width | knock | base |
|---|---|---|---|---|---|---|---|
| las_hand | a glim | 1 | 7 | 70/90/110/130 | 1.3×1.1 | 5/180 | 1400 |
| las_long | a long glim | 2 | 9 | 160/110/190/230 | 2.0×1.2 | 6.5/220 | 2600 |
| las_broad | a broad glim | 2 | 7 | 140/120/170/210 | 1.2×2.6 | 6/200 | 2200 |
| arc_cut | a spitter | 1 | 10 | 60/80/100/120 | 0.7×0.8 | 3/140 | 1600 |
| mono_blade | a whisper | 1 | 11 | 45/80/90/110 | 0.9×0.9 | 2/120 | 3100 |
| stun_hand | a douser | 1 | 2 | 80/100/120/150 | 1.1×1.0 | **16/300** | 1200 |
| pulse_hammer | a knocker | 2 | 5 | 190/130/210/250 | 1.15×1.6 | **20/340** | 1900 |
| rep_light | a chatter | 1 | 3 | 40/70/70/90 | 1.05×0.9 | 2.5/120 | 2000 |
| beam_lance | a needle | 1 | 8 | 120/90/150/180 | 2.4×0.7 | 3.5/160 | 2400 |
| flash_burst | a bright one | 1 | 1 | 50/90/100/130 | 1.4×2.2 | 8/240 | 900 |
| sonic_wave | a hum | 2 | 6 | 110/120/140/170 | 1.3×2.2 | 9/260 | 1700 |
| plasma_torch | a blue one | 3 | 12 | 150/110/180/220 | 1.1×1.3 | 7/220 | 4200 |
| wick | *a dram* | — | — | — | — | — | 150 |

Each also has `glare` (light radius while firing; unwired) and a `bite` edge value.
Design intent (Handover §6.1): a glim ignores the plate (`cuts`); **no content sets
`cuts`, so today nothing bypasses plate.** Drams come from the Works (trade) and
glints (1 tile in ~22,000; 70 min dig; never regrows).

### 9.4 Materials and goods (base coin; bulk default 1)

| id | name | bulk | base | feeds | notes |
|---|---|---|---|---|---|
| driftwood | driftwood | 3 | 8 | | fuel |
| wrack | wrack | 2 | 4 | | kelp ash |
| mussels / whelks / samphire | | 1 | 14 / 22 / 18 | 4 / 3 / 2 | shore food |
| wool | raw wool | 1 | 26 | | yarn |
| reeds | reeds | 2 | 6 | | basket |
| gorse_cut | cut gorse | 2 | 5 | | lime fuel |
| timber | timber | 6 | 22 | | charcoal, hafts |
| resin / pitch | | 1 / 2 | 30 / 340 | | |
| peat | peat | 3 | 7 | | fuel |
| crottle / dye | | 1 / 1 | 26 / 450 | | |
| brimstone | brimstone | 4 | 320 | | (no recipe uses it yet) |
| limestone / lime | | 5 / 1 | 4 / 230 | | |
| salt | salt | 1 | 22 | | |
| kelp_ash | kelp ash | 1 | 620 | | |
| stone | stone | 5 | 6 | | |
| coal / charcoal | | 3 / 2 | 30 / 30 | | smelting fuel |
| tin_ore / tin | | 4 / 1 | 34 / 240 | | |
| iron_ore / iron | | 4 / 1 | 90 / 530 | | |
| scrap | *a piece of plate* | 2 | 132 | | off beaten machines, tips, wrecks |
| bread / soup / stew / smoked | | 1 | 40 / 55 / 70 / 95 | 10 / 8 / 14 / 12 | smoked keeps a month |
| pot / yarn / blanket / basket | | 3 / 1 / 3 / 2 | 700 / 120 / 740 / 90 | | |
| lamp / oil | | 2 / 1 | 420 / 95 | | oil = 6 h of light |
| oilcloth | an oilcloth | 2 | 180 | | sleep dry outdoors |
| hone | a hone | 1 | 45 | | |
| bed | a bed for the night | 0 | 95 | | script purchase |
| photograph, letter | *a photograph*, *the refusal* | 0 | – | | starting papers |

### 9.5 Taking from the ground (verb, item, world minutes, tide, regrow hours, count, hardness)

| Cover | Verb | Item | Min | Tide | Regrow h | × | Needs |
|---|---|---|---|---|---|---|---|
| Rock / Boulder | break | stone | 14 / 20 | | never | 1 | |
| OreCoal / OreTin | dig | coal / tin_ore | 22 | | never | 1 | iron |
| OreIron | dig | iron_ore | 30 | | never | 1 | steel |
| Tree / Pine | fell | timber | 18 | | never | 2 | |
| Deadwood | fell | timber | 11 | | never | 1 | |
| Gorse | cut | gorse_cut | 9 | | 72 | 1 | |
| Reeds | cut | reeds | 7 | | 24 | 2 | |
| Peat | cut | peat | 10 | | never | 3 | |
| Musselrock | gather | mussels | 6 | low | 12 | 1 | |
| Whelks | gather | whelks | 11 | low | 20 | 1 | |
| Samphire | gather | samphire | 5 | | 18 | 1 | |
| Wrack | gather | wrack | 4 | | 6 | 2 | |
| Driftwood | gather | driftwood | 3 | | 12 | 1 | |
| Resin | tap | resin | 8 | | 96 | 1 | |
| Crottle | scrape | crottle | 12 | | 240 | 1 | |
| Saltpan | scrape | salt | 9 | low | 24 | 2 | |
| Brimstone | dig | brimstone | 16 | | never | 1 | |
| Clints | break | limestone | 13 | | never | 2 | |
| Tip | turn | scrap | 90 | | 48 | 1 | |
| Wreck | break | scrap | 120 | | never | 2 | |
| Glint | dig | wick (dram) | 70 | | never | 1 | |

Mined rock leaves Gravel floor (tunnelling is mining). A tip is deliberately ~22× worse
than taking plate off a machine. "Never" regrowth = a permanent edit in the save.
Verbs `dig/cut/fell/break` need a matching tool; `gather/scrape/tap/turn` do not.

### 9.6 Recipes (`recipes.json`, 28) — station, world minutes, inputs → output

| id | at | min | needs | makes |
|---|---|---|---|---|
| charcoal | fire | 180 | driftwood 4 | charcoal ×2 |
| charcoal_wood | fire | 180 | timber 2 | charcoal ×2 |
| tin | fire | 240 | tin_ore 3, charcoal 2 | tin |
| iron | fire | 300 | iron_ore 3, charcoal 3 | iron |
| iron_scrap | fire | 240 | scrap 3, charcoal 2 | iron |
| pitch | fire | 200 | resin 4 | pitch |
| dye | fire | 260 | crottle 5 | dye |
| stew | fire | 60 | mussels 4, samphire 2 | stew ×2 |
| smoked | fire | 200 | whelks 5, driftwood 3 | smoked ×2 |
| pick_made | fire | 240 | scrap 1, timber 1, charcoal 1 | pick |
| mattock_made | fire | 300 | scrap 2, timber 1, charcoal 1 | mattock |
| axe_made | fire | 270 | scrap 1, timber 1, charcoal 2 | axe_hand |
| billhook_made | fire | 210 | scrap 1, timber 1, charcoal 1 | billhook |
| pot | bench | 300 | tin 2 | pot |
| basket | bench | 120 | reeds 6 | basket |
| kit_plate | bench | 240 | scrap 3, iron 1 | wear **plate** (+3 health) |
| kit_brace | bench | 180 | scrap 2, timber 1, iron 1 | wear **brace** (+700 wind) |
| kit_rig | bench | 150 | scrap 1, yarn 3, oilcloth 1 | wear **rig** (+20 creel) |
| kit_lens | bench | 200 | scrap 1, tin 1, resin 1 | wear **lens** (+3 sight) |
| kit_aerial | bench | 160 | scrap 2, tin 2 | wear **aerial** (+4 tiles hearing machines) |
| yarn | wheel | 150 | wool 3 | yarn |
| blanket | loom | 420 | yarn 4 | blanket |
| lime | kiln | 240 | limestone 3, coal 2 | lime ×2 |
| lime_gorse | kiln | 240 | limestone 3, gorse_cut 5 | lime ×2 |
| kelp_ash | kiln | 300 | wrack 8 | kelp_ash |
| knife_cemented | kiln | 900 | knife 1, charcoal 4 | knife_shear |
| axe_cemented | kiln | 1800 | axe_hand 1, charcoal 8 | axe_felling |
| mattock_cemented | kiln | 1800 | mattock 1, charcoal 8 | mattock_steel |

Stations `fire/bench/wheel/loom` are inside interiors; `kiln` is an outdoor cover
(dunes, limestone pavement); no anvil. Wearing is one piece at a time, a drawn layer,
no damage reduction. Loop: *mine what you can reach → craft a better tool → reach
further*; **tools are made out of machines**; steel cementation eats the tool for
15–30 h; the top rung stays found. Every recipe must be worth more than its inputs.

### 9.7 Trade and money (flagged)

Markets on greens (T or E). Buy = going × (want + 30%); sell = base × want; going =
`base × (1 + drift×(day−1) + 0.055×parishes from home)`; per-day stall stock.
`economy.json` carries three currencies: coin (drift 2.1%/day), chit (7%/day), green
(fixed supply 21000, no drift). **That drifting-money/fixed-supply scheme (and keepers
"remembering" old prices) is residue of the subject ruling 2 deleted — do not port it
without an owner decision.** Machines cannot be traded with at all.

---

## 10. People, villages, talking, records

- **Villagers** stand on the green (2–4), facing in; no schedules. Name from 28
  (`folk.json`), trade from 12 (fisher, netmaker, carter, smith, carpenter, shepherd,
  collier, baker, cooper, weaver, wheelwright, reeve), sheet from 13. **About 1 in 3
  talks** (`hash&0xFF < 85`), with a script picked from a weighted list: `folk/road`
  ×3 (the only thing in the world that says Head Office exists), `folk/photograph` ×3,
  `folk/asking` ×3 (the only cause given for being filed; branches on `filed ≥1 / ≥3`),
  `less` ×2, `chits`, `found`, `tally`, `boat`, `leaving` ×1. Others give a one-line
  notice: *"{Name}, {trade}. {line}"*.
- **The seven named people** (`scripts/seven/*`: linnet, adah, ansel, marek, dane,
  halvard, thale) may never appear as street faces.
- **Keepers** at landmarks: arc keepers run `arc/<id>`; other keepers "remember".
- **Interaction.** Only by pressing the action key at something (ruling 5). Reach
  order outdoors: person → keeper → door/adit → kiln → workable cover → market green →
  stone ring → rest. Indoors: station → actor → node → look → exit. Doors are entered
  by walking into them. Looking at a thing (`look/*`) is how places speak.
- **Machines talk** when you press the key at one that has a script (the sorter, the
  reader): same dialogue box and choices. The voice issues instructions, claims
  authority, and is wrong in a way checkable against something in the world (the
  photograph, the docket). A machine still cannot be bought off.
- **Script language (`.usp`, worth porting as-is)**: `:: node`, `-> jump`, `actor:
  speech`, narration, `* choice` / `* [cond] choice`, `if/else/endif`; effects `set/
  clear`, `add var n`, `give/take`, `earn/pay`, `wait n` (world min), `buy`, `note`,
  `trade`, `sleep/camp`, `play cue`, `act who verb` (turn, walk, nod, shake, pause, hand,
  take…), `end <arc> stopped|served`, `stop`. Conditions `has/lacks/not/and/or`,
  comparisons, built-ins (`day, hour, low.water, raining, hungry, wet, filed`…).
  Typewriter text; Enter completes then advances; Esc cannot skip; not saved mid-way.
- **Records (manipulate).** `filed` 0..4, never decays, never cleared (clearing it is
  the unbuilt purpose of the Cold Rooms arc). Machine-family sight ×(100 + 25×filed)%,
  i.e. up to double. Only sight; not hearing, not reach. Nothing on screen says so;
  villagers (`folk/asking`) notice a description going round. Escape a clerk by
  distance (tether) or by breaking sight (fog, dark, walls); once it has read you,
  nothing stops the filing.
- **Notebook** (Tab): manual, partial, chosen — only what scripts `note` and keepers
  remember; no automatic quest log or evidence ledger (26-MECHANICS §2).

---

## 11. The seven arcs and Head Office

**Structure.** One arc per country, sited by §3.9, all seven reachable in every seed.
Each has a **keeper** (a person at a landmark) and a middle made of the machine's verb.
Quests are flags set in conversation; later movements are gated on earlier ones and on
having *been* somewhere or through something (August, a windy day, the grip), then a
final `choose` node offers **(stop it)** / **(serve it)** / **(not yet)**. Both endings
set `arc.<id>.done` (the "card") and `arc.<id>.how` (1 stopped, 2 served). No card
item exists; the gate counts flags. Neither ending is ever called right; each keeper
says the cost of both, flatly.

| Arc | Site | Country | Machinery still… | Verb | Quests (required → optional) | Stopped | Served |
|---|---|---|---|---|---|---|---|
| **The Cut** `cut` | cairn | Bonelands | following a seam | works them (enslave) | way → fetched ("It does not kill what it finds up here. It walks it down.") → deaf; opt. tally | "The seam is quiet. Nothing has come up out of it since, and nothing goes down." | (give it the shifts) "It cuts where they ask now. It still fetches, and they choose whose turn it is." |
| **The Rows** `rows` | cairn | Coast | sowing and cutting on a calendar | works them | headland → hands ("In August it does not want the field. It comes in for what it needs.") → wind ("There was a day it did not go up."); opt. scarecrow, store | "The rows went over. It took two seasons and then it was just a field." | (let it feed the village) "They eat off it. They also work to its calendar, and its calendar is eleven years old." |
| **The Yard** `yard` | **wreck** | Coast | delivering to addresses that are ash | talks to them | round → address (set by **the sorter**, a hatch: "Held for the address. The address was never occupied.") → hall; opt. parcel with your family name | "The hall is still full. Nobody has opened it." | (give it the doors still standing) "They give it the addresses. It delivers to them, on the hour, exactly." |
| **The Level** `level` | cairn | Moss | pumping a fen dry for fields that are gone | holds them (ensnare) | lamps → held ("In the water it does not have to be quick. It only has to have hold of you.") → sluice; opt. peat | "The water came back up over it in a fortnight. There is a roof showing." | (set it to the ground people are on) "It keeps the water off where they live now. The rest of the level is going under, and that is the arrangement." |
| **The Round** `round` | cairn | Pinewood | keeping a curfew | holds them | hour → kept ("It takes hours. It has never once wanted anything in the basket.") → roll; opt. sweeper | "Nobody keeps the hour now. It took a while before anyone believed it." | (give it a list of our own) "The curfew is theirs. They set it, and it is kept exactly." |
| **The Line** `line` | cairn | Snowfield | holding up a grid that feeds nothing | kills them | span → climb ("Once you are up, you are what is on the span.") → stack; opt. shelter | "The line is down across the pass. It is a long way round now." | (put the huts on it) "It feeds the huts under it now. The span is still live and they still do not go up." |
| **The Cold Rooms** `cold` | cairn | Burning | keeping the records cold | talks to them (manipulate) | doors → reading (set by **the reader**, a slot: "Parish of the rift. Not in order." It offers to close your entry) → signature ("The last one is dated and a person wrote it."); opt. own drawer | "It is warm in there now. Nothing in it is readable." | (give it the parish as it stands) "They can ask it things. It answers, and it is right, and that is the trouble." |

**Head Office.** Near the origin, not hidden, reachable in the first hour. Walking
onto the doors with fewer than seven `done` flags runs `head/doors`: *"The doors are
shut and there is no handle on this side of them."* A panel reads what you carry and
says *"It counts one."* / *"It counts another."* per finished arc, then *"Then it stops
counting, which is the answer."* **No number is ever printed.** With seven: a long
room that narrows, nobody behind the counter, an open drawer; it reads the seven back
in filing order (*"The seam under the pavement: stopped."* / *"…reassigned."*),
*"It does not say whether any of that was the right way round."*, then *"Your own
docket is in the drawer, with the correction already made. It has been made for some
time."* → `ending.done` → credits; the save is marked finished.

**Arc gaps:** quest flags come from dialogue answers, not world checks; middles mostly
*describe* the verb; borer/keeper/stack unbuilt; an ending changes only keeper lines;
`cold` cannot yet clear records.

---

## 12. Controls and UI

| Key | World | Fight |
|---|---|---|
| WASD / arrows | step (held repeats at StepSeconds) | move (continuous) |
| Shift | run (held) | **dodge** (press) — one key, "get out of the way, or cover ground" |
| E / Enter / Space | act on what is in reach (verb line shows `e   speak` etc.) | **swing**; while held: **pull** against the grip |
| F | lamp | — |
| I / Tab / M / T | bag / notebook / map (outdoors) / trade (on a green) | refused once: *"Not while this is on you."* |
| Esc | pause (go on, save, what the keys do, settings, leave the coast) | refused |
| 1–9 | dialogue choice | — |
| `` ` `` ×3 in 1.5 s | arm dev mode; `` ` `` toggles the panel | works in fights |

**Principles.**
- **No menus, prompts, cursor or text during a fight** (ruling 1). The only
  combat feedback is in the world: the working part's warm glow, the flat ring on steel,
  the body breathing hard when blown or hurt, the small health gauge.
- **No meters for survival**; one HUD state word at most (*the lamp is low, you have to
  eat, hungry, wet through, tired, peckish*), clock `day N  HH:MM`, place name, verb line
  at the bottom (`e   <verb>`, `walk in`, `t   trade`).
- **Nothing speaks unasked** (ruling 5). Short flashes for world events (≈2.6 s).
- **Menu standard** (`docs/33-MENUS.md` §4): one input module; up/down choose (wrap;
  repeat after 0.35 s, then 0.06 s), left/right change a value, Enter/Space/E confirm,
  Esc backs out one level, a screen's own key closes it, digits are dialogue's.
  Lower-case title + rule, list, ≤3 lines of detail, footer of fixed words ending
  `esc`. Cursor is `"> "` only. Unavailable rows faded `#6c6555` but selectable;
  confirming one plays `refused` and says why in one plain sentence. Sounds
  `open_book/close_book/menu_move/menu_select/refused`. Draw order = input priority.
- **Screens:** title, character builder, 3 save slots, dialogue, bag, notebook, map
  (explored cells), trade, workbench, pause, keys page (once on first run), settings,
  credits. Autosave every 20 s, on quit, from pause (seed + state + world edits).
- **Dev mode** (chord-armed in any build, web included): `field` (height/moisture/
  biome overlay), `survey` (world at 1 px/tile), `zoom`, `figures` (every sprite, state,
  facing), `clock`, `rate`, `hour ±`, `day ±`, `weather`, `go to` (landmarks, keepers,
  machines), `lamp`, `shut`; side panel with coords, time, weather, ground.

---

## 13. Built vs only designed (checked by call site)

| System | Status |
|---|---|
| Generated world, countries, rivers, cliffs, caves, ores, adits, villages, roads, quays, landmarks, interiors, Head Office, Works | **Built and wired** (JS port of terrain/villages exists) |
| Real-time clock, day/night, tide, weather spells, lightning, debris showers, murk | **Wired** |
| Seasons | Partial: after day 22 weather hardens; **day-34 road close does nothing** |
| Tile-step movement, StepSeconds body cost, run | **Wired** |
| Hunger/tired/wet/hurt/fouled, eat, sleep/rest, lamp oil, collapse | **Wired** (walking in rain does *not* wet you; `Sky.Toil` weather step cost is uncalled) |
| `Fighting.Field`: swing, plate/working part (with glow), knockback, dodge + wind, grip/wrench, second acts, 4 outcomes | **Wired** |
| Carried → deepest mine face (enslave) | **Wired**; being *set to work* (quota) is not built |
| Records / clerk (manipulate) | **Wired** but invisible; no way to clear |
| Warden arrest, flock spraying (dart `hits`) | **Wired** |
| Mining with hardness gate, gathering, regrowth, tips, glints, wrecks | **Wired** |
| Crafting (28 recipes, 5 station kinds), wearing (5 pieces), hone, re-edge | **Wired** |
| Trade/markets, three currencies with drift | **Wired** (money scheme flagged, §9.7) |
| Seven arcs: keepers, scripts, endings, Head Office gate, counter, credits | **Wired**; quests verified only by dialogue; no card item |
| Machine talk (sorter, reader) | **Wired** for 2 of 7 arcs |
| Notebook | **Wired** (manual) |
| Found weapons' `cuts` (plate bypass) | **Unreachable**: no content sets it |
| Found weapons' `glare` light, `Tools.Burn` per swing | **Unwired** (drams deducted in bulk after a fight) |
| `Mood.Hurt` / world stagger on creatures | **Dead**: fights write back only dead/fleeing/idle |
| Errand machines in a fight | Lunge at you like rushers, contrary to "does not come at you" |
| Bodiless hazard line after a plain walking step | Probably never shown (only flushed after dialogue) |
| `Game.Place` (building), structures | **Not built** ("Building" is the one unbuilt open-world item) |
| Weather acting on machines/villagers/roofs, wind bearing, tracks, workable machine-age marks, animated covers | **Designed only** (32-BIOMES §2–3) |
| Big site machines (borer, keeper, stack, walking readers), Burning's second machine | **Designed only** |
| Authored towns (Rill, Tern, Saltmarket, Ashgate, Coldwater), `NewStory`, `rill/opening` | Retired; not offered in the build |

**Doc vs code corrections found:** 5 dodges from full wind → code gives 4; bare-hands
lockout "420" → 440 (420 is the knife); dodge "a tile and a half" → ≈1.08 tiles; grip
"560/280 ms" → 420/140 ms minimum; charge "pauses after every run" → only after a wall;
32-BIOMES §3.1 "clock moves 2 minutes a step" → stale (ruling 9); land shares quoted
in `Terrain.cs` (Pinewood 25.96%…) → stale, use §3.3.

**Keep exactly in the rebuild:** the units; the four-verb mechanisms; plate side from
swinger position; dodge window numbers; grip as a quantity vs a 6 s clock; carried →
mine face; records as a sight multiplier; hardness ladder + edge blend; ground-named
spawn `where`; hash-deterministic generation; `.usp`; the voice. The old world steps
tiles and fights continuously; making world movement continuous (5 tiles/s scaled by
`StepSeconds`) breaks no ruling.
