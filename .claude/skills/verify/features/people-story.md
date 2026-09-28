# People and story

The player's own body, villagers, fauna, named cast, the story's talks and fragments.

<!-- covers: system:33_avatar, system:35_folk, system:37_fauna, system:48_wake, system:49_cast, system:49_story -->

## Sub-features

- 33_avatar `src/systems/33_avatar.gd`: `tools/tour.sh tours/character.tour`.
- 35_folk `src/systems/35_folk.gd`: `tools/tour.sh tours/locals.tour`.
- 37_fauna `src/systems/37_fauna.gd`: `tools/tour.sh tours/wild.tour`.
- 48_wake `src/systems/48_wake.gd` (the first morning in the surf, `src/core/story/wake_spot.gd`): `tools/tour.sh tours/home-coast.tour --scene=title --seed=1`, the slice's proof tour from the title (frames 01-03), and `tools/test.sh test_wake`.
- 49_cast `src/systems/49_cast.gd`: `tools/tour.sh tours/cast.tour`.
- 49_story `src/systems/49_story.gd`: `tools/tour.sh tours/story.tour`.
  - Room words (StoryRooms, `StoryContent.ROOMS`, read with `use` inside): `tools/tour.sh tours/bunker_words.tour --seed=4 --hour=15 --weather=clear:0`, `tests/story/test_rooms.gd`.
  - His bunker's gated terminal and the tenants per bunker (`StoryRooms.tenants`): `tools/tour.sh tours/bunker_woken.tour --seed=4 --hour=15 --weather=clear:0 --beats=built_halcyon`, `tests/story/test_under_the_stones.gd`.

## How to reach it

- The tours above; `--talk=ID` / `--read=ID` in a shot.

## How to check it

`tools/tour.sh tours/character.tour` (proof rules: README).

## Gotchas

- Every story line is bound by `docs/STORY.md`.
