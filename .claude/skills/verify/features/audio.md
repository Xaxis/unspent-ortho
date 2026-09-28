# Audio and score

Procedural sound and the per-landscape score.

<!-- covers: system:70_audio, system:75_music -->

## Sub-features

- 70_audio `src/systems/70_audio.gd`: `tools/tour.sh tours/score.tour`.
- 75_music `src/systems/75_music.gd`: `tools/tour.sh tours/score-blend.tour`.

## How to reach it

- `tools/audio.sh` (spectrograms), `tools/audio.sh --score --land=ID`.

## How to check it

`tools/tour.sh tours/score.tour` (proof rules: README).

## Gotchas

- A new `sfx` name needs a line in `src/audio/sound_names.gd` or a test fails.
