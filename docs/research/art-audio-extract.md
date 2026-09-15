# UNSPENT: art and audio extract for the ortho rebuild

Source: `/Users/wilneeley/Projects/unspent` (read-only), 2026-09-15. Sources read: `docs/05`, `09` (§1, 1a, 1d, 1f),
`20`, `31` (§1, §3), `32`, `06`, `.claude/rules/art.md` and `audio.md`, `tools/art/{palette,machines,creatures,threats,sprites,buildings,weather}.py`,
`tools/audio/{synth,sfx,music,mix}.py`, `content/{threats,looks,creatures}.json`, `tilesets/*.json`, `DayLight.cs`,
`Surface.Cast`, `Game.Light`, `OpenWorld.Glow`, `GameHost.MachineBed`. I also looked at the machine, people, tile and
building sheets, the title and in-game shots. **Target engine: Godot 4.7, GDScript, Compatibility renderer** (§7 audio plan, §8).

**Stale material, ignore it.** Parts of 05 and 09 still describe the deleted game: the Basin, the rings and ring palettes,
the Spire, the procedural battle backdrops, the ledger transparency, "no orange", and the spec of 384x216 with 16 px tiles.
The build that actually runs is 640x360 with 32 px tiles (32 PPU), 16 ramps and 92 colours. Everything below reflects that build.

---

## 1. Look and mood

- **In one line.** A cold northern coast in late autumn, eleven years after the handover. *Nothing went dark*: the grid
  holds, the pumps run and the harvesters go out. What stopped is the part that asked. The machines are predators and
  barely working. People live in the gaps, where they mine, make and mend. No grimdark: it is ordinary. The dread comes
  from the machines being routine, not from them being monstrous.
- **Palette mood.** Greens are grey-green. Browns have no orange in them until something rusts. The only saturated
  colour anywhere is something lit, something burning, something in flower (placed and seasonal), or **a machine**.
  - The reference is EarthBound's attitude (flat, deadpan, readable at a glance), not its hardware limits.
  - No HD-2D look and no 16-bit cosplay.
  - The brief to artists: "Wet stone, wet wool, low light. Never cartoon outlines in pure black, saturated greens, cheerful skies."
- **Two idioms (ADR-008 §4). This is the key rule.**
  - **MADE:** only the 16 coast ramps; warm, worn to the owner's grip; irregular where the material is (a creel yes, a letter may be a rectangle); hand-cut edges that change direction every pixel or two.
  - **FOUND** (machines and their salvage): indigo-violet, >40 per channel from every palette colour even at the dawn tint; too regular (straightness ≥0.80, mirror ≥0.90); nobody can make or mend one. Colour carries the split; edges only confirm it.
- **What reads as hand-made and worn:**
  - **Asymmetry**: one shoulder plated is salvage, both is issued kit.
  - **Marks, never areas**: a split, a nail, a 2-4 px wet patch. Rain streaks run **down** in columns, never speckle.
  - Dirt in the **bottom** corners; one rubbed-bright edge (bright everywhere reads as chrome).
  - Lime wash off in patches where roofs drip and boots scuff; turf banked against walls; plate patches weighted with stones.
  - Houses rebuilt from machine plate: old material stays where it held, plate goes where it failed.
- **Light rule.** Key light always comes from the **upper left** of the screen, and every sprite is drawn to it.
  - Shadows are a **colour** (blue-violet), not black.
  - Every ramp rotates: blue-violet dark → the ramp's own hue in the middle → warm highlight.
