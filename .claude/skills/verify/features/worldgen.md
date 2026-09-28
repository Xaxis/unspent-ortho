# World generation

Growing a world from a seed.

<!-- covers: job:worldgen -->

## Sub-features

- worldgen `src/core/world_gen.gd`: `tools/map.sh --seed=7` (top-down map).
- Plan and sections: `WorldGen.plan` runs every stage up to the surface, `begin_sections` + `section(c, core)` lay one section's surface, `finish` the rest; `generate` = plan + one window + finish. `tools/test.sh test_surface_sections`: a 512 world in sixteen sections, any order, on the worker pool, byte for byte the whole world's.
- Works as rows: `GenWorks._work` composes each work from its row alone; `tools/test.sh test_works_rows` compares in-world and alone.

## How to reach it

- `tools/test.sh test_world_gen`, `tools/test.sh test_parity`.

## How to check it

`tools/map.sh --seed=7` (proof rules: README).

## Gotchas

- Anything that changes what a seed makes bumps `WorldStamp.GEN` and re-accepts parity.
