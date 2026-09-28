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
- web: `tools/web.sh`, reached by `tools/web.sh`. `--programs` over a tour fails the run on any GL program first drawn after an `echo event` (a freeze a player meets); `--cold` builds every program as on a first visit.

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
- Cost tests (`TestCase.yard_lt` and the absolute `TestCase.cost_lt`; a timing bar is never a bare `lt`) are not judged inside the shards: each shard lists the ones it met and check.sh runs them again alone after (`== costs, alone`), because beside sibling shards a cost reads up to 2.2x. A cost that fails there is a real miss; its log is kept at `shots/check/costs.log`.
- Frame cost in play: `tools/tour.sh tours/stutters.tour --stats --seed=7 --hour=12 --weather=clear:0`
- Every web run fails on a GL program the browser refuses to draw with (`web FAILED: GL program N (src/…gdshader) failed …`, its GLSL kept as `shots/export/<out>-glfail-pN.{vs,fs}.glsl`): each program's first three draws are checked with getError (tools/web/web.mjs).
- Frame cost underground, in a lidded hall and under a tear (`tour lidded |` and `tour tear |` lines), on the web build: `tools/web.sh --tour=tours/cave-cost.tour --uncapped --timeout=600 --trace --args=--seed=7,--realm=underground,--hour=12,--stats`. `--trace` prints the tour's step lines (`tour t=... fps=...`), otherwise kept only in the tour's console.log.
  prints p50/p95/p99/worst per window (first shoulder press, over the shoulder, top-down)
  and names what each slow frame spent. Write the load (`sysctl -n vm.loadavg`) beside
  every number; this box swings from 10 to 100.
- Never pipe a gate through `tail` in a way that hides its exit code.
- `tools/deploy.sh --prod` is deliberate; a push to main deploys a preview.
- `tools/deploy.sh` exports from `--config=playtest` unless told otherwise (`--prod` too), so a deployed build has dev mode behind the chord; CI's deploy exports the same.
