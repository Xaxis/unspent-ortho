# Machines and fighting

Machines on the land, their disposition, depots, keepers, the fight, targeting, defences and raids.

<!-- covers: system:30_mobs, system:32_disposition, system:34_works, system:36_machine_parade, system:40_fight, system:42_target, system:44_sentinels, system:45_taken, system:47_defences, system:48_raids -->

## Sub-features

- 30_mobs: `src/systems/30_mobs.gd`, reached by `tools/tour.sh tours/machines.tour`.
- 32_disposition: `src/systems/32_disposition.gd`, reached by `tools/tour.sh tours/disposition.tour`.
- 34_works: `src/systems/34_works.gd`, reached by `tools/tour.sh tours/works.tour`.
- 36_machine_parade: `src/systems/36_machine_parade.gd`, reached by `tools/tour.sh tours/machines-day.tour`.
- 40_fight: `src/systems/40_fight.gd`, reached by `tools/tour.sh tours/fight.tour`.
  Height: a ledge (2 levels) stands bodies out of each other's blows (`tools/test.sh test_height`).
  Climbing (the jump key at a rock face too tall to jump; a route ruled up a face you face; breath a
  level, fall damage when it runs out; the climber's level on the face for blows):
  `tools/test.sh test_climb`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/climb.tour` (header has its options).
  The vertical line (the grapple at the foot of a face up to 8 levels, hauled up to a post, pylon or
  trunk at the top): `tools/test.sh test_vertical_grapple`,
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/vertical_grapple.tour` (header has its options).
  The drop strike, a jump's landing off a ledge as a plate-opening blow: `tools/test.sh test_drop_strike`,
  `tools/tour.sh tours/drop_strike.tour` (header has its options).
  The heavy blow, swing held 300 ms: `tools/test.sh "test_heavy,test_bouts"` (the reader's time-to-kill
  metric prints there), `TOUR_FIXED_FPS=60 tools/tour.sh tours/heavy_blow.tour`.
  Every bite's ground ring (dashed where it lands, an inner ring closing on the strike):
  `tools/test.sh test_tell_ring`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/bite_ring.tour`.
  The thrower (the middens' sorter, Brains `throw`): a lane-long bite told by its lane on the
  ground, a reload that is the opening; `tools/test.sh test_throw` (the reader's bout numbers print
  there), `TOUR_FIXED_FPS=60 tools/tour.sh tours/thrower.tour` (header has its options).
  The dropper (the tamper, the scrapwood's own, Brains `drop`): waits on a ledge and comes down on where the player
  stood, told by its shadow growing on the ground; `tools/test.sh test_dropper`,
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/dropper.tour` (top view and over the shoulder; the tour
  command `over KIND` stages a body on a lip with the player below).
  Ten awake machines' draw cost: `tools/test.sh test_awake_cost`.
  Part sides (a landscape's `over` part moves the working part; the model builds it there):
  `tools/test.sh test_part_sides`, `tools/shot.sh shots/x.png --scene=gallery --filter=sides_hauler --zoom=4`,
  `tools/tour.sh tours/part_sides.tour` and `tours/part_sides_cave.tour` (headers have their options).
  Night hearing (a machine hears further and makes up its mind faster by ear at night): the day
  and night noticing distances and night bouts print in `tools/test.sh test_first_meetings:test_by_night`.
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
