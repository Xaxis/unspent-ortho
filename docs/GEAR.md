# GEAR.md: the gear economy as a progression across landscapes

Contract for the built gear economy (G1-G9), plus the unbuilt spec for the land materials (G10, §11).

Owner direction (2026-09-15, VISION §Gear): every weapon, armour and power is obtainable,
varied by region, dropped by rarity or crafted by difficulty. Elite materials come from one
landscape, one enemy or one keeper. A higher grade buys modifiers, never a bigger number.
The rule this document adds: **every piece comes from a place or a deed, never from nowhere.**

## 1. The pieces

- **Tiers are idioms:** made (by hand), mended (machine parts bound with cord), found
  (machine tech taken whole, cannot be mended).
- **Slots:** head, body, hands, back, tool, craft. Modules socket into slots and grant
  resists and abilities (dash, glide, scan, grapple, spoof; jump is innate).
- **FightKit** (`src/core/gear/fight_kit.gd`, whose header lists each): modules change a
  fight, not a number (harmonic, phase, damp, leech, capacitor, ablative, gyro, clamp, the
  keeper powers of §5 and the armour of §6).
- **GearTree** (`src/content/gear/gear_tree.gd`): families climb common, rare, prime
  (relic for the thin blade). Each rung keeps the family's numbers, adds sockets and wants
  one elite material.
- **EliteStock:** land materials (a raw only that land gives, refined at a station),
  machine materials (a per-kill chance off one roster kind), spoils (found weapons).
- **Economy:** craft tiers hand, fire, bench, kiln, jig (kiln and jig pours can fail into a
  flawed twin or `spoil`); `Modifiers` tags pair or conflict (`modifier_table.gd`);
  `Reforge` takes modules out with a field risk.
- **Reachability:** `Sources.path_to` proves every item is reachable and
  `GearEconomy.problems()` fails the build if one is not. `Guide.next_elite` sends the
  player to the next elite material, preferring the land underfoot.

## 3. The shape: one loop per landscape, one deed per region

| Source | What | Gate |
|---|---|---|
| **The land** | its raw, refined to its elite material at a station | walking there, a steel edge, the right station |
| **Its machines** | a machine material (per-kill chance) and found weapons (spoils) | fighting what lives there |
| **Its keeper** | its core, and with it **a power** (§5) | the region's hardest deed, in one of the keeper's ways |

Progression runs outward from home (STORY: no stop is nearer home than the last). Deep
relics wear the machines' name, and the plan hunts whoever carries them (G9):

| Band | Lands | What the player makes of it |
|---|---|---|
| **Home** | coast, moss, pinewood, scrapwood, grey_orchards | made kit and steel. Rare rungs from bog_iron (moss) and seasoned timber (pinewood hall). The coast keeper's reaper_core is the first power. |
| **Near** | bonelands, burning, snowfield, salt_flats, sulphur_jungle, the_crags | the kiln and the rest of the rare rungs (clint_spar, cinder_glass, frost_varnish, hush_slate). The foundry's lance casting. First prime parts off wardens and cutters. |
| **Far** | glass_desert, mesas, frost_sea, drowned_city, ruined_metropolis, slums, green_towers | prime rungs on the jig (fulgurite_core, span_wire, tower_cable, brine_copper, deep_ice_lens) and their keepers' powers |
| **Deep** | machine_city, server_fields, the_middens, limestone_caves | relics: pieces that wear the machines' name, each with a cost |

The band is not a level gate. It is where the raw and the keeper are; the jig and a steel
edge are what hold an early crosser back.

## 4. What rarity means in play

**Grade = sockets = decisions.** Never damage (VISION).

| Grade | Sockets | Where it drops or is made | In play |
|---|---|---|---|
| common | 0 (made wear 1: a made piece is where the first module lives) | made by hand or at a fire | a tool that works |
| uncommon | 1 | found weapons off kills, mended kit at the bench | one decision |
| rare | 2 | a land's elite material at a bench | two decisions, a pair possible |
| prime | 3 | a machine's material on the jig | a combo and a conflict to manage |
| relic | 3, unique, with a **cost** | one per keeper or deep room | changes a rule, and takes something back |

- Sockets default to `Rarity.SLOTS[grade]`; made wear keeps its one socket by an explicit
  override, and a test holds the table to it (G2).
- A drop's rarity is shown, not rolled: a dropped found weapon is its family's uncommon
  rung. A kill's rarity decides **whether** it drops, never its stats. The pickup line names
  the grade.

## 5. Powers from keepers

