# GEAR.md: the gear economy as a progression across landscapes

The design, approved 2026-09-26 (rulings in §10), and what is built of it (§12).
The table in §5 says each keeper power as it is built; where the build changed a
row, the row says why.
Owner direction (2026-09-15, VISION §Gear): every weapon, armour and power is obtainable,
varied by region, dropped by rarity or crafted by difficulty. Elite materials come from one
landscape, one enemy or one keeper. A higher grade buys modifiers, never a bigger number.
The rule this document adds: **every piece comes from a place or a deed, never from nowhere.**

## 1. What exists (the foundation is good)

- **Three idioms are the tiers.** Made (by hand), mended (machine parts bound with cord),
  found (machine tech taken whole, cannot be mended).
- **Slots.** Head, body, hands, back, tool and craft. The craft slot is unused.
- **Modules and abilities.**
  - Modules socket into slots and grant resists and abilities.
  - The abilities are dash, glide, scan, grapple and spoof; jump is innate.
- **FightKit.** Eight modules change a fight, not a number:
  - harmonic: a blow that rings off plate still bites.
  - phase: the first blow reads through plate and guard, with a long stall.
  - damp: your blows are quiet.
  - leech: a kill returns charge.
  - capacitor: every third charged swing is free.
  - ablative: soaks one blow, then is gone.
  - gyro: a hit does not cancel your swing.
  - clamp: you take a third of the knockback.
- **GearTree.** Families climb common → rare → prime (→ relic for the thin blade).
  - Each rung keeps the family's numbers and adds sockets.
  - Each rung wants one elite material.
- **EliteStock.**
  - Ten land materials, refined at a station from a raw only that land gives.
  - Ten machine materials, a per-kill chance off one roster kind.
  - Spoils: found weapons off kills.
- **Economy pieces.**
  - Craft tiers: hand, fire, bench, kiln, jig. Kiln and jig pours can fail into a flawed
    twin or `spoil`.
  - `Modifiers` tags make pairs combine or conflict (quiet and loud, hot needing cool,
    charge and charge).
  - `Reforge` takes modules out, with a field risk.
  - `Sources.path_to` proves every item is reachable; `GearEconomy.problems()` fails the
    build if one is not.
- **The late goal** (`Guide.next_elite`) already sends the player to the next elite
  material, preferring the land underfoot.

## 2. The gaps (measured)

