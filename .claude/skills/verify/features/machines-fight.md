# Machines and fighting

Machines on the land, their disposition, depots, keepers, the fight, targeting, defences and raids.

<!-- covers: system:30_mobs, system:32_disposition, system:34_works, system:36_machine_parade, system:40_fight, system:42_target, system:44_sentinels, system:45_taken, system:47_defences, system:48_raids -->

## Sub-features

- 30_mobs: `src/systems/30_mobs.gd`, reached by `tools/tour.sh tours/machines.tour`.
- 32_disposition: `src/systems/32_disposition.gd`, reached by `tools/tour.sh tours/disposition.tour`.
- 34_works: `src/systems/34_works.gd`, reached by `tools/tour.sh tours/works.tour`.
- 36_machine_parade: `src/systems/36_machine_parade.gd`, reached by `tools/tour.sh tours/machines-day.tour`.
- 40_fight: `src/systems/40_fight.gd`, reached by `tools/tour.sh tours/fight.tour`.
- 42_target: `src/systems/42_target.gd`, reached by `tools/tour.sh tours/targeting.tour`. A lock holds the body (facing, strafe arc, swing, dodge: `src/core/fight/lock_on.gd`, `tools/test.sh test_lock_on`), proven in both views by `tools/tour.sh tours/lockon_top.tour` and `tours/lockon_shoulder.tour` (each tour's header has its options).
- 44_sentinels: `src/systems/44_sentinels.gd`, reached by `tools/tour.sh tours/sentinels.tour`.
- 45_taken: `src/systems/45_taken.gd`, reached by `tools/tour.sh tours/harvest.tour`.
- 47_defences: `src/systems/47_defences.gd`, reached by `tools/tour.sh tours/defences.tour`.
- 48_raids: `src/systems/48_raids.gd`, reached by `tools/tour.sh tours/raids.tour`.

## How to reach it

- `tools/tour.sh tours/fight.tour`, `tours/targeting.tour`, `tours/sentinels.tour`, `tours/raids.tour`; `--spawn=KIND@DEG` in a shot.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/machines.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- A tour `await` means since-last-asked; a latch that passed earlier proves nothing.
- `--spawn` bearings are degrees, 0 east, 90 south.
