# Survival, gear and building

Taking from the world, hunger and weather, hazards, tracks, gear and abilities, the economy, crafts, settlements.

<!-- covers: system:44_crafts, system:46_settlements, system:50_survival, system:51_harvest, system:52_hazards, system:52_survival_fx, system:53_tracks, system:54_gear, system:56_economy -->

## Sub-features

- 44_crafts: `src/systems/44_crafts.gd`, reached by `tools/tour.sh tours/crafts.tour`.
- 46_settlements: `src/systems/46_settlements.gd`, reached by `tools/tour.sh tours/settlements.tour`.
  Carried off near your holding wakes at its hearth (`tools/tour.sh tours/carried_home.tour`); building
  raises the region's interference by loudness (`tools/test.sh test_noticed`, `tours/built_noticed.tour`);
  the gate, walked through and breached first (`tools/test.sh test_gate`,
  `tools/shot.sh shots/x.png --scene=gallery --filter="holding gate"`); the cellar, whose stores a raid
  cannot take (`tools/test.sh test_cellar`, gallery `--filter="holding cellar"`); the stolen cell,
  unlocked by a keeper's core (`tools/test.sh test_unlocks`, gallery `--filter="holding stolen cell"`).
- 50_survival: `src/systems/50_survival.gd`, reached by `tools/tour.sh tours/survival.tour`.
  Carried off leaves the bag on a heap where you were taken, under your own rag, marked on the
  survey ("your things") and standing as the goal until taken back; a bad end is filed against
  the region: `tools/test.sh test_bag_heap`, `tools/tour.sh tours/bag_heap.tour` (header has its options).
- 51_harvest: `src/systems/51_harvest.gd`, reached by `tools/tour.sh tours/harvest.tour`.
- 52_hazards: `src/systems/52_hazards.gd`, reached by `tools/tour.sh tours/hazards.tour`.
  At eye level no cue draws over the body (ground marks depth-tested, a cough is air out of the
  mouth): `tools/test.sh test_shoulder:test_no_hazard`, `tools/tour.sh tours/cue_eye.tour` (options in its header).
- 52_survival_fx: `src/systems/52_survival_fx.gd`, reached by `tools/tour.sh tours/survival.tour`.
- 53_tracks: `src/systems/53_tracks.gd`, reached by `tools/tour.sh tours/tracks.tour`.
- 54_gear: `src/systems/54_gear.gd`, reached by `tools/tour.sh tours/gear-economy.tour`.
  A scan over a dart says its answer at once ("It takes and goes. Break its sight."):
  `tools/test.sh test_abilities:test_a_scan_says`, `tools/tour.sh tours/scan_dart.tour` (options in its header).
  The lattice at a gate (nothing against harvesters, strong against cutters): `tools/test.sh test_lattice_icelens:test_the_lattice_at_a_gate`.
  Keeper powers (a keeper's core on the jig, a relic module): the undertow (reaper_core, hands) makes the grapple
  haul a machine in, stalled, for double wind: `tools/test.sh test_undertow` (its bout prints),
  `tools/tour.sh tours/undertow.tour` (options in its header).
  The rake (rake_core, tool): a heavy, drawn, holds the biters in the arc ahead open; chargers ride over it; heavies
  ring 1.5x: `tools/test.sh test_rake` (its gate bout prints), `tools/tour.sh tours/rake.tour` (options in its header).
  The anchor (anchor_core, body): stood still, rooted, no throw and no grip, and no dodge while rooted:
  `tools/test.sh test_anchor` (its bout prints), `tools/tour.sh tours/anchor.tour` (options in its header).
  The lock (lockkeeper_core, back): a narrow way passed while hunted is shut behind you to machines, a charge a lock:
  `tools/test.sh test_lock` (its bout prints), `tools/tour.sh tours/lock.tour` (options in its header).
  A keeper's core reads on the slate as the choice it is (the holding's cell, the power worn), side by side:
  `tools/test.sh test_rules:test_a_keepers_core`, `tools/tour.sh tours/core_choice.tour` (options in its header).
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
