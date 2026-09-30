# World look

The lit world: sky and hour, weather, lights and lamps, landscape grounds, foreground, fliers, holograms, crowns, the view.

<!-- covers: system:08_pointer, system:09_view, system:10_sky, system:11_dome, system:12_landscape, system:13_fore, system:14_fliers, system:15_lights, system:16_vents, system:17_holo, system:18_crowns, system:18_meadow, system:18_trample, system:19_colossi, system:19_orbit, system:21_falls, system:41_shoulder, system:42_stage, system:43_above, system:43_climb, system:95_flyover, system:96_eye -->

"(h)" means the tour's header has its options.

## Sub-features

- 09_view `src/systems/09_view.gd`: `tools/tour.sh tours/zoom.tour`.
- 08_pointer `src/systems/08_pointer.gd` (scroll, pan, pinch; docs/CONTROLS.md): `tools/test.sh test_pointer`.
- 41_shoulder `src/systems/41_shoulder.gd` (+ `CameraRig`, `src/core/view/shoulder.gd`): `tools/tour.sh tours/shoulder.tour --seed=4 --hour=12 --weather=clear:0`; a still with `--view=shoulder`; rules and cost `tools/test.sh test_shoulder`.
- 42_stage `src/systems/42_stage.gd` (+ `CameraRig.stage_weight`/`stage_fov`, `Game.staged`): the one staged look, turn to a point or a sky bearing, hold, turn back, keys held; `tools/test.sh test_stage`, and the Tether's first sight in `tours/home-coast.tour` frame 03 (48_wake).
  - Lock looked over a villager on the line: `tools/tour.sh tours/lockon_crowd.tour --seed=4 --hour=11 --weather=clear:0 --folk=14`.
  - Eye kept out of what is drawn, near plane off the ground: `tools/tour.sh tours/spring_arm.tour --seed=4 --hour=11 --weather=clear:0`.
  - Something lower than the eye behind the player looked over (Shoulder.over): `tools/test.sh test_shoulder:test_a_rock_lower`.
  - Too tight to stand behind (Shoulder.crowd/inside): `tools/tour.sh tours/bunker.tour` frame 04; `tours/tight_eye.tour` (machine city decks).
  - Sight cone never opens a big body's own front (Crowns.reach_of): `tools/test.sh test_crowns:test_a_big_body`; `tools/shot.sh shots/x.png --seed=1 --place=coast --spawn=sentinel.coast@40 --view=shoulder --hour=10 --weather=clear:0` shows the reaper whole.
  - Person rim a hairline at any distance; FOUND's stipple world-pinned, no rings by the eye (`found_stipple`): `tools/tour.sh tours/maintenance.tour` frame 05, `tools/tour.sh tours/grazing.tour --seed=4 --hour=15 --weather=clear:0`.
  - Down a corridor the view turns along it (Shoulder.corridor/along): `tools/test.sh test_corridor_view`, `tools/tour.sh tours/lands_slots.tour --seed=1 --weather=clear:0` frames slots-floor-0..3.
  - Every room kind's smallest room: eye under the ceiling, off every wall (`Shoulder.settle_eye`/`fallback`): `tools/test.sh test_shoulder_in_rooms`; `tours/face-hold.tour` frame 05, `tours/house.tour` frames 06/07.
- 10_sky `src/systems/10_sky.gd`: `tools/tour.sh tours/sky.tour`.
- 11_dome `src/systems/11_dome.gd`: `tools/tour.sh tours/slums-dome.tour`.
  - Without volumetric air (web) the day is a soft column (`shaft_column.gdshader`), never a white slab: `tools/web.sh --tour=tours/cave-walls.tour --uncapped --timeout=600 --args=--seed=7,--realm=underground,--hour=12` frame 02; desktop `godot --path . --rendering-method gl_compatibility -- --tour=tours/cave-walls.tour --seed=7 --realm=underground --hour=12 --quality=web`.
- 12_landscape `src/systems/12_landscape.gd`: `tools/tour.sh tours/landscape.tour`.
  - Land materials' raws (GEAR.md §11) at eye level by name: `tools/tour.sh tours/materials.tour` (seed 1), `tours/materials_caves.tour` (dripstone).
  - Snowfield grid hung with ice: `tools/tour.sh tours/iced_line.tour` (seed 4).
  - Cave walls at eye level (pale lips, no shimmer, `CAVE_FAR_ROUGH`; `lip_sag`; smooth fog): `tools/tour.sh tours/cave-walls.tour --seed=7 --realm=underground --hour=12`.
- 13_fore `src/systems/13_fore.gd`: `tools/tour.sh tours/depth.tour`.
  - Web: `tools/web.sh --tour=tours/depth.tour --args=--seed=1`, no failed GL program; under a tear `tools/web.sh --tour=tours/cave-cost.tour --uncapped --timeout=600 --args=--seed=7,--realm=underground,--hour=12,--stats` frame 02 shows the column, not a white block.
