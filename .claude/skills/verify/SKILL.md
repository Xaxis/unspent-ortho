---
name: verify
description: Verify UNSPENT (Godot 4.7 game, all built in code, plus its tools/*.sh loop). Has the feature map of where every game system, slate screen, scene and tool lives, how to launch and health-check a run, and a proven recipe for checking each. Use to prove a change in this repo works, to find where a feature lives, or to see what a change could break.
---

# Verify UNSPENT

`FM=~/.claude/claude-core/bin/featuremap`

- **Where does a feature live?** Look it up in `features.json` (`id`, `entry`, `reach`),
  then read `features/<area>.md` for its recipe.
- **What did my change touch?** `$FM affected` (add `--since origin/main` on a branch).
- **Keeping it current:** the generator can't see this Godot project on its own, so
  every system, screen, scene and tool is declared in `featuremap.config.json`. When
  you add, rename or remove one, edit that file, run `$FM generate --write`, update
  the area file, and confirm `$FM check` exits 0. Commit it with the feature.

## Static checks

| Check | Command | Proves | Baseline (2026-09-23) |
|---|---|---|---|
| import | `godot --headless --path . --import --quit` | every script parses, class cache fresh | passes, 3 s, 0 `SCRIPT ERROR` |
| tests (targeted) | `tools/test.sh FILTER` | the named test files | e.g. `test_world_stamp` 15/15 in 16 s |
| gate | `tools/check.sh` | all tests in shards + 4 real frames | needs memory, see Gotchas |

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

```sh
godot --version; vm_stat | sed -n 2p; pgrep -ix godot | wc -l
```

4.7.x, free pages × 16 KB over ~500 MB for a full suite (use a filter below that),
and how many runs are already in flight (other sessions' runs; never kill them).

## Drive

- A scene or screen: `tools/shot.sh` with the recipe's options, then Read the PNG. A
  green test says nothing about how it looks.
- A system in play: its tour (`reach` in `features.json`). A tour fails on an awaited
  thing that never comes and saves `FAILED-lineN.png`.
- Rules and data: `tools/test.sh FILTER`, where the filter is a test file or
  `file:method` substring.

## Evidence

- The command, its exit code and the decisive output line (`N passed, 0 failed`,
  `tour X done`).
- For anything visible: the PNG path, and that you looked at it.
- An unreachable path is reported with what's missing, never as verified.

## Cleanup

Shots and tours exit by themselves. Tour frames overwrite `shots/tour/<name>/`, one run
per checkout. Kill only processes you started.
