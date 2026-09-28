# Tools

The loop scripts.

<!-- covers: cli:audio, cli:canon, cli:check, cli:deploy, cli:export, cli:map, cli:shot, cli:test, cli:tour, cli:web -->

## Sub-features

- audio, canon, check, deploy, export, map, shot, test, tour: `tools/NAME.sh`.
- web `tools/web.sh`: exports and boots the web build in headless Chromium.
  - `--programs` over a tour fails on any GL program first drawn after an `echo event` (a freeze a player meets); `--cold` builds every program as on a first visit.
  - Every run fails on a GL program the browser refuses (`web FAILED: GL program N …`; GLSL kept as `shots/export/<out>-glfail-pN.{vs,fs}.glsl`; first three draws checked with getError, `tools/web/web.mjs`).
- preflight `tools/preflight.sh`: the whole-tree rule tests (prop identity, whole-world readers, feature map, tour claims, worker types, room kinds), .uid and feature-map checks, ~90 s; red on any `WorldProp == WorldProp`.

## How to reach it

- Frame cost in play: `tools/tour.sh tours/stutters.tour --stats --seed=7 --hour=12 --weather=clear:0` prints p50/p95/p99/worst per window (first shoulder press, over the shoulder, top-down) and names what each slow frame spent.
- Frame cost underground (`tour lidded |`, `tour tear |` lines), web: `tools/web.sh --tour=tours/cave-cost.tour --uncapped --timeout=600 --trace --args=--seed=7,--realm=underground,--hour=12,--stats`; `--trace` prints the tour's step lines (`tour t=... fps=...`).
- `tools/deploy.sh` needs `VERCEL_TOKEN` in `.env`.

## How to check it

`tools/audio.sh` (proof rules: README).

## Gotchas

- `tools/check.sh` runs three shards at once and dies under ~500 MB free. CI runs the gate as eight shard jobs (`tools/check.sh --no-shots --shards=8 --only=I`).
- Cost tests (`TestCase.yard_lt`, the absolute `TestCase.cost_lt`; never a bare `lt`) are judged alone after the shards (`== costs, alone`), because beside siblings a cost reads up to 2.2x. A miss there is real; its log is `shots/check/costs.log`.
- Write the load (`sysctl -n vm.loadavg`) beside every frame-cost number; this box swings from 10 to 100.
- Never pipe a gate through `tail` in a way that hides its exit code.
- `tools/deploy.sh --prod` is deliberate; a push to main deploys a preview. Deploys export `--config=playtest` unless told otherwise (`--prod` too, and CI), so a deployed build has dev mode behind the chord.
