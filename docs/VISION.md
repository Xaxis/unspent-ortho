# UNSPENT — the vision

The north star for every milestone. `DESIGN.md` says how the game works now,
`ART.md` how it looks, `ROADMAP.md` what is next. This page says what the whole
thing becomes. Where they disagree, this page describes the destination and the
others describe the road.

## 1. Premise (owner, 2026-09-15)

The few dwindling humans who persist after the machine apocalypse. The machines
still mean to eliminate every human, but **many are indifferent**, as long as
humans do not interfere with the machines' **ultimate plan**. The plan is the core
story arc. Around it grow **generative subarcs** that can be finished in many
different ways.

The story's words are written in the story milestone. Everything below makes the
premise *playable* so the words have something to stand on.

## 2. The machines and the plan

**Disposition is a system, not a label.** Every machine has a role in the plan and a
disposition toward the player:

| Role | Default | What it does | Turns hostile when |
|---|---|---|---|
| Workers (harvesters, haulers, cutters, sweepers, linemen) | indifferent | build, carry, mine, maintain the plan | you get in the way, damage the work, take its parts |
| Keepers (wardens, works guards) | wary | hold plan sites and routes | you trespass on a site or break curfew |
| Watchers and clerks | observant | see and file; raise interference | always report; never fight |
| Hunters (long-legs, runners, dredgers) | hostile | remove humans | always; more of them as interference rises |
| Recyclers | indifferent | take the dead and the broken | you are downed near them |