A keeper's core has two uses and **the player chooses**: the holding's stolen cell (four
power day and night, the loudest thing in the game), or, on the jig, the keeper's module
(relic, one slot, unique); the slate shows both side by side (`src/ui/ui_rules.gd`). Each
module is the keeper's way of fighting turned to the player's use, with a cost, because a
power with no cost is a number.

| Core | Keeper (land) | Module | Slot | What it does | Its cost | Tag |
|---|---|---|---|---|---|---|
| reaper_core | tide reaper (coast) | mod_undertow | hands | the grapple drags a machine ahead one body-length in, stopping 1.0 short; its tell broken, it stands stalled | the haul costs double wind | held |
| rake_core | pan rake (salt flats) | mod_rake | tool | a heavy, as drawn, rakes a 3-tile arc: every biter in it has its tell broken and stands stalled open; a charger rides over it | heavy blows 1.5x as loud | loud |
| plumb_core | plumb (the crags) | mod_plumb | head | a scan rings where each roused machine will tell its next blow | the scan's cooldown doubles | read |
| anvil_core | anvil (glass desert) | none | — | SET ASIDE (§12): its core is the holding's cell only | — | — |
| unbuilder_core | unbuilder (ruined metropolis) | mod_unbuild | hands | `use` held 1.5 s at an open (stalled or spent) machine's part, gathered across openings, strips it: no bite, its elite part into the creel | time: a strip is slower than a kill | read |
| lockkeeper_core | lockkeeper (drowned city) | mod_lock | back | hunted (a roused machine within 20 tiles), a narrow way passed between two solid things no more than 2.2 tiles apart is shut behind you to machines for 20 s (`FightSim.lock_walls`); gates already stop machines, so it locks the narrow ways a chase runs through | 1 charge (wick) a lock | charge |
| anchor_core | anchor (mesas) | mod_anchor | body | standing still 0.6 s roots you: no knockback, no grab; a lineman's grip fails and is a miss that leaves it open | rooted, and for 0.3 s into pulling up, no dodge | steady |
| listener_core | listener (frost sea) | mod_listen | head | a tell's ground ring is drawn through what stands between at eye level | your noise and steps carry 1.5x | sight |
| plough_core | plough (snowfield) | mod_ploughshare | hands | a dodge within 30° of square to a charging machine's line, its bite winding up or live, within 4.5 tiles, turns it: recovery and cooldown x2, and it drives on past for a run as long again. It widens the shared overrun instead of breaking it | half a dodge's breath a turn | quick |

- Every relic also carries the relic heat (G9).
- Tag pairs: anchor with gyro (steady) and undertow (held) makes a planted grappler; rake
  with damp (quiet against loud) is the conflict to manage.
- Code: `fight_kit.gd`, `fight_sim.gd`, `items.gd`, `recipes.gd`; tests in the verify skill.

## 6. Armour and pieces that change how you fight

One verb per piece. **Rule for new pieces:** each names the FightSim or ability hook it
changes. A piece that only adds resist is armour for the land, which is fine, but not for
this list.

| Piece | Slot | Grade | From | Changes (hook) |
|---|---|---|---|---|
| scale coat (`coat_scale`) | body | rare | tide_iron (harvester), bench | the first blow of each fight within 70° of straight back is turned; never spent (`FightSim._hurt_hero`) |
| hush wrap (`wrap_hush`) | body | rare | hush_slate (the crags) | the body's own acts (walk, run, dodge, drop, eat) take moss's ground term on any land; tools and water unchanged (`StealthNoise.radius`) |
| vane cloak (`cloak_vane`) | back | prime | vane_true (sweeper) | in wind above 0.4 a dodge within 50° of downwind carries twice as far (`FightSim._dodge`, `Weather.bearing`); worn where the wing goes; its vanes (PersonBody `vanes`) are fitted kit only, never a villager's |
| lens visor (scanner_lens + mod_icelens) | head | rare | deep_ice_lens | scan reach x1.5, and glare no longer cuts your sight (`ability_scan.gd`) |
| cable gauntlets (brace_cable, brace_ram) | hands | rare | tower_cable | the grapple takes a working part that faces the line, stalls it (once per STALL_EVERY_MS) and pulls the player in to 0.3 off it (`AbilityGrapple.anchor`, `FightSim.cable`); with the undertow fitted, it hauls instead |
| lattice (mod_lattice) | tool | prime | fulgurite_core | a landed blow discharges `LATTICE_DAMAGE` 2, shared nearest first among bodies within `LATTICE_REACH` 2.0, `LATTICE_CHARGES` 1, a visible arc; hot, so it wants a cool. Its identity: no gain on harvesters, strong against cutters |

## 7. Where things are found (loot per interior)

- A room is lived in exactly when its recipe seats a household or squatters
  (`const SEATS`, `InteriorKind.seats`): cottage, home, stilt_room, hulk_hold, tower_lobby,
  cliff_room, rooted_floor, tenement, roundhouse, squat.
