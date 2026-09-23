# UNSPENT

A real-time action-survival game on a generated world where half-broken machines
work the land and hunt the people still living in the gaps. Godot 4.7, typed
GDScript, lit 3D (Forward+ on desktop, Compatibility on the web). Everything is
generated in code: meshes, sounds, music, the UI and the world.

## Play it

```sh
tools/_import.sh && godot --path .
```

WASD move, Shift run, Space jump, J swing, K dodge, E use, C make, I carry, M map,
F lamp, Ctrl/Q crouch, hold Z to target, Esc pause, ` dev mode.

## Build it

```sh
tools/test.sh [filter]   # headless tests
tools/check.sh           # the gate: tests and real frames
tools/shot.sh out.png    # one rendered frame
tools/tour.sh x.tour     # a scripted run through real input
tools/web.sh             # the web build, booted in a headless browser
tools/deploy.sh          # deploy to Vercel and prove it runs there
```

## Docs

- `docs/VISION.md`: where the game is going.
- `docs/ROADMAP.md`: where it stands and what's next.
- `docs/DESIGN.md`: how it plays and the rules of each system.
- `docs/LOOK.md`: the look, binding.
- `docs/STORY.md`: the story, binding.
- `docs/LANDSCAPES.md`: what each landscape must have.
- `CLAUDE.md`: how to work in this repo.
