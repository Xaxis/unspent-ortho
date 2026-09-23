# Survival, gear and building

Taking from the world, hunger and weather, hazards, tracks, gear and abilities, the economy, crafts, settlements.

<!-- covers: system:44_crafts, system:46_settlements, system:50_survival, system:51_harvest, system:52_hazards, system:52_survival_fx, system:53_tracks, system:54_gear, system:56_economy -->

## Sub-features

- 44_crafts: `src/systems/44_crafts.gd`, reached by `tools/tour.sh tours/crafts.tour`.
- 46_settlements: `src/systems/46_settlements.gd`, reached by `tools/tour.sh tours/settlements.tour`.
- 50_survival: `src/systems/50_survival.gd`, reached by `tools/tour.sh tours/survival.tour`.
- 51_harvest: `src/systems/51_harvest.gd`, reached by `tools/tour.sh tours/harvest.tour`.
- 52_hazards: `src/systems/52_hazards.gd`, reached by `tools/tour.sh tours/hazards.tour`.
- 52_survival_fx: `src/systems/52_survival_fx.gd`, reached by `tools/tour.sh tours/survival.tour`.
- 53_tracks: `src/systems/53_tracks.gd`, reached by `tools/tour.sh tours/tracks.tour`.
- 54_gear: `src/systems/54_gear.gd`, reached by `tools/tour.sh tours/gear-economy.tour`.
- 56_economy: `src/systems/56_economy.gd`, reached by `tools/tour.sh tours/gear-economy.tour`.

## How to reach it

- `tools/tour.sh tours/survival.tour`, `tours/harvest.tour`, `tours/hazards.tour`, `tours/crafts.tour`, `tours/settlements.tour`; `--give=ID:N --held=ID` in a shot.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/crafts.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- A hazard claim needs its weather staged (`--weather=`); `clear:0` hides it.
