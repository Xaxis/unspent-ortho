# CLAUDE.md — unspent-ortho

*UNSPENT*, rebuilt: a real-time action-survival game on a generated coast where
half-broken machines hunt the people still living in the gaps. Godot 4.7,
GDScript, orthographic 3D rendered at 640x360 and upscaled with nearest
filtering. The land is drawn by hand: washes, inked contours, hatched shade;
the machines are drawn by a ruler; and every screen the player reads is one
hacked slate made of machine parts (docs/ART.md §9). **`docs/VISION.md` is the destination** (the
machines' plan, 20+ procedurally composed landscape types across surface,
underground and orbital realms, a mecha sentinel per landscape, portals and time,
crafts, mended high tech). **`docs/ART.md` is the binding style bible. Nothing may
look like Minecraft or any voxel game; every landscape must be hauntingly beautiful
and detailed.**

`../unspent` is the old Unity attempt. Read it for mechanics numbers and art
direction (already distilled in `docs/research/`). **Never port its story, arcs,
dialogue or lore**: all fiction is being rewritten (see `docs/DESIGN.md` §Story).

## The loop (memorise this)

```sh
tools/check.sh                              # THE gate: 3 test shards + 4 real frames side by side. ~35 s. Run before every commit.
tools/test.sh [filter]                      # headless tests only (one process, ~45 s for all; filter by "file:method" substring)
tools/shot.sh shots/x.png [options]         # one real rendered frame, ~2 s
tools/shot.sh shots/g.png --scene=gallery [--filter=pine]   # every model, lit, on a plinth
tools/map.sh --seed=N                       # top-down map + villages + a tile inside each country and ecotone
tools/tour.sh tours/x.tour [boot options]   # play a scripted sequence through REAL input, frames per step
tools/canon.sh [--accept]                   # the canon frames beside the accepted set on ONE contact sheet: shots/canon/sheet.png
tools/audio.sh                              # bake every sound and draw its spectrogram (audio package)
tools/audio.sh --score [--land=ID|--cross=A,B]  # minutes of the evolving score per landscape -> shots/score/
tools/export.sh web|web-nothreads|mac|all   # export a build into build/<target>/ in seconds, print wasm/pck sizes (brotli, gzip)
tools/web.sh [--nothreads] [--no-export] [--quick]  # export, boot in headless Chromium, frames in shots/export/; fails on errors, blank or non-integer canvas, silence, lost saves
tools/check.sh --web                        # the gate plus both web builds in the browser (~2 min more)
godot --path .                              # play it (WASD, Shift run/dodge, Space swing, K dodge, E use, C make, I carry, M map, F lamp, Esc pause)
```

Shot and boot options live in `src/boot_options.gd` (its header lists every one).
The everyday ones: `--seed=N --size=N --at=X,Y --village=N --place=NAME --hour=H
--zoom=F --walk=DX,DY,SECS [--run] --frames=N --scale=N --scene=game|gallery|title
--stats --load=N --saves=DIR`; staging a moment: `--weather=KIND:S --lamp --spawn=K,K --act=NAME[:MS]
--give=ID:N --held=ID --build=STATION --put=KIND --use[=KIND] --hold=SECS
--screen=NAME --explore=N --parade=K --folk=N --fauna=KIND:N --look= --pose= --face=`.

**Tours** (`tours/*.tour`, commands in the header of `src/systems/98_tour.gd`) are
how a feature is proven reachable: walk there, press the real action, `await`
what a player would see, shoot it. A tour fails if an awaited thing never comes,
and saves a `FAILED-lineN` frame. The runner outlives the game it began in: when
that game gives way (to the title, or to a loaded game) it follows the next one, so
a tour can leave, `await title`, press a real key on the title (`key ACTION`),
`await game`, and hold two frames to each other (`same A B TOL [X,Y,W,H]`, a crop for
anything small). Other awaits: `saved`, `station:NAME` (in reach). Each tour saves under
`user://tool-saves/<tour name>`, clear of the player's saves and of other tours. The M1 proofs:

