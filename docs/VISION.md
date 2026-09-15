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

**Sound: haunting, synthesizer-heavy, evolving ambient** (owner, 2026-09-15).
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
