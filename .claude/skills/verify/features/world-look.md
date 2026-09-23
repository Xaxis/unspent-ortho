# World look

The lit world: sky and hour, weather, lights and lamps, landscape grounds, foreground, fliers, holograms, crowns, the view.

<!-- covers: system:09_view, system:10_sky, system:11_dome, system:12_landscape, system:13_fore, system:14_fliers, system:15_lights, system:16_vents, system:17_holo, system:18_crowns, system:41_shoulder, system:95_flyover, system:96_eye -->

## Sub-features

- 09_view: `src/systems/09_view.gd`, reached by `tools/tour.sh tours/zoom.tour`.
- 41_shoulder: `src/systems/41_shoulder.gd` (with `CameraRig` and `src/core/view/shoulder.gd`), the view over the shoulder on L / right mouse, reached by `tools/tour.sh tours/shoulder.tour --seed=4 --hour=12 --weather=clear:0`; a still with `--view=shoulder`; rules in `tools/test.sh test_shoulder`.
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
