# Landscapes, built to depth

The per-landscape specs for docs/ROADMAP.md M3. **DECIDED** (owner delegated design, 2026-09-22):
a builder starts from its landscape's section here and may change a detail only with a frame
or a measurement that shows the spec was wrong, written back into this file.
The words people say are the story-wright's, not this file's.

**Shared systems, in build order** (each lands once, before the landscapes that need it):
1. L0: declared content reaches the world (in flight), plus Takes rows for the 23 signature kinds.
2. L1: `SiteKinds` read by worldgen, as rates per area; `test_landscape_depth`.
3. Per-prop hazard sources (a kind declares "within R adds H").
4. `Ground.GLASS` and its mark decided explicitly.
5. Time-varying ground edits (leads, cut rings, later the tide).
6. Flying bodies; 7. spanning props; 8. machines that wear crafts; 9. ruled canals; 10. a works-mark atlas.

Landscapes whose section needs a shared system that has not landed are built without that
piece first, and the piece is added when it lands.


Read-only design pass, 2026-09-22, against `main` at 21bc99a (L0 not merged: `unspent-ortho-a5` is in flight).
Every spec follows ROADMAP M3's rule: PLAN → LAND → PEOPLE → PLAYER, each caused by the one before.
No story lines, arcs or dialogue are written here; a local is named only by trade and situation. The story-wright owns the words.

## Before you build: what was measured

**Frame arithmetic.** One play frame is 26.7 × 17.9 tiles (about 478). At 72 px per world unit and pitch 57, one tile is about 72 × 60 px on screen. So a prop of radius 0.3 is roughly a 43 px mark. A works `half` of (9, 6) covers two thirds of a frame's width. "Per frame" below means over a frame of that ground in the landscape's core.

**Why things are dead today.** Three mechanisms, all confirmed in code:

1. **The roll cap.** `gen_scatter.gd:1193` throws a tile away when `r > reach[ground]`:
   - 0.5 on NEEDLES, LIMESTONE, MUD, ASH, CLINKER and SWARF
   - 0.4 on SNOW, GRASS and HEATH
   - 0.25 on BONE, GRAVEL, SAND, SHINGLE, SALT and PAN
   - 0.3 on everything else (ROCK, MOSS, ICE, FLOOR, SCREE, PEAT, ROAD)

   So a `r > 0.60 and r < 0.609` window never fires on ROCK.
2. **Ore is not a pass.** `BiomeDef.ore` rates are read only by `_declares_ore` (the way-in seam and quarries) and by `declared()`. A tile gets ore only if `_scatter` returns it AND the kind is in `props` (`allow()`).
3. **Grounds the surface never lays.** A recipe branch keyed on a ground that the landscape's `_surface` never returns can fire only on a neighbour's border band.

Also:
- **ROAD ground is probably unscatterable everywhere.** `gen_surface.gd:210` lays it under the road network, and the scatter skips `road[i] != 0`. Verify with one print before building on it.
- **New prop kinds depend on L0.** `PropKind.COUNT` is 68 and `allow()` packs into an int64 (`1 << kind`). Every new kind below is past bit 63, so none of it can be dealt until L0 widens the mask.
- **A works `mark` is one of four today.** `WorksMap.CHANNEL` is cut, scorch, quarry and bores: four channels of one RGBA texture. `src/render/` is frozen. So every spec below picks one of the four and says what that channel reads as on this ground. A fifth channel is listed under shared systems.
- **A keeper takes exactly three ways** (`SentinelDef.ways`; tests hold three), from FORCE, FOUNDER, STARVE and SPOOF. FORCE is always one. Each spec says which fourth way is left out and why.

---

## 1. The Crags (`the_crags.gd`)

### Dead today

| Declaration | Why it never reaches the world |
|---|---|
| CAIRN (MOSS r 0.30), STANDING_STONE (MOSS 0.50, LIMESTONE 0.60), GRAVE (MOSS 0.70), RUIN (ROCK 0.80) | above their ground's roll cap |
| MEMORIAL on HEATH/GRASS (0.55) | above the cap, and `_surface` never lays HEATH or GRASS |
| CLINTS on LIMESTONE | `_surface` never lays LIMESTONE. CLINTS on ROCK is live but gives nothing: its Takes row is limestone-gated |
| DEAD_TREE and BUSH on heath | `_surface` never lays heath |
| `ore` IRON_ORE 0.012 | not in `props` and never returned |
| `villages = 1` | alive, and should be kept |

Placed today: BUSH (moss, peat), BOULDER, CLINTS (rock), STONE_ORE. **Revive, not add:** cairns, stones, graves, memorials and ruins. Move each band under its ground's cap, e.g. MOSS `0.24..0.2475` for CAIRN. Lay LIMESTONE where `rs` is between 0.9 and 1.4, so the pavement exists.

### PLAN — a survey that never closes

The plan surveyed this land, and its instruments return nothing it can file. So it keeps re-surveying. That is the one machine behaviour here: exact, patient, and failing. It is not hostility.

**Works: the survey bench.** `GenWorks.register(&"the_crags")`, with `_works` laying 1–2 per region on MOSS or LIMESTONE, recorded as `&"bench"`.
- **Mark `bores`.** An exact grid of core holes, one every 1.5 tiles, cut into the lichen along the bearing, plus the survey's paint lines. At 72 px/unit each bore is a dark 10–14 px disc in a ruled lattice, laid across moss that is otherwise all soft irregular grey. It is the only ruled thing in the landscape, and it reads from across a valley.
- **Props:** a THEODOLITE_MAST at each corner, CORE_RACK rows along the long axis, SURVEY posts, one SIGN.

**Keeper: "the plumb"** (`designs/plumb.gd`, roster `sentinel.crags`).
- **Body:** a very tall tripod, about 7 units, with a hanging plumb-weight on a chain under a lamp-less head. Three thin FOUND legs. The weight swings and marks. The silhouette is a triangle over a pendulum. `stations = [&"bench"]`, `feeds = [THEODOLITE_MAST, CORE_RACK, SURVEY]`, `reach` 28, hulk WRECKAGE.