- 14_fliers `src/systems/14_fliers.gd`: `tools/tour.sh tours/slums_street.tour`.
- 15_lights `src/systems/15_lights.gd`: `tools/tour.sh tours/nights.tour`.
  - Web lamp pools rank on-screen lights first (`pool_before`): `tools/web.sh --tour=tours/lamp-pool.tour --programs --args=--seed=7,--weather=clear:0`, 0 new programs.
- 16_vents `src/systems/16_vents.gd`: `tools/tour.sh tours/hazards.tour`.
- 17_holo `src/systems/17_holo.gd`: `tools/tour.sh tours/slums_street.tour`.
- 18_crowns `src/systems/18_crowns.gd`: `tools/tour.sh tours/foliage.tour`.
  - A crown opens only between the eye and a body, never round the player: `tools/tour.sh tours/crowns-eye.tour --seed=1 --hour=11 --weather=clear:0` frames 02/03 (orchard), 05 (pinewood).
- 18_trample `src/systems/18_trample.gd`: `tools/tour.sh tours/foliage_meadow.tour --seed=7`; 01/02, 05/06 gust pairs, 03/04/07 grass parted; `perf grass` gives cost. Tests `tools/test.sh tests/render/test_trample,tests/render/test_wind`.
  - Snow and ash on the blades: `tools/tour.sh tours/foliage_snow_ash.tour` (seed 1), `tours/foliage_ash.tour` (seed 7).
- 18_meadow `src/systems/18_meadow.gd` (eye level only): `tools/tour.sh tours/foliage_meadow_ring.tour --seed=7 [--quality=TIER]`; 01-03 a front crossing, 04 the path; `perf meadow` gives cost. Tests `tools/test.sh test_meadow_ring,test_quality`.
  - Each landscape's grasses (`GrassSpecies`, `BiomeDef.grasses`): `tools/tour.sh tours/foliage_species.tour --seed=7`; tests `tests/render/test_species,tests/render/test_meadow`.
