# UNSPENT

A real-time action-survival game on a generated world where half-broken machines
work the land and hunt the people still living in the gaps. Godot 4.7, typed
GDScript, lit 3D (Forward+ on desktop, Compatibility on the web). Everything is
generated in code: meshes, sounds, music, the UI and the world.

## Play it

```sh
tools/_import.sh && godot --path .
```

WASD move, Shift run, Space jump, J swing, K dodge, E use, I carry, M map, F lamp,
Ctrl crouch and C make (on a Mac C crouch, Y make), hold Z to target, Esc pause.
All three schemes: `docs/CONTROLS.md`.

## Build it

```sh
tools/test.sh [filter]   # headless tests
tools/check.sh           # the gate: tests and real frames
tools/shot.sh out.png    # one rendered frame
tools/tour.sh x.tour     # a scripted run through real input
tools/web.sh             # the web build, booted in a headless browser
tools/deploy.sh          # deploy to Vercel and prove it runs there
```

## Releasing

A version tag makes macOS, Linux, Windows and the web, boots each on its own OS, and
leaves them on a **draft** GitHub Release (`.github/workflows/release.yml`):

```sh
git tag v0.3.0 && git push origin v0.3.0        # or untagged, from any branch:
env -u GITHUB_TOKEN gh workflow run release.yml --ref BRANCH -f version=0.3.0-rc.1
```

Builds come from `configs/release.json`, stamped with the tag's version (each zip's
`.build.json`). Publishing the draft is deliberate, like `tools/deploy.sh --prod`. macOS is
ad-hoc signed and Windows unsigned until the owner's Developer ID and code-signing
certificate are secrets (the workflow's header names them). One build by hand:
`tools/export.sh linux`, then `tools/boot-check.sh build/linux/UNSPENT.x86_64`.

## Docs

- `docs/VISION.md`: where the game is going.
- `docs/ROADMAP.md`: where it stands and what's next.
- `docs/DESIGN.md`: how it plays and the rules of each system; `docs/GEAR.md`,
  `CONTROLS.md`, `ABOVE.md`, `HUSH.md`, `MIDDENS_ROOMS.md` go deeper.
- `docs/LOOK.md`: the look, binding.
- `docs/STORY.md`: the story, binding.
- `docs/LANDSCAPES.md`: what each landscape must have.
- `CLAUDE.md`: how to work in this repo.