| Phase | Health | Working part | What it does |
|---|---|---|---|
| sighting | 1.0 | back | Slow. The weight swings as a sweep (wide width, long windup). The tell is the head turning to sight you. |
| staking | 0.6 | front, guarded | It drives a leg into the ground as a stamp. Its guard is the leg that is planted. |
| plumbing | 0.3 | none (the weight) | It drops the weight straight down in a ring, then must winch it up. The winch pause is its opening. |

**Its ways:**
- **FORCE.**
- **FOUNDER on PEAT**, hold about 1500 ms. The valleys hold peat and the tripod's point feet go through. Fog hides where the peat is, which is the land doing the work.
- **STARVE** on its masts and core racks.
- **SPOOF is left out on purpose.** Its orders do not come by relay: it lost its line in the fog. That keeps "the land the explanation does not reach" true in the mechanics.

**Unique roster kind: `chainman`, worker.**
- Walks the survey lines dragging a measuring chain (errand, `stretch` 9, pace 3.5). It stops at each stone to set a tiny tripod, then goes on.
- `where`: `the_crags`, grounds moss/limestone/rock, hours 8–18.
- It turns on `blocked`: stand on its line and it pushes. Drops `chain_link`.
- Keep the watcher weight low. The roster stays thinnest-in-game on purpose.

### LAND

Relief stays as it is.
- Add LIMESTONE to `_surface` (see Dead today).
- Pools of BLACKWATER tarns are kept.

**New prop kinds:**

| Kind | What it is | Size (units) | Pen | Where, per frame |
|---|---|---|---|---|
| `LINTEL` | a fallen trilithon: two uprights and the cap stone across them, one upright leaning | 3.2 wide, 2.4 high | MADE (CUTSTONE row 91) | LIMESTONE and MOSS, about 0.3 per frame (a window under the cap) |
| `CARVED_FACE` | a boulder with a worn human face cut into it, half-lidded with lichen | 1.2 | MADE (CUTSTONE) | ROCK, about 0.5 per frame |
| `THEODOLITE_MAST` | the plan's sighting mast: a thin tripod with a ruled head and a small cold lens that never finds its target | 2.6 high | FOUND | works only (THEIRS) |
| `CORE_RACK` | a rack of stone cores pulled from the bores, each labelled, stacked in ruled rows | 1.6 × 0.6 | FOUND | works only |
| `HOLLOW_WAY` | a sunken lane between two dry-stone banks, walled with moss | 4 long | MADE (CUTSTONE) | HEATH and MOSS near ruins, about 0.4 per frame |

**Site kind: `&"barrow"`.** A mound (ground KEEP, radius 5) with a CAIRN on top and a LINTEL at its mouth, plus 3 GRAVE and 1 STANDING_STONE. It holds `&"old_iron"`, is `behind` OPEN with `guard` 0.0, and has `clear` 26. The challenge is the dark, not a machine.

**Landmark kind: `&"broch"`.** A roofless round dry-stone tower, about 8 units, with a stair in the wall thickness.
- `wants &"high"`, `sees` 13, `guarded false`, `mark &"broch"`.
- Its cache sits in the stair.
- The Crags keep `cast_stones` and `firewatch`, and drop `clerks_office`: the plan has no office here.

### PEOPLE

Keep **villages = 1**. Few people and old ones, living in what was already standing.

**Built forms** (`d.built.stock`, plan `&"ring"`):

| Form | What it is | High |
|---|---|---|
| `&"roundhouse"` | a drystone round with a conical turf-and-thatch roof | 3.0 |
| `&"lean_to_broch"` | a timber lean-to built into a broken tower's wall | 2.8 |
| `&"byre"` | long, low, sunk into the slope | 2.2 |

The three rows go in `FORMS`, each with `LIT: false`. This is the one village with no stolen neon.

**Dressing and trade:**
- Shelter is `roundhouse`.
- Trade: **the waller**, who rebuilds the dry-stone and keeps the barrows. A local in `StoryPlan.LOCALS` as `local_the_crags`.
- Dressing: add `dress.shelter` for turf over stone.

### PLAYER

**Hazards:** `wet 0.5`, `dark 0.45`. Add **`resonance 0.3` near stones only.** This is the one mechanical trace of "the unknown force": the stones hum on a scanner. It needs a per-prop hazard source; see shared systems.

**Answers:** oilskin (wet), lamp and the scan head (dark), and the fork (`mod_fork`, `resonance 0.45`) for resonance.

**Only-in material: `hush_slate`.**
- Raw `hushstone`, broken from a `CARVED_FACE` (ground-gated to ROCK in the Crags; `stuff` steel), refined at the kiln.
- *"stone a scanner reads as nothing at all"*.
- **Feeds `mod_hush`:** a module for head, body or back. It gives the tag `quiet`: a machine's `sees` at you is cut while you stand still. It pairs against `mod_lattice`, because one hides you and the other shouts.

**What each new prop does to a body:**

| Prop | Effect |
|---|---|
| LINTEL | Shelter: the roof answer takes wet and dark under the cap. Solid 1.2. |
| CARVED_FACE | Takes `break hushstone` ×1, steel, uses 2. |
| HOLLOW_WAY | Cover: it lowers `Cover.at` between its banks. |
| THEODOLITE_MAST | Takes `strip lens_glass` ×1; filed as theft. |
| CORE_RACK | Takes `turn stone` ×2, keep; theft. |
| CAIRN (revived) | Needs a Takes row: `turn stone` ×1. Its cache is the site's. |

---

## 2. The Frost Sea (`frost_sea.gd`)

### Dead today

| Declaration | Why it never reaches the world |
|---|---|
| BOULDER on ICE (0.80) and SNOW (0.60); RELAY on ROCK (0.50) | above their ground's cap |
| SURVEY on SNOW (0.10) | live but rare: SNOW is only the bank |
| DEBRIS on ICE (0.20..0.206) | live |
| SHINGLE DRIFTWOOD, WRACK and BOULDER | live |
| GRAVEL DRIFTWOOD | apron only |

- RELAY and SURVEY are THEIRS and belong in works, not scatter.
- `villages = 0` is correct.
- Revive ice erratics at ICE `0.21..0.222`.

### PLAN — sounding what is under the ice

VISION §3: its keeper "listens through the ice". The plan is mapping the sea floor by sound through the ice sheet.

