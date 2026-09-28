# The game's spine

The entry scene and the signal bus every package talks through.

<!-- covers: autoload:Events, scene:main -->

## Sub-features

- Events `src/events.gd`: `autoload singleton Events`.
- main `src/main.tscn`: `godot --path .`.
- Putting the player down (start, load, door, warp, respawn, hours passing, craft, pad edge, leap, dev or tour
  jump): all go through `Player.place` -> `WorldQuery.stand_at`, whole by `body_fits` (every corner a step from
  the middle, headroom): `tools/test.sh test_stand_at`.

## How to reach it

- `godot --path .`; `tools/shot.sh $S/f.png --seed=7`.

## How to check it

`tools/shot.sh $S/f.png --seed=7` (proof rules: README).

## Gotchas

- A new `class_name` needs `tools/_import.sh` before a hand run.