**Interference** is kept per plan network (a region's works and what serves it).
Sabotage, theft, killing workers and being filed raise it; time, distance, hiding
and misidentification lower it. As it rises, indifferent machines grow wary, then
hostile, and hunters are sent. The machines are **barely functioning**: records are
corrupt, signatures are misread, coverage has gaps. Those failures are the player's
tools (spoofed signatures, blind spots, confused routes).

**The plan is visible and progresses.** It is a world-spanning undertaking the
player can see from far away and learn about over the game (for example, a tether
rising to orbit, fields of servers drinking rivers, the land being re-made).
It advances in stages on the world clock and through subarcs. The story milestone
decides what it is and why; systems must support: stages, sites per region,
world changes per stage, and player influence (slow, stall, redirect, understand,
or even help).

**Generative subarcs.** A subarc generator builds goals from world state: rescue,
sabotage, recover, repair, escort, bargain, discover, witness. Each goal has several
methods (stealth, force, craft, trade, time) and consequences (interference, plan
stage, village fortunes, new routes). The same subarc plays differently on every
seed and for every player.

## 3. The world: realms and 20+ landscapes

**At least 20 landscape *types*, always procedurally generated.** A type is a
definition in the biome registry (its grounds, forms, props, life, weather, light,
hazards, enemies, sentinel). Every seed composes its own world from the types: which
appear, where, how large, how many times, and how they meet. No two worlds are the
same map; every world is recognisably made of the same landscapes. The tables below
are the types, not places.

Every world holds one or a few large **oceans separating continents**, some of the
rarer types exclusive to particular continents, with the underground beneath them
and the orbital bodies above (owner, 2026-09-18). **`docs/WORLD.md` is the shape
of a world and worldgen answers to it**; this section is what a world is made OF.

The world is several **realms**, each generated from the seed, joined by roads,
shafts, portals and crafts. Within a realm, landscapes **blend seamlessly** through
ecotones (ART.md §1 law 6). Every landscape has its own ground, hatch hand, props,
decor, weather, light, hazards, sounds and **enemies**.

### Surface (15)
| # | Landscape | Character | Hazards | Enemies (examples) |
|---|---|---|---|---|
| 1 | Coast | turf, heath, shingle, sea cliffs, villages | wet, tide | harvesters, flocks, runners |
| 2 | Moss | fen, black water, peat, reeds | bog, wet, leeches | dredgers, keepers of the pumps |
| 3 | Pinewood | tiered pines, clearings, needles | dark, curfew | wardens, sweepers |
| 4 | Snowfield | snow, ice, pylons strung with wire | cold, whiteout | linemen, long-legs |
| 5 | Bonelands | limestone pavement, grikes, standing stones | exposure, grikes | cutters, haulers |
| 6 | Burning | ash, clinker, vents, basalt | heat, fumes | clerks, vent crawlers |
| 7 | Salt Flats | white crust, mirages, evaporation pans | heat, glare, thirst | pan rakers, mirage decoys |
| 8 | Glass Desert | sand fused to glass, craters | heat, radiation, shards | glass skaters, strike beacons |
| 9 | Scrapwood | forests grown through dead machines | magnetism, collapse | recyclers, magnet swarms |
| 10 | Drowned City | towers in the tide, streets as canals | drowning, tide | divers, ferry keepers |
| 11 | Server Fields | endless humming cooling arrays drinking rivers | heat, EM noise | coolant crawlers, auditors |
| 12 | Grey Orchards | automated farms gone wrong, spore mist | toxins, spores | sprayers, pickers |
| 13 | Mesas | red canyons, wind, cliffs | wind, falls | cliff anchors, kites |
| 14 | Frost Sea | frozen sea, pressure ridges, ice caves | cold, cracking ice | ice cutters, sounders |
| 15 | Ruined Metropolis | a dead megacity: collapsed towers, broken highways stacked in tiers, plazas of shattered glass, districts the machines still run (lit, clean, patrolled) beside districts left to rot; the Undercroft lies beneath it | falls, collapse, dust, dark | demolition rigs, traffic wardens that still direct nothing, tower sentries |

### Underground (6)
| # | Landscape | Character | Hazards | Enemies |
|---|---|---|---|---|
| 16 | Limestone Caves | karst halls, underground rivers, glow-worms | dark, floods | blind crawlers |
| 17 | Crystal Hollows | geode caverns, resonant stone | resonance, falls | resonators |
| 18 | The Adits | the machines' mines, carried-off people at the faces | collapse, dust | drill rigs, overseers |
| 19 | Magma Vaults | beneath the Burning, rivers of light | heat, fumes | slag golems, vent keepers |
| 20 | Rootways | fungal forest in the deep, bioluminescence | spores, dark | spore-walkers |
| 21 | Undercroft | the buried city beneath the Ruined Metropolis: metro, archives, sewers | dark, toxins | archivists, sealed guards |

### Orbital (3)
| # | Landscape | Character | Hazards | Enemies |
|---|---|---|---|---|
| 22 | Tether Station | the anchor and climber platforms of the plan | vacuum at edges, falls | tether keepers |
| 23 | The Foundry | the plan's construction in orbit, zero-g yards | vacuum, radiation, zero-g | assemblers, welders |
| 24 | The Ring | a dead satellite ring, drifting debris | vacuum, debris, cold | salvage drones |

### Eras (through time portals)
| # | Era | What it is |
|---|---|---|
| A | The Before | the same land before the machines were handed the world |
| B | The After | the plan finished: what the world becomes if nobody interferes |

### Sentinels: every landscape has its keeper

Each landscape is held by a **mecha sentinel**: its core boss, unique, powerful,
and powerful *differently* (owner, 2026-09-15). **To fully own and control a
landscape's resources, its sentinel must be defeated.** Until then the land's best
seams, groves, springs and salvage stay guarded, patrols answer to it, and its works
cannot be taken for good.

Sentinel rules:
- **One sentinel design per landscape type, never reskinned between types.** Every
  generated region of that type has its own sentinel instance, varied by seed (arena
  shape from the terrain it stands in, which weak points are exposed, patrol reach,
  what it guards), so the second Salt Flats sentinel is the same species and a
  different fight.
- **Distinct bodies.** Each type's sentinel has its own body plan, arena, phases,
  weak points and behaviour drawn from what that landscape's machines do for the plan
  (the Coast's sentinel reaps; the Frost Sea's listens through the ice; the Foundry's
  assembles itself back together).
- **Tactics, not stats.** Each can be beaten several ways and none by trading hits:
  terrain (lure it onto cracking ice, drop it into a sinkhole, flood its channel), the
  plan's own logic (make it indifferent, starve its works, spoof its orders), crafts
  (outpace it on a sled, strike from a glider), gear and abilities (a resistance that
  lets you stand where it cannot follow, a scanner that reveals the moving weak point),
  time (fight it in the Before, before it was finished), preparation (traps on its
  route, allies from a village). The more a player understands the landscape, the more
  ways they see.
- **Readable and fair.** Telegraphs drawn in the machine's own language (working parts
  flare, plates open, optics track), phases announced by the body, never by text.
- **Consequences.** Defeat changes the land visibly and permanently: its works go dark,
  patrols thin, guarded resources open, the plan's stage in that region stalls,
  villages come out, and the player can claim what the sentinel held. Interference
  across the plan jumps: the next landscapes answer.
- **Look.** Sentinels are the grandest FOUND drawings in the game: exact, enormous,
  wrong, and unforgettable in silhouette at 640x360.

## 4. Portals and time

- **Portals** link realms and distant places: old machine gates that need power, keys
  or repair; late in the game the player can mend one. A portal is a place, drawn and
  sounded, never a menu.
