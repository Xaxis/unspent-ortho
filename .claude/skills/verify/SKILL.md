---
name: verify
description: Verify UNSPENT (Godot 4.7 game, all built in code, plus its tools/*.sh loop). Has the feature map of where every game system, slate screen, scene and tool lives, how to launch and health-check a run, and a proven recipe for checking each. Use to prove a change in this repo works, to find where a feature lives, or to see what a change could break.
---

# Verify UNSPENT

Contract for proving a change to the built game: where each feature lives and the command that proves it.

`FM=~/.claude/claude-core/bin/featuremap`

- **Where does a feature live?** Look it up in `features.json` (`id`, `entry`, `reach`),
  then read `features/<area>.md` for its recipe.
- **What did my change touch?** `$FM affected` (add `--since origin/main` on a branch).
- **Keeping it current:** every system, screen, scene and tool is declared in
  `featuremap.config.json` (the generator can't see Godot). On add, rename or remove: edit
  it, `$FM generate --write`, update the area file, `$FM check` exits 0, commit together.

## Static checks

| Check | Command | Proves |
|---|---|---|
| import | `godot --headless --path . --import --quit` | every script parses (0 `SCRIPT ERROR`), class cache fresh |
| tests | `tools/test.sh FILTER` | the named test files |
| preflight | `tools/preflight.sh` | the whole-tree rules, ~90 s, and every shader compiled by the real renderer (`tools/shaders.sh`) |
| gate | `tools/check.sh` | all tests in shards + 4 real frames; ~500 MB free, CI runs it |

Known pre-existing failures: `test_world_gen_works:test_budgets` (works stage 0.23-0.25 of
generation vs a 0.22 bar; the fix is in the GEN 24 branch `m3/standing`).

## Launch

A run is a shot, a tour or a test; each is its own process and ends itself.

```sh
S=<your scratchpad>
tools/shot.sh $S/frame.png --seed=7 --hour=11 --weather=clear:0     # one frame
tools/tour.sh tours/smoke.tour                                      # frames in shots/tour/smoke/
godot --path .                                                      # a person playing
```

Ready when: `shot.sh` exits 0 and the PNG exists (about 60 s: it builds a world);
`tour.sh` prints `tour NAME done -> shots/tour/NAME`.
Needs: `godot` 4.7 on PATH. After a pull, `tools/_import.sh` first.

## Doctor

`godot --version; vm_stat | sed -n 2p; pgrep -ix godot | wc -l`: 4.7.x, free pages × 16 KB
over ~500 MB for a full suite, and how many runs other sessions have in flight (never kill
them).

## Drive

- A scene or screen: `tools/shot.sh` with the recipe's options, then Read the PNG.
- A system in play: its tour (`reach` in `features.json`). A tour fails on an awaited
  thing that never comes and saves `FAILED-lineN.png`.
- Rules and data: `tools/test.sh FILTER` (a test file or `file:method` substring).

## Evidence

The command, its exit code and the decisive line (`N passed, 0 failed`, `tour X done`);
for anything visible, the PNG path and that you looked. An unreachable path is reported
with what's missing, never as verified.

## Cleanup

Shots and tours exit by themselves. Tour frames overwrite `shots/tour/<name>/`, one run
per checkout. Kill only processes you started.