**Works: the sounding line.** `_works` on ICE, 2 per region, recorded as `&"soundings"`.
- **Mark `bores`.** A ruled line of round holes kept open through the ice. Each is a black 12 px disc with a pale refrozen rim, every 2 tiles along the bearing, plus paint lines. On a white-blue plain it is the most legible mark in the game.
- **Props:** SOUNDING_RIG over every fourth hole, a PIPE run (a heated line keeping them open), SURVEY at the ends, and a WATER_TANK as a fuel cell.

**Keeper: "the listener"** (`designs/listener.gd`, roster `sentinel.frost`).
- **Body:** a wide, low disc body on six splayed ski-feet, with a crown of long hydrophone spears it drives into the ice. It reads as a spider with needles held upright.
- `stations = [&"soundings"]`, `feeds = [SOUNDING_RIG, PIPE, WATER_TANK]`, `reach` 34 (the sea is open).

| Phase | Health | Working part | What it does |
|---|---|---|---|
| listening | 1.0 | back | Spears down, near-still. It turns on noise: `hears` high, `sees` low. Crouching matters. |
| cutting | 0.6 | left | It saws a ring in the ice round the player: the blow plus a ground edit that opens BLACKWATER for a minute. |
| breaching | 0.3 | front | It runs, skis hissing: fast, straight charges. It turns badly (`turn` 0.8). |

**Its ways:**
- **FORCE.**
- **FOUNDER on BLACKWATER**, hold about 1200 ms. Lure it across a lead, or across its own cut ring, which gives the cutting phase a counter-play.
- **SPOOF**, hold about 2400 ms. Its orders come as pings. Stand on a sounding hole wearing the signet and it files you as a rig.
- **STARVE is left out.** The rigs are scattered across a sea too wide to starve it in a reasonable walk.

**Unique roster kind: `icesaw`, worker.**
- A low sled with a circular saw and a single amber lens. Errand runs straight along the bearing (stretch 12, pace 5), then turns 90°.
- `where`: frost_sea on ICE.
- **Its cuts are real:** a 1-tile BLACKWATER line opens behind it and refreezes over 30 world minutes. That makes it the moving `collapse` hazard.
- Turns on `blocked` and `damaged`. Drops `saw_tooth`.

### LAND

- Relief is kept.
- **Pressure ridges** are ROCK at `rs > 1.2`. Make them run in lines: a `ridge` relief field aligned to one noise direction.
- **New ground behaviour:** *refrozen lead*, a time-varying BLACKWATER↔ICE. See shared systems.

**New prop kinds:**

| Kind | What it is | Size (units) | Pen | Where, per frame |
|---|---|---|---|---|
| `PRESSURE_BLOCK` | a tilted slab of sea ice thrown up at a ridge, translucent at the edge | 1.5 × 0.9 × 1.2 | MADE (GLASS row 86, its first caller) | ROCK ridges, 4–6 per frame, clumped on `t.clump` |
| `FROZEN_HULL` | a trawler locked in the ice up to its gunwale, rimed, one mast | 6 × 2, 3.5 high | FOUND hull, MADE rigging | ICE, about 0.15 per frame (window under 0.3) |
| `SOUNDING_RIG` | a tripod over a hole with a ruled drum and a hanging cable | 2.2 | FOUND | works only |
| `SEAL_HOLE` | a breathing hole with blood-dark ice round it and bones: life going on | 0.6 | MADE | ICE, about 1 per frame |

**Site kind: `&"floe_camp"`.**
- Ground ICE, radius 6: a dead expedition's tents (SHACK), 2 FROZEN sledges (DEBRIS), a FIRE ring gone black, 2 GRAVE.
- Holds `&"salvage_kit"`; `behind` PRESSURE (cold); guard 0.

**Landmark kind: `&"ice_arch"`.**
- A great pressure-ridge arch you walk under, 6 units high, with a cold blue shaft of light through it by day.
- `wants &"open"`, `sees` 12, `guarded false`. Its cache sits frozen in the arch's foot.

### PEOPLE

Keep **villages = 0** on purpose. No one lives on moving ice.
- People appear as the floe camp: the dead, and one `camp` site with a living **ice-fisher** at a SEAL_HOLE. A drifting trader, set by `camp` site `holds`.
- **Shelter:** a snow-banked `SHACK` using `dress.shelter`.
- **No built forms.** Declare `built` empty and say why in the file.

### PLAYER

**Hazards:** `cold 0.85`, `collapse 0.4`. Collapse is now CAUSED: it rises within 2 tiles of BLACKWATER and of an icesaw's fresh cut.

**Answers:**
- the wrap and the woollen mod for cold
- `mod_spring` / grip boots (`resist collapse`)
- **the hover sled**, which spreads its weight: its `wear` on BLACKWATER is kept and it may cross a refrozen lead.

**Only-in material: `deep_ice_lens`** (VISION §6.1 names it).
- Raw `lens_ice`, cut from a `PRESSURE_BLOCK` with a steel edge, ground-gated to ROCK, refined at the bench.
- **Feeds `mod_icelens`:** head, resist glare 0.3 and dark 0.2. It gives the tag `sight`, which extends `scan` reach, and it pairs with the scan head.

**What each new prop does to a body:**

| Prop | Effect |
|---|---|
| PRESSURE_BLOCK | Cover, the only cover on the sea. Takes `cut lens_ice` ×1, steel, uses 2. |
| FROZEN_HULL | Shelter from cold: inside the hold, `Hazards` shelter. Takes `strip scrap` ×2 and `strip iron` ×1. |
| SEAL_HOLE | Takes `gather fish` (needs a line), keep. Hazard: collapse +0.2 within 1 tile. |
| SOUNDING_RIG | Takes `strip line_coil_scrap`; theft. |

---

## 3. The Glass Desert (`glass_desert.gd`)

### Dead today

| Declaration | Why it never reaches the world |
|---|---|
| STANDING_STONE on SAND (0.70) | above its ground's cap |
| SURVEY on GRAVEL (0.40) | above the cap, and GRAVEL is only the village ground |
| SALT DEBRIS | live, but SALT is only `e ≤ 3` and bank |

