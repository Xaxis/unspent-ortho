# World places

Realms and portals, landmarks and caches, regional holds.

<!-- covers: system:20_realms, system:22_landmarks, system:24_holds -->

## Sub-features

- 20_realms: `src/systems/20_realms.gd`, reached by `tools/tour.sh tours/realms.tour`.
- 22_landmarks: `src/systems/22_landmarks.gd`, reached by `tools/tour.sh tours/landmarks.tour`.
- 24_holds: `src/systems/24_holds.gd`, reached by `tools/tour.sh tours/region.tour`.

## How to reach it

- `tools/tour.sh tours/realms.tour`, `tours/landmarks.tour`, `tours/region.tour`.

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