- **Time portals** open the same coordinates in another era. What the player does in
  the Before changes the present: a tree planted, a door left open, a machine never
  built, a river diverted. The After shows consequences and teaches the plan. Time
  is a mechanic for puzzles, shortcuts, rescues and subarcs, never a cutscene.
- Rules the systems must hold: eras share seed and coordinates; edits in an era are
  saved per era; a declared set of edit kinds propagates forward; paradox-safe (the
  present recomputes from its inputs, never loops).

## 5. Crafts (vehicles)

High-tech crafts built or found; each opens terrain and raises mining or fighting:

| Craft | Tier | Opens | Also |
|---|---|---|---|
| Raft, boat | made | rivers, coast, drowned streets | carry |
| Glider wings | mended | descend mesas and cliffs, cross canyons | escape |
| Hover sled | mended | bog, salt, ice, black water | speed, haul |
| Walker rig | mended | heavy loads, deep snow, scree | mining and fighting boost |
| Drill crawler | found | tunnels to the underground, hard rock | mining tier |
| Submersible | found | drowned city depths, frost sea | pressure |
| Climber | found | the tether to orbit | the orbital realm |

## 6. Tools, gear and abilities

Three idioms of making, which are also the tiers:

- **Made**: hand tools and kit a person can make and mend (M1).
- **Mended**: human-built from machine parts: FOUND pieces bound with MADE cord,
  hatching and patches. Most of the high tech the player uses. (ART.md adds this idiom.)
- **Found**: machine technology taken whole: strongest, costs charges, cannot be mended.

**Gear is modular**: slots (head, body, hands, back, tool, craft) take modules. Modules
grant **resistances** (cold, heat, fumes, toxins, radiation, vacuum, pressure, EM,
resonance, time-shear) and **abilities** (dash, grapple, glide, scan for working parts
and interference, signature spoofing, shielding, magnet boots, jump jets, drill and
cutter tiers). Players **configure** loadouts for where they are going; the world
asks, the gear answers, the combinations make builds.

### 6.1 Every weapon, armour and power is obtainable (owner, 2026-09-15)

Advanced weaponry, armour and powers are all obtainable, but **varied by region**, and
each comes **either by rarity (dropped) or by difficulty (crafted)**. Nothing is a
reward for playing long; everything is a reward for going somewhere or beating something.

**Rarity** — five grades, which decide how many modifiers a piece carries and how
strange they are, never a flat damage ladder:

| Grade | Where it comes from | Modifiers |
|---|---|---|
| Common | anywhere, salvage and simple making | 0 |
| Uncommon | regional scrap, ordinary machines | 1 |
| Rare | landscape-specific caches, works, landmarks, veteran machines | 2 |
| Prime | named enemies, deep realms, orbital foundries, hard recipes | 3, one regional |
| Relic | sentinels, the Before, the plan's own stock | 3 + one unique |

**Elite materials are the gate**, and each is found in **one or two landscapes only**,
or drops from **one kind of enemy or one sentinel** (fulgurite cores from the glass
desert's strike fields, deep-ice lenses from the frost sea, slag steel from the magma
vault, mycelium weave from the undercroft, foundry alloy from the orbital works,
sentinel cores one per sentinel, era-glass from a time portal). A player who wants the
best of a kind must travel, dive, climb or fight for it. This is the spine of the
long game and the reason to take every landscape from its keeper.

**Craft difficulty** matches the ladder: recipes name a station tier (hand, forge,
bench, machine shop, foundry taken from the machines), a number of steps, and a failure
mode on the hardest ones (a ruined material, a piece that comes out flawed but usable).

**Modifiers are the elegance.** "Ultra high-tech refuse of all types": the parts are
salvaged, mismatched, half-understood, and they change how you play rather than how big
the numbers are. A modifier reads as a part with a name and a look — cooling loop,
capacitor bank, gyro brace, phase coil, harmonic edge, leech coil, magnet clamp, signal
spoofer, shock lattice, drone tether, ablative plate, era shim. Rules that keep the
system elegant instead of merely large:

- Every modifier changes a **decision**, not just a number: new reach, a new opening, a
  resource to spend, a risk to take, a hazard survived.
- Modifiers **combine and conflict**: a cooling loop pays for a shock lattice's heat; a
  capacitor bank and a leech coil make a charge build; a spoofer and a lattice fight
  each other, because one hides you and the other shouts.
- They carry the **idiom** with them (MADE binding, MENDED patchwork, FOUND exactness),
  so a build is visible on the body.