- 95_flyover `src/systems/95_flyover.gd`: `tools/tour.sh tours/flyover.tour`.
- 19_colossi `src/systems/19_colossi.gd` (`src/core/colossus/`, `src/render/colossus/`; horizon only, never in the top camera's sky): `tools/shot.sh shots/colossi.png --seed=7 --place=coast --hour=12 --eye=1.7,-5 --face=359 --stats` (stats give each walker's bearing; `--colossus=W@MINUTE`, `--colossi=off`). Tests `tools/test.sh test_colossus`. Tours (h):
  - `tours/colossi_stride.tour` (the walk), `tours/colossi_turn.tour` (turning past), `tours/colossi_step.tour` (quake, footfall, boom at real delays; `await colossus_quake`, `sound:colossus_step`), `tours/colossi_gaze.tour` (Shoulder.GAZE_LEAST), `tours/colossi_shadow.tour` (sky.gdshaderinc `sky_colossus`), `tours/colossi_edge.tour` (a shadow edge on terraces), `tours/colossi_night.tour`, `tours/colossi_ember.tour`.
  - A foot in the region (`gen_treads.gd`, landmark `tread`, `place tread0`; pads stop bodies, put one out, crush props): stage `--colossus=2@tread0+20` (`-10` for the landing), `near colossus_foot`/`near colossus_pad`; `tours/colossi_tread.tour`, `tours/colossi_landing.tour`, `tours/colossi_warning.tour` (`await colossus_warned`, 1.5 s ahead); `tools/test.sh test_colossus_treads`.
  - The climb up the half-broken walker (slice 3 step 7), headless core only so far: `src/core/colossus/walker_climb.gd` (`WalkerClimb`: pitches joined by rides, holds from the seed, breath the grip, the leg's swing forbids moves and drains, a set-down shakes a spent climber off, the cable catches a fall): `tools/test.sh test_walker_climb` (a climber reading the gait reaches the hub in about 13.5 real minutes on seed 1). The leg up close, where the hands are (step 7b): `src/models/colossus_leg_model.gd`, a patch of a pitch around the climbing line in the bone's own frame, every point off `WalkerClimb.surface_at`, a rung per hold and a lit shelf per ledge: `tools/test.sh test_walker_leg`, and `tools/shot.sh shots/leg.png --scene=gallery --filter="a ledge on" --hour=12 --pitch=5`.
- 19_orbit `src/systems/19_orbit.gd` (`src/core/orbit/`, `src/render/orbit/`; horizon only): `tools/tour.sh tours/orbit_sky.tour --seed=7 --place=coast --hour=12 --orbit=zenith@12 --eye=1.7,-80,70 --face=146 --weather=clear:0`; `tours/orbit_night.tour`, `tours/orbit_gaze.tour` (h). `--orbit=zenith@H`, `--orbit=off`; `tools/test.sh test_orbit`. The Tether (`src/core/orbit/tether.gd`, `orbit_tether_at` in `orbit_sky.gdshaderinc`): a line off the far shore to the Foundry, fixed, with a climber at night: `tools/tour.sh tours/tether.tour --seed=1 --place=coast --weather=clear:0 --eye=1.7,-30,70 --face=235 --orbit=zenith@1512/235` (dawn, noon, a ring pass at night) and `tools/test.sh test_tether`; `--stats` prints "world tether".
- 43_climb `src/systems/43_climb.gd`, the climb up the straddling walker's leg (`WalkerClimb`, the leg under his hands `src/render/colossus/colossus_leg.gd` on `colossus_leg_model.gd`, its own eye): `use` at a planted tread's rim, `move_up` hold to hold, rides between pitches, the hub reads `enclave_panel`. Its words are `StoryContent.CLIMB`: the rim's hint names the `use` key and the swing's names none (`tools/test.sh test_walker_climb_play:test_the_climbs_hints`), a line on the glass for a slip, a fall and each ride. Stage a hold with `--climb=PITCH[:HOLD]` beside `--colossus=2@tread0+20 --place=tread0` (`tools/shot.sh shots/c.png --seed=1 --place=tread0 --colossus=2@tread0+20 --climb=thigh:14 --hour=12 --stats`: `world climb` and its precision line). Tests `tools/test.sh test_walker` (the fit to the body, the patch, the core, the played climb). Tour (h, ~15 min): `tours/colossi_climb.tour`, tread to `enclave_met`.
- 21_falls `src/systems/21_falls.gd` (`fall_schedule.gd`, felt queue `rumble.gd` shared with 19_colossi): `tools/tour.sh tours/falls_sky.tour --seed=7 --place=coast --hour=21.2 --view=shoulder --weather=clear:0 --fall=dust@21.3,fragment@21.4,mass@21.75,dust@23.3,fragment@23.4,mass@23.75`; from above `tools/tour.sh tours/falls_top.tour --seed=7 --place=coast --hour=23.4 --view=top --weather=clear:0 --fall=mass@23.5` (`await fall_flash`, `fall_boom`). `--fall=CLASS@AT[/B][:age=S]`, `:bench`, `--fall=off`; `tools/test.sh test_falls,test_rumble`.
- 96_eye `src/systems/96_eye.gd`: `tools/shot.sh shots/eye.png --seed=7 --place=coast --hour=20 --eye=1.7,10,60 --face=110`; `tools/test.sh test_horizon` (a rebuilt level is the same bytes; memory plateaus on `--stats`).
- 43_above `src/systems/43_above.gd`, ground above the ground (docs/ABOVE.md): rules `tools/test.sh test_overhead`, drawing `test_spans`, the cut `test_above_map`.
  - Staged spans (AboveStage): `tools/tour.sh tours/above-arch.tour --seed=1 --place=moss --above=arch --hour=10.5 --weather=clear:0`, `tools/tour.sh tours/above-roof.tour --seed=1 --place=moss --above=roof --hour=10.5 --weather=clear:0` (`await above_cut`/`above_whole`).
  - Cave roofs (GenAbove): `tools/tour.sh tours/cave-roofs.tour --seed=7 --realm=underground --hour=12` (`near under_roof`); `tools/test.sh test_cave_roofs`.
  - Under the lid (`tools/test.sh test_above_map:test_the_day`): `TOUR_FIXED_FPS=60 tools/tour.sh tours/cave-dark.tour --seed=7 --realm=underground --hour=12` (`near deep_under_roof`: near ground reads, far hall dark).
  - Glide under the lid: `tools/test.sh test_abilities:test_a_glide`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/glide-under-roof.tour --seed=7 --realm=underground --hour=12 --fit=glide_wing` (`near glide_under_roof`); traffic light on a span's top: `tools/test.sh test_fliers_over_spans`.
  - Far roof (`overhead_tops`): `tools/test.sh test_horizon:test_a_far_roof`; `tools/shot.sh shots/x.png --seed=7 --realm=underground --hour=12 --eye=45,16` shows roof to the horizon, no pale open halls.

## How to reach it

- Night `--hour=23`; a landscape `--place=NAME` or a tour's `near KIND`. A place stands within four tiles of a flat, clear patch (`GenPlaces.has_room`): `tools/test.sh test_places_room`.

## How to check it

`tools/tour.sh tours/zoom.tour` (proof rules: README); web warm lights: platform.md.

## Gotchas

- The web build is Compatibility, not Forward+: re-check a light change with `tools/web.sh --quick`.
- `--stats` prints timings and writes NO image.
