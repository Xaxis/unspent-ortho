# World places

Realms and portals, the rooms behind a house's door, landmarks and caches, the hush, ruins, regional holds.

<!-- covers: system:20_realms, system:21_doors, system:22_landmarks, system:23_hush, system:23_ruins, system:24_holds -->

## Sub-features

- 20_realms `src/systems/20_realms.gd`: `tools/tour.sh tours/realms.tour`.
  - A shaft's start is short: the new world is readied on the raise's worker (`src/core/realm/realm_warm.gd`) and only the chunk underfoot is built on arrival: `tools/test.sh test_crossing_start`; web `tools/web.sh --tour=tours/crossing.tour --crossing=20`.
  - Shafts sited on the land alone and held clear (`Portals.site`), so 2029 opens them on the present's tiles: `tools/test.sh test_every_seed_s_shafts`; a still beside one with `--realm=era`.
- 23_hush `src/systems/23_hush.gd` + `src/core/hush_sites.gd` (docs/HUSH.md): `tools/tour.sh tours/hush.tour --seed=7 --hour=11 --weather=clear:0` (`near hush_ring`); `tools/test.sh test_hush_sites`.
  - The quiet (`--hush=always`): `tools/tour.sh tours/hush-quiet.tour --seed=7 --hour=11 --weather=fog:0.6:wind=0.9 --hush=always`; `tools/test.sh test_hush`.
  - Stones turned while off screen: `tools/tour.sh tours/hush-stones.tour --seed=7 --hour=11 --weather=clear:0` (01/02 above, 03/04 shoulder); `tools/test.sh test_hush,test_props_rebake`.
  - Nobody's lights (fog nights; `await nobodys_light`, `near nobodys_light`): `tools/tour.sh tours/hush-lights.tour --seed=7 --hour=23 --weather=fog:0.7`.
  - The rings answer (once a night; `await ring_answering`, `near ring_answer`): `tools/tour.sh tours/hush-answer.tour --seed=7 --hour=23 --weather=clear:0`.
- 21_doors `src/systems/21_doors.gd` (`src/core/interior/`, `src/models/interior/`): `tools/tour.sh tours/house.tour --seed=4 --hour=11 --weather=clear:0`, a coast door, its room in both views, out again.
  - Shaders outlive the visit (21_doors `_keep_shaders`): `tools/test.sh test_room_shaders_kept`; web, a room entered twice builds no program the second time (`tools/web.sh --programs`).
  - Everything a room draws has a material, its grass the outside's (`WorldView.setup_sharing`): `tools/test.sh test_room_drawn`.
  - Loot (GEAR.md §7): `tools/test.sh test_room_loot`; `tools/tour.sh tours/bay_locker.tour --seed=4 --hour=15 --weather=clear:0`, `tools/tour.sh tours/larder_safe.tour --seed=4 --hour=12.5 --weather=clear:0`.
  - Kept-by shelf: `tools/test.sh test_room_loot,test_doors:test_the_kept_by`; `tools/tour.sh tours/kept_by.tour --seed=4 --hour=15 --weather=clear:0` (`near shelf`, `thanked`).
  - Door hush (`door_hush.gd`; SoundEffects `passing_light|mid|heavy`): `tools/test.sh test_door_hush`; `tools/tour.sh tours/door-hush.tour --seed=1 --hour=11 --weather=clear:0` (`unhushed`, `hushed`); listen with `tools/audio.sh passing_`.
  - Face settlement (docs/MIDDENS_ROOMS.md §2): `tools/tour.sh tours/face-hold.tour --seed=1 --hour=11 --weather=clear:0 --give=record:1`; 01/01b the mouth above and over the shoulder, 02 the plan, 03 down the sort, 03b the sort read (`desk:the_sort`), 04 up the lookout (`above`), 05 the reader at home (`near dweller`), 06 the string given, 07 its route on the map. Rules `tools/test.sh test_face_hold`; dwellers `test_dwellers`; the string `test_string_deed,test_slot_route`.
  - Container warren (docs/MIDDENS_ROOMS.md §1): `tools/tour.sh tours/container-warren.tour --seed=1 --hour=11 --weather=clear:0`; 01 the end in the face, 02 the run from above, 02b the manifest (`wall:manifest`), 03 down the run, 05-07 up a ladder and back (`below`, `above`, `below`; `near ladder`, `near ladder_top`). Rules `tools/test.sh test_container_warren,test_slot_doors`.
  - Buckled bay (crouch under, stand stopped; real keys both ways): `tools/test.sh test_warren_bay_in_game`; a machine taller than the room held at its lip: `tools/test.sh test_machines_under_roofs`; `tools/tour.sh tours/warren-bay.tour --seed=1 --hour=11 --weather=clear:0`.
  - Tower crawl out onto the plateau (`SlotDoors.exit_beside`, `out_back`): `tools/tour.sh tours/warren-tower.tour --seed=1 --hour=11 --weather=clear:0`.
