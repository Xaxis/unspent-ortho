# UNSPENT — dev mode

Dev mode is the slate's service mode: the stolen display module's own debug
menu, hacked open. It serves three jobs, and they are one feature because they
share one idea — **a moment of the game, a configuration of the game and a
build of the game are all things you can name, keep, send and get back**.

1. **Feedback and testing** in any build it is allowed in, the web included:
   warp, time, weather, body, give, spawn, a readout, clean pictures, and notes
   that capture a frame, the state and the exact command that stages it again.
2. **Master configurations**: named files that say what a build of the game is —
   its channel and version, whether dev mode is reachable, the island a new game
   starts on, what the player starts with, the rules it runs by, and what a build
   of it is made for.
3. **Builds** made from a configuration, on the owner's machine only: exported,
   stamped with the configuration and commit, kept on a shelf, played, proven in
   a browser, and put on the internet as a preview or as production.

## Where dev mode is reachable

`dev.access` in the configuration a build was made from decides it:

| access | what a player sees |
|---|---|
| `open`  | a **dev** row on home and on the title; `` ` `` opens the dev app |
| `chord` | nothing, until `` ` `` is struck three times inside 1.5 s; then as open, remembered on that device |
| `off`   | nothing; the chord does nothing |

- **An export with no configuration is `off`**, and its stamp calls itself a
  release (nothing on its title). `tools/deploy.sh` exports without one, so
  production never carries dev mode unless a configuration says so.
- **A shipped build ignores `--dev` and `--config`** unless its own stamp lets dev
  mode in at all, so a release app cannot be argued into opening it.
- **A source run for a person** (`godot --path .`) is the owner at their own
  machine: at least `chord`, whatever configuration is active, so choosing
  `release` to try it can never lock the owner out.
- **Tool runs** (`--shot`, `--tour`, the test runner) never read the owner's
  persisted choices and are `off` unless given `--dev` or `--config=NAME`. Every
  shot, tour and canon frame is unchanged by dev mode existing.

What is **local** (the machine the game is built on): a run from source
(`OS.has_feature("editor_runtime")`), not on the web, with `tools/export.sh` on
disk beside it. Only there: making builds, the shelf, deploying, running the gate
and tours, and writing configurations into `configs/`. Everywhere else those
pages are listed, faded, and say why when chosen (the menu standard).

## Master configurations

`configs/<name>.json`, checked in. A configuration holds only what it changes;
every setting has a default in `ConfigSchema`, and `base` names a configuration
it builds on (`release` is `playtest` with dev mode off and a release channel).

```json
{ "base": "playtest", "settings": { "build.channel": "release", "dev.access": "off" } }
```

| group | settings | applied |
|---|---|---|
| build | label, channel (dev, playtest, release), version | stamped into builds; shown on the title of a non-release build |
| dev | access | at boot |
| world | first island (and whether it is the only one the title offers), size, hour, where a new game starts, weather and its strength | a new game |
| start | kit (items), gear fitted, lamp lit | a new game |
| rules | clock rate, harm taken, hunger pace, how many bodies come, whether they come at all, the first hour's guide | the running game, live |
| builds | targets (web, web without threads, mac), template (release, debug) | what "make it" makes |

Readers ask `GameConfig.value(id)`. A new setting is a row in `ConfigSchema`
plus the one line that reads it; `tests/dev/test_configs.gd` fails on a
configuration that names a setting nobody declared or a value out of range.

Which configuration is active: `--config=NAME`, else (exported) the build's
stamp, else (a source run for a person) the one last chosen in dev mode, else
none (every default). In a build, dev mode may change settings for the session;
the build's own stamp is never rewritten. Changes kept in a build go to
`user://dev/configs/` and can be copied out as JSON and pasted in at the
owner's machine.

A game started from dev mode (play a configuration, restage a note) keeps its
saves in `user://dev-saves/<config>`, apart from the player's, until the title
comes back (a tool run's go under `user://tool-saves/` with its other saves).

## Builds

`tools/export.sh TARGET --config=NAME [--debug]` resolves the configuration
(`src/dev/stamp_build.gd`, headless), writes it with the commit, time, target and
template to `res://stamp/build.json` for the export to pack, exports, removes the
stamp, and writes the same record with sizes to `build/<target>/build.json`. A
build without `--config` is stamped too, with no configuration. The running
game trusts a stamp only when it is an exported template.

The shelf is `build/web`, `build/web-nothreads`, `build/mac` (what `tools/web.sh`
and `tools/deploy.sh` use) and `build/kept/<id>/<target>` (builds set aside).
From a build on the shelf: **play** (mac: the app; web: served with the
cross-origin headers by `tools/web/web.mjs --serve` and opened in the browser),
**prove** (`tools/web.sh --no-export`), **keep**, **deploy a preview**, **deploy
production** (asked twice), **use its configuration**, and **throw away** (kept
builds).

Each build is deployed under `/b/<commit>-<config>-<hash>/`, which is cached for
a year: two builds of one commit (a playtest, then a release) never share a path.

Jobs run one at a time in the background (`DevJobs`), their log tailed on the
slate, and they outlive the game that started them. Exports take turns through a
lock, since they share the stamp; a web build served for play finds another port
when one is held, and goes when the game that started it does. Before any job the slate
reads the machine's load and the Godot runs already going (another session may
be mid-tour): on a busy machine it asks again rather than piling on.

## Notes (feedback)

A note is a picture of the world as it was (never the slate), a kind (bug, look,
feel, idea, slow), words, the build and configuration, the state (seed, size,
place, hour, weather, what was carried, held and worn), and the exact command
that stages that moment again:

```
tools/shot.sh shots/notes/note-20260916-141203.png --seed=1 --size=512 --at=212.4,301.9 --hour=19.25 --weather=rain:0.8 --held=knife --give=driftwood:3 --config=playtest
```

Notes live in `user://dev/notes/`; a source run also writes them to
`shots/notes/` where a session can Read them. On the web a note can be copied
(JSON) and downloaded (picture and JSON). Any note can be **restaged**: a new
game at that moment, in that build.

## Keys (while dev mode is reachable)

| key | |
|---|---|
| `` ` `` | open or close the dev app (three times to arm, where access is `chord`) |
| F2 | a note, now: the picture is taken before the slate wakes |
| F3 | the readout on the glass's edge |
| F4 | a picture with nothing of the slate on it |

Every one is also a row in the app, so nothing depends on a function key a
browser keeps for itself.

## Look

Dev mode is the module's service mode, so it wears the module's violet
(`UiTheme.MACHINE`), never the player's phosphor: a violet `DEV` cap on the
status bar, a dashed violet rule under it, a violet tag on the rows that reach
it, and a small `DEV` flag in the corner of play while it is reachable. A
non-release build says its channel, version and commit on the title's glass.
Nothing of it appears in a shot or a tour unless asked for (`--dev`).
