# Tools

The loop scripts.

<!-- covers: cli:audio, cli:boot-check, cli:canon, cli:check, cli:deploy, cli:export, cli:map, cli:shaders, cli:shard-times, cli:shot, cli:sweep, cli:test, cli:tour, cli:web, job:release -->

## Sub-features

- audio, canon, check, deploy, export, map, shot, test, tour: `tools/NAME.sh`.
- export `tools/export.sh linux|windows|mac|web|web-nothreads [--config=NAME] [--version=X]`: linux and windows are one x86_64 file each with the pck embedded; `--version` stamps over the configuration's (`build.json` `version`).
- boot-check `tools/boot-check.sh BUILD` (a Linux binary, a `.exe`, a `.app`): launches the export as a player does, plus `--headless`, and passes on `boot-check ok ... boot ready title N ms`; red on a SCRIPT ERROR, an early exit or no ready line in `--timeout` (600 s). Headless draws nothing, so main.gd prints the line there without waiting for a drawn frame, and a release template prints it as it comes only because project.godot sets `run/flush_stdout_on_print.pc` for desktop builds (without it a Linux and a mac build sat 600 s with empty logs). Locally `tools/heavy.sh tools/boot-check.sh build/linux/UNSPENT.x86_64`; the user data is a fresh folder.
- release `.github/workflows/release.yml` (a `v*` tag, or `gh workflow run release.yml --ref BRANCH -f version=X` once the file is on main; before that GitHub answers 404, and a branch proves it with a test-only tag `v0.0.0-test.N`, deleted after with its draft): exports all four on ubuntu from `--config=release`, boots each on its own OS (boot-check on ubuntu, windows, macos; `tools/web.sh --boot-only --swiftshader` for the web), then a DRAFT release `vX` with the zips and their `.build.json`. Proof: every job green, `gh release view vX` says `draft=true`; delete a test draft after (`gh release delete vX --yes`). The Linux zip boots here: `tools/heavy.sh tools/gpu.sh run/UNSPENT.x86_64 -- --scene=title --shot=/abs/title.png`. Signing runs only with the owner's secrets (the workflow header names them); it has never run.
- tour `tools/tour.sh`, run bare, boots with its header's options and takes the header's `TOUR_TIMEOUT` and `TOUR_FIXED_FPS` where the shell set none (`tools/_tour_args.sh`): `tools/test.sh test_tour_header`; `tools/tour.sh tours/home-coast.tour` prints `tour env: TOUR_TIMEOUT=600 (from its header)`. A tour in tours/ whose header runs only another is refused; a copy anywhere else (a scratchpad probe) runs with a `tour note:` line. A header's `sweep: skip, WHY` line keeps tour.sh off it with that reason and makes `tools/tour-sweep.sh` print `SKIP name (WHY)` (tours/degrade_fit.tour, Compatibility-only). Off macOS its hidden window, and shot.sh's, run with vsync off (`focus_frame_flags`, tools/_focus.sh). With it on, the compositor presented the one-pixel window about once a second, and a fixed-step `wait 3.0` took 180 s against about 2 s now: its log's `fps=` reads near 90, not 1.
- web `tools/web.sh`: exports and boots the web build in headless Chromium.
- shard-times `tools/shard-times.sh RUN_ID` (or `--logs F...`): rebuilds `tests/shard_times.txt` from a gate run's `file-time PATH MS` lines (each file's shard run plus its costs and played reruns) and prints the eight shards the table makes; `tests/run.gd` shards by it, longest first onto the lightest shard (`shard_of`, `tools/test.sh test_shard_of`). Refresh it after a run whose shards came out uneven.
- sweep `tools/sweep.sh` (`tools/gd/sweep.gd`): every weapon against every common machine and the wall crowds, over the shoulder; `--reader=human[:SEED]` judges balance, `--crowd=N`, `--singles|--crowds`; a measurement, never a gate, ~10 min, killed at `SWEEP_TIMEOUT`. Quick: `tools/sweep.sh --weapons=knife --machines=cutter`.
  - `--programs` over a tour fails on any GL program first drawn after an `echo event` (a freeze a player meets); `--cold` builds every program as on a first visit.
  - Every run fails on a GL program the browser refuses (`web FAILED: GL program N …`; GLSL kept as `shots/export/<out>-glfail-pN.{vs,fs}.glsl`; first three draws checked with getError, `tools/web/web.mjs`).
  - A threaded build's page sizes the engine's worker pool from the machine's cores (`src/boot/shell.html`, at most `POOL_MOST`): every run prints `boot pool N workers (C cores)` and fails without it. With `--verbose` the island's raise says what it took (`realm surface raised in N ms`, and `realm warm surface: {...}` for its warm-up).
- preflight `tools/preflight.sh`: the whole-tree rule tests (prop identity, whole-world readers, feature map, tour claims, worker types, room kinds), .uid and feature-map checks, ~90 s; red on any `WorldProp == WorldProp`. Then `tools/shaders.sh` through heavy.sh. `--ci` sends the tests to GitHub's runners through `tools/ci-test.sh` (four parts, the pushed branch, which must be HEAD) and keeps only the shaders here.
- ci-test `tools/ci-test.sh FILTER [--ref B] [--parts N] [--repeat N] [--fixed-fps N] [--same]`: dispatches `.github/workflows/test.yml` on origin's head of the branch, waits, prints each part's FAIL and `passed,` lines and `ci-test: success`, exit 0 only when every part is green (exit 0, a summary, no SCRIPT ERROR/LOAD FAIL). Check: `tools/ci-test.sh test_world_stamp --parts 1` prints `part 0 round 1 | ... passed,` and `ci-test: success`; a filter naming a failing test exits 1 with its FAIL line.
- heavy and gpu: `tools/heavy.sh CMD` waits for a slot in claude-core's box-wide pool (`~/.claude/claude-core/bin/heavy --status`), then for one of this game's own; `tools/gpu.sh CMD` holds the box's one GPU lease (`~/.claude/claude-core/bin/gpu --status`, `journalctl -t box-gpu`) and draws in a private Xvfb. Stack them heavy outside, gpu inside: `tools/heavy.sh tools/gpu.sh tools/tour.sh T`; `tools/tour-sweep.sh` does so per tour. Proof: a tour's run.log names `Vulkan ... RADV`, never `llvmpipe`, and the lease's release line says `gpu=True`.
- shaders `tools/shaders.sh` (`tools/gd/shaders.gd`): every `*.gdshader` under src and the shaders built in code (MobFx's marks, the doors' iris) compiled and drawn by the real renderer, ~10 s warm; red on any `SHADER ERROR`, which the gate's dummy renderer never prints. A cold shader cache can hold its exit for minutes (`SHADERS_TIMEOUT`, 300 s scaled by load).

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
