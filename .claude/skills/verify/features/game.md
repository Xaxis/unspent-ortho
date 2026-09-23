# The game's spine

The entry scene and the signal bus every package talks through.

<!-- covers: autoload:Events, scene:main -->

## Sub-features

- Events: `src/events.gd`, reached by `autoload singleton Events`.
- main: `src/main.tscn`, reached by `godot --path .`.

## How to reach it

- `godot --path .`; `tools/shot.sh $S/f.png --seed=7`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
autoload singleton Events
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- A new `class_name` needs `tools/_import.sh` before a hand run.
