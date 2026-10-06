# World generation

Growing a world from a seed.

<!-- covers: job:worldgen -->

## Sub-features

- worldgen `src/core/world_gen.gd`: `tools/map.sh --seed=7` (top-down map).
- Plan and sections: `WorldGen.plan` runs every stage up to the surface, `begin_sections` + `section(c, core)` lay one section's surface, `finish` the rest; `generate` = plan + one window + finish. `tools/test.sh test_surface_sections`: a 512 world in sixteen sections, any order, on the worker pool, byte for byte the whole world's.
- Works as rows: `GenWorks._work` composes each work from its row alone; `tools/test.sh test_works_rows` compares in-world and alone.
- World cache `src/boot/world_cache.gd`: `BootWorld.world` (every game, tour and realm raise) and the tests' `Worlds.world` load a world another process already grew from `~/.cache/unspent-worlds/` (0.4 s at 1840) instead of growing it. Keyed on the md5 of every script under src, the WorldStamp, the engine, seed, size and realm; capped at 4 GB, least recently used out. `tools/test.sh test_world_cache`: a grown 1840 world kept and read back differs in nothing, and dropping any one field from the encoding goes red. A tour's log says `world cache: seed 1 at 1840 (surface) loaded in N ms`.

## How to reach it

- `tools/test.sh test_world_gen`, `tools/test.sh test_parity`.

## How to check it

`tools/map.sh --seed=7` (proof rules: README).

## Gotchas

- Anything that changes what a seed makes bumps `WorldStamp.GEN` and re-accepts parity.
- Timing worldgen through a boot or `Worlds.world`? `UNSPENT_WORLD_CACHE=off` (or `WorldCache.enabled = false` in a test about a raise in flight, as test_raise_in_background does), or a kept world stands in and the number is a load. `WorldGen.generate` itself never reads the cache.