- Gear can be **broken down** for its materials and its modifiers **re-socketed** at a
  bench, at the risk of losing the part. Nothing is dead loot.
- Modifiers are **regional**: a landscape's materials bias the modifiers found and
  crafted there, so builds carry the map's memory.

## 7. Architecture this demands (build early, before content)

1. **Realms**: a world is a set of realms (surface, underground levels, orbital
   platforms, eras) generated from the seed, each with its own WorldData, view and
   saved edits; the game holds an active realm and moves between them.
2. **Biome registry**: landscapes are data (`src/content/biomes/*.gd`, auto-discovered):
   ground palettes and grades, hatch hand, wall material, props and decor tables,
   weather, light, hazards, enemy roster, sound bed, music motif, realm kinds, climate
   envelope. The six M1 countries become the first six entries. Worldgen picks and
   blends from the registry.
3. **Hazards and resistances**: one model for every pressure; biomes declare hazards,
   gear declares resistances.
4. **Abilities and modules**: gear modules grant abilities through one interface the
   player controller, fight and movement all read.
5. **Crafts**: mountable actors with their own movement rules and terrain access;
   WorldQuery asks the craft, not just the ground.
6. **Portals**: links between (realm, place) pairs with activation rules and a
   transition; time portals as realm pairs sharing coordinates.
7. **Sentinels**: a boss framework per landscape (arena, phases, weak points,
   multi-solution defeat conditions, resource ownership and world consequences),
   so each sentinel is content on a shared spine.
8. **Disposition and interference**: per-machine role and disposition, per-network
   interference, and every sense and brain reads them.
9. **Plan and subarcs**: plan stages as world state; a subarc generator over world
   state with goals, methods and consequences; all saved.

## 8. Look across realms (extends ART.md)

**Beautifully dystopian** (owner, 2026-09-15). The whole game is a futuristic,
sci-fi, crumbling world, cyberpunk landscapes of **ordered chaos and mystery**. The
dystopia is in the mood, the art, the themes, and **every element of every
landscape**, not in a filter.

- **The land tells what happened.** Every landscape is dense with its own
  dystopian evidence: collapsed and half-reclaimed structures, dead and still-running
  infrastructure, machine scars (cut lines, drill fields, quarries, drained basins),
  wrecks and debris, fences, barricades and warning signs, abandoned vehicles,
  graves and memorials, poisoned water and scorched ground, and the patched, wired,
  scavenged places where people still live.
- **Ordered chaos.** The machines' exact grids (rails, relay lines, arrays, fields
  sown in perfect rows, lit districts) run straight through chaotic ruin, overgrowth
  and hand-built shelter. The FOUND is ruler-straight; the MADE is crooked and patched.
- **Mood by landscape and hour.** Each landscape has its own weather and light: bleak
  grey days on the coast, drowned green gloom in the moss, hard white glare on the
  bonelands, furnace dusk in the burning. Night, storms and fog are where the mood
  deepens and where light becomes precious.
- **Neon and rain are accents that mean something:** machine districts, relay
  corridors, the metropolis, the server fields, settlements running stolen tech;
  rain-slick streets where it rains. Never everywhere.
- **Mystery.** Silhouettes on the horizon, lights that move where nothing should,
  districts that hum, landmarks glimpsed through weather.

**Sound: haunting, synthesizer-heavy, evolving ambient, and seamless across the
world** (owner, 2026-09-15: the soundtracks must blend and transition seamlessly
with the landscape the player is in: equal-power crossfades over an ecotone, keys and
tempos that match across a border, layers that arrive and leave rather than restart) (owner, 2026-09-15).
Generative synth drones, pads, pulses and slow arpeggios that evolve with the hour,
the rain, the landscape, the plan's presence and danger; each landscape has its own
key, timbre and rhythm; machine districts pulse. This supersedes the old research's
"no synth pads" rule.

**Hauntingly beautiful and detailed** (owner, 2026-09-15). Every landscape must stop
a player in their tracks: dense with considered detail at walking scale (marks, wear,
small lives, traces of before), composed at distance (silhouettes, light, weather,
a landmark on the horizon), and haunted: quiet evidence of what was lost and what
the machines are still doing. Beauty that aches is the bar, not pretty.

The notebook changes medium with where you are, so each realm is unmistakable:

- **Surface, present**: ink and wash (ART.md as it is).
- **Underground**: scratchboard. The page is dark; lines are scraped pale; the lamp
  brings back the colour wash inside its pool.
- **Orbital**: graphite and white ink on black paper; stipple stars; the Earth below
  drawn as a slow washed disc; FOUND structures in exact blueprint line.