- Everything else is live: SAND debris and wreckage, ROCK boulders and stone ore.
- `stone_circles: 1` is live through sites.
- **The glass is not a ground.** It is ROCK tinted spruce-slate. Matter row GLASS (86) is unreached. See shared systems: `Ground.GLASS`.

### PLAN — the strike fields

VISION: "fulgurite cores from the glass desert's strike fields", with enemies "glass skaters, strike beacons". The plan draws lightning down on purpose. Ruled fields of rods call dry-storm strikes into the sand, and the fused tubes are harvested. The glassing itself was a strike, and the fields are the same act, repeated small.

**Works: the strike field.** `_works` on SAND or ROCK, 1–2 per region, recorded as `&"strike_field"`, half (10, 7).
- **Mark `scorch`.** On glass it reads as blackened dendritic burns round each rod: Lichtenberg figures fused darker into the pale plates. The shader already tears the scorch rim raggedly, and here the rim should be the branch.
- **Props:** a ruled grid of STRIKE_ROD, 3 × 4, every 4 tiles. FULGURITE clusters at the rod feet. A CONVEYOR run off one edge. SURVEY at the corners.

**Keeper: "the anvil"** (`designs/anvil.gd`, roster `sentinel.glass`).
- **Body:** a tall three-legged mast, about 8 units, with a copper crown of rods and a heavy shielded core low between the legs. The legs end in wide skates, not feet. Silhouette: a candelabrum on skates.
- `stations = [&"strike_field"]`, `feeds = [STRIKE_ROD, CONVEYOR, SURVEY]`, `reach` 30.

| Phase | Health | Working part | What it does |
|---|---|---|---|
| skating | 1.0 | back | Fast glides across ROCK (glass). Its turn is poor. |
| calling | 0.6 | front, guarded | It plants itself; the crown glows cold white. After a telegraph it strikes a 2-tile ring round a marked point. The sand hisses a pale ring first, a ground decal from `MobFx`. Guard: the charge shield. |
| grounded | 0.3 | left | The crown is spent and it drags a burnt leg. Slow, heavy, and it can be walked round. |

**Its ways:**
- **FORCE.**
- **FOUNDER on SAND**, hold about 1400 ms. Skates built for glass bog down in drift sand; lure it off the plates.
- **STARVE** on its rods. Break them and the crown has nothing to call through.
- **SPOOF is left out.** It answers the sky, not a relay.

**Unique roster kind: `skater`, hunter.**
- A long low FOUND body on four blade-skates. Charge approach with `turns` 6 (very long re-aim), `pace` 9, dash 14 on ROCK. It is slowed to 40% on SAND (`keeps_to` rock, salt, gravel; it *follows* onto sand at a crawl).
- `where`: glass_desert, grounds rock/salt, hours 9–19.
- **The whole fight is "stand on sand".** Drops `skate_blade`.

### LAND

- **Ground:** introduce **`Ground.GLASS`**, appended after SWARF. `_surface` returns GLASS where it returns ROCK today, and keeps ROCK for the crater rims (`rs > 1.0`).
- **Craters:** a `pools` pass of SALT with `r_max` 2.6 exists. Add a crater relief feature (a ring rise), or reuse the `stone_circles` site slot as a crater site (below).

**New prop kinds:**

| Kind | What it is | Size (units) | Pen | Where, per frame |
|---|---|---|---|---|
| `FULGURITE` | a cluster of branching fused-sand tubes standing up out of the drift like dead coral | 0.8 high, 0.5 wide | MADE (GLASS row 86) | SAND, 2–3 per frame; clustered 5–8 at rods |
| `GLASS_BLISTER` | a burst dome of glass where a gas pocket rose as it cooled, edge shattered, black inside | 1.8 wide, 0.7 high | MADE (GLASS) | GLASS, about 1 per frame |
| `FUSED_CAR` | a vehicle caught in the glassing, sunk to its sills in a glass pool, one side melted smooth | 3.8 × 1.8 | FOUND body, glazed | GLASS, about 0.4 per frame (a VEHICLE variant would not do: it must melt) |
| `STRIKE_ROD` | a ruled copper-and-steel mast on a guyed foot, 5 units, a cold blinking tip | 5.0 | FOUND | works only (THEIRS) |

**Site kind: `&"crater"`.**
- Ground GLASS, radius 7: a rim of BOULDER, 3 FUSED_CAR, 2 GLASS_BLISTER, DEBRIS.
- Holds `&"plate"`; `behind` PRESSURE (radiation in the bowl, 0.5); guard 0.

**Landmark kind: `&"glass_spire"`.** A single fused column where the first strike came down, 9 units, green-black and translucent at the edges.
- `wants &"open"`, `sees` 13, `guarded true`: a skater circles it.
- Its cache sits at its foot.

### PEOPLE

Keep **villages = 0.** Nobody drinks here.
- **Camp site:** a **glass-picker**, who sifts fulgurite and sells it at the border. Her shelter is a SHACK roofed with a car door (`dress.shelter` sheet plate).
- No built forms, stated in the file.
- Dressing is kept, with `dress.bleach` so bone and wood read sand-scoured.

### PLAYER

**Hazards:** `heat 0.6`, `glare 0.7`, `thirst 0.6`. **Add `radiation 0.35`**, rising to 0.6 inside a crater site and in the strike field. VISION §3 lists radiation for this land, and nothing else in the game declares it outside the back-plate resist.

**Answers:**
- brim hat (glare, heat)
- water still (thirst)
- lead back-plate (radiation 0.6)
- `mod_foil`

**Only-in material: `fulgurite_core`.**
- Raw `fulgurite` from FULGURITE (`break`, iron, ground-gated to SAND in the glass desert), refined at the kiln.
- **Feeds `mod_lattice`**, the shock lattice. It is prime and currently has no `from`, so this closes a gap VISION §6.1 names. It also feeds a rare rung `lance_glass`.

**What each new prop does to a body:**

| Prop | Effect |
|---|---|
| FULGURITE | Takes `break fulgurite` ×1, uses 2. |
| GLASS_BLISTER | Shelter: shade inside answers glare and heat. Cuts: `collapse` 0.3 on stepping in. |
| FUSED_CAR | Takes `strip scrap` ×2 and `pry copper_ore` ×1 (steel); cover. |
| STRIKE_ROD | Takes `strip copper` ×1; theft. It draws a strike in DRY_STORM if you stand within 2 tiles. |