1. **Keepers give almost nothing.**
   - The seven cores' only use is the stolen cell (SETTLE S5).
   - `listener_core` (frost_sea's keeper) has no item row, so the listener drops nothing.
   - Beating a keeper, the hardest deed in a region, does not change how you fight.
2. **Half the landscapes have no material.** Ten of the ~23 lands have an elite material.
   These have none: coast, salt_flats, pinewood, grey_orchards, sulphur_jungle, slums,
   green_towers, machine_city, server_fields, limestone_caves, the_middens, scrapwood and
   sea.
3. **Every interior holds something** (G6). Every kind has an `Interiors.LOOT` row. A room
   nobody lives in keeps it in a strongbox; a lived-in room keeps it on its kept-by shelf,
   given once on good terms and never taken.
4. **Rarity is metadata.**
   - `Drops.roll` returns `{item, count}` and nothing reads a row's `rarity`.
   - Sockets come from `Items.DEFS.sockets`. That does not always follow the grade: common
     made wear has one socket, where `Rarity.SLOTS` says a common has none.
5. **Two modules do nothing.**
   - mod_lattice says "every blow shocks", and no code does it.
   - mod_icelens's `sight` tag extends nothing.
   - `kit_lens` is read by no caller.
6. **Armour is resist only.** Body, head and hands pieces answer hazards. Only ablative,
   gyro and clamp (modules) touch the fight.
7. **Salvage has no key.** `Reforge.salvage` exists and nothing calls it, so a rung you
   outgrow is dead weight.

## 3. The shape: one loop per landscape, one deed per region

Each landscape gives **three things**, each from something the player does there.

| Source | What | Gate |
|---|---|---|
| **The land** | its raw, refined to its elite material at a station | walking there, a steel edge, the right station |
| **Its machines** | a machine material (per-kill chance) and found weapons (spoils) | fighting what lives there |
| **Its keeper** | its core, and with it **a power** (a keeper module, §5) | the region's hardest deed, in one of the keeper's ways |

The **interior** of each landscape holds one piece that could come from nowhere else (§6).

Progression stays outward from home (STORY: no stop is nearer home than the last):

| Band | Lands | What the player makes of it |
|---|---|---|
| **Home** | coast, moss, pinewood, scrapwood, grey_orchards | made kit and steel. Rare rungs from bog_iron (moss) and seasoned timber (pinewood hall). The coast keeper's reaper_core is the first power. |
| **Near** | bonelands, burning, snowfield, salt_flats, sulphur_jungle, the_crags | the kiln and the rest of the rare rungs (clint_spar, cinder_glass, frost_varnish, hush_slate). The foundry's lance casting. First prime parts off wardens and cutters. |
| **Far** | glass_desert, mesas, frost_sea, drowned_city, ruined_metropolis, slums, green_towers | prime rungs on the jig (fulgurite_core, span_wire, tower_cable, brine_copper, deep_ice_lens) and their keepers' powers |
| **Deep** | machine_city, server_fields, the_middens, limestone_caves | relics: pieces that wear the machines' name, each with a cost |

The band is not a level gate. It is where the raw and the keeper are. A player who crosses
early can take a far material early; the jig and a steel edge are what hold them.

## 4. What rarity means in play

**Grade = sockets = decisions.** It is never damage (VISION). Enforce it in one place:

| Grade | Sockets | Where it drops or is made | In play |
|---|---|---|---|
| common | 0 (made wear 1, as now: a made piece is where the first module lives) | made by hand or at a fire | a tool that works |
| uncommon | 1 | found weapons off kills, mended kit at the bench | one decision |
| rare | 2 | a land's elite material at a bench | two decisions, a pair possible (§5 tags) |
| prime | 3 | a machine's material on the jig | three: a combo and a conflict to manage |
| relic | 3, unique, with a **cost** | one per keeper or deep room | changes a rule, and takes something back |

- **Rule:** `Items.DEFS.sockets` defaults to `Rarity.SLOTS[grade]` from GearTree. Made wear
  keeps its one socket by an explicit override, and a test holds the table to it.
- **A drop's rarity is shown, not rolled.**
  - A dropped found weapon is its family's uncommon rung; its grade is its row.
  - What a kill's rarity decides is **whether** it drops (the per-kill chance), never its
    stats.
  - The slate names the grade in the pickup line ("a rare rung"), so the rarity is felt.

## 5. Powers from keepers: what beating a keeper changes

Each keeper core has two uses. **The player chooses**, and the choice is the point:

- **Power a holding.** The stolen cell (S5): four power day and night, the loudest thing in
  the game.
- **Power yourself.** On the jig, the core becomes the keeper's module: relic grade, fits
  one slot, unique.

Each keeper module is the keeper's own way of fighting turned to the player's use. It
changes a decision in a fight and carries a cost. All hook into FightSim or an ability that
exists.

| Core | Keeper (land) | Module id (proposed) | Slot | What it does in a fight | Its cost |
|---|---|---|---|---|---|
| reaper_core | tide reaper (coast) | mod_undertow | hands | the grapple takes hold of a machine ahead and drags it one body-length in, stopping 1.0 short; its tell broken, it stands stalled | the haul costs double wind |
| rake_core | pan rake (salt flats) | mod_rake | tool | as a heavy is drawn it rakes a 3-tile arc: every biter in it has its tell broken and stands stalled open; a charger rides over it (built: throwing them back lost bouts, raking a charger gave it its run back) | heavy blows are 1.5x as loud |
| plumb_core | plumb (the crags) | mod_plumb | head | scan reads where a machine will be at its next tell (a mark on the ground, from its brain's plan) | the scan's cooldown doubles |
| anvil_core | anvil (glass desert) | mod_anvil | tool | SET ASIDE: two heavy-blow versions and two versions of "glass the ground" measured worse (§12); its core stays the holding's cell only | — |
| unbuilder_core | unbuilder (ruined metropolis) | mod_unbuild | hands | on a stalled machine, `use` strips its working part: it is disarmed (bite null) and its prime material drops | the strip is a held `use` of 1.5 s inside the stall |
| lockkeeper_core | lockkeeper (drowned city) | mod_lock | back | hunted (a roused machine within 20 tiles), a narrow way you pass between two solid things no more than 2.2 tiles apart is shut behind you to machines for 20 s (`FightSim.lock_walls`). Built so because a holding's gates already stop machines and machines never follow into a room: a door lock would do nothing | 1 charge (wick) a lock |
| anchor_core | anchor (mesas) | mod_anchor | body | standing still for 0.6 s roots you: no knockback, no grab; a lineman's grip fails, and is a miss that leaves it open | rooted, and for 0.3 s into pulling the root up, you cannot dodge |
| listener_core | listener (frost sea) | mod_listen | head | you hear machines through walls: their tells show as marks at their place for 2 s | you are heard as far as you hear (your noise radius x1.5) |

- **Data gap to fix first:** add the `listener_core` item row. Today the listener drops
  nothing (§2.1).
- **Why a cost:** a relic "changes a rule and takes something back" (§4). A power with no
  cost is a number.
- **They meet the tag table.** Each carries a tag so pairs matter:
  - undertow: held
  - rake: loud
  - plumb: read
  - anvil: loud
  - unbuild: read
  - lock: charge
  - anchor: steady
  - listen: sight
- **What those tags make:**
  - anchor with gyro (steady) and undertow (held) makes a planted grappler.
  - rake with damp (quiet against loud) is the conflict to manage.

## 6. Armour and powers that change how you fight

Armour answers the land today; it should also answer the fight, one verb per piece. Most of
these use modules that already exist, applied to a piece. Where the effect needs code, that
is written in.

| Piece | Slot | Grade | From | Changes |
|---|---|---|---|---|
| **scale coat** (`coat_scale`, built) | body | rare | tide_iron (harvester), bench | the first blow of each fight that lands within 70° of straight back is turned (FightSim._hurt_hero; never spent) |
| **hush wrap** (`wrap_hush`, built) | body | rare | hush_slate (the crags) | your steps are quiet on any land: the body's own acts take moss's ground term (StealthNoise.radius; water is untouched) |
| **vane cloak** (`cloak_vane`, built) | back | prime | vane_true (sweeper) | in wind above 0.4 a dodge within 50° of downwind carries twice as far (FightSim._dodge; `Weather.bearing` is the wind's axis); worn where the wing goes |
| **lens visor** (existing scanner_lens + mod_icelens) | head | rare | deep_ice_lens | **fix mod_icelens:** scan reach +50%, and glare no longer cuts your sight |
| **cable gauntlets** (existing brace_cable, and brace_ram over it; built) | hands | rare | tower_cable | the grapple takes a machine whose working part faces the line, stalls it and pulls the player to it (AbilityGrapple.anchor, FightSim.cable); the undertow, fitted too, hauls instead |
| **lattice** (existing mod_lattice) | tool | prime | fulgurite_core | **build it:** a blow that lands also shocks every body within 1.2 for 1 damage; hot, so it wants a cool |

**Rule for new pieces:** each must name the FightSim or ability hook it changes. A piece
that only adds resist is armour for the land; that is fine, but it is not what this list is
for.

## 7. Where things are found (loot per interior)

Each landscape's interior holds one thing that cannot be had elsewhere, plus its land's
material at a better rate than the land's cache.

| Interior | Land | Proposed LOOT row (existing ids unless noted) |
|---|---|---|
| saw_hall (world/homes) | pinewood | seasoned_timber 6-10 (as teammate3 set it); haft 2-4; mod_grip .4 |
| cottage | coast | rag, oil, wick; hat_brim .3 |
| maintenance_bay | machine_city | line_coil .5; mod_capacitor .4; las_hand .3 |
| stilt_room / hulk_hold | drowned_city | brine_copper 1-2; bilge_pump .5; mod_seal .35 |
| tower_lobby | ruined_metropolis | tower_cable 1-2; boom_ram .3; mod_gyro .35 |
| tenement | slums | scrap 3-6; rebreather .35; mod_filter .5 |
| roundhouse | the_crags | hush_slate 1-2; mod_hush .4 |
| rooted_floor | green_towers | resin; mod_spring .4; (proposed) green_towers' material |
| cliff_room | mesas | span_wire 1-2; glide_wing .35 |

- **Coordinate ids:** every id above exists except where marked.
- **The saw hall is world/homes'.** Its row is theirs to set; I list it so the table is
  whole.

**Lands with no material** get one each, from something only that land has, as the first
ten did. That is worldgen content, owned by the lands and stream builders; I propose the
table and they own the props:

| Land | Raw (prop) | Material | Station |
|---|---|---|---|
| salt_flats | pan crust (PAN ground) | salt_glass | kiln |
| sulphur_jungle | vent crust (VENT in jungle) | sulphur_bloom | fire |
| grey_orchards | grafted heartwood | graft_wood | bench |
| green_towers | tower moss core | root_cable | fire |
| server_fields | server blade | cold_die | bench |
| the_middens | sorted bale | midden_alloy | kiln |
| limestone_caves | dripstone | cave_lime | kiln |

Each gets a rung in GearTree, so `GearEconomy.problems()` keeps every one reachable and used.

## 8. The loop in one sentence per band

- **Home.** Make a knife, bind your first module, and take the tide reaper for your first
  power, or for your holding's cell.
- **Near.** Your kiln pours the land's glass and spar. A warden's lens puts a third socket on
  your beam.
- **Far.** The jig makes prime. Each keeper you end is one more rule you can bend, and one
  more cost you carry.
- **Deep.** Relics wear the machines' name, and the plan hunts whoever carries them.
  - This makes one of the "costs" systemic: a relic in your loadout raises Interference by
    `&"carried"` per world hour, as found tech in a holding does.

## 9. Slices, each red first, each with a proof

| # | Slice | Files | Proof |
|---|---|---|---|
| G1 | listener_core row; the keeper table test fails on any core with no row | items.gd, sentinels.gd test | test: every BiomeDef.sentinel design's core is an Items row |
| G2 | Sockets follow grade (`Rarity.SLOTS`), with the made-wear override explicit | gear.gd, gear_tree.gd | test: every GearTree item's sockets equal its grade's, except named overrides |
| G3 | Build mod_lattice and fix mod_icelens | fight_sim.gd, abilities | tests: lattice shocks bodies within 1.2 on a landed blow; icelens scan reach x1.5; a bout number |
| G4 | Keeper modules: the core on the jig → mod_undertow first (the coast's), then one per slice | recipes, items, fight_sim / abilities | a test per module's rule and its cost; a tour frame of the power in use |
| G5 | Core choice: the slate shows both uses of a core (cell or module) | 46_settlements, gear page | a tour: holding a core, both offered |
| G6 | Interior LOOT rows for the nine rooms (§7) | interiors.gd | test: every interior kind has a row, and every row id is an Items row |
| G7 | Salvage key: take a rung apart at a bench (`Reforge.salvage`), elite back | 54_gear | test: a rare rung salvaged returns its elite material |
| G8 | Fight-armour pieces (§6), one per slice, each naming its hook | items, gear_tree, fight_sim | per-piece test on its hook, and a bout number |
| G9 | Relic heat: a carried relic raises Interference (`&"carried"`) | 32_disposition | test: a relic in the loadout raises the region per hour; a made kit does not |
| G10 | New land materials (§7), with the lands and stream builders | biomes, takes, elite_stock | `GearEconomy.problems()` stays empty; each land's elite goal line reads right |

- **Order:** G1 and G2 are small and fix the data. G3 makes the two dead modules real. G4
  and G5 are the heart: keepers change the fight, and the core is a choice. G6 and G7 fill
  the world. G8 to G10 grow it.
- **Proof protocol:** each slice is red first. Each fight-changing slice carries a bout
  number (test_bouts style) that shows the decision it creates, and a tour frame read by
  eye.

## 10. Rulings (coordinator, 2026-09-26)

1. **One use per core.** The choice must cost: a core in a cell is a core not on your arm.
2. **A carried relic raises interference while carried.** It is a found-tech signature the
   machines read. State the number and measure it against the settlement signatures (G9).
   Built: 0.03 a relic an hour (Interference `carried`), a third of a region's own cooling
   (0.09 an hour). Three hours of one relic is what a stolen cell raised in a holding files once.
3. **New land materials wait** until streaming's S3 settles, batched with the other GEN
   content (machine_city order, drowned water, density).

## 11. Handoff: land materials for the GEN batch

Owned by the lands and stream builders; to go in with the next GEN bump. Each needs a prop
(or a take off an existing one), an EliteStock row, a refining recipe, and a GearTree rung
so `GearEconomy.problems()` stays empty.

| Land | Raw (prop) | Material | Station |
|---|---|---|---|
| salt_flats | pan crust (PAN ground) | salt_glass | kiln |
| sulphur_jungle | vent crust | sulphur_bloom | fire |
| grey_orchards | grafted heartwood | graft_wood | bench |
| green_towers | tower moss core | root_cable | fire |
| server_fields | server blade | cold_die | bench |
| the_middens | sorted bale | midden_alloy | kiln |
| limestone_caves | dripstone | cave_lime | kiln |

G10 is therefore out of this build; G1–G9 go now.

## 12. Progress

**Start here before designing a power against chargers.** Two keeper powers (the anvil's heavy blow and its glass) failed for the same reason: a skilled player already beats a lone charger with nothing lost, and a charging crowd is beaten through the shared overrun, when they all arrive and stand spent together. A power that stops or slows chargers one at a time breaks that shared opening and loses to bare.

- G1: listener_core row; a keeper drop with no row is an error, not a skip (160f4bba).
- G2: sockets follow grade; axe_works 2 (ea25496d).
- G3: lattice (reach 2.0, 2 damage shared nearest first, 1 charge, a visible arc) and icelens (scan x1.5) (d3ea03fb..bd0e64df). Gate test holds its identity: 3 harvesters no faster; 3 cutters 41% sooner, 3/24 -> 8/24 won (6a6cc010).
- Crowd reader + no hopeless matchup: 48 weapons x 17 common machines, every pair won at least 1 of 4 (674d6942). Darts are not fought; the scan says "It takes and goes. Break its sight."
- G4 undertow: reaper_core on the jig -> mod_undertow (relic, hands). Grapple hauls a machine ahead one body-length (stopping 1.0 short), breaks its tell, stalls it; double wind. Bout: harvester 4.4 -> 3.1 s, hauler 3.1 -> 5.2 s (hauled for nothing). Keeper cores are now a Sources step (`beat`).
- G5: a keeper's core reads on the slate as the choice (cell vs power), side by side (08f85e15).
- G4 rake: held open, not thrown; chargers ride over it. 2 cutters 18 -> 22/24; 3 harvesters unchanged (0890154a).
- G4 anvil: SET ASIDE. (1) a heavy on plate cracks that side for the bout, every swing x1.4: slower in every duel (runner 3.9 -> 7.1 s, cutter 6.6 -> 10.1 s), 3 harvesters 24 -> 12/24; (2) a heavy on plate jams open, heavies x1.4: 2 cutters 18 = 18/24, sweeper 15 -> 6/24, 3 harvesters 24/24 7.8 -> 15/24 43.7 s. Why: a skilled player beats plate by walking round, a heavy's tell is the danger in any crowd where plate matters, and a slower heavy spoils the charger, where heavies already pay. Propose a different verb for anvil_core, not on the heavy blow.
- G4 anchor: stood still 600 ms roots; no throw, no grip (a failed grip is a miss); no dodge while rooted and 300 ms into pulling it up. 2 linemen 18.3 -> 8.5 s, 2 cutters 18 -> 17/24 (the reader keeps a step going against biters).
- G4 lock: a gap between two solid things (<= 2.2 tiles, edge to edge) passed while a machine hunts within 20 tiles is shut to machines for 20 s, a charge. (The open world has few doors to lock, so it locks the narrow ways a chase runs through.) Hunted through a gap in a boulder line: 29 tiles behind bare, 47 locked, after 12 s.
- G4 ear (listen): a tell ring drawn through what stands between at eye level; steps and noise 1.5x. With the shoulder reader: a cutter in front and a thrower behind, 1.8 -> 1.4 health lost a bout; a walk past twelve hunters rouses 12 against 10.
- G4 plumb: a scan rings where each roused machine will tell (edge of its reach on the line to the player); scan cooldown x2. Bout (shoulder reader scanning when ready, answering a tell it was braced for at 80 ms instead of 220 ms): 1.0 -> 0.7 health lost a bout. The gain rests on that modelled reaction time; the doubled cooldown did not cost in this bout.
- G4 unbuild: use held 1.5 s at an open (stalled or spent) machine's part, gathered across openings, strips it: no bite, its elite part into the creel. The reader strips only a body it faces alone. A lone cutter: 6.6 s bare, 16.2 s stripped, 24 parts in 24; a lone harvester 4.4 vs 4.1 s; two cutters 18/24 both, 14.3 vs 29.3 s, 18 parts. The cost is time: a strip is slower than a kill, and pays in parts.
- G4 anvil, second verb, "glass the ground": SET ASIDE. A press (key 1) lays a patch of glass 1.5 tiles in radius, 2.5 ahead, for 30 s, 2 charges, 12 s cooldown; the player crosses it freely. Pass bar (shoulder reader, set before the last try): 3 harvesters beat bare on wins or health lost, a lone charger no worse than bare, biters unchanged. (A) as approved: on glass a body moves at half speed and no run starts; a run carried onto it skids and stalls once (STALL_MS). Crowd reader, 24 bouts: 1 harvester 4.4 -> 4.0 s, 1 hauler 3.1 = 3.1 s, 2 cutters unchanged (0 skids), 3 harvesters 24/24 both but 7.8 -> 31.6 s and 0.4 -> 3.0 health lost. Variants, shoulder reader, 16 bouts: no bite on glass, and no run for 0.8 s after coming off it: 1 harvester 4.4 -> 7.0 s (0 lost both), 2 harvesters 1.1 -> 5.6 lost, 3 harvesters 14 -> 8/16; a skid that slides the body to the player's feet: 1 harvester 0 -> 4.1 lost; the patch at the player's feet: 3 harvesters 14 -> 10/16. (B), the last try: a charger that skids is stuck fast until the patch goes or a blow lands. 1 harvester 0 -> 3.4 lost, 2 harvesters 1.1 -> 4.9 lost, 3 harvesters 14 -> 8/16 won, 1.5 -> 9.8 lost. 2 haulers and 2 longlegs came out within about 15% of bare throughout, with nothing lost; skaters never skid. Why: a skilled player already takes a lone charger with nothing lost, since its run overruns and leaves it open; a charging crowd arrives and overruns together, and that shared opening is the win. Glass stops them at different moments, so they come off it one at a time and the shared opening is gone. A body struck free, or walking off the glass at the player's side, then runs from point blank. The code is kept as a patch outside the repo.
- G8 scale coat: tide iron over a long coat, body, rare; the first blow of a fight within 70° of straight back does no harm, one a fight, never spent. Shoulder reader, 16 bouts: 3 runners 1.50 -> 0.50 health lost; 2 cutters 13 -> 14/16 won, 3.19 -> 2.44 lost; a lone harvester unchanged (it never gets round).
- G8 hush wrap: a warm wrap lined with hush slate, body, rare; walk, run, dodge, drop and eat are heard as on moss on any land, tools and water unchanged. A walk across shingle past twelve idle runners 12-15 tiles off: 10 come bare, 0 hushed.
- G8 vane cloak: back, prime; in a wind above 0.4 a dodge within 50° of downwind carries 2x (2.5 tiles, not 1.26). Fleeing a harvester downwind in a 0.8 wind, 16.7 -> 19.7 tiles ahead after 5 s, no bites either way. Its cost, standing to fight with a reader that dodges without reading the wind: 3 runners 1.50 -> 2.38 health lost, 2 cutters 3.19 -> 4.12, bouts won unchanged; the long dodge carries it out of the opening it dodged for.
- G8 cable line: brace_cable and brace_ram; the grapple takes a working part that faces it, stalls it (once per STALL_EVERY_MS) and pulls the player in to 0.3 off its body. Crowd reader, 24 bouts: a lone harvester 4.4 -> 3.1 s (a line every bout, its front faces the player between runs); a hauler and 2 cutters unchanged (their parts never face it at range); 3 harvesters 0.38 -> 0.75 health lost (pulled in on the last of them). G8 is done: scale coat, hush wrap, vane cloak, cable line.
- G9 relic heat: every relic in the loadout, and a relic in the hand, warms the player's region by 0.03 an hour (Interference `carried`, applied after the hour's cooling, never gapped). Through the game on the coast, an hour wearing the lock: 0.000 -> 0.030; in made kit, 0.000. One relic slows a cooling file by a third, three hold it, four warm a calm region to wary in about nine hours. The reads app names it under the interference trace while a relic is worn, by line id (StoryContent.READS_CAUSE `carried`, words "KEEPER CORE OFF STATION. LOCATING.").
- Vane cloak model: five trued vanes hung from a bar across the shoulders, fanned down the back (PersonBody `vanes`, a salvage part only fitted kit wears, PersonLook.KIT_SALVAGE, so no villager is dealt it). Seen over the shoulder in tours/vane_cloak.tour.
- G4 ploughshare: plough_core on the jig -> mod_ploughshare (relic, hands). A dodge within 30° of square to a charging machine's line, its bite winding up or live, within 4.5 tiles, turns it: recovery and cooldown x2, and it drives on past for a run as long again once its bite is done. It widens the shared overrun instead of breaking it. Shoulder reader, 16 bouts: 3 harvesters 14 -> 16/16 won, 1.50 -> 0.38 health lost; a lone harvester 16/16 both, nothing lost; 2 cutters and 3 runners exactly as bare (a plain dodge is untouched). Without the drive past: 3 harvesters 1.12 lost. The approved cost, every dodge x1.5 breath, broke the biters (2 cutters 3.19 -> 9.19 lost, 3 runners 1.50 -> 4.25; at x1.25, 6.19 and 4.12), because a reader dodges biters all bout. The cost is paid per turn instead: half a dodge's breath each. A full dodge's breath (3 harvesters 10/16, 6.75 lost) and three quarters (1.50 -> 3.38) lose to bare, so turning a crowd winds you past half. Its standing cost is a relic's: worn, it warms the region by 0.03 an hour (G9 relic heat).
- G6 room loot: a room is lived in exactly when its recipe seats a household or squatters (`const SEATS`, InteriorKind.seats): cottage, home, stilt_room, hulk_hold, tower_lobby, cliff_room, rooted_floor, tenement, roundhouse, squat. Every other room is the machines' or nobody's (weapons_hall, foundry, data_hall, saw_hall, maintenance_bay, laid_table, bunker, frozen_hold) and keeps its row in a strongbox; the bay's parts locker and the laid table's larder safe are new. Every kind has a LOOT row; line_coil and boom_ram stay off them, each one machine's own. A lived-in room's row is on its kept-by shelf, one of its own pieces (`const KEPT_BY`): never taken, a stranger told whose it is (`kept_by_theirs`); once the region has thanked the player for an ask he answered (Story.heard "REGION:goal:said"), given once a door (`kept_by_given`, then `kept_by_gave`), saved under doors `given`. The shelf takes the key only when it is nearer the hands than every story slot, so no words beside it go unread (24 slots in 120 laid rooms went unread without that rule).