- **Signature wall marking.** A near-white enamel plate (`rime 5` #ddf0f7), with an `ink 0` border, two soft runs of
  `slate 2` ticks and four fixings, is **struck through by a hand-drawn line**.
  - The strike is 2 px thick, slightly off level, and runs 2 px past both edges.
  - It is the same mark as the refused docket the player carries, and it means "the machinery still counts this house".
  - It sits a third of the way along the wall, a little under half height, clear of the door.
- **Grid discipline.** Whatever a tile carries becomes the pattern.
  - Masses stay nearly flat; interest lives at edges and in rare features.
  - Large forms must come from world-position fields, never from per-tile noise.
  - Mean luminance should vary by no more than ~5 between tile variants, or the tiles read as a chequer.

## 2. Palettes (exact hex)

### 2a. The 16 coast ramps (index 0 = occlusion/outline … top = highlight)
| ramp | values | role |
|---|---|---|
| ink | #08070f #12111d #1e1c2e #2f2c45 #454263 | outline (ink0, never pure black), eyes, boot soles. Reserved |
| stone | #1b1f2b #2f3646 #4a5566 #6d7a8c #97a2b0 #c8cfd8 | worked stone, setts, paving, gravel, quay, clinker |
| brine | #0a1524 #10263f #1b3f60 #2b6389 #4392b0 #7fcbd8 | sea and sky. Water b2/b1, shallow b3, deep/tarn b1 |
| slate | #131a24 #232f3d #37485a #52667a #75899c #a3b4c4 | wet rock, cliff, scree, gull mantle, trousers |
| earth | #1a1220 #33231f #4f3627 #6f4d31 #997044 #c79c62 | timber, mud, rope, road; dirt e3, furrow/needles/peat e2, jetty |
| rust | #2a1018 #4a1d18 #6e3320 #9a4f28 #c47438 #e8a557 | rust, brick, tile; "the one warm thing in most frames" |
| moss | #10161f #1a2a24 #2c4430 #46693a #6d9247 #a3c25e | turf: grass m2/m3, marsh, cliff top |
| spruce | #0c1220 #152530 #1d3c41 #2a5a53 #42846a #7ab291 | conifers (colder and bluer than broadleaf), blackwater edge |
| sand | #221d26 #3b3238 #5c4d45 #85705a #ad9370 #d8c193 | shingle and dune (warm grey, not yellow); sand s4, strand s3 |
| linen | #2f2a2b #4c443f #6f6559 #968a76 #c0b394 #e8dcc0 | paper, lime wash, sailcloth; **limestone l4/l5**, saltpan |
| flesh | #33191b #5b2f28 #8c563a #b87f57 #e0aa7e | skin |
| copper | #33200a #5f3c10 #93601a #c78d2c #f0bb4e | brass, tin, **lamplight**, gull bill. Reserved |
| ash | #23262e #3b404a #5c626e #868d99 #b8bfc9 | smoke, fog, cloud, breath; **ashfall** a1/a2 |
| ember | #2a0d06 #5c1c08 #93330c #c85a15 #f5a52f #fff0c0 | the only emitter: lava e3/e4, vents, fire |
| rime | #131f2e #21384a #35586e #5d8ba0 #96c0d0 #ddf0f7 | ice and snow (snow r5/r4, ice r4); **glim light = rime5 over rime3** |
| bloom | #2b1430 #5e254c #a03d6c #d06f92 #eda3b8 #fbd2de | flowers only (thrift, heather), placed and seasonal |

`blend_ramp(a, b, t)` mixes two ramps so that trees in a wood vary in hue while staying on the palette.

### 2b. Ground by biome, as the dominant sampled tile colours
- **Coast.** Grass #2c4430/#46693a/#1a2a24. Heath #4f3627/#1a2a24 (earth plus moss). Sand #ad9370/#5c4d45. Dune #ad9370/#d8c193. Gravel/shingle #4a5566/#2f3646. Cliff #131a24/#232f3d. Quay #2f3646/#4a5566. Jetty #4f3627/#6f4d31. Furrow #4f3627/#6f4d31.
- **Pinewood.** Needles #4f3627/#33231f/#6f4d31. Pines in spruce #1d3c41→#42846a.
- **Moss (fen).** Marsh #2c4430/#1a2a24. Blackwater #0a1524 with spruce edges #152530/#1d3c41. Peat bank #33231f/#4f3627. Bog cotton #1a2a24 with #c0b394 tufts. Tarn #10263f.
- **Snowfield.** Snow #ddf0f7/#96c0d0 with #b8bfc9. Ice #96c0d0/#ddf0f7/#5d8ba0. Soot marks in the lee of drifts.
- **Burning.** Ashfall #3b404a/#5c626e/#23262e. Clinker #2f3646/#1b1f2b/#12111d. Lava #c85a15/#f5a52f/#5c1c08 in ink #08070f.
- **Bonelands.** Limestone #c0b394/#e8dcc0/#968a76 (pale bone). Scree #232f3d/#131a24. Bedrock #1b1f2b.

### 2c. Machine ("found") ramps, deliberately not in `palette.py`
- **Base `FOUND`:** #140a24 #2b1550 #4a1f8c #7433e0 #9d5cff #dcc4ff (hue 262). Body fill v3, lit rim and rubs v4, dark rim v2, cavity a v0/v1 checker, rivets and fasteners v5.
- **Per kind (values 0-5), along a violet arc** from cold/wet (indigo) to dry/burnt (magenta):
```
dredger   #0f0b27 #1f1657 #342199 #5136f5 #7b5bff #cec4ff   248.5
hauler    #100b25 #231651 #3b218e #5c36e3 #8b5fff #d3c5ff   253
cutter    #130927 #281257 #441999 #6a2af5 #9151ff #d6c0ff   259
lineman   #130a24 #291650 #46218c #6d36e0 #9c5fff #dac5ff   259.5
watcher   #150827 #2d1156 #4d1796 #7926f0 #a04eff #dbbfff   264.5
longlegs  #160b25 #2f1652 #51218f #8037e6 #ab5fff #dfc5ff   265
runner    #180b25 #351651 #5b218e #9036e3 #bb5fff #e5c5ff   271
warden    #180726 #340e55 #5a1294 #8d1fed #b447ff #e2bdff   272
clerk     #170821 #32114a #571881 #8927cf #b34deb #d5b2eb   275
sweeper   #1c0726 #3c0e54 #691293 #a51eeb #cb47ff #eabdff   279.5
harvester #1d0b25 #3f1753 #6e2291 #ad38e8 #d35fff #eec5ff   280
flock     #1f0328 #440658 #78029b #bd05f7 #d930ff #efb4ff   285.5
```
- **Working-part (cavity) colour, `LENS` amber:** #3a2a08 #8f6a12 #e8c23a #fff3c0. It is the only warm part of a machine
  and means **"soft side, hit here"**.
- **Plated face, `COLD` visor slit:** #16222e #27485c #4f8ca6 #b4dced. A scanning highlight on a shut face means
  **"armour, nothing to reach"**.
- **Outline:** always `ink 0`. The found colour belongs in the body, and ink marks the edge.
- **Weathered salvage plate on houses:** `FOUND` mixed 60% toward `slate`, giving ≈ #131424 #262545 #3f386e #6052a3
  #8577c4 #babadc (computed). A roof plate reads as "came off a machine" and can never be mistaken for a live one.
- **Constraints:**
  - body values must clear grass luminance under the night tint (≥48 for value 3 and ≥66 for value 4, measured at the tint);
  - adjacent machines must differ by ≥14 per channel;
  - a glim must never be violet, because the player's light must not share the predators' colour.

### 2d. People (`ramps.txt`)
- **Player base:** skin `flesh3` #b87f57, hair `sand2` #5c4d45, shirt `linen2` #6f6559, trousers `slate1` #232f3d, boots `earth1` #33231f.
- **Wearable ramps** (hair, shirt, trousers, boots): stone, brine, slate, earth, rust, moss, spruce, sand, linen, values 0-5. `ink` and `copper` are reserved, never recoloured.
- **Skin windows:** deep #1a1220 #33231f #4f3627 #6f4d31 #997044; brown #33191b #5b2f28 #8c563a #b87f57 #e0aa7e; tan #5b2f28 #8c563a #b87f57 #e0aa7e #d8c193; fair #8c563a #b87f57 #e0aa7e #d8c193 #e8dcc0.
- **Hair presets:** black (ink), dark (earth), red (rust), fair (sand), grey (ash), white (linen).
- **NPC skin** stays within 3 adjacent values. Identity is carried by **costume** (class, trade, age, weather), never by complexion.
- **Contrast bar:** skin to outer layer ≥25 luminance, outer to trousers ≥25, total spread ≥60.

### 2e. UI
- The player's own UI is a **hand-ruled notebook**: linen paper (#e8dcc0/#c0b394) in ink (#08070f/#1e1c2e), off-grid, corrections visible, pixel font `unspent_5x7`.
- Institutional surfaces use "transit authority" styling (heavy grid, thick rules, one accent, over-explained labels). UI is the quietest layer, visually and in sound (§7).

## 3. Machines (12). Sprite cell 32×48 px, feet at row 44; 1 row ≈ 4 cm; a person is ≈41 rows tall

Rules shared by all of them:
- **Silhouettes** are mirror-exact in the stand, odd widths about the centre. **Two faces only**: a **plate** (bevel, rivets, cold visor slit) and a **cavity** (dark recess with amber moving in it) on the weak side only (`front`/`back`/`left`/`right`).
- **Wear**: downward streaks, one seam with fasteners, bottom-corner dirt, a rubbed edge on big panels only. Legs only get dirtier.
- **States** per facing: walk ×8, attack ×4, hurt ×2, dead ×4, alert, back ×2, stand, breath. Hold telegraph, impact, still, alert, stand, breath. Hurt = the **light goes out** (no flinch). Attack = alert pose then **being nearer** (no lunge on errands). Back = withdraw still facing you. Walk: 1 px bob twice per stride, head-on sway, stance 62%.
- **Sprite-capped**: the 32 px cell compressed them (the bull note admits the same). The "3D" column is a recommended fiction scale in tiles (1 tile ≈ 1.3 m; person ≈ 1.35).

| machine | sprite w×h px | 3D size (u) | silhouette and readable features | weak side, working part |
|---|---|---|---|---|
| **watcher** (errand, stands) | head bar 13-15w×8; mast 3w; hub 15w×6; 31h | ~0.7w, 1.6-1.8 tall | **A cross on a tripod.** A hard vertical, the only cross-shaped thing in the game. Head width shows facing (end-on it is as wide as the mast). Three straight legs, 4 px apart. | FRONT: the optic in the head. Alert: rises 5 and puts **fins** out above and below the head. Dead: light dies, legs fold, the post stays standing. |
| **long-legs** (charge) | body 11-13w×7 at rows 17-24; legs 20 rows; 27h | body 1.2×0.9, 2.0+ tall | **A gantry.** A flat slab on four thin legs at its corners; **daylight under the body is the read** ("you see the legs first, over the dyke"). | BACK: the hub. Alert: stands 5 taller and splays. Dead: legs splay outward and the slab drops flat. |
| **harvester** (charge) | hull 21-23w×9; track 13-15w×6 with 3 road wheels; 18h | 2.6w×2.2l×1.2h | **A slab.** Wide, low and square, nearly the full cell width, on a continuous track. Intake bar with an amber comb across the front; lamp at the top corner. Hull pitches and yaws over the ground. | FRONT: the intake, which is also the dangerous end. Alert: intake drops 4. Hurt: lamp out, comb stops. Dead: settles, the row spills. |
| **cutter** (rush) | disc Ø15 (chamfered octagon); body 9-11w; chassis 19w; 33h | disc Ø1.1 on edge; 1.4 tall | **The only circle in the game.** A disc standing on edge, wider than the body, mounted above it, with 8 amber teeth. Compact upright body with six fanned legs. | BACK: the drive. Deaf while cutting. Alert: blade lifts 8. Dead: disc stops and the body sinks onto its spoil. |
| **hauler** (charge) | 2 boxes, 12-13w each ×9; hinge post; 6 wheels r2; ore load in `stone` on top; ~27l×15h | 2.4l×0.7w×0.7h | **A line.** Long, articulated in two segments that pivot. Load is never level. Head-on it is 11 px. | LEFT: the hinge, on one flank only (never mirror the open side). Alert: jacks up 6. Dead: hinge folds and the load tips out. |
| **warden** (dart, arrests) | head 15-17w×8; column 7-9w×15; 2 legs; 32h | 1.6 tall, head 0.9w | **A bollard that walks.** A solid column, a broad head, and a visor band at a man's chest height. Walks on two legs at one unhurried speed. | FRONT: head and band. Alert: squares up, band at full. Hurt: band goes out and nothing else moves. Dead: falls over and is still a column. |
| **sweeper** (errand) | deck 17-19w×7; hopper 9-11w×12; 2 wheels; brush strip at the foot; 25h | deck 1.0w, 0.9 tall | **A T.** Low deck with a tall hopper over the middle; the only silhouette with a corner. Small. The brush turns. | BACK. Alert: hopper lifts 6 ("comes over you, not after you"). Dead: hopper tips and everything spills. |
| **dredger** (rush) | hull 15-17w×11; skirt with jaw notch 7-9w; 6 legs half-drowned; brine waterline | 1.4w, hull 0.5 above water | **A low hull** with something moving underneath. Jaw is a notch in the **middle of the underside**, lined with amber. | FRONT: the jaw, which is mouth and weak point at once. Alert: heaves 5, jaw opens 3 wider. Dead: the fen closes over it. |
| **lineman** (rush) | body 13-15w×18; two 3 px arms up out of frame | body 0.7×0.8; arms 2-3 up to a span | **A staple.** Small body, both arms straight up on a pylon or span. Bright grips travel hand over hand. | FRONT. Alert: lets go and comes down (arms drop to 20). Dead: arms come down before the body. |
| **flock** (dart) | 9 bodies of 2 px on a jittered 3×3 grid, step 7; amber centre pixel | 20-60 shards ≈0.08u in a 1-3u cloud | **A scatter, never a formation.** Each body flies its own 1 px orbit. It has no ink ring. | NONE ("too small to plate"). Grounded by wind. Alert/hurt: closes up (step 4). |
| **runner** (rush) | body 9-11w, rows 20-37; satchel plate on back; 2 legs; 24h | 0.45w, 1.3 tall | **Almost a person, headless**, with a satchel where shoulders would be. A real stride in which every step is identical, with no weight shift. | BACK: the satchel. Alert: stops and squares up. Dead: goes down and the satchel falls open. |
| **clerk** (dart, files you) | lid 11-13w×7 on 2 long legs at the lid corners; stride 5 | lid 0.6×0.6×0.3; hip 0.6 → 1.2 | **An archway walking** (staple or croquet hoop), "all head, all legs". Walks stooped with the head down at hip height. | NONE. Alert: the **head comes up 9 rows on a neck that wasn't there**, the biggest silhouette change on the rung. Dead: legs go out sideways, head comes down last. |

**Where they live, and how far they can be heard.** `racket` is the distance in tiles at which the bed becomes audible:

| machine | country | ground | racket (tiles) |
|---|---|---|---|
| watcher | anywhere, rises | — | 18 |
| long-legs | open country | — | 20 |
| harvester | Coast | furrow, grass | 22 |
| cutter | Bonelands | limestone | 16 |
| hauler | Bonelands | stone, dirt, sand | 19 |
| warden | Pinewood, 20:00-05:00 | — | 9 |
| sweeper | Pinewood tracks, 05:00-11:00 | — | 13 |
| dredger | Moss | water | 14 |
| lineman | Snowfield, on a span | — | 11 |
| flock | Coast fields, daylight, calm | — | 12 |
| runner | roads, 06:00-13:00 | — | 10 |
| clerk | Burning | ash, clinker | none |

- Each country's pair is **one job split in half** (opposite approach, opposite weak side). Machines are **identical copies** ("off the same line"); animals vary by seed.
- `WorkingPart`: the glow is a world object, not a HUD marker. Facing away, it sits **behind** the body, dimmed (a spill over the shoulder). It reacts only to blows that land.

**Animals** (ink outline plus own-ramp rim):
- **Gull**: 14×12 lozenge; body `linen`, mantle `slate`, bill `copper` (heavy, hooked, red spot), legs `flesh`; black wingtip crosses above the tail.
- **Dog**: a **wedge** (tucked waist, deep chest, head above the back, tail a line), ~16 long × 14-16 tall; coats `earth2`/`ink2`/`ash1`/`ink3`/`earth1`/`ash2`, never `earth3` (road colour). **Sheep**: a **brick** (no waist or neck, head low, lumpy fleece outline). **Rat**: 12 px (upscaled), `earth`/`ash`/`slate`.
- **Bull**: a **barrel**, 29w×30h at full height and half length; rust-brown, pale face, horns, dewlap, hump, tufted tail, no daylight under the belly.
- **Fish**: only a fin, a submerged shadow and a swirl, drifting on period 3 against the swell's 4 so it reads alive. **Rough** (robber, press gang): a normal person.

## 4. People

- **Proportions** on 48 rows: headroom 3, head 9, neck 2, torso 13, legs 14, boots 5; widths head 9, chest 12, side 8, leg 6, shin 5, boot 8; arms hang **outside** the torso. Chunky, about **4.6 heads tall**, legs given the height because walks read from the legs.
- **Builds** (`dy` lowers the upper body): man (base); woman dy+1, chest −3, the only build with hips wider than shoulders; boy dy+7; heavy chest +4; slight dy+2, long torso and short legs; old dy+4, stoop 2; tall dy−1, short torso over long legs; stark dy−1, starved, narrow at every row, small head; squat dy+4, chest +5, short legs; bent dy+3, a big person folded, stoop 5. Each pair must differ by ≥3 px on some axis and ≥18% in silhouette.
- **Clothing axes** (`looks.json`): hair style (bald, bun, crop, long, tail, thin, unkempt); hat, each changing the silhouette (band, brim, cap, knit, scarf, sou'wester); coat (jerkin, long, oilskin); shirt cut (tucked, loose, smock); beard (chin, full, stache); rolled sleeves, apron, belt (copper buckle), shawl, neckerchief. Shirt, trousers, boots and hair each take one of the 9 wearable ramps at values 0-5.
- **Crowd rule.** Nobody has fewer than two of {build, hat, coat}, and no two people share all three. Everyone wears wool
  or canvas, except the paymaster, who wears pressed cloth.
- **Salvage off the machines.** One or two parts per person, never the full set, drawn in `slate`/`stone`/`copper`/`ink`
  plus `ember` for anything live. Each part is at least 2 px thick and moves with its limb.

| part | what it is |
|---|---|
| brace | strut down one shin, hinged at the knee |
| plate | slab tied over one shoulder |
| rig | chest webbing with a buckle |
| gauntlet | forearm sleeved in conduit |
| tally | plates swinging at the hip |
| aerial | whip off one shoulder with a live tip; breaks the silhouette |
| lens | dark-rimmed optic over one eye |
| mask | 5 px wrap over the mouth with a cheek canister |

- **No black keyline on people.** `_contour` lights the edge facing the upper left one step up its own ramp and the far
  edge one step down.
- **Animation**: 8-frame walk (contact, down, passing, up; head lands a frame late, shoulders counter-rotate, coat hem swings), plus swing, stand, breath (a posed 1 px settle, feet planted). Variants: carry, work (break/dig/fell/cut tool arc), rest (sit), hurt.

## 5. Terrain and props

- **Countries** come from two noise fields, warmth (cell 1800) and wetness (cell 1520): warm <0.388 → Snowfield if wet <0.47, else Pinewood; warm >0.6 and wet <0.49 → Burning; wet >0.665 → Moss; wet <0.418 → Bonelands; else Coast (~40% of land). A straight crossing is ~500-600 tiles.
- **Grounds** have grade variants g0/g2/g3 (thin → full) chosen by world position, with fringes N/E/S/W.
- **Marks the handover left on the ground** (the machine age washing up):

| country | grounds | covers and props |
|---|---|---|
| **Coast** | grass, heath (thin grade burnt), marsh, sand, strand, dune+marram, gravel/shingle, cliff/cliff_top, scree, rockpool, wrack, furrow, quay, jetty, slipway, steps, stream, bridge | Broadleaf trees (2 in 6 grown round an **iron hoop with cable**). Gorse (yellow flowers). Driftpiles (2 in 7 hold a **float and a coil of cable**). Mussel rock, whelks, samphire, drystone dykes, kiln. Shingle carries **sea glass** and **slag**; wrack carries fishing line; thin turf has rust in the soil. |
| **Pinewood** | needles (thin grades **swept into long curves** by something on its round) | Pines in spruce (tall, stacked tiers), resin pines, deadwood (1 in 3 carries a **crossarm with two clay insulators** and wire). |
| **Moss** | marsh, blackwater (sky band goes green at its edges), tarn, peat bank, bog cotton, crottle | Reedbeds (2 in 4 carry a **cable with its sheath split to the copper**). Peat banks (2 in 5 have a **pipe through the face with an ochre stain fan**). **Wisps** (cold light orbs). Oily film in marbled bands on wet hollows. |
| **Snowfield** | snow (**soot** in the lee of drifts), ice | Poles, pylons, **the stack** (the tallest thing, with a lamp blinking at night). |
| **Burning** | ashfall (leaves of **burnt ruled paper**), clinker (vitrified green-black glass pools, rust), lava (animated), brimstone | **Vents** (1 in 2 is a **flanged pipe**, bolted and steaming, lit 0.45). |
| **Bonelands** | limestone pavement (clints and grikes with **rows of drill holes**, split blocks), scree, bedrock | Standing stones (2 in 4 **cast, not quarried**: a leg with bent rebar and rust run, or a foot with cut bolts). Adits. Ore seams (tin, coal, iron). |
| **everywhere** | — | **Tips** (scrap heaps 8-20 tiles across; give scrap). **Glints** (a dram in a tip, 1 in 22,268 tiles). |

- **Decor** (flat, small): tuft, flowers, thistle, heather, tormentil, asphodel, lichen, moss, weed, stubble; stones, molehill, puddle, crack, slab, frost, cone; branch, mushroom, shells, bones, rope, ember, sulphur.
- **Village props:** well, post, lantern, net rack, pots, barrels, crates, buoys, mooring, washing line, woodpile, cart,
  market stall, upturned hull, smoke rack, loom, wheel, bench, table, hearth, firepit.
- **Buildings.** Each is one picture (never assembled from tiles). Base anchor is (128,240) on a 256² canvas. Silhouette
  reads first, then roof material, then walls:
  - **but** (5×4): a **machine housing lived in**. A violet-plate box with rounded shoulders, riveted seams and a bullnose
    lid; sods along the lid; a stone chimney stack; a burnt-through door and window; the original hatch barred from outside;
    a louvred vent; a junction box; rust bleeds from the rib.
  - **washed** (6×5): lime-washed rubble walls under a roof re-laid in weathered plate. Hipped roof, cable to a pole.
  - **slated** (7×5): gable end, rubble walls, half the slates, **the other half replaced in plate** course by course.
  - **long** (8×6): thatch **roped down with cable** and weighted with cast discs, built against the **foot of a lattice
    pylon** (violet lattice mast with cables).
  - **Details on all of them:** dark overhang under eaves, ridge lighter than eaves, turf at the foot, soft ground shadow;
    `copper`-framed windows over `brine` glass; the struck-through plate.
- **Landmarks:** stone circle 7×5 (leaning menhirs, fallen **cast pipe sections**, a cable); cairn 3×2 (one variant with a **lens eye** on top, one with a crane arm); wreck 7×3 (ribbed hull banded violet and rust, crane or cabin); broch 4×4 (drystone tower with a **lattice aerial mast**); boat 5×2 (earth-wood hull, one in plate).
- **Title vista.** Night sea, a headland village silhouette, an **evenly spaced line of pylons still carrying**, one lit
  lamp, a watcher on the point.

## 6. Lighting and weather

- **Clock.** 1 real second = 1 world minute (a 24-minute day). Dawn is at 06:00 (fade 1.5 h), dusk at 20:00 (fade 1 h),
  darkest light 0.62. The season is one 34-day autumn in which the light **drains** rather than cycles:
  r×(1+0.06·turn), g×(1−0.04·turn), b×(1−0.13·turn).
- **Sky tint** is a per-channel multiply, by day fraction `t`:

| t | colour (r, g, b) | level |
|---|---|---|
| <0.22 | Night (0.56, 0.64, 0.90) | 0.82 |
| 0.22-0.30 | ramps Night → Dawn (1.00, 0.84, 0.70) | → 0.86 |
| 0.30-0.40 | ramps Dawn → Noon (1, 1, 0.99) | → 1.0 |
| 0.40-0.70 | Noon | 1.0 |
| 0.70-0.80 | ramps Noon → Dusk (0.98, 0.74, 0.58) | → 0.80 |
| 0.80-0.90 | ramps Dusk → Night | → 0.82 |

  - Night is **blue, not black**.
  - Interiors ignore the sky and use (1, 0.95, 0.88)×0.92 ("somebody lit a lamp").
- **Regional light tint** (`Surface.Cast`, w and d = warmth and wetness scaled to −1..1): r = 1 + 0.075w − 0.03d, g = 1 − 0.02|w| + 0.015d, b = 1 − 0.085w − 0.045d, normalised so the max channel is 1 (hue only). Warm tilts to fire, cold to ice, wet to green, dry to bone.
- **Shade is a colour.** The per-tile light value v lerps the tint from cool (0.62, 0.74, 1.16) in dark to warm
  (1.07, 1.01, 0.88) in light. Nearby fire pushes it toward (1.75, 1.06, 0.52).
- **Fire glow** sources within d² ≤ 8 tiles: lava 1.0, door 0.72, vent 0.45, building 0.22.
- **Lamp.** Smoothstep falloff over the sight radius. Only a lamp (or a cave) emits; nobody glows.
  - The player's own light floor is 0.45.
  - NPCs are lit by their own tile, so at the edge of a lamp they read as shapes.
- **Cast shadows** are geometry, not paint: **one value** (a multiply by one ramp step, ≈ ×0.700, ×0.704, ×0.749, so ground texture stays visible inside); hard edge thresholded at alpha 0.5; a **shear** so the foot stays pinned; length 0.5× height at midday to a cap of 1.35× at day's ends; the sun **swings only 70°** about the upper-left key; at the horizon coverage **dissolves** 1 → ½ → 0 rather than fading; nothing casts at night; contact ellipses at the feet stay fixed.
- **Hillside relief.** `sunlit = gradient · sun`, read over ±4 tiles, gain 8.5, capped so the neighbour step stays ≤2%.
- **Weather is a multiply, never a white veil**, eased toward 1 by strength: rain (0.86, 0.89, 0.96), storm (0.70, 0.75, 0.88), fog (0.88, 0.91, 0.94) (a *bright* grey day), sand (0.94, 0.84, 0.68), snow (0.95, 0.97, 1.0), hail (0.84, 0.88, 0.95), heat (1.0, 0.96, 0.88).
  - Overlay alpha ceilings: sand 0.52, fog 0.50, snow 0.40, hail 0.36, storm 0.34, rain 0.26, heat 0.20.
  - Fog overlay: an `ash3` wash with 8-cell grain (`ash4` brighter, `ash2` darker) drifting 4 px a frame. Rain, snow, hail: many small marks at random positions on wrapping tiles, parallax layers that loop exactly. Lightning: 32×96 bolts, 3-frame flicker, screen goes pale, strikes biased to the tallest thing.
- **Timing**: a spell is 17 h with strength sin² over it; kind changes only at zero strength; wind is a scalar (bearing planned).
- **Planned, not built:** animated reeds and cable leaning in wind (per-tile phase); vents breathing and flickering; wisps
  as cold light; low-sun snow glints; dappled canopy shadow; the stack's night lamp; a **lens glint when a watcher sees you
  by eye**.

## 7. Audio direction

- **In one line:** "Machinery that nobody switched off, heard from a distance, over weather." It is not menacing; it is Tuesday.
- **Music style**: early-90s sample-based writing (Tanaka lineage), warm and harmonically strange. Not chiptune, orchestral or ambient drone. **No "mysterious tech" synth pads**, no sad piano.
- **Room tone** under every interior: 50/100/150 Hz hum with 0.06% drift, plus noise low-passed at 340 Hz.
- **Beds** are named after the thing making the sound, and they are placed by world conditions.
- **Machine beds are deliberately synthetic.** Everything alive or natural wanders (detuned partials, LFOs on
  non-aligned rates). Machines never wander: exact integer partials, no amplitude LFO, identical samples at exact
  intervals. **The contrast is the characterisation.** Every machine bed is an 8.0 s loop with event counts that
  divide 352,800 samples:

| clip | recipe |
|---|---|
| watcher | thin level note: partials 137.5/275/412.5/687.5/1100/1787.5 Hz (amplitudes .055/.10/.085/.055/.03/.014), plus a fixed inharmonic 1063 Hz "bearing", plus casing hiss 1.9-7 kHz |
| long-legs | 10 identical knocks at 0.8 s. Each knock is a plate ring at 196/541/1058/1750 Hz (≈1:2.76:5.40:8.93) plus a 132 Hz ground thump plus a click. Under it, a whir from noise at 340-2400 Hz and a 147 Hz hum. Near-silence between knocks |
| harvester | busy and dense: drive 156/312/468 Hz; cutting bar is noise at 1.7-7.5 kHz gated at 28 Hz; crop fall lags a quarter cycle; engine 112 pulses; reel 40 slaps |
| cutter | the only bright one: noise at 2.6-11 kHz gated at 14 Hz, rock fall at 0.5-3.2 kHz, drive 168 Hz |
| hauler | laden rumble (noise 190-1400 Hz plus 152 Hz); 56 identical **double** rail-joint knocks |
| warden | the quietest: 96 even, damped footfalls (178/402/905 Hz) over almost nothing |
| sweeper | the only machine with no transient: noise at 1.1-6.8 kHz swelling 7× (sine, not gate), plus deck grit and 174 Hz |
| dredger | the only wet one: water noise 240-2600 Hz; 8 identical slow hydraulic jaw closes (noise swell, soft knock, draining) |
| lineman | the highest: the **wire tone** 412.5/825/1237.5/1063 Hz, plus 32 bright alternating grips at 690/1490/2870 Hz, no body below 200 Hz |
| flock | no single source: noise at 1.4-7.6 kHz plus 0.9-2.6 kHz, 21 Hz tremolo, 3× swell, **nothing below 900 Hz, so wind masks it** (the audible mechanic) |
| runner | 84 identical light steps (232/540/1180 Hz) at 10.5 per second, plus a satchel knock every other step. It is uncanny because every step is the same |

- **Country beds**: **shore** (4 overlapping washes on a 5.4 s cycle, noise 260 Hz-2.4/5 kHz with sin³ envelope, shingle rattle above 4.2 kHz); **wind** (two noise bands on 0.041/0.017 Hz gust products); **pines** (canopy hiss 0.9-3.4 kHz, trunk band under 180 Hz, two far branch snaps); **moss** (still air under 420 Hz, seep, drips every 0.5-2.4 s); **snowfield** (quietest, thin hiss 2.2-5.2 kHz); **rift** (27.5/41/55 Hz note, 120-640 Hz roar, steam above 2.6 kHz, deep thuds); **bones** (wind 0.7-2.4 kHz plus grike bottle tones 146.8/220 Hz); **works_hum** (41.3 Hz shaft with harmonics to 371 Hz, air, belts, 1.15 s beat). Weather: storm, hail (and on a roof), snow, sandstorm, heat, fog, cave, thunder far/mid/near/close, gust, foghorn.
- **Living sound is placed, not played.** A gull needs shore, daylight, flyable weather and something to interest it; gulls
  are densest at low tide near villages. Near and far versions of one creature are matched on **loudness**, and distance is
  a timbre change (duller and wetter) before it is a level change.
- **Music**: 72 BPM, 10 tracks (title, home, rill, road, tern, saltmarket, ashgate, coldwater, works, room_tone). FM electric piano, marimba, Karplus-Strong pluck, flute, 5-voice strings, pad, bass, choir, bell; convolution reverb on a generated impulse response; humanised timing and velocity. **One four-note figure** is whole at home and loses harmony track by track up the coast; nobody mentions it. Music **ducks under dialogue and nothing else**.
- **Mix.** The reference level, 0 dB, is the weather bed at full strength:

| level | what sits there |
|---|---|
| +6…+10 dB | thunder only |
| −4…+5 dB | world events: steps, gathering, doors, gulls, eating |
| −2 dB | money |
| ≤−6 dB | interface |

  - Buses: sfx gain 0.75; beds 0.34×0.75 = 0.255 (9.4 dB apart).
  - `heard = rms(loudest 0.5 s) × bus × call_scale`.
  - A refusal is a *different* sound from an acceptance, never a louder one.
  - **Nothing carries its weight below 120 Hz** (laptop speakers). Judge on a laptop, not headphones.
  - Only the **loudest nearby machine** plays: `level = 0.45 + 0.55·(1 − d/racket)`.
  - Hearing takes no penalty from weather or dark: "you hear it before you see it".

### Godot procedural audio plan (GDScript)
- **Loops as `AudioStreamWAV`, not live generation.** Render each bed once in GDScript into a `PackedFloat32Array`, convert to 16-bit PCM, and play it through `AudioStreamPlayer`.
  - `AudioStreamWAV` settings: `format = FORMAT_16_BITS`, `loop_mode = LOOP_FORWARD`, `loop_end = n`.
  - Loop points are sample-exact, so the machine discipline survives.
  - Port `synth.py`: PolyBLEP saw and square, exponential envelopes, RBJ biquads, Karplus-Strong, FM EP and bell, and `RandomNumberGenerator` with fixed seeds (PCG32, deterministic).
- **Keep machine beds at 44,100 Hz.** Every source event count (7, 8, 32, 40, 56, 84, 96, 112, 168, 224) divides 352,800 = 2⁵·3²·5²·7².
  - At 48 kHz (384,000) the 7-based counts do not divide.
  - At 22,050 Hz, 32, 96 and 224 do not divide.
  - Godot resamples to the output rate on playback; the loop itself stays exact.
- **Periodic noise.** Run the IIR over three back-to-back copies of the noise and keep the last. This is cheaper in GDScript than the random-phase FFT `_loop_noise` uses. Other beds can use a 0.8-1 s crossfade.
- **`AudioStreamGenerator` only for what must track live state**, such as wind following `Sky.Wind`. Fill it with `push_buffer()` from `_process`, with `buffer_length` about 0.1 s.
- **Cost (an estimate, not measured).** One 8 s bed is 352,800 samples × several filtered layers, which is tens of millions of GDScript ops: seconds per bed on desktop, several times slower on web.
  - On desktop, render on `WorkerThreadPool`.
  - On web without threads, time-slice across frames.
  - Cache the bytes in `user://` (IndexedDB on web). Render per country on demand.
- **Buses** (`AudioServer`): Music (`AudioEffectCompressor` sidechained to Dialogue: ducks under dialogue and nothing else), SFX −2.5 dB (0.75), Ambience −11.9 dB (0.255), UI (≤ −6 dB vs the weather bed), Dialogue.
  - Machine bed: one `AudioStreamPlayer` with `volume_db = linear_to_db(0.45 + 0.55·(1 − d/racket))`, loudest machine only.
  - Use 2D players with computed volume. An ortho camera makes `AudioStreamPlayer3D` distance-to-camera meaningless.
  - Distance timbre: **pre-render near and far variants** (duller and wetter) rather than applying a live `AudioEffectLowPassFilter`.
- **UNSURE on web:**
  - Godot 4.3 added "sample" playback for web. As far as I know, in that mode bus effects (compressor sidechain, filters, reverb) and `AudioStreamGenerator` are not supported, and "stream" mode wants a threaded export (cross-origin isolation headers).
  - Check `audio/general/default_playback_type.web` and test ducking plus a generator on an actual web export before relying on either.
  - A pure `AudioStreamWAV` path with gains baked in is the safe fallback.

## 8. Translation to Godot 4.7 (GDScript, Compatibility renderer), orthographic low-poly 3D

**How far to trust this section.** My Godot knowledge is from the 4.2-4.4 era. Every "UNSURE" item below is a Compatibility-renderer (OpenGL ES 3 / WebGL 2) capability to verify in a spike scene on desktop **and** web before building on it. 4.7 may have closed some of these gaps.

**Scene layout (pixel look).**
- `SubViewportContainer` (`stretch = true`, `stretch_shrink = 3`, `texture_filter = NEAREST`) → `SubViewport` 640×360 (`msaa_3d`, `screen_space_aa`, `use_debanding` all off) → 3D world and `Camera3D`. 640×360 is the source's native size; ×3 = 1080p, ×2 = 720p. Integer scales only, letterbox the rest.
- Do **not** use `Viewport.scaling_3d_scale`. UNSURE: I believe Compatibility's only 3D scaling mode is bilinear, which blurs. Post-processing is a `canvas_item` shader on the container (or a `TextureRect` with a `ViewportTexture`); see "Post".

**Camera.**
- `Camera3D`, `projection = PROJECTION_ORTHOGONAL`, `keep_aspect = KEEP_HEIGHT`, `rotation_degrees = (-55…-60, 45, 0)`. Never rotated at runtime.
  - Yaw 45° shows two faces of a machine at once, so weak sides read from more places.
  - Pitch is steeper than isometric because the source is a steep oblique that shows wall fronts.
- Place the camera about 100 u back along its view axis, with `near` 0.05 and `far` 300, so tall props never clip.
- **`size = 11.25`** gives 20 tiles across the 640 px width, and a texel of 11.25/360 = **0.03125 u, exactly one source pixel per tile-plane texel**. Up to `size ≈ 14` (25 tiles wide) is acceptable.
- **Texel snapping** stops crawl (the known "pixel-art 3D camera" technique): express the follow target in the camera basis, round x and y to the texel, move the camera by the rounded amount, offset the container by the leftover fraction × `stretch_shrink` screen pixels, and render the SubViewport 2 texels oversize and crop. UNSURE how this interacts with physics interpolation; snap in `_process` after movement.

**Units.** 1 tile = 1 u ≈ 1.3 m; terrain height steps 0.25-0.5 u. Person ≈ 1.35 u, dog withers ≈ 0.5, bull ≈ 1.1; machines at the §3 "3D" scale; walls ≈ 1.3-1.7 u, ridges ≈ 2.5-3 u. Physics defaults assume metres, so scale gravity if it is ever used.

**Meshes (`SurfaceTool` → `ArrayMesh`).**
- Build every mesh in GDScript: `begin(PRIMITIVE_TRIANGLES)`, then `set_color()` with **the exact §2 hex looked up from a palette table** (never a computed colour), `set_normal()` per face for flat shading, `add_vertex()`, then `commit()`.
  - Alternative: call `generate_normals()` after `set_smooth_group(0xFFFFFFFF)` for flat normals. UNSURE of the exact flat-group value in 4.7; per-face normals set by hand are safe.
- Wear is per-face or per-vertex colour **steps to the neighbouring ramp value**:
  - **MADE:** hash-seeded vertex jitter of 3-8%, uneven bevels, 1-3° lean, no mirrored halves, sparse ±1 steps as marks; ragged strips for thatch and turf; separate jittered boxes for drystone.
  - **FOUND:** exact symmetry, crisp chamfers, straight members, centred odd features, rivet rows on seams, dark streak faces running **down** from openings, one bright rubbed edge on the biggest panel, dark lower corners, off-palette `FOUND_BY_KIND` colours.
- **Terrain:** merged `ArrayMesh` chunks of 32×32 tiles, one material, vertex colour taken from world-position fields (grade, relief, region) and never from per-tile noise. Keep adjacent-tile mean luminance within ~5.

**Material: the palette-step light model** (spatial shader, one shared material, per-object uniforms kept to a minimum).
- The source measured that one ramp step down ≈ a per-channel multiply of **(0.700, 0.704, 0.749)**, and that it keeps hue rotating toward blue-violet. So lighting is a **quantised multiply**, not a ramp lookup:

```glsl
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled; // UNSURE all honoured in Compat
global uniform vec3 step_down; // (0.700,0.704,0.749) display-space; see colour note
void fragment() { ALBEDO = COLOR.rgb; }
void light() {
  float ndl = dot(NORMAL, LIGHT);
  bool lit = ndl > 0.15 && ATTENUATION > 0.5;          // one hard shadow value, no penumbra
  vec3 m = lit ? vec3(1.0) : (ndl < -0.35 ? step_down * step_down : step_down);
  DIFFUSE_LIGHT += m * LIGHT_COLOR / PI;                 // LIGHT_COLOR carries energy*PI in Godot 4
}
```

- UNSURE: whether a custom `light()` and `ATTENUATION` (which includes the shadow map) behave identically in Compatibility's multi-pass lighting. Test it first.
  - Fallback: an `unshaded` shader doing N·L from a global light-direction uniform. That fallback **loses shadow-map access**.
- **Colour space (UNSURE, and it decides whether hexes are exact).** Godot's 3D pipeline is linear.
  - If Compatibility is also linear, convert palette colours with `Color.srgb_to_linear()` at mesh build, and use `step_down^2.2` ≈ (0.456, 0.462, 0.530) in the shader. The source's multiplies were display-space.
  - Build a swatch scene: 16 ramps at noon, lit faces only, screenshot on desktop and web, and assert that pixel hexes equal §2.
  - Environment: `tonemap_mode = LINEAR`, exposure 1, glow off, adjustments off.
- **Emission** (on-palette ends or deliberately off-palette): lava and vents (`ember` 3/4), glim core `rime5` #ddf0f7, working part `LENS` #e8c23a/#fff3c0, visor `COLD` #b4dced.
  - Add soft glow as a billboard quad with an `unshaded, blend_add` material; do not rely on Environment glow (UNSURE in Compatibility).
  - Hurt means emission is set to 0.
- **People get a rim, not an outline:** near the silhouette (view-space `abs(NORMAL.z) < 0.35`), divide by `step_down` where the normal points screen up-left (one step lighter) and multiply by it where it points down-right.

**Lights and shadows.**
- **One `DirectionalLight3D` only.** Compatibility lights are multi-pass, so every extra light re-draws what it touches. There are also per-object light limits (`rendering/limits/opengl/max_lights_per_object`).
- Direction from the camera basis: arriving from **screen upper left** at ~50° elevation, daily swing ±35° about that key (§6), shadow length capped at 0.5-1.35× height by limiting elevation, and a stepped dissolve (not a fade) at the horizon.
- Shadows: `shadow_enabled`, `directional_shadow_mode = ORTHOGONAL`, `directional_shadow_max_distance` fitted to the view (~40 u), atlas 2048 (or 4096), `shadow_blur` 0, hard filter. UNSURE whether Compatibility honours the soft-shadow filter settings (hard is what we want anyway). Tune `shadow_bias` and `shadow_normal_bias` against acne on flat low-poly faces.
- **Lamp and fire are shader terms, not `OmniLight3D`s.**
  - Globals: player position, lamp radius, and a `vec4` array of the nearest ≤16 fire sources (position and strength: lava 1.0, door 0.72, vent 0.45, house 0.22).
  - Apply a smoothstep lamp falloff and the fire lerp toward (1.75, 1.06, 0.52) in `fragment()` as a multiply on `ALBEDO`.
  - UNSURE: that global uniform arrays work in Compatibility on WebGL 2. Fall back to a per-chunk material uniform.

**Environment, weather, fog.**
- `WorldEnvironment`: background a solid colour, ambient light and reflected light off, SSAO/SSR/SDFGI off (they are Forward+ only anyway).
- **Weather and day are multiplies in the post shader, not fog.** Night, dawn, dusk, the season drain, weather, and the region `Cast` sampled at the player (slow enough for one value per screen) all happen there.
- `Environment.fog_enabled` is plain depth or exponential fog. Under an ortho camera it becomes a **screen-vertical gradient** over flat ground, not airlight. Use it, if at all, very lightly for Fog weather (`fog_light_color` `ash4` #b8bfc9, low density).
  - UNSURE which fog modes (depth, height, sun scatter) Compatibility exposes in 4.7.
  - Volumetric fog is Forward+ only.
- **Weather overlays** (rain, snow, hail marks; fog grain; sand) go in a **separate** low-res `SubViewport` or `TextureRect` layered over the world with `NEAREST` filtering.
  - Draw them with `CPUParticles2D` or a scrolling procedural `canvas_item` shader at the §6 alpha ceilings.
  - Keep them out of the palette snap so alpha does not band.
  - UNSURE: whether `GPUParticles2D` is reliable on Compatibility web. CPU particles are the safe choice.

**Outlines (`ink0` #08070f on machines, animals, props and buildings; none on people).**
- **Primary: an inverted hull**, which should work in Compatibility because it is only a second pass.
  - A `next_pass` spatial material with `render_mode unshaded, cull_front, shadows_disabled` pushes vertices out along a normal by **one texel** (`camera.size / 360` u) and outputs ink0.
  - Flat-shaded meshes split at hard edges and leave gaps at corners, so feed the hull **averaged normals**. Either use a separate outline `ArrayMesh` built with smoothed normals (safe, though it adds a draw), or store the averaged normal in `CUSTOM0` (UNSURE whether custom vertex channels work in Compatibility).
- **Optional: a depth-edge post pass** on a full-screen quad reading `hint_depth_texture`.
  - UNSURE if depth reads are reliable in Compatibility or WebGL 2.
  - `hint_normal_roughness_texture` is Forward+ only, so a normal-based edge is not available. Prototype only after the hull works.
- Buildings and props: the outline could be the own-ramp darkest value (a hull colour uniform per object) rather than ink0, at creases only.

**Props (`MultiMeshInstance3D`).**
- One `MultiMesh` per prop type **per terrain chunk**. A MultiMesh culls as a whole by its AABB, so a world-sized one never culls.
- Per-instance `use_colors` carries palette variation (e.g. `blend_ramp` mixes, from a table of exact colours); `use_custom_data` carries a wind phase (per-instance phase, so nothing moves in unison; animate only above the wind threshold).
- UNSURE: `INSTANCE_CUSTOM` support in Compatibility. Fall back to a phase hashed from the instance transform origin in the vertex shader.
- Decor, tufts, stones and rocks are instanced. Unique buildings and landmarks are single `MeshInstance3D`s.

**Post (`canvas_item` shader on the upscaled image).**
1. Optional **palette snap** through a 2D-strip LUT (32³ packed into a 1024×32 texture, `filter_nearest`). This is safer than `sampler3D`, which is UNSURE in WebGL export. Build it from palette ∪ `FOUND_BY_KIND` ∪ `LENS` ∪ `COLD` ∪ plate.
2. **× tint** = sky(t) × weather × season × region, all from §6, as global or material uniforms.
3. Composite weather overlays above.
- Start **without** the snap: exact vertex hexes × fixed step multiplies are already near-palette. Add the snap only if lighting drifts off palette.

**Readability gates to carry over.** Machine bodies clear grass luminance at the night tint (§2c). Black-mask silhouette test at gameplay zoom for all 12 (cross, gantry, slab, disc, line, bollard, T, hull, staple, scatter, headless figure, archway). Alert poses change the silhouette more than any walk pose. Test banding on snow, the palest ground.

**Animation.** Code-driven (a `Node3D` hierarchy of mesh parts, or `Skeleton3D` bones set from GDScript): stance 62%, bob twice per stride, head-on hip sway, straight machine legs pivoting at the hip. Machine gaits **perfectly regular**; people humanised, head a frame late. Hurt = emission off; dead = light first, then collapse, lingering ~30 game minutes. Step transforms at 30 Hz if that suits the pixel feel.

**Performance budget** (integrated laptop GPU, 60 fps, web included).
- ≤ 300 draw calls **including** the shadow pass and outline hulls. Compatibility has no automatic 3D batching, so merge static geometry per chunk and MultiMesh everything repeated.
- About 6-9 visible chunks at 45° yaw. ≤ 250k triangles on screen. Machines ≤ 2k triangles, people ≤ 800, houses ≤ 3k.
- One directional shadow map. No real-time omni or spot lights. No Forward+ effects.
- All textures (LUT, noise) are tiny `ImageTexture`s generated at startup.
- **Web payload UNSURE and probably over the source's 20 MB.** The Godot web template alone is tens of MB uncompressed (roughly 8-10 MB brotli in 4.x). A custom export template with unused modules disabled is the lever. Game content itself is code only.
- Threads: a non-threaded web export avoids cross-origin-isolation hosting but pushes audio rendering and chunk building onto the main thread. Time-slice both (see §7).
