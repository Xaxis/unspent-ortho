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
tools/deploy.sh [--prod] [--dir=DIR]        # export, put it on Vercel, and prove it runs THERE in a real browser
tools/export.sh web --config=playtest       # a build of a master configuration (configs/), stamped with it and the commit
godot --path .                              # play it (WASD, Shift run/dodge, Space swing, K dodge, E use, C make, I carry, M map, F lamp, Ctrl/Q crouch, Esc pause, ` dev mode)
```

**Dev mode** (`docs/DEV.md`, `src/dev/`) is the slate's service mode, in the
module's violet: `` ` `` (or home's dev row) opens it in any build whose
configuration allows it, the web included — warp, time, weather, body, things,
bodies, view, a readout (F3), clean pictures (F4) and notes (F2) that keep a frame,
the state and the `tools/shot.sh` line that stages the moment again (from source
they land in `shots/notes/`: Read them). On this machine it also edits the master
configurations in `configs/`, makes stamped builds, keeps a shelf of them, plays,
proves and deploys them, and runs the gate and any tour with the command its own
header gives, showing the frames. A shot or tour sees none of it unless given
`--dev[=PAGE[:ROW]]` or `--config=NAME`; `tours/dev.tour` is its proof.

**A run is never seen and never takes the keyboard.** A hundred shots and tours an
hour must not interrupt the person at the machine, so a tool run opens its window
**off the screen entirely** (`tools/_focus.sh` `focus_position`, far outside any
display — it renders identically there), unfocusable (`project.godot`,
`display/window/size/no_focus`), and `tools/_focus.sh` hands the keyboard back
within about a twentieth of a second, because macOS brings the app forward
whatever the window's flags say. Only a session a person means to play takes the
focus (`src/main.gd`: no `--shot`, no `--tour`). `UNSPENT_KEEP_FOCUS=1` puts a
tool run on screen and in front, to watch it play. The header of `tools/_focus.sh`
records the two tidier-looking approaches that do not work, so nobody spends the
afternoon on them again.

**Shipping it.** `github.com/Xaxis/unspent-ortho` (public) is the remote; commits
are the owner's, as everywhere else. `tools/deploy.sh` exports the threaded web
build, puts it on Vercel (project `unspent`, team `xaxis-projects`) and then loads
the deployed URL in a real browser to prove the host is serving it correctly —
the threaded build only starts on a cross-origin-isolated page, so the headers in
that script are load-bearing, not decoration. Each build is served from
`/b/<sha>/` with `/` redirecting to it, so every file can be cached forever and a
returning player can never run a new pack against an old engine.
`VERCEL_TOKEN` lives in `.env` (never committed) and in the repository's secrets,
with `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`. A push to main deploys a preview;
production — what `unspent.world` will serve — is a deliberate act: run the
deploy workflow by hand with `production`, or `tools/deploy.sh --prod`.

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
`user://tool-saves/<tour name>`, clear of the player's saves and of other tours.

**Every tour carries its own options in its header**, so `ls tours/` is the list
and the file itself says how to run it. Each wave adds its own. Run them all before
integrating a wave, and never delete or weaken a tour to make one pass.

**Look at the pictures.** A green test says nothing about how the game looks. After
any visible change, shoot the affected place and Read the PNG. After any model
change, shoot the gallery. Judge beauty, not just correctness.

Never pipe a gate through `tail`/`head` in a way that hides its exit code. The
tools print their own summaries.

## Layout

| Path | What |
|---|---|
| `src/core/` | Pure rules and data: world data, queries, clock, RNG, body, inventory, crafting, weather. No nodes, no rendering. Headless-testable. |
| `src/core/worldgen/` | World generation stages (`WorldGen.generate` runs them): shape, landscape layout, relief, water, settlements, access, surface, scatter, places. Every stage reads the registry; nothing here knows a landscape by name. |
| `src/content/biomes/` | One file per landscape type (docs/VISION.md §3). Adding a landscape is adding a file here. |
| `src/core/fight/`, `src/core/mobs/` | The fight simulation (`FightSim`, fixed 8 ms slices), blows, plate, grip, outcomes; mob state, senses, brains, spawner. |
| `src/core/disposition/`, `src/core/stealth/` | Roles in the machines' plan, what each body makes of the player, interference per plan network; noise, cover and `StealthQuery`, the one door every sense goes through. |
| `src/core/survival/` | Taking from the world (`Takes`), stations, eating, sleeping, lamp oil, the strand laid by the spawn. |
| `src/content/` | Tunables and data tables as GDScript consts: `tuning`, `items`, `recipes`, `roster`. |
| `src/render/` | Terrain mesher, transitions, decor, world view (chunk streaming on a worker), camera, sky light, weather visuals, shaders, palette. |
| `src/models/` | Procedural meshes: `props/`, `machines/`, `people/`, `animals/`. Any script here with `static func gallery() -> Array` shows up in the gallery. |
| `src/actors/` | Nodes in the world: player, mobs, hit marks (`MobFx`). |
| `src/core/save/` | Saving: the registry (`SaveGame`), the core state (`SaveCore`), the file (`SaveFile`), slots and autosave rules. |
| `src/dev/` | Dev mode (docs/DEV.md): who can reach it (`DevMode`), master configurations (`ConfigSchema`, `GameConfig`, `ConfigChoices`, `configs/*.json`), build stamps (`DevStamp`, `stamp_build.gd`), cheats, notes, the readout, background jobs and the shelf (`DevJobs`, `DevBuilds`), and its app on the slate (`UiDevScreen`, `pages/`). |
| `src/boot/` | The loading page (`BootPage`, `BootStages`), the hand-over of a made world (`BootWorld`), the one script that names the scenes (`BootScenes`), the web shell and the browser probe. |
| `src/systems/` | `NN_name.gd` game systems, loaded in order: 05 save, 10 sky, 12 landscape, 15 lights, 16 vents, 30 mobs, 35 folk, 36 parade, 37 fauna, 40 fight, 50/52 survival, 70 audio, 75 music, 90 ui, 94 dev, 98 tour. |
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

## Another session may be running right now

Assume you are not alone: waves run for hours, and the owner opens other sessions.
**Look before you touch anything shared:**

```sh
git worktree list                       # a worktree is someone's live desk
git branch --list 'a2/*' 'm2/*'         # branches a wave is writing to
pgrep -x godot | wc -l                  # runs in flight (a tour can take minutes)
sysctl -n vm.loadavg                    # 14 cores here: over ~20 means saturated
```

- **Never write in another session's worktree**, commit on its branch, or delete it.
  What is under `.claude/worktrees/` belongs to a builder that is probably mid-edit.
- **Never rebase, reset or force-push `main`**, and never rewrite pushed history.
  Merge, and only the branches of the wave you are integrating.
- **Do not kill stray `godot` processes.** One of them is likely another session's
  tour, and killing it fails a proof someone is waiting on.
- **Keep total builders across all sessions to about six.** Past saturation nobody
  goes faster and the clock-watching tests start lying. If the load is already high,
  wait rather than launch.
- **Wall-clock results lie under load.** Test budgets scale by
  `TestCase.machine_slack()` and tool timeouts by `tools/_slack.sh`; a timing failure
  while a wave runs must be re-run alone before it is believed.
- **A change under `tools/` does not reach a running wave**: every worktree holds
  its own copy, frozen when it branched. Patch the live worktrees too, or the fix
  only applies to the next wave.
- Untracked scratch a session drops into another worktree (an `override.cfg`, say)
  belongs in `.git/info/exclude` so it cannot end up in someone's commit.

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
| Signal bus | `src/events.gd` (autoload `Events`) | sfx, message, hint, hit, fight_ended, killed, took, made, time_skipped, screen_changed, saved. `hint(text, key)` is the teaching channel: said in its moment or dropped, never queued behind a fight's quiet the way `message` is, so no lesson arrives out of context. Because it is dropped, a lesson whose moment is "the fight is over" (a machine breaks off still near, still hushing the glass) must be held by whoever owns it until `Hud.can_teach()`, never emitted into the quiet, or it is lost for good. `sfx` takes any name: `src/audio/sound_names.gd` maps it (ALIAS table, `work_`/`build_`/`alert_`/`snatch_`/`step_` patterns); a new emit adds a line there, and a test fails on an unmapped literal. A built station emits `made(station, 1)`. |
| Systems | `src/systems/NN_name.gd` extends `GameSystem` | auto-loaded in name order (scripts compile on loader threads during world gen); never edit `game.gd` to add one |
| Player condition | `src/core/body.gd` | fight owns health/wind/grip; survival owns hunger/wet/load/lamp oil; the lamp action (15_lights) owns `lamp_lit`; UI only reads |
| The player's body | `Player.hero` / `Player.sim` | in a running game the fight body owns position and facing: anything that moves or turns the player sets `hero.pos`/`hero.facing` too (`Survival.face`, the tour's `at`) |
| Carrying | `src/core/inventory.gd`, `src/content/items.gd` | `held` is the tool and the weapon; `wear(id, uses)` wears an edge; `worn`/`wear_kit` for salvage kit |
| Making | `src/core/crafting.gd` | UI calls `Crafting.missing / why_not / make_in` and `Survival.stations_near / describe_target / eat / hold` directly (`UiLink`) |
| Figures | `src/models/figure_model.gd` | `FigureModel.create(kind)` loads `models/machines/<kind>.gd` (always FOUND, whatever material is passed) or `models/animals/<kind>.gd`; animal mobs use `AnimalModel.spawn(kind, mat, seed)` so none look alike. Poses stand walk alert windup strike hurt dead; `part_position()`, `set_part_lit`, `flare_part`, `set_hunting(on)` (the mob says when it is running you down; the eyes lock), `top_toward(up)` (the posed body's highest point, for a tell), `draw_calls()` (budget: a machine 6). A machine's built-in lamps blink `MachineModel.disposition` (&"indifferent" \| &"wary" \| &"observant" \| &"hostile"), which starts at its role and which the disposition system sets on a live mob's model. |
| People | `src/models/person_model.gd` | `play_action` (swing dodge hurt work downed carried), `set_held`, `set_look`; people draw after the outline pass (render priority 10) and are held by their rim, never inked. Looks dress by land and trade with `PersonLook.dress(spec, BiomeDef.hazards, trade, seed)` (gear, patches, gaunt), then `PersonLook.set_apart(look, taken, hazards, seed)` so no two in a village share a silhouette; a crowd sets `pose_hz = PersonModel.CROWD_HZ`, the player keeps 0; whoever places a figure sets `model.sun = game.sky.sun` (its shadow twin follows it) |
| Props | `src/models/prop_models.gd` | `PropModels.node(kind, variant, country)` (surface 1 is FOUND on found.gdshader: never set material_override); `glow_points(kind, variant, country)` says where a model's lights and flames are, in its own frame and colour (15_lights reads it: a pool for the kinds in its `SOURCES`, a glint and a wet-ground reflection for every other kind that declares one; `"blink": true` puts it on the machines' beat). A variant with no light returns none. Props turn by `-rot`. |
| Sky | `src/render/sky.gdshaderinc` | `sky_apply()` is the only place lit colour is tinted by time/weather/region. Lit shaders also use `sky_ink` (world), `sky_pool` for lamp and fire light (world, found, water, person), `sky_line` (outline) and `sky_shade`. FOUND shaders `#define SKY_FOUND` before the include (nothing settles on a machine). `sky_power()` is the machines' power, stuttering after lightning: FOUND emission (strips, beacons, lit parts on found.gdshader), pylon beacon glows, the working part's ring (`part_glow.gdshader`) and the glint list follow it. SkyLight is the ONLY writer of `sky_*`, `neon_*`, `glint_*` and `wind_strength`, once a frame; lights to mirror in wet ground go in `SkyLight.glints` (15_lights), never extra OmniLights. **`neon_grade.x` is a GAIN and it is one number for the whole frame**, so `neon_graded()` ends on a shoulder (`SKY_TOP_KNEE`, `SKY_TOP`) and `neon_skyglow()` answers to the same ceiling: nothing lit can reach the page, because a pale landscape seen from a dark one was being multiplied onto it and clipped white holds no wash, no shade band, no hatch and no ink. Below the knee nothing is touched. A machine's own light is emission and is NOT held: neon is meant to burn. `tests/render/test_page_ceiling.gd` reads the two numbers out of the shader. |
| World edits | `WorldData.depleted`, `WorldView.refresh_props(prop)` | taken props disappear from view and collision; `Survival.add_prop` puts a new one in the world |
| Mobs | any mob node | joins group `&"mobs"`, exposes `kind: StringName`, `pos: Vector2` (tile space), `alive: bool`, `hostile: bool` (false for pests like gulls; the slate hides its hints only near hostiles) and `aware: bool` (it has noticed the player: alerted, chasing or attacking; the score tenses for it) |
| Weather | `src/core/weather.gd` | `Weather.at(seed, minutes)`, `Weather.at_place(seed, minutes, country)`, `Weather.at_type(seed, minutes, type_id)` -> `{kind, strength, wind, mist}`, `Weather.settled(...)`; pure. A landscape's climate lives in its own file, not here: `BiomeDef.weather` (rows `[kind, weight, squall]` summing to 100) and `BiomeDef.mist`, read through `Weather.climate(type_id)`. The sky reads `at_type`/`settled_type` for `BiomeRegistry.at(world, pos).id`, and `at_place` is the legacy Country door. A reader that does not know a kind reads `Weather.family(kind)` (drizzle is rain, whiteout blizzard, glare heat, dry_storm dust, haze fog). Survival (wetness), mobs, landscape sway and audio call it directly. |
| Master configurations and dev mode | `src/dev/config_schema.gd`, `src/dev/game_config.gd`, `src/dev/dev_mode.gd` | A setting is ONE row in `ConfigSchema.ROWS` (id `group.name`, kind, default, when it applies: boot, new, live, build) and every reader asks `GameConfig.value(id)`; the defaults are the game as it is, so a run with no configuration is unchanged. A configuration file holds only what it changes over its `base`; `tests/dev/test_configs.gd` fails on a setting nobody declared or a value the content does not allow. A new game takes `GameConfig.fill_new_game(options)` (the title, main.gd, dev mode's play), never a loaded one, and never over an option named on the command line. Live rules are applied by 94_dev on `GameConfig.revision`. An exported build carries its configuration in `res://stamp/build.json` (`tools/export.sh`), trusted only in a template. `DevMode.reachable()` is the only question of whether dev mode shows: a tool run is `off` unless asked, a source run for a person never below `chord`, a build what its configuration says. Dev mode's app is added to the slate by 94_dev (`90_ui.add_app`) and opens beside a hostile; everything it keeps on a device lives under `DevMode.user_root()` (the test runner and the tools have their own). A game dev mode starts saves under `user://dev-saves/`. |
| Boot options | `src/boot_options.gd` | packages may ADD options; never rename existing ones; keep the header list complete |
| Saving | `src/core/save/save_game.gd` | every system `SaveGame.register(key, save, load)` in its setup. `save` returns JSON-safe values (`SaveCodec` for INF, vectors, bytes); `load` gets them back through JSON (numbers as floats, keys as Strings: convert with `SaveCodec.to_int/to_vec2/to_counts`). A loaded game is applied in `GameSystem.started()` (after every setup, before the first frame) in registration order; 05_save registers the core state first (`SaveCore`: world edits, clock, player, body, inventory, survival, explored, weather). Keys nobody registers are carried forward. Slots: `SaveSlots` (0 autosave: sleep, a landscape first entered, 3 world hours, leaving; never mid-fight or under a page; 1-3 manual; `--load=N`, `--saves=DIR`); file: `SaveFile` (header and data each md5-checked; bump `VERSION`, add a `migrate` / `migrate_header` step). **A save keeps only the seed and grows the world again, so every save carries `WorldStamp.current()`** — a digest of the registry's ordered type ids and the `BiomeDef` fields worldgen reads (`WorldStamp.TERRAIN`; the look, weather, hazards and roster are deliberately outside it, in `WorldStamp.LOOK`). A save whose stamp is not this build's is refused by name (code `&"elsewhere"`), because **adding a landscape moves every seed's island**. So: a landscape added, reordered, or retuned where worldgen reads it invalidates every save on disk, and that is intended — a field added to `BiomeDef` goes in one of the two lists or `tests/save/test_world_stamp.gd` fails. A worldgen stage that changes what a seed makes bumps `WorldStamp.GEN` by hand; `SaveCore.disagrees` is the second line that catches one that did not, once the world is grown. **A refused save is never half-opened**: that game applies nothing, takes no save of any kind (the autosave would write over the very slot just refused), remembers the slot in `SaveSlots.turned_away` so nothing offers it again, and hands back to the title, which says the whole reason on its glass. |
| Landscape types | `src/content/biomes/*.gd`, `src/core/biome/` | A landscape is ONE file: `static func make() -> BiomeDef` under `src/content/biomes/`, auto-discovered, sorted by `order`, given the index every tile carries. It declares where it lies (`anchors` for the journey, `temp_range`/`moist_range`/`adjacency` for a landscape placed by its climate), `share`, `relief`, border and ecotone reach, hatch, ground washes and marks, decor and tree tints, props and ore, `surface`/`scatter` recipes, sites, pools, villages, weather, hazards, roster, bed and motif. Readers ask `BiomeRegistry.at(world, pos)`, `.by_index(i)`, `.land_indices()`, `.count()`; never branch on `Country` (it is only names for the first seven slots) and never size an array by it. At most `BiomeRegistry.SLOTS` (16) types: border pairs pack two indices into a byte. `BiomeRegistry.mute_to(ids)` narrows the registry for a test. **The one place still hard-coded is what a landscape's OBJECTS are made of**: `src/models/props/{houses,remains,rocks,shore,works,trees,built}.gd` still `match` on `Country`, so a new landscape's houses, boulders, wrecks, signs and shore dressing fall back to the coast's until those files read the registry too (a landscape may already colour its trees and rock with `BiomeDef.tree_tints`/`rock_color`/`decor_tints`). Adding those fields is M2 wave B's; until then, expect a new landscape's village to be dressed as the coast's. |
| Regions | `WorldData.regions`, `WorldData.region_at(x, y)` | Every connected run of one landscape type is a place: `{id, type, index, tiles, centre, bounds}`, biggest first. One type may hold several. Sentinels, works networks, subarcs and saves key on `id`. A run smaller than `GenCountries.REGION_TILES` belongs to no region. |
| Stealth and gear on the body | `src/core/body.gd` | `crouched`, `spoof_until`, `resist`, `pressure` |
| Pressures | `src/core/hazards/hazards.gd`, `src/systems/52_hazards.gd` | `Hazards.felt(Place)` turns a landscape type's `BiomeDef.hazards` through the hour, weather, height, shelter and fire into raw strengths; `after_resist(raw, Body.resist)` is what the body carries, written to `Body.pressure` every half second. **`BiomeDef.hazards` is the authority**: the hour, the weather and the height only scale what a landscape declares, and what the hour adds on its own is capped under `BITE` (`NIGHT_MOST`), so night never presses a place that calls itself mild. Thresholds in order: `FELT` (a gauge and a cue), `BITE` (`Hazards.move_factor` slows the legs; Survival multiplies it in), `HARM` (a slow drain that stops at `HARM_FLOOR`). A cue's mark, sound and colour are `HazardCues`. A landscape may only declare a hazard in `Hazards.IDS` (sixteen: the twelve of VISION §6 plus glare, thirst, magnetism and collapse), and something wearable must answer every id any landscape declares — `tests/hazards` and `tests/gear` fail on either, so a new pressure is added to the model, the glyphs and the gear in one go. Answer a tour with `pressure`, `pressure_bites`, `answered`, `answered:ID` (that one pressure bit earlier and no longer does: a place that presses three ways at once, where the answers share a slot, can never be wholly answered), `sheltered` or a hazard id |
| Gear and abilities | `src/core/gear/`, `src/systems/54_gear.gd` | A wearable piece declares `slot`, `sockets`, `resist`, `ability` and `tier` in `Items.DEFS`; a module declares `module: true` and `fits`. `Loadout` records what is in each slot, `Gear.resist_total` writes `Body.resist`, `Gear.abilities_of` fits the `AbilityBook`. An `Ability` (id, action, cooldown, charges, wind, press/hold/passive) never touches a node: it sets `ctx.motion` (an `AbilityMotion`, the ONE thing that may put the body where walking could not) and calls `ctx.draw`, and 54_gear runs both. `--fit=ID,ID` wears gear at boot. Answer a tour with `ability:ID`, `gliding`, `resisting`, `spoofed` (the signet fired) or `unnoticed` (a machine within reach has not read you: the spoof proved, not asserted) |
| Noticing the player | `src/core/stealth/stealth_query.gd` | `StealthQuery` is the ONLY door: `Senses.notices/sees/hears` delegate to it, and it adds crouch, cover (`Cover.at`), the lamp, a spoofed signature and the body's own cone (`facing`, omitted = no cone). How loud the player is rides on `Moment.loudness` (`StealthNoise.loudness`), which is the whole of what shortens hearing; the stealth fields on a Moment (`crouched`, `cover`, `spoofed`, `loudness`, `interference`) are written once a frame by 32_disposition. A noise event is `FightSim.make_noise(at, radius)`. |
| Roles and disposition | `src/core/disposition/` | A roster row's `role` (`Roles`: worker keeper watcher hunter recycler) decides its default disposition, its sight cone and what turns it (`Roles.TURNS`). A live body's `disposition` is `Disposition.of(role, interference level, disturbed)`, written onto `MobState` and its `MachineModel` by 32_disposition. `FightSim.disturb(mob, cause)` is how another package turns one (causes: blocked damaged theft trespass curfew downed); a role that does not take that cause amiss works on, though a blow still makes anything stop and deal with it. All three rungs are real: `MobState.at_work()` is a body still on its round, `indifferent()` one that is calm, `watchful()` (`wary`) one that keeps its round but looks up four times as often, never lets its suspicion settle, lets nobody inside 0.45 of what it can see, and forgets a lost player twice as fast. `MobState.suspicion` 0..1 is how sure it is, drawn on the body (Mob: the working part catches, the alert snaps at 1), never as text. |
| Interference | `src/core/disposition/interference.gd` | One 0..1 per plan network (`Interference.network(world, pos)`: the REGION a tile stands in, so two runs of one landscape keep separate files), raised by `32_disposition.raise(cause, at)` and lowered by time, distance, hiding, nothing being aware of the player, and `Body.spoof_until`. Every cause has a producer in play: theft and sabotage (hands on the plan's works, a blow struck on a machine at its work), killed_worker/killed_machine (`Events.killed`, except a body the network itself sent), filed (`Body.filed`), curfew and trespass (a keeper's hours and site), blocked (held up on its round) — a body that turns reports what it took amiss through `_turned`, so a new `Roles.TURNS` cause reaches the network without new wiring. Levels calm/wary/hostile/hunted change every machine in the region; at hunted the network sends hunters, at most two out at once, and what it sent and lost it does not file. Saved under key `disposition`. |
| Transitions | `WorldData.country2`, `WorldData.blend` | worldgen writes (0.5 on the border, 0 by 12-24 tiles); `Transitions.fill` pulls the band in for renderers; there is no fallback for worlds without them |
| Score and soundscape | `src/audio/score_*.gd`, `src/systems/75_music.gd`, `src/audio/sound_mix.gd` | A landscape type's music is `ScoreLandscapes.SPECS[id]` (key, mode, rhythm, chords, timbres); a type without one gets a score composed from its id, whose key is chosen to stand in the same tonal web (`ScoreLandscapes.affinity`, which also sets how wide an ecotone's crossfade is), and `BiomeDef.music_motif` may name another's. Landscapes crossfade with equal power on `WorldData.country2`/`blend`, read through `SoundMix.land_share` (what the ear is in) and `SoundMix.land_soon` (what it is walking toward, so the next landscape's core is baked before its border), both keyed by the registry's type index; a landscape is only crossfaded into as far as its core stems are baked (`ScoreConductor.core_keys`), so nothing that moves a player faster than the bake — a portal, fast travel — can make the score fall silent. Installations (hum, grid pulse), wreckage (wind in metal), roofs (gutters) and canopy (rain on leaves) are prop kinds whose NAME has a whole word in `SoundMix.INSTALLATION_WORDS` (heard only within its `INSTALLATION_REACH`) / `WRECK_WORDS` / `SHELTER_WORDS` / `LEAF_WORDS`; strung wire (`WIRE_WORDS`: poles) only sings faintly in the wind. A sentinel joins group `&"sentinels"` exposing `pos`, `reach`, `alive`, `land`. Any system can answer a tour's `await WHAT` with `tour_seen(what) -> bool`. |
| Works and evidence | `src/core/worldgen/gen_works.gd`, `src/render/works_map.gd` | GenWorks records landmarks `{kind, pos, country, dir: Vector2, half: Vector2, mark: &cut\|&scorch\|&quarry\|&bores}`; `GenWorks.bearing(seed)` is the machines' survey bearing and `GenWorks.survey_sections(seed, size)` is pure. `WorksMap.bake(world)` hangs on `WorldView.works`, and any renderer or system (the map, audio, a spawner) may read it. What the ruin left is salvage: `Takes` gives plate from debris, cars and barricades and wood from fences and stumps. |
| The slate's apps | `src/ui/slate_feeds.gd` | `SlateFeeds.provide(&"loadout"\|&"reads", func(game) -> Dictionary)` fills gear and machine reads; `SlateFeeds.on_act(app, func(game, row_id) -> String)` says what confirming a row does (a leading `!` is a refusal). Shapes are in the file's header. Without a feed each app shows what the game already knows and never a dead screen: gear says what would fit each empty slot and what this landscape presses a body with, and machine reads reads the ground (the works the machines left, and the bearing they surveyed along). The saves app is not a feed: it drives `05_save` (`save_to`, `load_from`) itself. |
| Starting a world | `src/boot/boot_page.gd`, `src/boot/boot_world.gd` | Anything that starts a world calls `BootWorld.world(seed, size)` and `BootWorld.view(world)`, never `WorldGen.generate` or a bare `WorldView`. A game or title for play opens through `BootPage.open_game(parent, options)` / `BootPage.open_title(parent, options)` so the loading page draws while it is made; shots and headless runs get `make_game` / `make_title`. `BootWorld.offer(world, view)` hands a world already on screen to the next scene. |
| Settlements | `src/core/settlement/`, `src/systems/46_settlements.gd` | The seam between building and being raided (docs/VISION.md §9), so neither package imports the other. `Settlement` holds `pieces` (`Structure`: kind, pos, health, powered, staffed_by, ruined), `people`, `stores` and `attention`; `signature()` is what a machine can sense (light, noise, smoke, radio, power, found_tech, traffic), each channel taking the loudest piece, less whatever hides it (`StructureKind.SIGNS`, `"mask"`). The settlement package builds, staffs, produces and repairs and OWNS the signs table; the raids package reads `signature()`, writes `attention`, and calls `damage_structure`. Events: `settlement_founded`, `structure_built/damaged/destroyed` (settlement), `settlement_noticed`, `attention_changed`, `raid_warned/began/ended` (raids). |
| Palette | `src/render/palette.gd` | The MACHINE ramps run one arc by ROLE, cold to warm, all inside the violet band (hue 240-336): cold indigo filers and observers, deep indigo keepers, violet workers, burnt magenta hunters. Low chroma, compressed top, and the body fill (step 3) sits BELOW the turf in value, so the amber `LENS` stays the only saturated thing on a machine and a machine is a dark mass by day. No kind meets another kind or any `PLATE` step, so a patched roof never reads as a live machine. It is a solved packing: retune a kind's hue, chroma and fill together and re-run `tests/models/test_machines_ramps.gd`. The machines' own light — a strip, a beacon, a working part — is written once in `src/models/props/works.gd` (`STRIP`, `BEACON`, `WORKING`) and read by the geometry, the pool, the glint and the fog shaft alike. |

Native-name trap: a static func on a `class_name` script must not share a name
with a `GDScript`/`Script` method (`is_tool`, `new`, `get_class`...): the call
resolves to the native one.