- Every kind has an `Interiors.LOOT` row. A room nobody lives in (the machines' or
  nobody's: weapons_hall, foundry, data_hall, saw_hall, maintenance_bay, laid_table, bunker,
  frozen_hold) keeps it in a strongbox. line_coil and boom_ram stay off every row, each one
  machine's own.
- A lived-in room's row is on its **kept-by shelf**, one of its own pieces (`const KEPT_BY`,
  `src/core/interior/kept_by.gd`): never taken, a stranger told whose it is
  (`kept_by_theirs`); once the region has thanked the player for an answered ask
  (`Story.heard "REGION:goal:said"`), given once a door (`kept_by_given`, then
  `kept_by_gave`), saved under doors `given`.
- The shelf takes the use key only when it is nearer the hands than every story slot, so no
  words beside it go unread.

## 9. Slices

Each is red first, and each fight-changing one carries a bout number and a tour frame.

| # | Slice | Status |
|---|---|---|
| G1 | every keeper core is an Items row; a drop with no row is an error, not a skip | built |
| G2 | sockets follow grade (§4) | built |
| G3 | lattice and icelens (§6) | built |
| G4 | keeper modules (§5) | built, anvil set aside |
| G5 | a core's two uses on the slate (§5) | built |
| G6 | a LOOT row for every interior kind (§7) | built |
| G7 | salvage: a recipe-made piece taken apart at a bench, 15 min, gives back its elite material and half the rest (`Reforge.salvage_recipes`) | built |
| G8 | fight armour (§6), each naming its hook | built |
| G9 | relic heat: each relic worn or in hand warms the region 0.03 an hour (Interference `carried`, after the hour's cooling); made kit does not; the reads app names it (`READS_CAUSE` `carried`) | built |
| G10 | land materials (§11) | waiting on the GEN batch |

No hopeless matchup: every weapon beats every common machine (not a keeper, not a dart) at
least 1 start of 4 with the crowd reader (`tools/test.sh test_matchups`). Darts are not
fought; the scan says "It takes and goes. Break its sight."

## 10. Rulings (coordinator, 2026-09-26)

1. **One use per core.** The choice must cost: a core in a cell is a core not on your arm.
2. **A carried relic raises interference while carried.** It is a found-tech signature the
   machines read. State the number and measure it against the settlement signatures (G9).
   Built: 0.03 a relic an hour (Interference `carried`), a third of a region's own cooling
   (0.09 an hour). Three hours of one relic is what a stolen cell raised in a holding files once.
3. **New land materials wait** until streaming's S3 settles, batched with the other GEN
   content (machine_city order, drowned water, density).

## 11. Handoff: land materials for the GEN batch (spec, G10)

Owned by the lands and stream builders; goes in with a GEN bump. Five raws already stand
(GEN 41: `PropKind.GRAFT_TREE`, `MOSS_CORE`, `SERVER_BLADE`, `MIDDEN_BALE`, `DRIPSTONE`;
`src/models/props/materials.gd`), and their takes say the material is pending
(`src/core/survival/takes.gd`). Each still needs its take, an EliteStock row, a refining
recipe and a GearTree rung, so `GearEconomy.problems()` stays empty and each land's elite
goal line reads right.

| Land | Raw (prop) | Material | Station |
|---|---|---|---|
| salt_flats | pan crust (PAN ground) | salt_glass | kiln |
| sulphur_jungle | vent crust | sulphur_bloom | fire |
| grey_orchards | grafted heartwood | graft_wood | bench |
| green_towers | tower moss core | root_cable | fire |
| server_fields | server blade | cold_die | bench |
| the_middens | sorted bale | midden_alloy | kiln |
| limestone_caves | dripstone | cave_lime | kiln |

## 12. Decisions from the build

- **Start here before designing a power against chargers.** A skilled player already beats
  a lone charger with nothing lost (its run overruns and leaves it open), and a charging
  crowd is beaten through the shared overrun, when they all arrive and stand spent
  together. A power that stops or slows chargers one at a time breaks that shared opening
  and loses to bare. The ploughshare wins by widening it.
- **The anvil is set aside.** Two heavy-blow verbs and two versions of "glass the ground"
  lost to bare (a skilled player beats plate by walking round; glass stops chargers one at a
  time). The glass code is kept as a patch outside the repo. A new verb for anvil_core must
  not be on the heavy blow.
- **The ploughshare's cost is per turn.** The approved cost, every dodge x1.5 breath, broke
  the fight against biters, which a player dodges all bout; half a dodge's breath a turn
  holds, and more loses to bare.
