# Tools

The loop scripts.

<!-- covers: cli:audio, cli:canon, cli:check, cli:deploy, cli:export, cli:map, cli:shot, cli:test, cli:tour, cli:web -->

## Sub-features

- audio: `tools/audio.sh`, reached by `tools/audio.sh`.
- canon: `tools/canon.sh`, reached by `tools/canon.sh`.
- check: `tools/check.sh`, reached by `tools/check.sh`.
- deploy: `tools/deploy.sh`, reached by `tools/deploy.sh`.
- export: `tools/export.sh`, reached by `tools/export.sh`.
- map: `tools/map.sh`, reached by `tools/map.sh`.
- shot: `tools/shot.sh`, reached by `tools/shot.sh`.
- test: `tools/test.sh`, reached by `tools/test.sh`.
- tour: `tools/tour.sh`, reached by `tools/tour.sh`.
- web: `tools/web.sh`, reached by `tools/web.sh`.

## How to reach it

- Each is its own command (`reach`). `tools/web.sh` exports and boots the web build in headless Chromium; `tools/deploy.sh` needs `VERCEL_TOKEN` in `.env`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/audio.sh
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- `tools/check.sh` runs three shards at once and dies on a box with under ~500 MB free.
- Frame cost in play: `tools/tour.sh tours/stutters.tour --stats --seed=7 --hour=12 --weather=clear:0`
  prints p50/p95/p99/worst per window (first shoulder press, over the shoulder, top-down)
  and names what each slow frame spent. Write the load (`sysctl -n vm.loadavg`) beside
  every number; this box swings from 10 to 100.
- Never pipe a gate through `tail` in a way that hides its exit code.
- `tools/deploy.sh --prod` is deliberate; a push to main deploys a preview.
