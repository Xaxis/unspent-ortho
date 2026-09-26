# Saves, dev mode and tours

Saving and loading, dev mode, the tour runner.

<!-- covers: system:05_save, system:94_dev, system:98_tour -->

## Sub-features

- 05_save: `src/systems/05_save.gd`, reached by `tools/tour.sh tours/saves.tour`.
- 94_dev: `src/systems/94_dev.gd`, reached by `tools/tour.sh tours/dev.tour`.
- 98_tour: `src/systems/98_tour.gd`, reached by `tools/tour.sh tours/smoke.tour`.
  `walkto prop:KIND SECS` walks to a prop by name with the real keys (`TOUR_TIMEOUT=500 tools/tour.sh tours/wild.tour --fail-downed`);
  `mark NAME` / `at mark:NAME` and `back KIND DIST` + `walkto prop:KIND SECS run through` (the slide round a lone trunk,
  printed as tiles past its middle): `TOUR_TIMEOUT=600 tools/tour.sh tours/feel.tour --give=driftwood:6,scrap:1`;
  a coordinate in `at` fails `tools/test.sh test_tour_claims`;
  `await fire_asked` is the fire's first press, `await asked` the region's ask (`tools/tour.sh tours/region.tour`, options in its header).

## How to reach it

- `tools/tour.sh tours/saves.tour`, `tours/dev.tour`; `--load=N --saves=DIR`.
- Dev mode in the real web build: `tools/web.sh --config=playtest --tour=tours/dev.tour --args=--seed=1,--hour=10,--weather=clear:0,--config=playtest` (frames in `shots/export/tour/dev/`). The build needs `--config` to have dev mode at all; the tour needs it in `--args` too, because a tool run opens dev mode only when asked.

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