---

## 4. The Ruined Metropolis (`ruined_metropolis.gd`)

### Dead today

| Declaration | Why it never reaches the world |
|---|---|
| MURAL (FLOOR 0.55) and ARCHIVE (FLOOR 0.88) | above their ground's cap. MURAL is also one of the four kinds that alias the first four bits (L0). |
| CHECKPOINT (ROAD 0.70) | above the cap, on ROAD, which is probably never scattered at all |
| STACK (GRASS 0.80) | above the cap |
| VEHICLE and BARRICADE on ROAD | probably dead (road-masked) |
| **All three ore rows** (IRON 0.03, COPPER 0.026, STONE 0.02) | none is in `props` and `_scatter` returns none |

- Live: FLOOR DEBRIS, RUIN and LAMP; SCREE/GRAVEL DEBRIS and WRECKAGE; GRASS PYLON; ROCK/MUD DEBRIS and RUIN.
- CHECKPOINT is THEIRS and should move to works.
- Move VEHICLE and BARRICADE onto FLOOR near roads (`t.road` distance), or into a `jam` vignette.

### PLAN — unbuilding the city

The plan is taking the city apart for what it is made of: copper, steel, glass. It works district by district. Kept districts are swept and lit because they are *queued*. Left districts are already stripped.

**Works: the demolition face.** `_works` on FLOOR, 2 per region, recorded as `&"unbuilding"`, half (9, 6).
- **Mark `quarry`.** On poured floor it reads as the slab peeled back in ruled benches, stepping down a level each, with rebar ends showing as a fine dark grid.
- **Props:** a DEMOLITION_GANTRY straddling the cut, SORTED_BALE stacks in rows (rebar, copper, glass cullet), a CONVEYOR run, LAMP at the corners (the kept half's light), and the CHECKPOINT at the road.

**Keeper: "the unbuilder"** (`designs/unbuilder.gd`, roster `sentinel.metropolis`).
- **Body:** a four-legged gantry crane, about 10 units, that straddles a street. A grab hangs on cables from its bridge; a cab rides the bridge. It is the tallest keeper and uses `tall_cut`.
- `stations = [&"unbuilding"]`, `feeds = [DEMOLITION_GANTRY, SORTED_BALE, CONVEYOR, LAMP]`, `reach` 26 (streets are narrow).

| Phase | Health | Working part | What it does |
|---|---|---|---|
| sorting | 1.0 | back | The grab drops on a marked tile. Wide telegraph (the cable pays out). |
| sweeping | 0.6 | right, guarded | The grab swings on its cable across the street. Its guard is the swinging side. |
| dropping | 0.3 | front | It drops whole bales: debris stamps. It slows as the cab runs out. |

**Its ways:**
- **FORCE.**
- **FOUNDER on GRASS**, hold about 1600 ms. The left districts are green because the ground under them is hollow (the Undercroft), and a gantry leg goes through. Lure it out of the kept streets.
- **SPOOF**, hold about 2200 ms. It takes orders from the district's own signal lamps. Stand under a live LAMP wearing the signet and it files you as a crew.
- **STARVE is left out**: the city is too big to strip its feeds.

**Unique roster kind: `demolisher`, worker.**
- A squat tracked body with a long hydraulic boom and a crushing jaw. Charge approach, `turns` 5, pace 3.5, dash 8. Its bite is heavy and slow and knocks far.
- `where`: ruined_metropolis, floor/gravel/scree, `near_props` ["ruin", "demolition_gantry"].
- It chews RUIN props in front of it: a live `Broken.work_down` on a RUIN over world minutes. It turns on `blocked`, `damaged` and `theft`. Drops `boom_ram`.
- A second, optional kind: `crossing_keeper` (keeper; stands at junctions signalling to empty roads). Hold it for L3.

### LAND

- Relief and the two-city surface are kept.
- **Bring back the kept/left line:** LAMP only where `gb < 0.2`; grass, stacks and pylons where `gb > 0.4`.

**New prop kinds:**

| Kind | What it is | Size (units) | Pen | Where, per frame |
|---|---|---|---|---|
| `DECK_SPAN` | a fallen span of elevated highway lying across a street at a tilt, rebar trailing, a lamp standard still on it | 8 × 2.5, one end 3 high | MADE (CONCRETE row 85) | FLOOR, about 0.25 per frame (big) |
| `LIFT_SHAFT` | a standing lift core with its tower gone round it, doors hanging, cable dangling | 2 × 2, 7 high | MADE (CONCRETE) + FOUND cable | FLOOR/GRASS, about 0.3 per frame |
| `SHOPFRONT` | a gutted ground-floor front: shutter half down, a dead sign-box, glass drift in front | 3 wide, 3 high | MADE (CONCRETE), FOUND sign (ENAMEL row 88, first caller) | FLOOR along roads, 1–2 per frame |
| `SORTED_BALE` | a ruled cube of crushed rebar, copper or cullet, strapped | 1.2 cube | FOUND | works only |
| `DEMOLITION_GANTRY` | a straddle frame over the cut | 6 | FOUND | works only |

**Site kind: `&"plaza"`.**
- Ground FLOOR, radius 7: a MURAL wall, 2 LAMP (dead), DEBRIS, a dry fountain as a RUIN variant, BENCH ×2, and GLASS drift decor.
- Holds `&"copper"`; `behind` OPEN; guard 0.4 (a sweeper round).

**Landmark kind: `&"broken_tower"`.** A glass-faced tower sheared at the 12th storey, its top lying across the next block.
- `wants &"high"`, `sees` 14, `guarded true` (demolishers).
- Its cache sits in a lift lobby. It drops `poured_pillar`, which is shared by 10 lands.

### PEOPLE

Keep **villages = 1** (Eighth Ward, The Cut).

**Built forms, its own, not RAISED:**

| Form | What it is | Reach | High | Lit |
|---|---|---|---|---|
| `&"infill"` | a ground floor walled in with salvaged doors inside a dead tower's frame | 2.2 | 4.0 | yes (one stolen tube) |
| `&"deck_house"` | a shack built on a fallen DECK_SPAN | 2.0 | 3.4 | no |
| `&"shaft_loft"` | rooms hung inside a LIFT_SHAFT, rope ladder | 1.6 | 6.5 | yes |
| `&"stall_row"` | shopfronts re-shuttered as homes | 2.4 | 3.0 | no |

- Keep plan `&"block"`.
- **Shelter:** `infill`.
- **Trade:** **the stripper**, who sells the machines' own sorted bales back, one armful at a time. A local `local_ruined_metropolis`.
- **Dressing:** already concrete. Add `dress.covers` as glass drift.

### PLAYER

**Hazards:** `dark 0.35`, `collapse 0.5`. **Add `toxins 0.25`**, the dust off crushed concrete, weather-scaled by DUST.

**Answers:** respirator, lamp, grip boots (collapse).

**Only-in material: `tower_cable`.**
- Raw `lift_cable`, cut from a `LIFT_SHAFT` (steel, ground-gated FLOOR/GRASS in the metropolis), refined at the forge.
- **Feeds a rare hands rung with `grapple`:** `brace_cable`, family of the grapple brace. A vertical city is where you climb.

**What each new prop does to a body:**

| Prop | Effect |
|---|---|
| DECK_SPAN | Crossing: its high end is a ledge (`Jump` up 2), a way onto a terrace. Shelter underneath. Takes `break stone` ×2 and `pry iron` ×1. |
| LIFT_SHAFT | Takes `cut lift_cable` ×1, uses 2. Cover. |
| SHOPFRONT | Shelter; takes `turn scrap` ×1, keep. |
| SORTED_BALE | Takes `pry copper` or `iron` ×2; theft; the demolisher turns. |

---

## 5. The Drowned City (`drowned_city.gd`)

### Dead today

| Declaration | Why it never reaches the world |
|---|---|
| SEA_WALL (FLOOR 0.60) | above its ground's cap |
| TIDE_GAUGE (MUD 0.50..0.5045) | `r > 0.50` fails a cap of 0.5 |
| HULL (SHINGLE 0.40) | above the cap. HULL is also placed by `beached_wrecks`. |
| **Its only two props of its own** (sea wall, tide gauge) | dead, as above |
| `ore` IRON and COPPER | not in `props`, never returned |

- ROAD DEBRIS is probably dead.
- Live: FLOOR DEBRIS and RUIN; MUD REEDS and POLE; SHINGLE DEBRIS; MOSS REEDS; GRAVEL WRECKAGE.
- **SEA_WALL and TIDE_GAUGE have no Takes rows** (ROADMAP).

### PLAN — the port kept running

The machines still run the port. Ferries keep a timetable along the canals, carrying salvage stripped from the drowned substations out to sea. Tide gauges log a sea level that keeps rising. One basin at a time is pumped dry and stripped.

**Works: the lock.** `_works` across a canal (BLACKWATER or WATER with FLOOR both sides), 1–2 per region, recorded as `&"lock"`.
- **Mark `cut`.** On MUD it reads as ruled drainage cuts running off the pumped basin. The dried basin floor shows the cut rows as dark parallel furrows 1 tile apart, the only straight lines under the tide line.
- **Props:** a LOCK_GATE pair across the water, PUMP_HOUSE, a PIPE run, TIDE_GAUGE ×2 (moved here from scatter), SIGN, and a stripped basin of DEBRIS.

**Keeper: "the lockkeeper"** (`designs/lockkeeper.gd`, roster `sentinel.drowned`).
- **Body:** a long barge hull on four tall stilt legs that wades the canals. A lock-gate blade hangs under its belly. Silhouette: a boat walking.
- `crosses: &"swim"`: it walks the deep.
- `stations = [&"lock"]`, `feeds = [LOCK_GATE, PUMP_HOUSE, TIDE_GAUGE, PIPE]`, `reach` 26.

| Phase | Health | Working part | What it does |
|---|---|---|---|
| wading | 1.0 | back | Stalks along canals, slow. Stilt stamps. |
| gating | 0.6 | front, guarded | Drops the blade: a wall across a canal that blocks a raft. The blow is the drop. Guard: the blade. |
| flooding | 0.3 | left | Opens its ballast: a wave (knockback in water). Its legs are exposed. |

**Its ways:**
- **FORCE.**
- **STARVE** on the locks' pumps and gauges. Break the lock and it has no timetable.
- **SPOOF**, hold about 2500 ms. It reads a ferry's call: ride a raft into its lane with the signet worn.
- **FOUNDER is left out.** It stands in water on purpose, so no ground here refuses it.

**Unique roster kind: `ferry`, keeper.**
- A flat FOUND barge machine, crane stub amidships, running fixed routes along canals at fixed hours (errand, stretch 16, pace 4). `crosses &"swim"`, `keeps_to` water, blackwater, mud.
- It turns on `trespass`: a raft in its lane within 3 tiles.
- **It rams, and it is the first thing that wears a craft:** a ram does hull damage via `CraftKinds` wear.
- `where`: drowned_city, hours 6–20. Drops `bilge_pump`.

### LAND

- **Relief:** keep it low. The city's grid of canals needs to read as a grid. Ask `GenWater` for straight channels between blocks (see shared systems: ruled canals), or accept the pools as basins.
- **Water is the street.** `water_wash` is kept.

**New prop kinds:**

| Kind | What it is | Size (units) | Pen | Where, per frame |
|---|---|---|---|---|
| `STAIR_TO_WATER` | a stone stair going down off a quay into black water, weed on the lower steps | 2 × 1.2 | MADE (CUTSTONE) | FLOOR at a water edge, about 1 per frame (edge-gated via `t.sea_steps` or blends) |
| `DROWNED_TRAM` | a tram half under water, roof above, trolley pole up, a fish net over its windows | 5 × 1.6 | FOUND | MUD/shallows, about 0.2 per frame |
| `MOORING_POST` | a timber bollard crowd with rope, the jetty gone | 0.4 × 1.6 | MADE (TIMBER, ROPE) | MUD at the edge, 3–4 per frame, in rows |
| `LOCK_GATE` | a ruled steel gate leaf in a stone recess | 3 × 2.5 | FOUND | works only |

Also: **revive SEA_WALL** onto FLOOR `0.20..0.2065` and TIDE_GAUGE into works.

**Site kind: `&"flooded_hall"`.**
- Ground KEEP, radius 6: a roofless hall standing in water (RUIN ×2), DEBRIS, REEDS.
- Holds `&"copper"` *under* the water; `behind` WATER (the raft's reason); guard 0.1.

**Landmark kind: `&"clock_tower"`.** A drowned civic clock tower, water to its second storey, hands stopped, a gull colony on its top.
- `wants &"water"`, `sees` 13, `guarded false`.
- Its cache sits in the belfry. Reached by raft and ladder.

### PEOPLE

Keep **villages = 1**. The stock is its own, not a trimmed RAISED:

| Form | What it is | High |
|---|---|---|
| `&"upper_floor"` | people live on floor 2+ of a flooded block, boats tied at the windows | 5.0, lit |
| `&"stilt_house"` | timber on piles over the mud | 3.0 |
| `&"hulk_home"` | a moored barge with a shed on deck | 2.6, lit |

- Keep plan `&"block"`.
- **Shelter:** `stilt_house`.
- **Trade:** **the ferrywoman**, who runs a hand ferry between blocks and knows the machine ferries' hours. `local_drowned_city` already exists in `LOCALS`, so the trade is its situation.
- **Dressing:** add `dress.timber` salt-grey and `dress.covers` weed below the tide line.

### PLAYER

**Hazards:** `wet 0.7`, `toxins 0.35`. **Add `pressure 0.3` in deep water only**: gated by `Swim.deep`, for the future submersible.

**Answers:** oilskin, respirator, `mod_seal` (below).

**Only-in material: `brine_copper`.**
- Raw `sea_copper`, stripped from a `DROWNED_TRAM`'s trolley gear (steel, only while `wading` or from a raft).
- **Feeds `mod_seal`:** body or back, resist wet 0.4 and pressure 0.3. It gives the tag `sealed`. Later it feeds the submersible hull.

**What each new prop does to a body:**

| Prop | Effect |
|---|---|
| STAIR_TO_WATER | Crossing: where a body enters or leaves deep water on foot; a raft `launch` point. |
| DROWNED_TRAM | Takes `strip sea_copper` ×1, uses 2; cover in shallows. |
| MOORING_POST | A raft parks here and does not drift. Takes `cut rope` ×1. |
| SEA_WALL | Needs Takes `break stone` ×2; cover. |
| TIDE_GAUGE | Needs Takes `strip brass`; theft. |

---

## 6. The Mesas (`mesas.gd`)

### Dead today

| Declaration | Why it never reaches the world |
|---|---|
| DEAD_TREE (SAND 0.70) and BOULDER (SAND 0.30..0.3065) | above SAND's cap of 0.25 |
| BUSH and STUMP on HEATH/GRASS | `_surface` never lays heath or grass (village edge only) |
| STUMP (0.55) | also above the cap |

- Live: SCREE BOULDER and STONE_ORE; ROCK BOULDER, IRON_ORE and COPPER_ORE; GRAVEL and SHINGLE BOULDER.
- **Ore is declared and in `props`, so ore is live.** It is the one of the six whose ore works.
- Canyon floors are sand with *nothing on it*. That is the emptiest frame of the six.

### PLAN — the ropeway

The plan carries its haul across the canyons, which no road can cross. Anchors are bolted into the scarps, cables are strung mesa top to mesa top, and buckets run along the bearing. Cliff anchors keep the bolts. Kites watch the spans.

**Works: the anchor station.** `_works` on a mesa top (`e ≥ 7`, SCREE), 2 per region, recorded as `&"ropeway"`.
- **Mark `quarry`.** On red rock it reads as benches cut into the scarp face in ruled steps, bright raw rock against the weathered red. From above it looks like the strata re-cut straight.
- **Props:** SPAN_PYLON at each station, a CABLE_SPAN drawn between two stations across the canyon (the first prop that spans), a BUCKET line on it, DRILL_RIG bolts, SURVEY.

**Keeper: "the anchor"** (`designs/anchor.gd`, roster `sentinel.mesas`).
- **Body:** a four-limbed climber with hooked grapnel feet and a long counterweight tail. It walks up scarp faces; it treats cliff levels as `levels 4`.
- `stations = [&"ropeway"]`, `feeds = [SPAN_PYLON, CABLE_SPAN, DRILL_RIG]`, `reach` 30.

| Phase | Health | Working part | What it does |
|---|---|---|---|
| bolting | 1.0 | back | Clinging and pounding: drops onto you from a terrace above. |
| swinging | 0.6 | right, guarded | It rides the cable: long lateral dashes. Guard: its tail. |
| grounded | 0.3 | front | Off the wall and lame. It cannot climb. |

**Its ways:**
- **FORCE.**
- **FOUNDER on SAND**, hold about 1500 ms. Grapnel feet find nothing in the wash; lure it down to the canyon floor.
- **STARVE** on the spans. Cut a CABLE_SPAN and a station goes dead.
- **SPOOF is left out.** It keeps to the bolts it drove, and reads no orders.

**Unique roster kind: `kite`, watcher.**
- A wide slow flying frame on a tether line from a SPAN_PYLON: `crosses &"fly"`, `sight_only`, `sees` 18, `tether` 14 from its post.
- It circles the canyon and files. **It is the first thing in the game that flies** (ROADMAP's city wave notes nothing does).
- **Cutting its tether line at the pylon** drops it: a theft and damaged cause, but a watcher has no turns, so it just files.
- `where`: mesas, hours 6–20, `near_props` ["span_pylon"]. Drops `kite_vane`.

### LAND

Relief is kept: it is the landscape's argument.
- **Water:** the `WATER` pools are kept. Add a **dry wash**: SAND channels along valleys, which exist already.

**New prop kinds:**

| Kind | What it is | Size (units) | Pen | Where, per frame |
|---|---|---|---|---|
| `HOODOO` | a standing rock spire with a harder cap stone balanced on it, banded | 0.8 wide, 3.5 high | MADE (rock, strata-banded) | SCREE and SAND, 2–3 per frame, clumped |
| `ARCH_RIB` | a thin natural arch spanning 4 tiles, walkable under | 4 × 3 | MADE | ROCK/SCREE at `rs` 1–1.9, about 0.2 per frame |
| `FALLEN_SPAN` | a snapped cable with a bucket line strewn down a slope, a pylon leg bent | 6 long | FOUND | SCREE below a station; works plus scatter 0.1 per frame |
| `CISTERN` | a cut-stone rock tank at a wall's foot, green water, a tin cup chained | 1.6 | MADE (CUTSTONE) | SAND at the foot of ROCK, about 0.3 per frame |
| `SPAN_PYLON` and `CABLE_SPAN` | the plan's | 5; span up to 30 | FOUND | works only |

- **Revive DEAD_TREE** onto SAND `0.10..0.108`, and a BOULDER band on SAND.

**Site kind: `&"cliff_dwelling"`.**
- Ground KEEP, radius 5, `wants` a ROCK face: rooms cut into the scarp (RUIN ×3), ladders (POLE), a CISTERN, BONES.
- Holds `&"salvage_kit"`; `behind` HEIGHT (a `Jump` up 2 to reach); guard 0.

**Landmark kind: `&"great_span"`.** Where the ropeway's biggest span crosses the widest canyon: two SPAN_PYLONs and a sagging cable with a bucket hung mid-air.
- `wants &"high"`, `sees` 14, `guarded true` (a kite).
- Its cache sits in the station hut.

### PEOPLE

Keep **villages = 1** (Rimgate, Drywater).

**Built forms** (plan `&"row"` along a bench: `row` wants FLAT relief, and a bench is flat):

| Form | What it is | High |
|---|---|---|
| `&"cut_room"` | dug into the scarp; only the front wall and door are built | 2.4 |
| `&"adobe"` | red mud-brick, flat roof with vigas | 2.6 |
| `&"watch_hut"` | on stilts at the rim edge | 3.4, lit (a stolen bucket lamp) |

- **Shelter:** `cut_room`.
- **Trade:** **the water-keeper**, who knows where the cisterns are and charges for it. A local `local_mesas`.
- **Dressing:** `dress.timber` silver (already bleached).

### PLAYER

**Hazards:** `heat 0.5`, `thirst 0.55`. **Add `collapse 0.3`** at rims: within 1 tile of a 2+ level drop, which is the land's "falls". VISION's wind and falls are not in `Hazards.IDS`, and a drop is `Jump`'s business.

**Answers:** brim, water still, grip boots, and **glide** (the back wing), which is the mesa's own answer.

**Only-in material: `span_wire`.**
- Raw `rope_steel`, cut from a `FALLEN_SPAN` (steel, ground-gated SCREE in the mesas), refined at the forge.
- **Feeds a rare glide wing rung:** `wing_span`, back slot, `ability glide`, 2 sockets. The existing wing carries no `from`. It also feeds a cable grapple.

**What each new prop does to a body:**

| Prop | Effect |
|---|---|
| HOODOO | Cover; solid 0.4; takes nothing. It is the land's own. |
| ARCH_RIB | Shelter from heat in its shade; a crossing (its top is walkable at +2 levels). |
| FALLEN_SPAN | Takes `cut rope_steel` ×1, uses 2. |
| CISTERN | Takes `draw water` ×1, keep, 120 min regrow. It answers thirst: the land's own spring. |
| CABLE_SPAN | With the grapple, a crossing between stations. |

---

## New shared systems the six need (build once)

1. **L0 must land first.** The 64-bit kind mask becomes wider; every new kind here is past bit 63. Then roll-cap-safe bands, ore reachable, and **Takes rows for existing signature kinds** (CAIRN, SEA_WALL, TIDE_GAUGE and the rest of the 23).
2. **A fifth works-mark channel, or a works-mark ATLAS.** `WorksMap` is RGBA-full: cut, scorch, quarry, bores. The six specs make do with the four. A `&"benches"` (ruled steps on a scarp) or `&"lichtenberg"` (branching burn) mark needs a second texture. That is a `src/render/` change, gated on the form wave's freeze.
3. **`Ground.GLASS`** (append-only), with its material row: matter GLASS 86 is currently unreached. Also used by PRESSURE_BLOCK and FULGURITE as a made mark. It needs a ground mark in the 40..70 band decided explicitly (CLAUDE.md warns a new mark there silently takes the land's wear).
4. **A time-varying ground edit:** a lead opening and refreezing. The icesaw's cuts and the listener's ring write BLACKWATER to `WorldData.ground` for N world minutes and restore it. That needs a saved edit list plus `WorldView` chunk refresh plus `WorldQuery` restamp. It is also the general form of "the tide".
5. **Per-prop hazard sources.** Resonance near stones, radiation in a crater, collapse near a lead or a rim. `Hazards.felt` reads only the landscape and weather today; it needs "within R of kind K adds H". Declared on the prop kind, not the landscape.
6. **Flying bodies** (`crosses &"fly"` realised): drawn at altitude, a tethered orbit brain, and a shadow on the ground (`Player.lift` idiom). It is needed by the kite, and later by the city.
7. **A spanning prop:** CABLE_SPAN between two stations. The model, its collision (none, or a grapple line) and its culling must cover two points, not one.
8. **Machines that damage crafts:** the ferry's ram into `CraftKinds` hull wear, and the lockkeeper's gate blocking a raft (`WorldQuery.set_blocks` under an owner that moves).
9. **A sentinel ground edit on a telegraph:** the listener's cut ring and the anvil's strike ring. `MobFx` decals plus item 4.
10. **Ruled canals in `GenWater`** for the drowned city: straight channels between blocks, not round pools. It is a worldgen change that turns `GEN`.
11. **`SiteKinds` read by worldgen** (currently read by nothing): the barrow, floe_camp, crater, plaza, flooded_hall and cliff_dwelling rows depend on it. This is L1's rate-per-area work.
12. **Six sentinel roster rows plus six unique roster kinds.** Each needs a `where` gate, drops, a model, and `EliteStock` entries for the machine-gated drops if wanted. Six new `EliteStock` land-materials: hush_slate, deep_ice_lens, fulgurite_core, tower_cable, brine_copper, span_wire. Each needs raw Takes, a refine recipe, a `GearTree` row and an `Items` row, and `test_obtainable` must pass.
