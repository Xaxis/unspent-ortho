# People and story

The player's own body, villagers, fauna, named cast, the story's talks and fragments.

<!-- covers: system:33_avatar, system:35_folk, system:37_fauna, system:49_cast, system:49_story -->

## Sub-features

- 33_avatar: `src/systems/33_avatar.gd`, reached by `tools/tour.sh tours/character.tour`.
- 35_folk: `src/systems/35_folk.gd`, reached by `tools/tour.sh tours/locals.tour`.
- 37_fauna: `src/systems/37_fauna.gd`, reached by `tools/tour.sh tours/wild.tour`.
- 49_cast: `src/systems/49_cast.gd`, reached by `tools/tour.sh tours/cast.tour`.
- 49_story: `src/systems/49_story.gd`, reached by `tools/tour.sh tours/story.tour`.

## How to reach it

- `tools/tour.sh tours/story.tour`, `tours/cast.tour`, `tours/character.tour`, `tours/locals.tour`; `--talk=ID` / `--read=ID` in a shot.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/character.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- Every story line is bound by `docs/STORY.md`.
