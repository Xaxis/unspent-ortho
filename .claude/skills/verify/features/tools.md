# Tools

The loop scripts.

<!-- covers: cli:audio, cli:canon, cli:check, cli:deploy, cli:export, cli:map, cli:shard-times, cli:shot, cli:sweep, cli:test, cli:tour, cli:web -->

## Sub-features

- audio, canon, check, deploy, export, map, shot, test, tour: `tools/NAME.sh`.
- tour `tools/tour.sh`, run bare, boots with its header's options and takes the header's `TOUR_TIMEOUT` and `TOUR_FIXED_FPS` where the shell set none (`tools/_tour_args.sh`): `tools/test.sh test_tour_header`; `tools/tour.sh tours/home-coast.tour` prints `tour env: TOUR_TIMEOUT=600 (from its header)`. Off macOS its hidden window, and shot.sh's, run with vsync off (`focus_frame_flags`, tools/_focus.sh). With it on, the compositor presented the one-pixel window about once a second, and a fixed-step `wait 3.0` took 180 s against about 2 s now: its log's `fps=` reads near 90, not 1.
- web `tools/web.sh`: exports and boots the web build in headless Chromium.
- shard-times `tools/shard-times.sh RUN_ID` (or `--logs F...`): rebuilds `tests/shard_times.txt` from a gate run's `file-time PATH MS` lines (each file's shard run plus its costs and played reruns) and prints the eight shards the table makes; `tests/run.gd` shards by it, longest first onto the lightest shard (`shard_of`, `tools/test.sh test_shard_of`). Refresh it after a run whose shards came out uneven.
- sweep `tools/sweep.sh` (`tools/gd/sweep.gd`): every weapon against every common machine and the wall crowds, over the shoulder; `--reader=human[:SEED]` judges balance, `--crowd=N`, `--singles|--crowds`; a measurement, never a gate, ~10 min, killed at `SWEEP_TIMEOUT`. Quick: `tools/sweep.sh --weapons=knife --machines=cutter`.
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
- Cost tests (`TestCase.yard_lt`, the absolute `TestCase.cost_lt`, `TestCase.ratio_lt` for two timings from one run; never a bare `lt`, and `test_cost_bars` in preflight fails on one) are judged alone after the shards (`== costs, alone`), because beside siblings a cost reads up to 2.2x. A miss there is real; its log is `shots/check/costs.log`.
- Write the load (`sysctl -n vm.loadavg`) beside every frame-cost number; this box swings from 10 to 100.
- Never pipe a gate through `tail` in a way that hides its exit code.
- `tools/deploy.sh --prod` is deliberate; a push to main deploys a preview. Deploys export `--config=playtest` unless told otherwise (`--prod` too, and CI), so a deployed build has dev mode behind the chord.
