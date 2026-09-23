# World generation

Growing a world from a seed.

<!-- covers: job:worldgen -->

## Sub-features

- worldgen: `src/core/world_gen.gd`, reached by `tools/map.sh --seed=7`.

## How to reach it

- `tools/map.sh --seed=7` (top-down map), `tools/test.sh test_world_gen`, `tools/test.sh test_parity`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/map.sh --seed=7
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- Anything that changes what a seed makes bumps `WorldStamp.GEN` and re-accepts parity.
