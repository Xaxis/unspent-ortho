# World places

Realms and portals, the rooms behind a house's door, landmarks and caches, regional holds.

<!-- covers: system:20_realms, system:21_doors, system:22_landmarks, system:24_holds -->

## Sub-features

- 20_realms: `src/systems/20_realms.gd`, reached by `tools/tour.sh tours/realms.tour`.
- 21_doors: `src/systems/21_doors.gd`, reached by `tools/tour.sh tours/house.tour --seed=4 --hour=11 --weather=clear:0`: a coast house's door, the room behind it (a pocket world, `src/core/interior/`, `src/models/interior/`), both views, and out again.
- 22_landmarks: `src/systems/22_landmarks.gd`, reached by `tools/tour.sh tours/landmarks.tour`.
- 24_holds: `src/systems/24_holds.gd`, reached by `tools/tour.sh tours/region.tour`.

## How to reach it

- `tools/tour.sh tours/realms.tour`, `tours/house.tour`, `tours/landmarks.tour`, `tours/region.tour`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/realms.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- Stage by name (`place NAME`, `near KIND`), never by a copied coordinate.
- A door's cost is `tests/interior/test_doors.gd`: it prints the swap in and out, best and worst of three trips, and fails a stall over 250 ms. Read the house tour's 02 and 04 side by side: the patch of sun on the boards must have moved between them.
- Indoors, the systems that keep the outside sleep (`indoors(inside)`, 20_realms) rather than re-reading it; a new system that keeps per-world state and does not declare `indoors` is still correct, only slower through a door.
