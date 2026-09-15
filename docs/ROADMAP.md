# Roadmap

Milestones end in something a person can play. Work inside a milestone runs as
parallel packages, each in its own worktree with its own directories, merged
one at a time behind `tools/check.sh`.

## M0 — Foundation (done, 2026-09-15)

Godot 4.7 project; seeded coast; orthographic 640x360 pixel look with hard
shadows and ink outlines; walkable; headless tests; 2-second real-frame
screenshots; gallery; world map; the gate in ~11 s; contracts for parallel work.

## M1 — The core loop (in progress)

Goal: wake on a beautiful coast, take from it, make a better tool, meet a machine
and beat it by finding its working side, survive a night, walk into a second
country and feel the land change.

| # | Package | Owns | Delivers |
|---|---|---|---|
| 1 | worldgen | `src/core/world_gen*`, ground/country/prop kinds, map tool | 384+ world, balanced countries as a journey, ecotone blend field, rivers, lakes, roads between villages, stations, landmarks, all prop kinds placed |
| 2 | landscape | terrain mesher, ground colours, world/water/outline shaders, world view, camera, prop models, decor | every country beautiful and distinct, ecotones, cliffs with strata, animated shore and rivers, dense instanced decor with wind, models for all 32 prop kinds |
| 3 | sky | sky light, `sky.gdshaderinc`, weather core and visuals, night lights | day/night per the source numbers, regional light tint, weather spells with particles and cloud shadows, lamps and the player's lantern |
| 4 | machines | `src/models/machines/` | the 12 machines, FOUND idiom, working parts, poses |
| 5 | characters | `person_model.gd`, `src/models/people/`, `src/models/animals/` | player and people with builds, looks, salvage kit, held tools, action animations; animals |
| 6 | fight | `src/core/fight/`, `src/core/mobs/`, player, mobs, roster | real-time swing/dodge/wind/health, plate side, grip, outcomes, spawning, senses, moods, approaches, hit feel |
| 7 | survival | `src/core/survival/`, items, recipes, crafting, inventory | taking from the world with tools and hardness, wear, regrowth, stations and recipes, campfires, eating, sleeping, load and hunger slowing you |
| 8 | ui | `src/ui/` | pixel font, notebook HUD and screens (inventory, crafting, map, pause, title), messages |
| 9 | audio | `src/audio/` | procedural beds per country, machine loops, SFX for every event, sparse music, the mix |

## M2 — Depth (next)

Interiors, NPCs with work and trade by barter, landmarks worth walking to,
machines' second acts and the four verbs fully felt, saves, settings, web export.

## M3 — The story (after the loop is fun)

A new story written from nothing (the old fiction is retired): what happened, who
is left, what the player wants, and why it is worth walking the whole coast.