```sh
tools/tour.sh tours/core_loop.tour --give=driftwood:6,scrap:1       # gather, fire, make, fight, night, border
tools/tour.sh tours/countries.tour --seed=1 --hour=10.5 --weather=clear:0
tools/tour.sh tours/fight.tour --seed=1 --hour=11
tools/tour.sh tours/saves.tour --seed=1 --hour=10 --weather=clear:0 --give=driftwood:6,stone:4   # save, leave, continue, load: frames and fire match
tools/tour.sh tours/export.tour --seed=1 --hour=10 --weather=clear:0   # a game through the loading page
```

The M2.0 proofs (each tour's header carries its own options):

```sh
tools/tour.sh tours/landscape.tour --seed=7 --weather=clear:0   # what every landscape holds of what happened
tools/tour.sh tours/sky.tour --seed=1                           # each landscape's own weather and hour
tools/tour.sh tours/machines.tour --seed=1 --hour=22.5 --weather=clear:0   # state told by light, wear, a kill
tools/tour.sh tours/characters.tour --seed=1                    # the last people, dressed by land and trade
TOUR_TIMEOUT=900 tools/tour.sh tours/score.tour                 # the score's layers, heard
tools/tour.sh tours/slate.tour --scene=title                    # the slate wakes, and every app from its key
```

**Look at the pictures.** A green test says nothing about how the game looks. After
any visible change, shoot the affected place and Read the PNG. After any model
change, shoot the gallery. Judge beauty, not just correctness.

Never pipe a gate through `tail`/`head` in a way that hides its exit code. The
tools print their own summaries.

## Layout

| Path | What |
|---|---|
| `src/core/` | Pure rules and data: world data, queries, clock, RNG, body, inventory, crafting, weather. No nodes, no rendering. Headless-testable. |
| `src/core/worldgen/` | World generation stages (`WorldGen.generate` runs them): shape, countries, relief, water, settlements, access, surface, scatter, places. |
| `src/core/fight/`, `src/core/mobs/` | The fight simulation (`FightSim`, fixed 8 ms slices), blows, plate, grip, outcomes; mob state, senses, brains, spawner. |
| `src/core/survival/` | Taking from the world (`Takes`), stations, eating, sleeping, lamp oil, the strand laid by the spawn. |
| `src/content/` | Tunables and data tables as GDScript consts: `tuning`, `items`, `recipes`, `roster`. |
| `src/render/` | Terrain mesher, transitions, decor, world view (chunk streaming on a worker), camera, sky light, weather visuals, shaders, palette. |
| `src/models/` | Procedural meshes: `props/`, `machines/`, `people/`, `animals/`. Any script here with `static func gallery() -> Array` shows up in the gallery. |
| `src/actors/` | Nodes in the world: player, mobs, hit marks (`MobFx`). |
| `src/core/save/` | Saving: the registry (`SaveGame`), the core state (`SaveCore`), the file (`SaveFile`), slots and autosave rules. |
| `src/boot/` | The loading page (`BootPage`, `BootStages`), the hand-over of a made world (`BootWorld`), the one script that names the scenes (`BootScenes`), the web shell and the browser probe. |
| `src/systems/` | `NN_name.gd` game systems, loaded in order: 05 save, 10 sky, 12 landscape, 15 lights, 16 vents, 30 mobs, 35 folk, 36 parade, 37 fauna, 40 fight, 50/52 survival, 70 audio, 75 music, 90 ui, 98 tour. |
| `src/ui/` | The slate (docs/ART.md §9): one hacked tablet drawn in code (`UiSlate`), its apps (carrying, making, map, home, gear, machine reads, saves, title), the HUD as its edge overlay, the pixel font, scans; `SlateFeeds` lets other packages fill gear, reads and saves. |
| `src/audio/` | Procedural synthesis, the sound sheet, beds, machines, music, the mix. |
| `src/game.gd` | Wires one running game together from BootOptions. |
| `src/main.gd` | Entry point; boot scene selection through `BootPage`; `--shot` capture. |
| `tests/` | `tests/**/test_*.gd`, extend `TestCase`, methods `test_*`. Runner loads every `src` script too. |
| `tools/` | The loop above. Keep it small: a new tool must replace work you do every day. |
| `tours/` | Scripted real-input proofs (see Tours above). |
| `docs/` | `ART.md` (binding look), `DESIGN.md` (what the game is), `ROADMAP.md` (what's next), `research/`. |

## Conventions

- **Typed GDScript.** `untyped_declaration` is an error. Use `:=` or explicit types;
  type `for` loop variables over untyped arrays (`for r: int in [...]`).
- **Everything built in code.** No `.tscn` beyond `src/main.tscn`, no imported art
  or audio. Meshes via `MeshKit`, colours via `Palette`, sounds generated.
- **Colours are sRGB palette values straight into `ALBEDO`.** The Compatibility
  renderer does no linear→sRGB conversion; converting made everything black.
- **Two lit materials.** MADE geometry uses `src/render/world.gdshader` (hatched
  shade, paper, ragged ground blends, sway); FOUND geometry (machines, pylons,
  plate, glims) uses `src/render/found.gdshader` (clean, unhatched, glowing parts).
  Write the ink vertex channels through `MeshKit` state (`style`, `style2`,
  `style_blend`, `wash2`, `wash_blend`, `sway`, `sway_phase`). See docs/ART.md §2.
- **No grid on screen.** Terrain is contour terraces; never add per-tile colour or
  square geometry. Boxes only as parts that are chamfered, tapered or broken up.
- **Coordinates.** Tile space `Vector2(x, y)`, x east, y south; 3D is `Vector3(x, h, y)`.
  Level `l` is `l * WorldData.STEP` high. A body steps ±1 level; 2+ is a cliff.
  Rotation: a model faces +X at `rotation.y = 0`; set `rotation.y = -facing`.
- **Determinism.** No `randf()`. Positional: `Rng.hash01(seed, x, y, salt)`.
  Sequences: `Rng.make(seed, salt)`.
- **`class_name` must not shadow a native class** (`Sky` failed). New class names
  need the import cache refreshed; the tools do it automatically.
- **Game logic in `src/core` or in an actor's `drive/step` methods that take
  explicit inputs and delta**, so tests and bots can run them without devices.
- Comments say *why* and give the contract. No narration of what the next line does.

## Working in parallel

- One builder, one worktree, one branch, one **owned directory set** (named in its
  brief). Touch shared files (`game.gd`, `tuning.gd`, `project.godot`, `world_view.gd`)
  with the smallest possible additive edit, so merges stay mechanical.
- A branch is done when: `tools/check.sh` is green in its worktree, its own new
  shots were looked at, and the feature is **reachable from a normal game start**
  (or from `--scene=gallery` for models). Unreachable code is not a feature.
- Integration is sequential: merge, run `tools/check.sh`, look at the shots, next.

## Commits

Author is always the owner, set on the command itself:

```sh
git -c user.name=Xaxis -c user.email=william.neeley@gmail.com commit -F msgfile
```

No `Co-Authored-By`, no generated-by lines, no attribution of any kind. Messages
lead with why, in short sentences.

## Contracts between parallel work (change only with every user updated)

| Seam | File | Rule |
|---|---|---|
| Signal bus | `src/events.gd` (autoload `Events`) | sfx, message, hit, fight_ended, killed, took, made, time_skipped, screen_changed, saved. `sfx` takes any name: `src/audio/sound_names.gd` maps it (ALIAS table, `work_`/`build_`/`alert_`/`snatch_`/`step_` patterns); a new emit adds a line there, and a test fails on an unmapped literal. A built station emits `made(station, 1)`. |
| Systems | `src/systems/NN_name.gd` extends `GameSystem` | auto-loaded in name order (scripts compile on loader threads during world gen); never edit `game.gd` to add one |
| Player condition | `src/core/body.gd` | fight owns health/wind/grip; survival owns hunger/wet/load/lamp oil; the lamp action (15_lights) owns `lamp_lit`; UI only reads |
| The player's body | `Player.hero` / `Player.sim` | in a running game the fight body owns position and facing: anything that moves or turns the player sets `hero.pos`/`hero.facing` too (`Survival.face`, the tour's `at`) |
| Carrying | `src/core/inventory.gd`, `src/content/items.gd` | `held` is the tool and the weapon; `wear(id, uses)` wears an edge; `worn`/`wear_kit` for salvage kit |
| Making | `src/core/crafting.gd` | UI calls `Crafting.missing / why_not / make_in` and `Survival.stations_near / describe_target / eat / hold` directly (`UiLink`) |
| Figures | `src/models/figure_model.gd` | `FigureModel.create(kind)` loads `models/machines/<kind>.gd` (always FOUND, whatever material is passed) or `models/animals/<kind>.gd`; animal mobs use `AnimalModel.spawn(kind, mat, seed)` so none look alike. Poses stand walk alert windup strike hurt dead; `part_position()`, `set_part_lit`, `flare_part`, `set_hunting(on)` (the mob says when it is running you down; the eyes lock), `top_toward(up)` (the posed body's highest point, for a tell), `draw_calls()` (budget: a machine 6). A machine's built-in lamps blink `MachineModel.disposition` (&"indifferent" \| &"wary" \| &"observant" \| &"hostile"), which starts at its role and which the disposition system sets on a live mob's model. |
| People | `src/models/person_model.gd` | `play_action` (swing dodge hurt work downed carried), `set_held`, `set_look`; people draw after the outline pass (render priority 10) and are held by their rim, never inked. Looks dress by land and trade with `PersonLook.dress(spec, BiomeDef.hazards, trade, seed)` (gear, patches, gaunt), then `PersonLook.set_apart(look, taken, hazards, seed)` so no two in a village share a silhouette; a crowd sets `pose_hz = PersonModel.CROWD_HZ`, the player keeps 0; whoever places a figure sets `model.sun = game.sky.sun` (its shadow twin follows it) |
| Props | `src/models/prop_models.gd` | `PropModels.node(kind, variant, country)` (surface 1 is FOUND on found.gdshader: never set material_override); `glow_points(kind, variant, country)` says where a model's lights and flames are, in its own frame and colour (15_lights reads it: a pool for the kinds in its `SOURCES`, a glint and a wet-ground reflection for every other kind that declares one; `"blink": true` puts it on the machines' beat). A variant with no light returns none. Props turn by `-rot`. |
| Sky | `src/render/sky.gdshaderinc` | `sky_apply()` is the only place lit colour is tinted by time/weather/region. Lit shaders also use `sky_ink` (world), `sky_pool` for lamp and fire light (world, found, water, person), `sky_line` (outline) and `sky_shade`. FOUND shaders `#define SKY_FOUND` before the include (nothing settles on a machine). `sky_power()` is the machines' power, stuttering after lightning: FOUND emission (strips, beacons, lit parts on found.gdshader), pylon beacon glows, the working part's ring (`part_glow.gdshader`) and the glint list follow it. SkyLight is the ONLY writer of `sky_*`, `neon_*`, `glint_*` and `wind_strength`, once a frame; lights to mirror in wet ground go in `SkyLight.glints` (15_lights), never extra OmniLights. |
| World edits | `WorldData.depleted`, `WorldView.refresh_props(prop)` | taken props disappear from view and collision; `Survival.add_prop` puts a new one in the world |
| Mobs | any mob node | joins group `&"mobs"`, exposes `kind: StringName`, `pos: Vector2` (tile space), `alive: bool`, `hostile: bool` (false for pests like gulls; the slate hides its hints only near hostiles) and `aware: bool` (it has noticed the player: alerted, chasing or attacking; the score tenses for it) |
| Weather | `src/core/weather.gd` | `Weather.at(seed, minutes)`, `Weather.at_place(seed, minutes, country)`, `Weather.at_type(seed, minutes, type_id)` -> `{kind, strength, wind, mist}`, `Weather.settled(...)`; pure. Climates are per landscape type (`Weather.CLIMATES`, a new type adds a row); the sky reads `at_type`/`settled_type` for `BiomeRegistry.at(world, pos).id`, and `at_place` is the legacy Country door. A reader that does not know a kind reads `Weather.family(kind)` (drizzle is rain, whiteout blizzard, glare heat, dry_storm dust, haze fog). Survival (wetness), mobs, landscape sway and audio call it directly. |
| Boot options | `src/boot_options.gd` | packages may ADD options; never rename existing ones; keep the header list complete |
| Saving | `src/core/save/save_game.gd` | every system `SaveGame.register(key, save, load)` in its setup. `save` returns JSON-safe values (`SaveCodec` for INF, vectors, bytes); `load` gets them back through JSON (numbers as floats, keys as Strings: convert with `SaveCodec.to_int/to_vec2/to_counts`). A loaded game is applied in `GameSystem.started()` (after every setup, before the first frame) in registration order; 05_save registers the core state first (`SaveCore`: world edits, clock, player, body, inventory, survival, explored, weather). Keys nobody registers are carried forward. Slots: `SaveSlots` (0 autosave: sleep, a landscape first entered, 3 world hours, leaving; never mid-fight or under a page; 1-3 manual; `--load=N`, `--saves=DIR`); file: `SaveFile` (header and data each md5-checked; bump `VERSION`, add a `migrate` step). |
| Landscape types | `src/core/biome/` | `BiomeRegistry.at(world, pos) -> BiomeDef` (hazards, roster, sentinel, hatch, sound); never branch on Country in new code |
| Stealth and gear on the body | `src/core/body.gd` | `crouched`, `spoof_until`, `resist`, `pressure` |
| Transitions | `WorldData.country2`, `WorldData.blend` | worldgen writes (0.5 on the border, 0 by 12-24 tiles); `Transitions.fill` pulls the band in for renderers; there is no fallback for worlds without them |
| Score and soundscape | `src/audio/score_*.gd`, `src/systems/75_music.gd`, `src/audio/sound_mix.gd` | A landscape type's music is `ScoreLandscapes.SPECS[id]` (key, mode, rhythm, chords, timbres); a type without one gets a score composed from its id, and `BiomeDef.music_motif` may name another's. Installations (hum, grid pulse), wreckage (wind in metal), roofs (gutters) and canopy (rain on leaves) are prop kinds whose NAME has a whole word in `SoundMix.INSTALLATION_WORDS` (heard only within its `INSTALLATION_REACH`) / `WRECK_WORDS` / `SHELTER_WORDS` / `LEAF_WORDS`; strung wire (`WIRE_WORDS`: poles) only sings faintly in the wind. A sentinel joins group `&"sentinels"` exposing `pos`, `reach`, `alive`, `land`. Any system can answer a tour's `await WHAT` with `tour_seen(what) -> bool`. |
| Works and evidence | `src/core/worldgen/gen_works.gd`, `src/render/works_map.gd` | GenWorks records landmarks `{kind, pos, country, dir: Vector2, half: Vector2, mark: &cut\|&scorch\|&quarry\|&bores}`; `GenWorks.bearing(seed)` is the machines' survey bearing and `GenWorks.survey_sections(seed, size)` is pure. `WorksMap.bake(world)` hangs on `WorldView.works`, and any renderer or system (the map, audio, a spawner) may read it. What the ruin left is salvage: `Takes` gives plate from debris, cars and barricades and wood from fences and stumps. |
| The slate's apps | `src/ui/slate_feeds.gd` | `SlateFeeds.provide(&"loadout"\|&"reads", func(game) -> Dictionary)` fills gear and machine reads; `SlateFeeds.on_act(app, func(game, row_id) -> String)` says what confirming a row does (a leading `!` is a refusal). Shapes are in the file's header. Without a feed each app shows what the game already knows. The saves app is not a feed: it drives `05_save` (`save_to`, `load_from`) itself. |
| Starting a world | `src/boot/boot_page.gd`, `src/boot/boot_world.gd` | Anything that starts a world calls `BootWorld.world(seed, size)` and `BootWorld.view(world)`, never `WorldGen.generate` or a bare `WorldView`. A game or title for play opens through `BootPage.open_game(parent, options)` / `BootPage.open_title(parent, options)` so the loading page draws while it is made; shots and headless runs get `make_game` / `make_title`. `BootWorld.offer(world, view)` hands a world already on screen to the next scene. |
| Palette | `src/render/palette.gd` | MACHINE and FOUND ramps are cold, low-chroma violets with a compressed top: the amber `LENS` is the only saturated thing on a machine. `PLATE` sits near slate so a patched roof never reads as a live machine. |

Native-name trap: a static func on a `class_name` script must not share a name
with a `GDScript`/`Script` method (`is_tool`, `new`, `get_class`...): the call
resolves to the native one.
