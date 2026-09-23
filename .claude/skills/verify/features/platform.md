# Saves, dev mode and tours

Saving and loading, dev mode, the tour runner.

<!-- covers: system:05_save, system:94_dev, system:98_tour -->

## Sub-features

- 05_save: `src/systems/05_save.gd`, reached by `tools/tour.sh tours/saves.tour`.
- 94_dev: `src/systems/94_dev.gd`, reached by `tools/tour.sh tours/dev.tour`.
- 98_tour: `src/systems/98_tour.gd`, reached by `tools/tour.sh tours/smoke.tour`.

## How to reach it

- `tools/tour.sh tours/saves.tour`, `tours/dev.tour`; `--load=N --saves=DIR`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/saves.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- A save from before a worldgen change is refused by its world stamp; that's intended.
