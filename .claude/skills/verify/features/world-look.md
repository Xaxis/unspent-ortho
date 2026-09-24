# World look

The lit world: sky and hour, weather, lights and lamps, landscape grounds, foreground, fliers, holograms, crowns, the view.

<!-- covers: system:08_pointer, system:09_view, system:10_sky, system:11_dome, system:12_landscape, system:13_fore, system:14_fliers, system:15_lights, system:16_vents, system:17_holo, system:18_crowns, system:19_colossi, system:41_shoulder, system:95_flyover, system:96_eye -->

## Sub-features

- 09_view: `src/systems/09_view.gd`, reached by `tools/tour.sh tours/zoom.tour`.
- 08_pointer: `src/systems/08_pointer.gd`, the scroll, a trackpad's pan and pinch: a held lock cycles, the shoulder view moves its eye, else the land zooms (docs/CONTROLS.md); rules in `tools/test.sh test_pointer`.
- 41_shoulder: `src/systems/41_shoulder.gd` (with `CameraRig` and `src/core/view/shoulder.gd`), the view over the shoulder, a press on Left Alt/Option and a held peek on the right mouse button, the arrows as its keyboard look, and a lock framed from the shoulder and looked over a villager on the line to it (`tools/tour.sh tours/lockon_crowd.tour --seed=4 --hour=11 --weather=clear:0 --folk=14`), reached by `tools/tour.sh tours/shoulder.tour --seed=4 --hour=12 --weather=clear:0`; a still with `--view=shoulder`; rules in `tools/test.sh test_shoulder`.
- 10_sky: `src/systems/10_sky.gd`, reached by `tools/tour.sh tours/sky.tour`.
- 11_dome: `src/systems/11_dome.gd`, reached by `tools/tour.sh tours/slums-dome.tour`.
- 12_landscape: `src/systems/12_landscape.gd`, reached by `tools/tour.sh tours/landscape.tour`.
- 13_fore: `src/systems/13_fore.gd`, reached by `tools/tour.sh tours/depth.tour`.
- 14_fliers: `src/systems/14_fliers.gd`, reached by `tools/tour.sh tours/slums_street.tour`.
- 15_lights: `src/systems/15_lights.gd`, reached by `tools/tour.sh tours/nights.tour`.
- 16_vents: `src/systems/16_vents.gd`, reached by `tools/tour.sh tours/hazards.tour`.
- 17_holo: `src/systems/17_holo.gd`, reached by `tools/tour.sh tours/slums_street.tour`.
- 18_crowns: `src/systems/18_crowns.gd`, reached by `tools/tour.sh tours/foliage.tour`.
- 95_flyover: `src/systems/95_flyover.gd`, reached by `tools/tour.sh tours/flyover.tour`.
- 19_colossi: `src/systems/19_colossi.gd`, the walking megastructures in the sky, drawn only while the horizon is in frame (core `src/core/colossus/`, model `src/models/colossus_model.gd`, view and shader `src/render/colossus/`, the dome shared with the sky through `src/render/sky_dome.gdshaderinc`), reached by `tools/shot.sh shots/colossi.png --seed=7 --place=coast --hour=12 --eye=1.7,-5 --face=359 --stats` (the stats line says each walker's bearing, for `--face`; `--colossus=W@MINUTE` stages one, `--colossi=off` takes them away); the walk in real seconds is `tours/colossi_stride.tour`, turning past them `tours/colossi_turn.tour`, a landing FELT (quake, footfall, boom at their real delays; `await colossus_quake`, `sound:colossus_step`) `tours/colossi_step.tour`, the shoulder view tipping up to one (Shoulder.GAZE_LEAST) `tours/colossi_gaze.tour`, a leg's shadow crossing the land (sky.gdshaderinc `sky_colossus`, globals `colossus_*`) `tours/colossi_shadow.tour`; a shadow's EDGE crossing the terraces `tours/colossi_edge.tour`, the night rings and the pulse climbing `tours/colossi_night.tour`, the last sun graded by height `tours/colossi_ember.tour`; tests `tools/test.sh test_colossus`. The top-down camera must draw nothing of them in the sky. A FOOT IN THE REGION (slice 3): the craters world generation cuts (`src/core/worldgen/gen_treads.gd`, `src/core/colossus/colossus_treads.gd`, landmark kind `tread`, `place tread0`), the near foot drawn in real space (`src/render/colossus/colossus_foot.gd`, `src/models/colossus_foot_model.gd`, dust and steam `colossus_dust.gdshader`), its pads stopping bodies, putting one out and crushing props; stage it with `--colossus=2@tread0+20` (or `-10` for the landing), stand under it with `near colossus_foot` / `near colossus_pad`; `tours/colossi_tread.tour` (noon and night lines in its header) and `tours/colossi_landing.tour`; tests `tools/test.sh test_colossus_treads`.
- 96_eye: `src/systems/96_eye.gd`, the eye-level horizon view (sky_eye.gdshader, SkyLight.sees_horizon, world_far silhouettes), reached by `tools/shot.sh shots/eye.png --seed=7 --place=coast --hour=20 --eye=1.7,10,60 --face=110`; tests `tools/test.sh test_horizon`.

## How to reach it

- Read the frame for the change. Night: `--hour=23`; a landscape: `--place=NAME` or a tour's `near KIND`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/zoom.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- The web build is Compatibility, not Forward+: re-check a light change with `tools/web.sh --quick`.
- `--stats` prints timings and writes NO image.