- **The Before**: warm watercolour on cream paper, softer lines, full colour, people.
- **The After**: cyanotype: white line on Prussian blue, everything ruled.
- **Portals**: a torn page between two media.
- **Mended things**: FOUND parts with MADE bindings, both idioms visible at once.
- **The slate** (every UI screen): a tablet the player hacked together from spare
  parts: a stolen machine display in a patched bezel. The world is full of
  technology, scavenged and stolen, and the slate is its most personal piece (ART.md §9).

## 9. Settlements: building, sustaining, defending, losing (owner, 2026-09-15)

Crafting does not stop at what a person carries. **Building is crafting at world
scale**: shelters, then a holding, then a town, with **defence systems** and
**sustainability systems** — solar farms, food generation, water, heat, power. And
**certain machines and enemies can destroy the player's work**. Everything built is
something that can be taken away, which is what makes building matter.

**What gets built.** Every piece is placed in the world, made of the same three idioms,
and shows its making: MADE frames and thatch, MENDED walls of machine plate on timber,
FOUND cores that hum and draw attention.

| Kind | Pieces | Gives |
|---|---|---|
| Shelter | lean-to, hut, cellar, bunk, hearth, store | sleep, safety, stash, a place to come back to |
| Power | solar array, wind spinner, pedal dynamo, battery stack, stolen cell | charges for FOUND gear, lights, turrets, benches |
| Food & water | plots, greenhouse, mushroom cellar, fish trap, snare line, catchment, filter, still | feeding people, long trips, trade |
| Work | forge, bench, machine shop, foundry, kiln, loom, radio mast | the craft-difficulty ladder of §6.1 |
| Defence | palisade, plate wall, gate, ditch, tower, snare, mine, EMP stake, salvaged turret, decoy mast, spoofer, netting, shutters | surviving a raid |
| Living | beds, rescued people, a healer, a smith, a scout, a child | production, stories, subarcs, something to lose |

**Sustainability is a loop, not a counter**: power is generated, stored and spent;
food is grown, stored and eaten; water is caught, filtered and drunk; parts wear and
need repair. People staff the pieces and produce while the player is away. Weather and
season press on it (a still week kills the wind spinners; a hard frost kills the plot),
so the player builds redundancy and the place develops a character.

**Machines come, and they decide when.** No raid timer. A settlement is engaged
because of what it did, and the player can read every step coming:

1. **Signature.** Every settlement continuously emits what machines can sense: power
   draw, light at night, smoke, noise, radio, traffic in and out, and the FOUND tech it
   runs. Big, bright, loud, stolen: seen sooner.
2. **Notice.** A passing worker files it, a watcher logs it, a scout drone photographs
   it, a clerk in a relay hut writes it down. **This is an encounter, and it is
   playable**: intercept the scout, jam the relay, take the record, follow the drone
   home, or let it go and accept what follows.
3. **Attention.** Per settlement, attention rises from notices, from the player's
   **interference** with that network (§2), from stolen FOUND tech running inside the
   walls, and from machines that never came home. It falls with quiet weeks, dark
   nights, spoofing, decoys that pull attention elsewhere, and destroying the record
   before it travels.
4. **Escalation, each step readable and answerable**: a survey (one machine, looks and
   leaves) → a probe (takes something, tests the wall) → a **raid** (a party with a
   purpose: salvage, harvest, dismantle) → a **siege** by a sentinel's own force once
   the region's keeper knows. Each step is announced by the world first: horizon
   lights, a drone at dusk, the radio going wrong, birds up, the people uneasy.
5. **The raid itself is a fight the player prepared for**: machines take roles
   (breachers at the gate, harvesters after the power and the food, snatchers after
   people) and attack what makes the signature: the solar farm, the mast, the FOUND
   core. Traps, turrets, walls, the ditch, the shutters and where the player stands all
   matter. Evacuating and hiding is a legitimate answer; so is not being there.
6. **Aftermath**: broken pieces, burnt plots, people taken or killed, wrecks in the
   yard worth salvaging, and repair that costs materials and days. A razed settlement
   leaves ruins the player can reclaim, and the region remembers.
7. **Ending it**: killing the region's sentinel (§3) quiets its network for good — the
   surest way to make a place safe is to take the landscape from its keeper.

Architecture this adds to §7: **building placement and structure state** (per realm,
saved, damageable, repairable); **a settlement as an entity** with signature, stores,
production, people and attention; **encounter-driven escalation** (notice → attention →
raid plan) that reads disposition and interference; and **raid actors** with roles and
targets that machines' existing senses and brains drive.
