# CLAUDE.md — unspent-ortho

*UNSPENT*, rebuilt: a real-time action-survival game on a generated coast where
half-broken machines hunt the people still living in the gaps. Godot 4.7,
GDScript, orthographic 3D rendered at 640x360 and upscaled with nearest
filtering, drawn as a living field notebook: washes, inked contours, hatched
shade, and machines drawn by a ruler. **`docs/ART.md` is the binding style bible.
Nothing may look like Minecraft or any voxel game.**

`../unspent` is the old Unity attempt. Read it for mechanics numbers and art
direction (already distilled in `docs/research/`). **Never port its story, arcs,
dialogue or lore**: all fiction is being rewritten (see `docs/DESIGN.md` §Story).

## The loop (memorise this)

```sh
tools/check.sh                              # THE gate: tests + 4 real frames. ~11 s. Run before every commit.
tools/test.sh [filter]                      # headless tests only, ~5 s
tools/shot.sh shots/x.png [options]         # one real rendered frame, ~2 s
tools/shot.sh shots/g.png --scene=gallery [--filter=pine]   # every model, lit, on a plinth
tools/map.sh --seed=N                       # top-down map + villages + a tile inside each country
tools/tour.sh tours/x.tour [boot options]   # play a scripted sequence through REAL input, frames per step
godot --path .                              # play it (WASD, Shift run, Space swing, K dodge, E use)
```

Shot options (`src/boot_options.gd`): `--seed=N --size=N --at=X,Y --village=N
--hour=H --zoom=F --walk=DX,DY,SECS [--run] --frames=N --scale=N --scene=game|gallery`.

**Tours** (`tours/*.tour`, format in `src/systems/98_tour.gd`) are how a feature is
proven reachable: walk there, press the real action, shoot what happened.

**Look at the pictures.** A green test says nothing about how the game looks. After
any visible change, shoot the affected place and Read the PNG. After any model
change, shoot the gallery. Judge beauty, not just correctness.

Never pipe a gate through `tail`/`head` in a way that hides its exit code. The
tools print their own summaries.

## Layout

| Path | What |
|---|---|
| `src/core/` | Pure rules and data: world gen, world data, queries, clock, RNG. No nodes, no rendering. Headless-testable. |
| `src/content/` | Tunables and data tables as GDScript consts (one copy, parser-checked). |
| `src/render/` | Everything that draws the world: terrain mesher, world view (chunk streaming), camera, sky/light, shaders, palette. |
| `src/models/` | Procedural meshes for props, people, machines, animals. Any script here with `static func gallery() -> Array` shows up in the gallery. |
| `src/actors/` | Nodes that live in the world: player, mobs. |
| `src/ui/` | HUD and screens (CanvasLayer, 640x360 pixel space). |
| `src/audio/` | Procedural audio generation and mixing. |
| `src/game.gd` | Wires one running game together from BootOptions. |
| `src/main.gd` | Entry point; boot scene selection; `--shot` capture. |
| `tests/` | `tests/**/test_*.gd`, extend `TestCase`, methods `test_*`. Runner loads every `src` script too. |
| `tools/` | The loop above. Keep it small: a new tool must replace work you do every day. |
| `docs/` | `DESIGN.md` (what the game is), `ROADMAP.md` (what's next), `research/` (distilled from the old repo). |

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
| Signal bus | `src/events.gd` (autoload `Events`) | sfx, message, hit, fight_ended, killed, took, made, time_skipped, screen_changed |
| Systems | `src/systems/NN_name.gd` extends `GameSystem` | auto-loaded in name order; never edit `game.gd` to add one |
| Player condition | `src/core/body.gd` | fight owns health/wind/grip; survival owns hunger/wet/load; UI reads |
| Carrying | `src/core/inventory.gd`, `src/content/items.gd` | `held` is the tool and the weapon |
| Making | `src/core/crafting.gd` | UI calls only its static functions |
| Figures | `src/models/figure_model.gd` | `FigureModel.create(kind)` loads `models/machines/<kind>.gd` or `models/animals/<kind>.gd` |
| People | `src/models/person_model.gd` | `play_action`, `set_held`, `set_look` |
| Sky | `src/render/sky.gdshaderinc` | `sky_apply()` is the only place lit colour is tinted by time/weather/region |
| World edits | `WorldData.depleted`, `WorldView.refresh_props(prop)` | taken props disappear from view and collision |
| Mobs | any mob node | joins group `&"mobs"`, exposes `kind: StringName`, `pos: Vector2` (tile space), `alive: bool` |
| Weather | `src/core/weather.gd` | `Weather.at(seed, minutes) -> {kind, strength, wind}`, pure; others check `ResourceLoader.exists` until it lands |
| Boot options | `src/boot_options.gd` | packages may ADD options (e.g. `--spawn=`, `--weather=`, `--screen=`, `--give=`); never rename existing ones |
| Transitions | `WorldData.country2`, `WorldData.blend` | worldgen writes, renderers blend |

Native-name trap: a static func on a `class_name` script must not share a name
with a `GDScript`/`Script` method (`is_tool`, `new`, `get_class`...): the call
resolves to the native one.