- 22_landmarks `src/systems/22_landmarks.gd`: `tools/tour.sh tours/landmarks.tour`.
- 23_ruins `src/systems/23_ruins.gd` (ruin walls stop a body, `RuinWalls`): `tools/test.sh test_ruin_walls`.
- 24_holds `src/systems/24_holds.gd`: `tools/tour.sh tours/region.tour`; barricades in the world's material: `tools/test.sh test_hold_drawn`.

## How to reach it

Room tours, each a door and its room from above and over the shoulder. Each runs
`tools/tour.sh tours/NAME.tour --seed=4 --hour=15 --weather=clear:0` unless its options are shown:
- `rooms`: three rooms by who lives there (`near door:fisher|tinker|keeper`); no two frames the same room.
- `hall` (`--seed=4 --hour=11 --weather=clear:0 --rooms=empty`): a depot hatch and the weapons hall.
- `hall-fight` (`--seed=4 --hour=11 --weather=clear:0`): residents turn, a blow lands, the warden's arrest puts you out.
- `hall-guard` (`--seed=4 --hour=11 --weather=clear:0`): a strongbox shut while the warden stands, turret sight lines.
- `hall-sneak` (`--seed=4 --hour=11 --weather=clear:0`): crouched to a strongbox unarrested (`walkto strongbox` picks a way out of sight).
- `bunker`: the hatch among the cast stones and the bunker, by the lantern.
- `roundhouse`: crags roundhouse (`form:ID`), by day, by its fire at night.
- `stilt`: drowned city stilt house over the water.
- `lobby`: metropolis infill and the lived-in tower lobby.
- `cliff`: mesas cut room dug into the rock.
- `hulk`: drowned city hulk and its hold.
- `rooted`: Green Towers shell, the floor the forest came through.
- `tenement`: slums stair hall, numbered doors, one flat open (`near thing:KIND`).
- `maintenance`: machine city service bay, dark but for standby points, and a lived-in niche.
- `foundry`: the burning's foundry, the line pouring, the racks.
- `foundry-sneak`: crouched behind the racks to the store.
- `foundry-light`: a sweep unshot, then shot in the pour's light (`InteriorKind.dark`, `glare`, `screens`, `near behind:KIND`); `tools/test.sh test_foundry`.
- `datahall`: server fields' data hall, racks, console and watcher, sentries, tape room.
- `datahall-hum`: to the tape room upright, unnoticed; the hum (`InteriorKind.hush`) in `tools/test.sh test_data_hall`.
- `laid_table` (`--seed=4 --hour=12.5 --weather=clear:0`): grey orchards grower's house, a meal at `near hatch`; `tools/test.sh test_laid_table`.
- `sawhall` (`--seed=4 --hour=12 --weather=clear:0`): pinewood saw hall on the shift, lit and loud.
- `sawhall-night` (`--seed=4 --hour=23 --weather=clear:0`): at curfew, haulers asleep in docks, crouched to the kiln unwoken (`InteriorKind.shift`, `MobState.asleep`).
- `sawhall-wake` (`--seed=4 --hour=23 --weather=clear:0`): upright, a sleeper wakes; `tools/test.sh test_saw_hall`.
- `frozenhold` (`--seed=4 --hour=23 --weather=clear:0 --give=driftwood:3`): frost sea trawler's hold, stove relit (`near stove`); `tools/test.sh test_frozen_hold`.
- `homes`: a landscape with no room of its own opens the cottage's bones in its colours (`BiomeDef.home`); `tools/test.sh test_homes`.
- `homes-three`, `homes-three-b`: homes by household (`door:HOUSEHOLD`).
- `homes-four`, `homes-forms`, `homes-forms-b`: more households, and homes behind forms with no room of their own.
- `squat`: a machine city squat, the crawl out back (`near crawl`, `out_back`); `tools/test.sh test_squat`.
- `homes-words`: homes' words at `slot:wall:home`; dealing in `tools/test.sh test_rooms`.

## How to check it

`tools/tour.sh tours/realms.tour` (proof rules: README).

## Gotchas

- Stage by name (`place NAME`, `near KIND`), never by a copied coordinate.
- A door's cost is `tests/interior/test_doors.gd` (swap in and out, best and worst of three, fails a stall over 250 ms). The house tour's 02 and 04: the patch of sun on the boards must have moved.
- `tests/interior/test_interiors.gd` walks from every door on seed 4 to its hearth, table and bed, and holds that every house opens on its own form's room (`BiomeDef.interiors` `form:ID`, before `house`).
- Indoors, the systems that keep the outside sleep (`indoors(inside)`, 20_realms); a new system without `indoors` is still correct, only slower through a door.
