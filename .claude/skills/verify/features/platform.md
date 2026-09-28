# Saves, dev mode and tours

Saving and loading, dev mode, the tour runner, the web's warm lights.

<!-- covers: system:01_warm_lights, system:05_save, system:94_dev, system:98_tour -->

## Sub-features

- 01_warm_lights `src/systems/01_warm_lights.gd`: the constant black light set and the boot's warm-up, so no door, dusk, fire or tear builds a shader program on the web. `tools/web.sh --tour=tours/every-room.tour --programs --timeout=900 --args=--seed=4,--hour=11,--weather=clear:0` exits 0 with no program first drawn at any event (every room kind, day and night). Cold cost with and without: `--cold` and the tour's first event.
- 05_save `src/systems/05_save.gd`: `tools/tour.sh tours/saves.tour`.
- 94_dev `src/systems/94_dev.gd`: `tools/tour.sh tours/dev.tour` (the app's five tabs, [ and ]).
  - The story map (STORY tab, `DevPageStoryMap` over `StoryMap`): `tools/tour.sh tours/story-map.tour --seed=7 --hour=11 --weather=clear:0 --dev=story --stats`; a frame straight onto it `tools/shot.sh shots/x.png --seed=1 --dev=story_map:order+was_cia` (words after the colon, joined by `+`: world, order, zoomN, a beat id, narrow). Projection tests: `tools/test.sh test_story_map`.
- 98_tour `src/systems/98_tour.gd`: `tools/tour.sh tours/smoke.tour`.
  - `walkto prop:KIND SECS` walks to a prop with the real keys: `TOUR_TIMEOUT=500 tools/tour.sh tours/wild.tour --fail-downed`.
  - `mark NAME` / `at mark:NAME`, `back KIND DIST` + `walkto prop:KIND SECS run through` (the slide round a lone trunk): `TOUR_TIMEOUT=600 tools/tour.sh tours/feel.tour --give=driftwood:6,scrap:1`.
  - A coordinate in `at` fails `tools/test.sh test_tour_claims`.
  - `await fire_asked` is the fire's first press, `await asked` the region's ask: `tools/tour.sh tours/region.tour` (options in its header).

## How to reach it

- `--load=N --saves=DIR` in a shot or tour.
- Dev mode in the real web build: `tools/web.sh --config=playtest --tour=tours/dev.tour --args=--seed=1,--hour=10,--weather=clear:0,--config=playtest` (frames in `shots/export/tour/dev/`). The build needs `--config` to have dev mode at all, and the tour needs it in `--args` too.

## How to check it

`tools/tour.sh tours/saves.tour` (proof rules: README).

## Gotchas

- A save from before a worldgen change is refused by its world stamp; that's intended.
