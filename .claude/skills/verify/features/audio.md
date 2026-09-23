# Audio and score

Procedural sound and the per-landscape score.

<!-- covers: system:70_audio, system:75_music -->

## Sub-features

- 70_audio: `src/systems/70_audio.gd`, reached by `tools/tour.sh tours/score.tour`.
- 75_music: `src/systems/75_music.gd`, reached by `tools/tour.sh tours/score-blend.tour`.

## How to reach it

- `tools/audio.sh` (spectrograms), `tools/audio.sh --score --land=ID`, `tools/tour.sh tours/score.tour`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/score.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- A new `sfx` name needs a line in `src/audio/sound_names.gd` or a test fails.
