# Saves, dev mode and tours

Saving and loading, dev mode, the tour runner, the web's warm lights.

<!-- covers: system:00_taps, system:01_warm_lights, system:05_save, system:94_dev, system:98_tour -->

## Sub-features

- 00_taps `src/systems/00_taps.gd`: a key that went down and came up inside one drawn frame (a quick tap on a slow frame, or a press held for physics steps of one frame's catch-up) is held down for one frame, so every system's own polled edge finds it: `tools/heavy.sh tools/test.sh test_era_gates:test_the_press_beside` on a loaded box (fps 2-6), where the press was lost 4 of 4 without it.
- 01_warm_lights `src/systems/01_warm_lights.gd`: the constant black light set and the boot's warm-up, so no door, dusk, fire or tear builds a shader program on the web. `tools/web.sh --tour=tours/every-room.tour --programs --timeout=900 --args=--seed=4,--hour=11,--weather=clear:0` exits 0 with no program first drawn at any event (every room kind, day and night). Cold cost with and without: `--cold` and the tour's first event. Its rack stands at the player's feet until `done()`; the boot page's cover and a shot both wait for it: `tools/test.sh test_warm_in_shots`, and a default `tools/shot.sh` at `--seed=1 --hour=11` shows no white disc or card at the player.
- 05_save `src/systems/05_save.gd`: `tools/tour.sh tours/saves.tour`.
- 94_dev `src/systems/94_dev.gd`: `tools/tour.sh tours/dev.tour` (the app's five tabs, [ and ]).
  - The story map (STORY tab, `DevPageStoryMap` over `StoryMap`): `tools/tour.sh tours/story-map.tour --seed=7 --hour=11 --weather=clear:0 --dev=story --stats`; a frame straight onto it `tools/shot.sh shots/x.png --seed=1 --dev=story_map:order+was_cia` (words after the colon, joined by `+`: world, order, zoomN, a beat id, narrow). Projection tests: `tools/test.sh test_story_map`.
  - The arc view (e on a chosen beat, `DevPageArcView` over `StoryArcGraph`, Godot's GraphEdit): the same tour's frames 07-08, or `tools/shot.sh shots/x.png --seed=7 --dev=story_map:crew_paid+arc`. Graph tests: `tools/test.sh test_arc_graph`.
- 98_tour `src/systems/98_tour.gd`: `tools/tour.sh tours/smoke.tour`.
  - `walkto prop:KIND SECS` walks to a prop with the real keys: `TOUR_TIMEOUT=500 tools/tour.sh tours/wild.tour --fail-downed`.
  - `walkto ground:KIND SECS [run]` walks onto the spot `ground` would jump to, and `walkto mob SECS till:CLAIM` stops a walk at a body once CLAIM holds: no tour walks them since home-coast's stage 7 went to the lure drive (2026-10-03); an unknown ground name fails `tools/test.sh test_tour_claims`.
  - `hour snatch` moves the clock to when the plan comes for the village that saw him first (48_raids `tour_hour`): `tools/test.sh test_seen_taken`, and home-coast's stage 6 on seed 7 (`TOUR_TIMEOUT=600 TOUR_FIXED_FPS=60 tools/tour.sh tours/home-coast.tour --scene=title --seed=7`, frame 17).
  - `until hint:VERB` waits for the key row to name VERB before a press (a street puts somebody in front of him most seconds, and the press is theirs), and `await hunger:N` for his hunger at N or under: home-coast's feed and sleep at Low Scar and its meal before the Reaper (the same run).
  - `dodge aside [SECS]` dodges out of the nearest body's bite across its facing, and `walkto plate` rounds to a plated flank when the back stands in deep water: `TOUR_FIXED_FPS=60 tools/tour.sh tours/sentinels.tour --seed=7 --hour=11 --weather=clear:0 --held=axe_felling --config=unharmed` (frames 03 and 05), and `tours/reaper_plating.tour`.
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
